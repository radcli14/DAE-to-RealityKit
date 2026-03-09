//
//  ColladaParser.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import XMLCoder
import simd

enum ColladaParserError: Error {
    case decodeFailed(Error)
}

struct ColladaParser {

    func parse(data: Data) throws -> Collada.RawScene {
        let decoder = XMLDecoder()
        decoder.trimValueWhitespaces = false
        decoder.shouldProcessNamespaces = true

        do {
            let collada = try decoder.decode(Collada.self, from: data)
            let up = UpAxis.from(collada.asset?.upAxis)
            let rootTransform = AxisConversion.toYUp(from: up)

            let geometryMap = buildGeometryMap(from: collada)
            let materialColorMap = buildMaterialColorMap(from: collada)

            let nodes = buildNodes(
                from: collada,
                rootTransform: rootTransform,
                geometryMap: geometryMap,
                materialColorMap: materialColorMap
            )
            return Collada.RawScene(rootNodes: nodes)
        } catch {
            throw ColladaParserError.decodeFailed(error)
        }
    }

    // MARK: - Geometry Map

    private func buildGeometryMap(from collada: Collada) -> [String: Collada.Geometry] {
        guard let lib = collada.libraryGeometries else { return [:] }
        var map: [String: Collada.Geometry] = [:]
        for geo in lib.geometries {
            if let geoId = geo.geometryId {
                map[geoId] = geo
            }
        }
        return map
    }

    // MARK: - Material Color Map

    private func buildMaterialColorMap(from collada: Collada) -> [String: Collada.ColorRGBA] {
        var effectColorMap: [String: Collada.ColorRGBA] = [:]
        if let effects = collada.libraryEffects?.effects {
            for effect in effects {
                if let eId = effect.effectId,
                   let color = effect.profileCommon?.technique?.diffuseColor {
                    effectColorMap[eId] = color
                }
            }
        }

        var materialColorMap: [String: Collada.ColorRGBA] = [:]
        if let materials = collada.libraryMaterials?.materials {
            for mat in materials {
                guard let matId = mat.materialId,
                      let effectUrl = mat.instanceEffect?.url else { continue }
                let effectId = String(effectUrl.dropFirst())
                if let color = effectColorMap[effectId] {
                    materialColorMap[matId] = color
                }
            }
        }
        return materialColorMap
    }

    // MARK: - Node Hierarchy

    private func buildNodes(
        from collada: Collada,
        rootTransform: simd_float4x4,
        geometryMap: [String: Collada.Geometry],
        materialColorMap: [String: Collada.ColorRGBA]
    ) -> [Collada.RawNode] {
        guard let lib = collada.libraryVisualScenes else { return [] }
        let sceneId = collada.scene?.instanceVisualScene?.url
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let visualScene: Collada.VisualScene?
        if let id = sceneId {
            visualScene = lib.visualScenes.first { $0.visualSceneId == id }
        } else {
            visualScene = lib.visualScenes.first
        }
        guard let vs = visualScene else { return [] }
        return vs.nodes.map { node in
            makeRawNode(
                node,
                parentWorldTransform: rootTransform,
                geometryMap: geometryMap,
                materialColorMap: materialColorMap
            )
        }
    }

    private func makeRawNode(
        _ node: Collada.Node,
        parentWorldTransform: simd_float4x4,
        geometryMap: [String: Collada.Geometry],
        materialColorMap: [String: Collada.ColorRGBA]
    ) -> Collada.RawNode {
        let local = localMatrix(from: node)
        let worldTransform = parentWorldTransform * local

        var mesh: Collada.RawMesh? = nil
        var diffuseColor: Collada.ColorRGBA? = nil
        if let instances = node.instanceGeometry {
            for inst in instances {
                let geoId = String(inst.url.dropFirst())
                if let geometry = geometryMap[geoId], let colladaMesh = geometry.mesh {
                    mesh = extractMesh(from: colladaMesh)
                }
                if let binds = inst.bindMaterial?.techniqueCommon?.instanceMaterials {
                    for bind in binds {
                        let matId = String(bind.target.dropFirst())
                        if let color = materialColorMap[matId] {
                            diffuseColor = color
                            break
                        }
                    }
                }
            }
        }

        let children = (node.children ?? []).map {
            makeRawNode(
                $0,
                parentWorldTransform: worldTransform,
                geometryMap: geometryMap,
                materialColorMap: materialColorMap
            )
        }

        return Collada.RawNode(
            name: node.name ?? node.nodeId,
            localTransform: local,
            mesh: mesh,
            diffuseColor: diffuseColor,
            children: children
        )
    }

    // MARK: - Transform

    private func localMatrix(from node: Collada.Node) -> simd_float4x4 {
        if let m = node.matrix?.values, m.count == 16 {
            // COLLADA matrices are row-major; simd_float4x4 is column-major
            let f = m.map { Float($0) }
            return simd_float4x4(columns: (
                SIMD4(f[0], f[4], f[8],  f[12]),
                SIMD4(f[1], f[5], f[9],  f[13]),
                SIMD4(f[2], f[6], f[10], f[14]),
                SIMD4(f[3], f[7], f[11], f[15])
            ))
        }

        // Compose from TRS: result = T * R * S
        var result = matrix_identity_float4x4

        if let t = node.translate?.first?.values, t.count >= 3 {
            result.columns.3 = SIMD4(Float(t[0]), Float(t[1]), Float(t[2]), 1)
        }

        if let rotations = node.rotate {
            for r in rotations {
                let v = r.values
                if v.count >= 4 {
                    let axis = SIMD3(Float(v[0]), Float(v[1]), Float(v[2]))
                    let angle = Float(v[3]) * .pi / 180.0
                    result = result * rotationMatrix(axis: axis, angle: angle)
                }
            }
        }

        if let s = node.scale?.first?.values, s.count >= 3 {
            let sx = Float(s[0]), sy = Float(s[1]), sz = Float(s[2])
            let scaleMatrix = simd_float4x4(
                SIMD4(sx, 0, 0, 0),
                SIMD4(0, sy, 0, 0),
                SIMD4(0, 0, sz, 0),
                SIMD4(0, 0, 0, 1)
            )
            result = result * scaleMatrix
        }

        return result
    }

    private func rotationMatrix(axis: SIMD3<Float>, angle: Float) -> simd_float4x4 {
        let a = simd_normalize(axis)
        let c = cos(angle)
        let s = sin(angle)
        let t: Float = 1 - c
        let x = a.x, y = a.y, z = a.z
        return simd_float4x4(
            SIMD4(t*x*x + c,   t*x*y + s*z, t*x*z - s*y, 0),
            SIMD4(t*x*y - s*z, t*y*y + c,   t*y*z + s*x, 0),
            SIMD4(t*x*z + s*y, t*y*z - s*x, t*z*z + c,   0),
            SIMD4(0, 0, 0, 1)
        )
    }

    // MARK: - Mesh Extraction

    private func extractMesh(from colladaMesh: Collada.Geometry.Mesh) -> Collada.RawMesh? {
        var sourceMap: [String: Collada.Geometry.Source] = [:]
        for src in colladaMesh.sources {
            if let srcId = src.sourceId {
                sourceMap["#\(srcId)"] = src
            }
        }

        var vertexSourceRef: String? = nil
        if let verts = colladaMesh.vertices {
            if let posInput = verts.inputs.first(where: { $0.semantic == "POSITION" }) {
                vertexSourceRef = posInput.source
            }
            if let vid = verts.id {
                sourceMap["#\(vid)"] = sourceMap[vertexSourceRef ?? ""]
            }
        }

        let primitives: [(inputs: [Collada.Geometry.Input], indices: [Int])]
        if let tris = colladaMesh.triangles, !tris.isEmpty {
            primitives = tris.map { ($0.inputs, $0.p.values) }
        } else if let polys = colladaMesh.polylist, !polys.isEmpty {
            primitives = polys.map { poly in
                let triangulated = triangulatePolylist(
                    vcount: poly.vcount?.values ?? [],
                    p: poly.p.values,
                    inputCount: poly.inputs.count
                )
                return (poly.inputs, triangulated)
            }
        } else {
            return nil
        }

        var allPositions: [SIMD3<Float>] = []
        var allNormals: [SIMD3<Float>] = []
        var allUVs: [SIMD2<Float>] = []
        var allIndices: [UInt32] = []
        var hasNormals = false
        var hasUVs = false

        for (inputs, pValues) in primitives {
            let inputCount = inputs.count
            guard inputCount > 0 else { continue }
            let vertexCount = pValues.count / inputCount

            var positionInput: (offset: Int, source: Collada.Geometry.Source)?
            var normalInput: (offset: Int, source: Collada.Geometry.Source)?
            var texcoordInput: (offset: Int, source: Collada.Geometry.Source)?

            for input in inputs {
                let offset = input.offset ?? 0
                let ref = input.source

                let resolvedSource: Collada.Geometry.Source?
                if input.semantic == "VERTEX" {
                    resolvedSource = sourceMap[vertexSourceRef ?? ""]
                } else {
                    resolvedSource = sourceMap[ref]
                }

                guard let src = resolvedSource else { continue }

                switch input.semantic {
                case "VERTEX":
                    positionInput = (offset, src)
                case "NORMAL":
                    normalInput = (offset, src)
                    hasNormals = true
                case "TEXCOORD":
                    texcoordInput = (offset, src)
                    hasUVs = true
                default:
                    break
                }
            }

            let baseIndex = UInt32(allPositions.count)

            for v in 0..<vertexCount {
                let baseOffset = v * inputCount

                if let pos = positionInput,
                   let floats = pos.source.floatArray?.values {
                    let idx = pValues[baseOffset + pos.offset]
                    let stride = pos.source.techniqueCommon?.accessor.stride ?? 3
                    let i = idx * stride
                    if i + 2 < floats.count {
                        allPositions.append(SIMD3(floats[i], floats[i+1], floats[i+2]))
                    }
                }

                if let norm = normalInput,
                   let floats = norm.source.floatArray?.values {
                    let idx = pValues[baseOffset + norm.offset]
                    let stride = norm.source.techniqueCommon?.accessor.stride ?? 3
                    let i = idx * stride
                    if i + 2 < floats.count {
                        allNormals.append(SIMD3(floats[i], floats[i+1], floats[i+2]))
                    }
                }

                if let tex = texcoordInput,
                   let floats = tex.source.floatArray?.values {
                    let idx = pValues[baseOffset + tex.offset]
                    let stride = tex.source.techniqueCommon?.accessor.stride ?? 2
                    let i = idx * stride
                    if i + 1 < floats.count {
                        allUVs.append(SIMD2(floats[i], floats[i+1]))
                    }
                }

                allIndices.append(baseIndex + UInt32(v))
            }
        }

        guard !allPositions.isEmpty else { return nil }

        return Collada.RawMesh(
            positions: allPositions,
            normals: hasNormals ? allNormals : nil,
            uvs: hasUVs ? allUVs : nil,
            indices: allIndices
        )
    }

    private func triangulatePolylist(vcount: [Int], p: [Int], inputCount: Int) -> [Int] {
        var result: [Int] = []
        var offset = 0
        for count in vcount {
            for i in 1..<(count - 1) {
                for j in 0..<inputCount {
                    result.append(p[offset + j])
                }
                for j in 0..<inputCount {
                    result.append(p[offset + i * inputCount + j])
                }
                for j in 0..<inputCount {
                    result.append(p[offset + (i + 1) * inputCount + j])
                }
            }
            offset += count * inputCount
        }
        return result
    }
}

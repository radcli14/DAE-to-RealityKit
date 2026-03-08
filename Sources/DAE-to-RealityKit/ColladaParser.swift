//
//  ColladaParser.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import XMLCoder
import simd

public enum ColladaParserError: Error {
    case decodeFailed(Error)
}

public struct ColladaParser {
    public init() {}

    public func parse(data: Data) throws -> RawScene {
        let decoder = XMLDecoder()
        decoder.trimValueWhitespaces = false
        decoder.shouldProcessNamespaces = false

        do {
            let collada = try decoder.decode(Collada.self, from: data)
            let up = UpAxis.from(collada.asset?.upAxis)
            let rootTransform = AxisConversion.toYUp(from: up)

            // Index geometry sources by id for resolving instance_geometry references
            let geometryMap = buildGeometryMap(from: collada)

            // Index materials/effects for diffuse color lookup
            let materialColorMap = buildMaterialColorMap(from: collada)

            // Build node hierarchy from the visual scene referenced in <scene>
            let nodes = buildNodes(
                from: collada,
                rootTransform: rootTransform,
                geometryMap: geometryMap,
                materialColorMap: materialColorMap
            )
            return RawScene(rootNodes: nodes)
        } catch {
            throw ColladaParserError.decodeFailed(error)
        }
    }

    // MARK: - Geometry Map

    /// Maps geometry id (e.g. "link_1-mesh") to its parsed mesh sources
    private func buildGeometryMap(from collada: Collada) -> [String: Geometry] {
        guard let lib = collada.libraryGeometries else { return [:] }
        var map: [String: Geometry] = [:]
        for geo in lib.geometries {
            if let geoId = geo.geometryId {
                map[geoId] = geo
            }
        }
        return map
    }

    // MARK: - Material Color Map

    /// Maps material id to its diffuse RGBA color
    private func buildMaterialColorMap(from collada: Collada) -> [String: ColorRGBA] {
        var effectColorMap: [String: ColorRGBA] = [:]
        if let effects = collada.libraryEffects?.effects {
            for effect in effects {
                if let eId = effect.effectId,
                   let color = effect.profileCommon?.technique?.diffuseColor {
                    effectColorMap[eId] = color
                }
            }
        }

        var materialColorMap: [String: ColorRGBA] = [:]
        if let materials = collada.libraryMaterials?.materials {
            for mat in materials {
                guard let matId = mat.materialId,
                      let effectUrl = mat.instanceEffect?.url else { continue }
                let effectId = String(effectUrl.dropFirst()) // remove leading '#'
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
        geometryMap: [String: Geometry],
        materialColorMap: [String: ColorRGBA]
    ) -> [RawNode] {
        guard let lib = collada.libraryVisualScenes else { return [] }
        let sceneId = collada.scene?.instanceVisualScene?.url
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let visualScene: VisualScene?
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
        _ node: ColladaNode,
        parentWorldTransform: simd_float4x4,
        geometryMap: [String: Geometry],
        materialColorMap: [String: ColorRGBA]
    ) -> RawNode {
        let local = localMatrix(from: node)
        let worldTransform = parentWorldTransform * local

        // Resolve mesh from instance_geometry
        var mesh: RawMesh? = nil
        var diffuseColor: ColorRGBA? = nil
        if let instances = node.instanceGeometry {
            for inst in instances {
                let geoId = String(inst.url.dropFirst()) // remove '#'
                if let geometry = geometryMap[geoId], let colladaMesh = geometry.mesh {
                    mesh = extractMesh(from: colladaMesh)
                }
                // Resolve material color
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

        return RawNode(
            name: node.name ?? node.nodeId,
            localTransform: local,
            mesh: mesh,
            diffuseColor: diffuseColor,
            children: children
        )
    }

    // MARK: - Transform

    /// Build the local transform matrix for a COLLADA node
    private func localMatrix(from node: ColladaNode) -> simd_float4x4 {
        // Prefer <matrix> if present
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

        // Translation
        if let t = node.translate?.first?.values, t.count >= 3 {
            result.columns.3 = SIMD4(Float(t[0]), Float(t[1]), Float(t[2]), 1)
        }

        // Rotations (applied in order they appear in the file)
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

        // Scale
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

    /// Extract positions, normals, UVs, and triangle indices from a COLLADA mesh
    private func extractMesh(from colladaMesh: ColladaMesh) -> RawMesh? {
        // Build a source map: "#sourceId" -> Source
        var sourceMap: [String: Source] = [:]
        for src in colladaMesh.sources {
            if let srcId = src.sourceId {
                sourceMap["#\(srcId)"] = src
            }
        }

        // Resolve the VERTEX input to its actual position source
        var vertexSourceRef: String? = nil
        if let verts = colladaMesh.vertices {
            if let posInput = verts.inputs.first(where: { $0.semantic == "POSITION" }) {
                vertexSourceRef = posInput.source
            }
            // Map the vertices id so VERTEX references resolve correctly
            if let vid = verts.id {
                sourceMap["#\(vid)"] = sourceMap[vertexSourceRef ?? ""]
            }
        }

        // Process triangles or polylist primitives
        let primitives: [(inputs: [Input], indices: [Int])]
        if let tris = colladaMesh.triangles, !tris.isEmpty {
            primitives = tris.map { ($0.inputs, $0.p.values) }
        } else if let polys = colladaMesh.polylist, !polys.isEmpty {
            // Convert polylists to triangle fans
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

        // Merge all primitives into a single mesh
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

            // Identify which inputs correspond to what
            var positionInput: (offset: Int, source: Source)?
            var normalInput: (offset: Int, source: Source)?
            var texcoordInput: (offset: Int, source: Source)?

            for input in inputs {
                let offset = input.offset ?? 0
                let ref = input.source

                // For VERTEX semantic, resolve through the vertices element
                let resolvedSource: Source?
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

                // Position
                if let pos = positionInput,
                   let floats = pos.source.floatArray?.values {
                    let idx = pValues[baseOffset + pos.offset]
                    let stride = pos.source.techniqueCommon?.accessor.stride ?? 3
                    let i = idx * stride
                    if i + 2 < floats.count {
                        allPositions.append(SIMD3(floats[i], floats[i+1], floats[i+2]))
                    }
                }

                // Normal
                if let norm = normalInput,
                   let floats = norm.source.floatArray?.values {
                    let idx = pValues[baseOffset + norm.offset]
                    let stride = norm.source.techniqueCommon?.accessor.stride ?? 3
                    let i = idx * stride
                    if i + 2 < floats.count {
                        allNormals.append(SIMD3(floats[i], floats[i+1], floats[i+2]))
                    }
                }

                // UV
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

        return RawMesh(
            positions: allPositions,
            normals: hasNormals ? allNormals : nil,
            uvs: hasUVs ? allUVs : nil,
            indices: allIndices
        )
    }

    /// Triangulate a polylist by treating each polygon as a triangle fan
    private func triangulatePolylist(vcount: [Int], p: [Int], inputCount: Int) -> [Int] {
        var result: [Int] = []
        var offset = 0
        for count in vcount {
            // Fan triangulation: vertex 0, i, i+1
            for i in 1..<(count - 1) {
                for j in 0..<inputCount {
                    result.append(p[offset + j]) // vertex 0
                }
                for j in 0..<inputCount {
                    result.append(p[offset + i * inputCount + j]) // vertex i
                }
                for j in 0..<inputCount {
                    result.append(p[offset + (i + 1) * inputCount + j]) // vertex i+1
                }
            }
            offset += count * inputCount
        }
        return result
    }
}

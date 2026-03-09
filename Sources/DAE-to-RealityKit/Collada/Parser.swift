//
//  ColladaParser.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import XMLCoder
import simd

extension Collada {
    /// Parses COLLADA 1.4.1 XML data into an intermediate scene representation.
    ///
    /// The parser decodes the XML into ``Collada`` model structures using `XMLDecoder`,
    /// then transforms the decoded data into a ``Collada/Parser/Scene`` containing
    /// a hierarchy of ``Collada/Parser/Node`` objects ready for conversion to RealityKit entities.
    ///
    /// ## Usage
    /// ```swift
    /// let parser = Collada.Parser()
    /// let scene = try parser.parse(data: xmlData)
    /// let entity = scene.rootNodes.first?.buildEntity()
    /// ```
    struct Parser {

        /// Errors that can occur during COLLADA parsing.
        enum Error: Swift.Error {
            /// The XML data could not be decoded into the ``Collada`` model structure.
            case decodeFailed(Swift.Error)
        }

        /// Parses COLLADA XML data into an intermediate ``Scene``.
        ///
        /// Decodes the XML, resolves material and texture references, builds the node
        /// hierarchy with transforms, and extracts mesh geometry.
        /// - Parameter data: Raw XML data of the COLLADA document.
        /// - Returns: A ``Scene`` containing the parsed node hierarchy.
        /// - Throws: ``Error/decodeFailed(_:)`` if XML decoding fails.
        func parse(data: Data) throws -> Scene {
            let decoder = XMLDecoder()
            decoder.trimValueWhitespaces = false
            decoder.shouldProcessNamespaces = true

            do {
                let collada = try decoder.decode(Collada.self, from: data)
                //let up = UpAxis.from(collada.asset?.upAxis)
                //let rootTransform = AxisConversion.toYUp(from: up)

                let materialMap = buildMaterialMap(from: collada)

                let nodes = buildNodes(
                    from: collada,
                    materialMap: materialMap
                )
                return Scene(rootNodes: nodes)
            } catch {
                throw Error.decodeFailed(error)
            }
        }

    // MARK: - Material Map

    /// Builds a mapping from material IDs to resolved ``Material`` values.
    ///
    /// Walks `<library_effects>` to extract shading properties and resolve texture paths,
    /// then maps each `<material>` ID to its effect's resolved material.
    private func buildMaterialMap(
        from collada: Collada,
    ) -> [String: Material] {
        // Build effect → Material map
        var effectMap: [String: Material] = [:]
        if let effects = collada.libraryEffects?.effects {
            for effect in effects {
                guard let eId = effect.effectId,
                      let technique = effect.profileCommon?.technique else { continue }

                // Resolve texture sampler → surface → image → file path
                var texturePath: String? = nil
                if let texRef = technique.diffuseTexture {
                    texturePath = resolveTexturePath(
                        samplerSid: texRef.texture,
                        newparams: effect.profileCommon?.newparams,
                        imageMap: collada.imageMap
                    )
                }

                effectMap[eId] = Material(
                    diffuseColor: technique.diffuseColor,
                    diffuseTexturePath: texturePath,
                    emissionColor: technique.emissionColor,
                    ambientColor: technique.ambientColor,
                    specularColor: technique.specularColor,
                    shininess: technique.shininess,
                    transparency: technique.transparency
                )
            }
        }

        // Map material ids to their resolved effect's Material
        var materialMap: [String: Material] = [:]
        if let materials = collada.libraryMaterials?.materials {
            for mat in materials {
                guard let matId = mat.materialId,
                      let effectUrl = mat.instanceEffect?.url else { continue }
                let effectId = String(effectUrl.dropFirst())
                if let rawMat = effectMap[effectId] {
                    materialMap[matId] = rawMat
                }
            }
        }
        return materialMap
    }

    /// Resolves the COLLADA texture pipeline: sampler → surface → image → file path.
    ///
    /// Follows the chain of `<newparam>` declarations to resolve a texture reference:
    /// 1. Find the `<sampler2D>` param matching `samplerSid`
    /// 2. Get the sampler's `<source>` → surface `sid`
    /// 3. Find the `<surface>` param → get `<init_from>` image ID
    /// 4. Look up the image ID in the image map to get the file path
    private func resolveTexturePath(
        samplerSid: String,
        newparams: [Collada.Effect.NewParam]?,
        imageMap: [String: String]
    ) -> String? {
        guard let params = newparams else { return nil }

        // Find sampler newparam → get its source (surface sid)
        let sampler = params.first { $0.sid == samplerSid }
        guard let surfaceSid = sampler?.sampler2D?.source else { return nil }

        // Find surface newparam → get its init_from (image id)
        let surface = params.first { $0.sid == surfaceSid }
        guard let imageId = surface?.surface?.initFrom else { return nil }

        // Look up image id in the image map
        return imageMap[imageId]
    }

    // MARK: - Node Hierarchy

    /// Builds the top-level node array from the active visual scene.
    ///
    /// Identifies which `<visual_scene>` to use (via `<scene>` → `<instance_visual_scene>`),
    /// then recursively converts each COLLADA node to a ``Node``, applying the root
    /// axis-conversion transform as the parent of all top-level nodes.
    private func buildNodes(
        from collada: Collada,
        materialMap: [String: Material]
    ) -> [Node] {
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
            makeNode(
                node,
                parentWorldTransform: collada.rootTransform,
                geometryMap: collada.geometryMap,
                materialMap: materialMap
            )
        }
    }

    /// Recursively converts a ``Collada/Node`` into a ``Collada/Parser/Node``.
    ///
    /// Computes the local transform, resolves geometry and material bindings,
    /// and recurses into child nodes.
    private func makeNode(
        _ node: Collada.Node,
        parentWorldTransform: simd_float4x4,
        geometryMap: [String: Collada.Geometry],
        materialMap: [String: Material]
    ) -> Node {
        let local = localMatrix(from: node)
        let worldTransform = parentWorldTransform * local

        var mesh: Mesh? = nil
        var nodeMaterial: Material? = nil
        if let instances = node.instanceGeometry {
            for inst in instances {
                let geoId = String(inst.url.dropFirst())
                if let geometry = geometryMap[geoId], let colladaMesh = geometry.mesh {
                    mesh = extractMesh(from: colladaMesh)
                }
                if let binds = inst.bindMaterial?.techniqueCommon?.instanceMaterials {
                    for bind in binds {
                        let matId = String(bind.target.dropFirst())
                        if let mat = materialMap[matId] {
                            nodeMaterial = mat
                            break
                        }
                    }
                }
            }
        }

        let children = (node.children ?? []).map {
            makeNode(
                $0,
                parentWorldTransform: worldTransform,
                geometryMap: geometryMap,
                materialMap: materialMap
            )
        }

        return Node(
            name: node.name ?? node.nodeId,
            localTransform: local,
            mesh: mesh,
            material: nodeMaterial,
            children: children
        )
    }

    // MARK: - Transform

    /// Computes the local transform matrix for a COLLADA node.
    ///
    /// If the node has a `<matrix>` element, converts it from row-major to column-major.
    /// Otherwise, composes the transform from TRS (translate, rotate, scale) elements
    /// in the order: result = T × R × S.
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

    /// Builds a rotation matrix from an axis and angle using the Rodrigues' rotation formula.
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

    /// Extracts vertex positions, normals, UVs, and indices from a ``Collada/Geometry/Mesh``.
    ///
    /// Resolves source references through `<vertices>` indirection, handles both
    /// `<triangles>` and `<polylist>` primitives (triangulating polylists via fan decomposition),
    /// and de-interleaves the shared index buffer into per-vertex attribute arrays.
    private func extractMesh(from colladaMesh: Collada.Geometry.Mesh) -> Mesh? {
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

        return Mesh(
            positions: allPositions,
            normals: hasNormals ? allNormals : nil,
            uvs: hasUVs ? allUVs : nil,
            indices: allIndices
        )
    }

    /// Converts a polylist's variable-vertex-count polygons into triangles using fan decomposition.
    ///
    /// For each polygon with N vertices, generates (N-2) triangles by fanning from the
    /// first vertex. Preserves the interleaved index structure (each vertex has `inputCount` indices).
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
}

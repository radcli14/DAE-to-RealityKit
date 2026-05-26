//
//  Entity+Write.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import RealityKit
import XMLCoder

public enum DAEWriteError: Error {
    case meshExtractionFailed
}

public extension Entity {
    @MainActor
    func writeDAEAsset(to url: URL) async throws {
        var geometries: [Collada.Geometry] = []
        var nodes: [Collada.Node] = []
        var geoIndex = 0

        func visit(_ entity: Entity) {
            if let modelEntity = entity as? ModelEntity, let model = modelEntity.model {
                for rkModel in model.mesh.contents.models {
                    for part in rkModel.parts {
                        let geoId = "geometry-\(geoIndex)"
                        geoIndex += 1

                        // Build positions source
                        let positionsArray = Array(part.positions)
                        let flatPositions = positionsArray.flatMap { [$0.x, $0.y, $0.z] }
                        let positionsSource = Collada.Geometry.Source(
                            sourceId: "\(geoId)-positions",
                            floatArray: Collada.FloatArray(
                                id: "\(geoId)-positions-array",
                                count: flatPositions.count,
                                values: flatPositions
                            ),
                            techniqueCommon: Collada.Geometry.TechniqueCommon(
                                accessor: Collada.Geometry.Accessor(
                                    source: "#\(geoId)-positions-array",
                                    count: positionsArray.count,
                                    stride: 3,
                                    params: [
                                        Collada.Geometry.Param(name: "X", type: "float"),
                                        Collada.Geometry.Param(name: "Y", type: "float"),
                                        Collada.Geometry.Param(name: "Z", type: "float"),
                                    ]
                                )
                            )
                        )

                        // Build normals source if available
                        var normalsSource: Collada.Geometry.Source? = nil
                        if let normals = part.normals {
                            let normalsArray = Array(normals)
                            let flatNormals = normalsArray.flatMap { [$0.x, $0.y, $0.z] }
                            normalsSource = Collada.Geometry.Source(
                                sourceId: "\(geoId)-normals",
                                floatArray: Collada.FloatArray(
                                    id: "\(geoId)-normals-array",
                                    count: flatNormals.count,
                                    values: flatNormals
                                ),
                                techniqueCommon: Collada.Geometry.TechniqueCommon(
                                    accessor: Collada.Geometry.Accessor(
                                        source: "#\(geoId)-normals-array",
                                        count: normalsArray.count,
                                        stride: 3,
                                        params: [
                                            Collada.Geometry.Param(name: "X", type: "float"),
                                            Collada.Geometry.Param(name: "Y", type: "float"),
                                            Collada.Geometry.Param(name: "Z", type: "float"),
                                        ]
                                    )
                                )
                            )
                        }

                        // Build UV source if available
                        var uvSource: Collada.Geometry.Source? = nil
                        if let textureCoordinates = part.textureCoordinates {
                            let uvsArray = Array(textureCoordinates)
                            let flatUVs = uvsArray.flatMap { [$0.x, $0.y] }
                            uvSource = Collada.Geometry.Source(
                                sourceId: "\(geoId)-map",
                                floatArray: Collada.FloatArray(
                                    id: "\(geoId)-map-array",
                                    count: flatUVs.count,
                                    values: flatUVs
                                ),
                                techniqueCommon: Collada.Geometry.TechniqueCommon(
                                    accessor: Collada.Geometry.Accessor(
                                        source: "#\(geoId)-map-array",
                                        count: uvsArray.count,
                                        stride: 2,
                                        params: [
                                            Collada.Geometry.Param(name: "S", type: "float"),
                                            Collada.Geometry.Param(name: "T", type: "float"),
                                        ]
                                    )
                                )
                            )
                        }

                        // Collect sources
                        var sources = [positionsSource]
                        if let normalsSource { sources.append(normalsSource) }
                        if let uvSource { sources.append(uvSource) }

                        // Build interleaved inputs; VERTEX is always offset 0
                        var inputs: [Collada.Geometry.Input] = [
                            Collada.Geometry.Input(
                                semantic: "VERTEX",
                                source: "#\(geoId)-vertices",
                                offset: 0,
                                set: nil
                            )
                        ]
                        var inputOffset = 1
                        if normalsSource != nil {
                            inputs.append(Collada.Geometry.Input(
                                semantic: "NORMAL",
                                source: "#\(geoId)-normals",
                                offset: inputOffset,
                                set: nil
                            ))
                            inputOffset += 1
                        }
                        if uvSource != nil {
                            inputs.append(Collada.Geometry.Input(
                                semantic: "TEXCOORD",
                                source: "#\(geoId)-map",
                                offset: inputOffset,
                                set: 0
                            ))
                            inputOffset += 1
                        }

                        // Build interleaved p index array: each vertex index repeated inputOffset times
                        guard let triangleIndicesBuffer = part.triangleIndices else { continue }
                        let rawIndices = Array(triangleIndicesBuffer)
                        let interleavedP = rawIndices.flatMap { idx in
                            Array(repeating: Int(idx), count: inputOffset)
                        }

                        let mesh = Collada.Geometry.Mesh(
                            sources: sources,
                            vertices: Collada.Geometry.Vertices(
                                id: "\(geoId)-vertices",
                                inputs: [
                                    Collada.Geometry.Input(
                                        semantic: "POSITION",
                                        source: "#\(geoId)-positions",
                                        offset: nil,
                                        set: nil
                                    )
                                ]
                            ),
                            triangles: [
                                Collada.Geometry.Triangles(
                                    count: rawIndices.count / 3,
                                    material: nil,
                                    inputs: inputs,
                                    p: Collada.IndexArray(values: interleavedP)
                                )
                            ],
                            polylist: nil
                        )

                        let entityName = entity.name.isEmpty ? geoId : entity.name
                        geometries.append(Collada.Geometry(
                            geometryId: geoId,
                            name: entityName,
                            mesh: mesh
                        ))

                        // Row-major COLLADA matrix from column-major SIMD (t[col][row])
                        let t = entity.transform.matrix
                        let matrixValues: [Double] = [
                            Double(t[0][0]), Double(t[1][0]), Double(t[2][0]), Double(t[3][0]),
                            Double(t[0][1]), Double(t[1][1]), Double(t[2][1]), Double(t[3][1]),
                            Double(t[0][2]), Double(t[1][2]), Double(t[2][2]), Double(t[3][2]),
                            Double(t[0][3]), Double(t[1][3]), Double(t[2][3]), Double(t[3][3]),
                        ]
                        nodes.append(Collada.Node(
                            nodeId: "node-\(geoId)",
                            sid: nil,
                            name: entityName,
                            type: "NODE",
                            matrix: Collada.Matrix4x4(values: matrixValues, sid: nil),
                            translate: nil,
                            rotate: nil,
                            scale: nil,
                            instanceGeometry: [
                                Collada.InstanceGeometry(url: "#\(geoId)", name: nil, bindMaterial: nil)
                            ],
                            children: nil
                        ))
                    }
                }
            }

            for child in entity.children {
                visit(child)
            }
        }

        visit(self)

        guard !geometries.isEmpty else {
            throw DAEWriteError.meshExtractionFailed
        }

        let collada = Collada(
            version: "1.4.1",
            asset: Collada.Asset(upAxis: "Y_UP"),
            libraryImages: nil,
            libraryEffects: nil,
            libraryMaterials: nil,
            libraryGeometries: Collada.LibraryGeometries(geometries: geometries),
            libraryVisualScenes: Collada.LibraryVisualScenes(
                visualScenes: [
                    Collada.VisualScene(
                        visualSceneId: "Scene",
                        name: "Scene",
                        nodes: nodes
                    )
                ]
            ),
            scene: Collada.Scene(
                instanceVisualScene: Collada.InstanceVisualScene(url: "#Scene")
            )
        )

        let encoder = XMLEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(
            collada,
            withRootKey: "COLLADA",
            rootAttributes: [
                "xmlns": "http://www.collada.org/2005/11/COLLADASchema",
            ]
        )
        try data.write(to: url)
    }
}

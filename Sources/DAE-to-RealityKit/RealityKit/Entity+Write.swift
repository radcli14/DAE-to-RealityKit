//
//  Entity+Write.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import CoreGraphics
import Foundation
import ImageIO
import Metal
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
        var colladaImages: [Collada.Image] = []
        var colladaEffects: [Collada.Effect] = []
        var colladaMaterials: [Collada.Material] = []
        var geoIndex = 0

        func visit(_ entity: Entity) async {
            if let modelEntity = entity as? ModelEntity, let model = modelEntity.model {
                for rkModel in model.mesh.contents.models {
                    for part in rkModel.parts {
                        let matIdx = Int(part.materialIndex)
                        let pbr = (matIdx < model.materials.count
                                   ? model.materials[matIdx]
                                   : model.materials.first) as? PhysicallyBasedMaterial
                        let geoId = "geometry-\(geoIndex)"
                        let matId = "mat-\(geoIndex)"
                        let effectId = "effect-\(geoIndex)"

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

                        // Collect sources and build interleaved inputs
                        var sources = [positionsSource]
                        if let normalsSource { sources.append(normalsSource) }
                        if let uvSource { sources.append(uvSource) }

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

                        guard let triangleIndicesBuffer = part.triangleIndices else { continue }
                        let rawIndices = Array(triangleIndicesBuffer)
                        let interleavedP = rawIndices.flatMap { idx in
                            Array(repeating: Int(idx), count: inputOffset)
                        }

                        // Extract PBR material and build COLLADA material structures
                        var bindMaterial: Collada.BindMaterial? = nil
                        if let pbr {
                            var newparams: [Collada.Effect.NewParam] = []

                            // Registers a texture, appends to colladaImages + newparams, returns a texture property.
                            func makeTextureProperty(_ resource: TextureResource, suffix: String) async -> Collada.Effect.Technique.ColorOrTextureProperty? {
                                guard let dataURI = await encodeTextureResourceAsDataURI(resource) else { return nil }
                                let imageId = "image-\(geoIndex)-\(suffix)"
                                colladaImages.append(Collada.Image(imageId: imageId, name: imageId, initFrom: dataURI))
                                newparams += [
                                    Collada.Effect.NewParam(
                                        sid: "\(imageId)-surface",
                                        surface: Collada.Effect.NewParam.Surface(type: "2D", initFrom: imageId),
                                        sampler2D: nil
                                    ),
                                    Collada.Effect.NewParam(
                                        sid: "\(imageId)-sampler",
                                        surface: nil,
                                        sampler2D: Collada.Effect.NewParam.Sampler2D(source: "\(imageId)-surface")
                                    ),
                                ]
                                return Collada.Effect.Technique.ColorOrTextureProperty(
                                    color: nil,
                                    texture: Collada.Effect.Technique.TextureReference(texture: "\(imageId)-sampler", texcoord: "TEX0"),
                                    float: nil
                                )
                            }

                            // Diffuse: texture or tint color
                            let diffuseProperty: Collada.Effect.Technique.ColorOrTextureProperty
                            if let texResource = pbr.baseColor.texture?.resource,
                               let texProp = await makeTextureProperty(texResource, suffix: "diffuse") {
                                diffuseProperty = texProp
                            } else {
                                var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
                                pbr.baseColor.tint.getRed(&r, green: &g, blue: &b, alpha: &a)
                                diffuseProperty = Collada.Effect.Technique.ColorOrTextureProperty(
                                    color: Collada.ColorRGBA(r: Float(r), g: Float(g), b: Float(b), a: Float(a)),
                                    texture: nil, float: nil
                                )
                            }

                            // Emission: texture or color (skipped when black and no texture)
                            var emissionProperty: Collada.Effect.Technique.ColorOrTextureProperty? = nil
                            if let texResource = pbr.emissiveColor.texture?.resource {
                                emissionProperty = await makeTextureProperty(texResource, suffix: "emission")
                            } else {
                                var er: CGFloat = 0, eg: CGFloat = 0, eb: CGFloat = 0, ea: CGFloat = 1
                                pbr.emissiveColor.color.getRed(&er, green: &eg, blue: &eb, alpha: &ea)
                                if er > 0 || eg > 0 || eb > 0 {
                                    emissionProperty = Collada.Effect.Technique.ColorOrTextureProperty(
                                        color: Collada.ColorRGBA(r: Float(er), g: Float(eg), b: Float(eb), a: 1.0),
                                        texture: nil, float: nil
                                    )
                                }
                            }

                            // Transparency: only exported when blending is .transparent.
                            // COLLADA A_ONE convention: opacity = transparent.alpha × transparency.
                            // Map opacity texture → <transparent><texture/></transparent>,
                            // or solid white + <transparency> scalar for uniform opacity.
                            var transparentProperty: Collada.Effect.Technique.ColorOrTextureProperty? = nil
                            var transparencyProperty: Collada.Effect.Technique.FloatProperty? = nil
                            if case .transparent(let opacity) = pbr.blending {
                                if let texResource = opacity.texture?.resource {
                                    transparentProperty = await makeTextureProperty(texResource, suffix: "opacity")
                                } else {
                                    transparentProperty = Collada.Effect.Technique.ColorOrTextureProperty(
                                        color: Collada.ColorRGBA(r: 1, g: 1, b: 1, a: 1),
                                        texture: nil, float: nil
                                    )
                                }
                                transparencyProperty = Collada.Effect.Technique.FloatProperty(float: opacity.scale)
                            }

                            // Roughness → shininess (COLLADA Phong convention, 0–128)
                            let shininess = (1.0 - pbr.roughness.scale) * 128.0

                            let phong = Collada.Effect.Technique.PhongShading(
                                emission: emissionProperty,
                                ambient: nil,
                                diffuse: diffuseProperty,
                                specular: nil,
                                shininess: Collada.Effect.Technique.FloatProperty(float: shininess),
                                transparent: transparentProperty,
                                transparency: transparencyProperty,
                                indexOfRefraction: nil
                            )
                            colladaEffects.append(Collada.Effect(
                                effectId: effectId,
                                profileCommon: Collada.Effect.ProfileCommon(
                                    newparams: newparams.isEmpty ? nil : newparams,
                                    technique: Collada.Effect.Technique(
                                        sid: "common",
                                        phong: phong,
                                        lambert: nil,
                                        blinn: nil
                                    )
                                )
                            ))
                            colladaMaterials.append(Collada.Material(
                                materialId: matId,
                                name: matId,
                                instanceEffect: Collada.InstanceEffect(url: "#\(effectId)")
                            ))
                            bindMaterial = Collada.BindMaterial(
                                techniqueCommon: Collada.BindMaterial.TechniqueCommon(
                                    instanceMaterials: [
                                        Collada.InstanceMaterial(symbol: matId, target: "#\(matId)")
                                    ]
                                )
                            )
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
                                    material: pbr != nil ? matId : nil,
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

                        // Row-major COLLADA matrix from column-major SIMD (t[col][row]).
                        // Use world-space transform so the flat node list has correct positions.
                        let t = entity.transformMatrix(relativeTo: nil)
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
                                Collada.InstanceGeometry(
                                    url: "#\(geoId)",
                                    name: nil,
                                    bindMaterial: bindMaterial
                                )
                            ],
                            children: nil
                        ))

                        geoIndex += 1
                    }
                }
            }

            for child in entity.children {
                await visit(child)
            }
        }

        await visit(self)

        guard !geometries.isEmpty else {
            throw DAEWriteError.meshExtractionFailed
        }

        let collada = Collada(
            version: "1.4.1",
            asset: Collada.Asset(upAxis: "Y_UP"),
            libraryImages: colladaImages.isEmpty ? nil : Collada.LibraryImages(images: colladaImages),
            libraryEffects: colladaEffects.isEmpty ? nil : Collada.LibraryEffects(effects: colladaEffects),
            libraryMaterials: colladaMaterials.isEmpty ? nil : Collada.LibraryMaterials(materials: colladaMaterials),
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

// MARK: - Texture Encode Helper

/// Reads pixel data from a `TextureResource` via Metal and returns it as a base64 JPEG data URI.
/// Returns `nil` on failure; caller falls back to solid color.
@MainActor
private func encodeTextureResourceAsDataURI(_ resource: TextureResource) async -> String? {
    guard let device = MTLCreateSystemDefaultDevice() else { return nil }

    let w = resource.width
    let h = resource.height
    guard w > 0, h > 0 else { return nil }

    let desc = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: w,
        height: h,
        mipmapped: false
    )
    desc.usage = .shaderWrite
    // .shared is CPU-readable without blit synchronisation on all supported platforms.
    desc.storageMode = .shared

    guard let mtlTex = device.makeTexture(descriptor: desc) else { return nil }

    do {
        try await resource.copy(to: mtlTex)
    } catch {
        print("Texture copy failed: \(error)")
        return nil
    }

    let bytesPerRow = 4 * w
    var bytes = [UInt8](repeating: 0, count: h * bytesPerRow)
    bytes.withUnsafeMutableBytes { ptr in
        mtlTex.getBytes(
            ptr.baseAddress!,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: w, height: h, depth: 1)
            ),
            mipmapLevel: 0
        )
    }

    // Scan alpha channel (byte index 3 of every RGBA quad) to decide encoding format.
    let hasAlpha = stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] < 255 }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let cgImage = CGImage(
              width: w, height: h,
              bitsPerComponent: 8, bitsPerPixel: 32,
              bytesPerRow: bytesPerRow,
              space: colorSpace,
              bitmapInfo: bitmapInfo,
              provider: provider,
              decode: nil,
              shouldInterpolate: true,
              intent: .defaultIntent
          ) else { return nil }

    let uti: CFString = hasAlpha ? ("public.png" as CFString) : ("public.jpeg" as CFString)
    let props: CFDictionary? = hasAlpha ? nil : [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
    let mimeType = hasAlpha ? "image/png" : "image/jpeg"

    let mutableData = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(mutableData, uti, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(dest, cgImage, props)
    guard CGImageDestinationFinalize(dest) else { return nil }

    let base64 = (mutableData as Data).base64EncodedString()
    return "data:\(mimeType);base64,\(base64)"
}

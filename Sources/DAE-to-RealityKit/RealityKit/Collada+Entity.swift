//
//  File.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import ImageIO
import RealityKit

// MARK: - Entity Building

extension Collada.Parser.Node {
    /// Converts this parsed node and its children into a RealityKit `ModelEntity` hierarchy.
    ///
    /// Creates a `ModelEntity` with the node's local transform, generates a `MeshResource`
    /// from the mesh data (if present), applies a `PhysicallyBasedMaterial` from the
    /// material properties (including async texture loading), and recursively builds child entities.
    @MainActor
    func buildEntity() async -> ModelEntity {
        let entity = ModelEntity()
        entity.name = name ?? "node"
        entity.transform.matrix = localTransform

        if let mesh {
            do {
                let meshResource = try mesh.buildMeshResource(name: name)
                entity.model = ModelComponent(mesh: meshResource, materials: [await buildMaterial()])
            } catch {
                print("Failed to generate mesh for node '\(name ?? "?")': \(error)")
            }
        }

        for child in children {
            entity.addChild(await child.buildEntity())
        }
        return entity
    }

    /// Builds a RealityKit `PhysicallyBasedMaterial` from the parsed COLLADA material properties.
    ///
    /// Maps COLLADA shading properties to PBR parameters:
    /// - Diffuse color → `baseColor.tint` (used as fallback when texture is absent or fails to load)
    /// - Diffuse texture → `baseColor` texture, loaded from a local or remote URL
    /// - Emission color → `emissiveColor` + `emissiveIntensity`
    /// - Shininess → `roughness` (inverted: `1 - shininess/128`)
    /// - Specular color → `specular` (using luminance)
    /// - Transparency → `blending` with alpha opacity
    @MainActor
    private func buildMaterial() async -> PhysicallyBasedMaterial {
        var pbr = PhysicallyBasedMaterial()

        if let mat = material {
            // Base color (diffuse) — set as tint first so it acts as a fallback
            // if the texture URL is absent or fails to load.
            if let dc = mat.diffuseColor {
                pbr.baseColor.tint = .init(
                    red: CGFloat(dc.r),
                    green: CGFloat(dc.g),
                    blue: CGFloat(dc.b),
                    alpha: CGFloat(dc.a)
                )
            }

            // Texture — async load from local/remote URL, or decode embedded data URI bytes.
            // Overwrites the tint-only baseColor on success; leaves it unchanged on failure.
            if let textureURL = mat.diffuseTextureURL,
               let texture = await loadTexture(from: textureURL) {
                pbr.baseColor = .init(texture: .init(texture))
            } else if let data = mat.diffuseTextureData,
                      let texture = await loadTexture(fromData: data) {
                pbr.baseColor = .init(texture: .init(texture))
            }

            // Emissive color
            if let ec = mat.emissionColor, (ec.r > 0 || ec.g > 0 || ec.b > 0) {
                pbr.emissiveColor = .init(
                    color: .init(
                        red: CGFloat(ec.r),
                        green: CGFloat(ec.g),
                        blue: CGFloat(ec.b),
                        alpha: 1.0
                    )
                )
                pbr.emissiveIntensity = 1.0
            }

            // Roughness derived from shininess
            // COLLADA shininess typically ranges 0–128; higher = shinier = lower roughness
            if let shininess = mat.shininess {
                let clamped = min(max(shininess, 0), 128)
                pbr.roughness = .init(floatLiteral: 1.0 - (clamped / 128.0))
            }

            // Specular
            if let sc = mat.specularColor {
                // Use the luminance of the specular color as the specular scale
                let luminance = 0.2126 * sc.r + 0.7152 * sc.g + 0.0722 * sc.b
                pbr.specular = .init(floatLiteral: luminance)
            }

            // Opacity: COLLADA A_ONE convention (the default) — opacity = transparent.alpha × transparency,
            // where 1.0 means fully opaque. Only enable transparent blending when opacity < 1.
            let transparentAlpha = mat.transparentColor?.a ?? 1.0
            let transparency = mat.transparency ?? 1.0
            let opacity = transparentAlpha * transparency
            if opacity < 1.0 {
                pbr.blending = .transparent(opacity: .init(floatLiteral: opacity))
            }
        }

        return pbr
    }

    /// Loads a `TextureResource` from a local file or remote URL.
    ///
    /// Resolution cascade:
    /// 1. **Local file URL** — delegates directly to `TextureResource(contentsOf:)`.
    /// 2. **Remote URL** (`http`/`https`) — downloads the image data via `URLSession`, decodes it
    ///    with ImageIO, then creates the texture from the resulting `CGImage`.
    /// 3. **Failure** — logs a diagnostic message and returns `nil` so callers fall back to the
    ///    flat color material without crashing.
    @MainActor
    private func loadTexture(from url: URL) async -> TextureResource? {
        do {
            if url.isFileURL {
                return try await TextureResource(
                    contentsOf: url,
                    withName: url.lastPathComponent,
                    options: .init(semantic: .color)
                )
            }

            // Remote URL: download → decode → create TextureResource
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                print("Texture fetch failed for \(url.lastPathComponent): non-2xx response")
                return nil
            }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                print("Texture decode failed for \(url.lastPathComponent): not a valid image")
                return nil
            }
            return try await TextureResource(
                image: cgImage,
                withName: url.lastPathComponent,
                options: .init(semantic: .color)
            )
        } catch {
            print("Texture load failed (\(url.lastPathComponent)): \(error)")
            return nil
        }
    }

    /// Loads a `TextureResource` from raw image bytes (e.g. a decoded base64 data URI).
    @MainActor
    private func loadTexture(fromData data: Data) async -> TextureResource? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            print("Texture decode failed for embedded data URI")
            return nil
        }
        return try? await TextureResource(
            image: cgImage,
            withName: "embedded",
            options: .init(semantic: .color)
        )
    }
}

extension Collada.Parser.Mesh {
    /// Generates a RealityKit `MeshResource` from the parsed vertex data.
    ///
    /// Creates a `MeshDescriptor` with positions, triangle indices, and optionally
    /// normals and texture coordinates, then generates the mesh resource.
    @MainActor
    func buildMeshResource(name: String? = nil) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: name ?? "mesh")
        descriptor.positions = MeshBuffer(positions)
        descriptor.primitives = .triangles(indices)
        if let normals {
            descriptor.normals = MeshBuffer(normals)
        }
        if let uvs {
            descriptor.textureCoordinates = MeshBuffer(uvs)
        }
        return try MeshResource.generate(from: [descriptor])
    }
}

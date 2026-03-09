//
//  File.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import RealityKit

// MARK: - Entity Building

extension Collada.Parser.Node {
    /// Converts this parsed node and its children into a RealityKit `ModelEntity` hierarchy.
    ///
    /// Creates a `ModelEntity` with the node's local transform, generates a `MeshResource`
    /// from the mesh data (if present), applies a `PhysicallyBasedMaterial` from the
    /// material properties, and recursively builds child entities.
    @MainActor
    func buildEntity() -> ModelEntity {
        let entity = ModelEntity()
        entity.name = name ?? "node"
        entity.transform.matrix = localTransform

        if let mesh {
            do {
                let meshResource = try mesh.buildMeshResource(name: name)
                entity.model = ModelComponent(mesh: meshResource, materials: [buildMaterial()])
            } catch {
                print("Failed to generate mesh for node '\(name ?? "?")': \(error)")
            }
        }

        for child in children {
            entity.addChild(child.buildEntity())
        }
        return entity
    }

    /// Builds a RealityKit `PhysicallyBasedMaterial` from the parsed COLLADA material properties.
    ///
    /// Maps COLLADA shading properties to PBR parameters:
    /// - Diffuse color → `baseColor.tint`
    /// - Emission color → `emissiveColor` + `emissiveIntensity`
    /// - Shininess → `roughness` (inverted: `1 - shininess/128`)
    /// - Specular color → `specular` (using luminance)
    /// - Transparency → `blending` with alpha opacity
    private func buildMaterial() -> PhysicallyBasedMaterial {
        var pbr = PhysicallyBasedMaterial()

        if let mat = material {
            // Base color (diffuse)
            if let dc = mat.diffuseColor {
                pbr.baseColor.tint = .init(
                    red: CGFloat(dc.r),
                    green: CGFloat(dc.g),
                    blue: CGFloat(dc.b),
                    alpha: CGFloat(dc.a)
                )
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

            // Transparency (COLLADA: 1.0 = fully transparent, RealityKit: alpha blending)
            if let transparency = mat.transparency, transparency > 0 {
                pbr.blending = .transparent(opacity: .init(floatLiteral: 1.0 - transparency))
            }
        }

        return pbr
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

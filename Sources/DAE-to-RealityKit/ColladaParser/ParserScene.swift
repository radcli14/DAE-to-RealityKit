//
//  RawScene.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import RealityKit
import simd

extension Collada.Parser {

    /// A set of root nodes representing the base element or elements in the assembly,
    /// which themselves may have child nodes.
    struct Scene: Sendable {
        var rootNodes: [Node]
    }

    /// A single node in the assembly, which stores transform, mesh, material,
    /// and child relationships in the assembly.
    struct Node: Sendable, Identifiable {
        var id: String { name ?? uuid }
        private let uuid = UUID().uuidString

        var name: String?
        /// The node's local transform relative to its parent
        var localTransform: simd_float4x4
        var mesh: Mesh?
        var material: Material?
        var children: [Node]

        init(
            name: String?,
            localTransform: simd_float4x4,
            mesh: Mesh? = nil,
            material: Material? = nil,
            children: [Node] = []
        ) {
            self.name = name
            self.localTransform = localTransform
            self.mesh = mesh
            self.material = material
            self.children = children
        }
    }

    /// Stores the positions, normals, uvs, and indices arrays representing a mesh
    struct Mesh: Sendable {
        var positions: [SIMD3<Float>]
        var normals: [SIMD3<Float>]? = nil
        var uvs: [SIMD2<Float>]? = nil
        var indices: [UInt32]
    }

    /// Stores the visual material properties extracted from the COLLADA effect
    struct Material: Sendable {
        var diffuseColor: Collada.ColorRGBA?
        var diffuseTexturePath: String?
        var emissionColor: Collada.ColorRGBA?
        var ambientColor: Collada.ColorRGBA?
        var specularColor: Collada.ColorRGBA?
        /// COLLADA shininess (0–128 typical), converted to roughness = 1 - (shininess / 128)
        var shininess: Float?
        var transparency: Float?
    }
}

// MARK: - Entity Building

extension Collada.Parser.Node {
    /// Convert the node data into a RealityKit `ModelEntity`
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

    /// Build a RealityKit `PhysicallyBasedMaterial` from the material properties
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

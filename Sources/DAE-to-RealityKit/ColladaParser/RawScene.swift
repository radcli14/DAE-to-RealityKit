//
//  RawScene.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import RealityKit
import simd

extension Collada {

    /// A set of root `RawNode` objects representing the base element or elements in the assembly,
    /// which themselves may have child nodes.
    struct RawScene: Sendable {
        var rootNodes: [RawNode]
    }

    /// A single node in the assembly, which stores transform, mesh, material,
    /// and child relationships in the assembly.
    struct RawNode: Sendable, Identifiable {
        var id: String { name ?? uuid }
        private let uuid = UUID().uuidString

        var name: String?
        /// The node's local transform relative to its parent
        var localTransform: simd_float4x4
        var mesh: RawMesh?
        var diffuseColor: ColorRGBA?
        var children: [RawNode]

        init(
            name: String?,
            localTransform: simd_float4x4,
            mesh: RawMesh? = nil,
            diffuseColor: ColorRGBA? = nil,
            children: [RawNode] = []
        ) {
            self.name = name
            self.localTransform = localTransform
            self.mesh = mesh
            self.diffuseColor = diffuseColor
            self.children = children
        }
    }

    /// Stores the positions, normals, uvs, and indices arrays representing a mesh
    struct RawMesh: Sendable {
        var positions: [SIMD3<Float>]
        var normals: [SIMD3<Float>]? = nil
        var uvs: [SIMD2<Float>]? = nil
        var indices: [UInt32]
    }
}

// MARK: - Entity Building

extension Collada.RawNode {
    /// Convert the node data into a RealityKit `ModelEntity`
    @MainActor
    func buildEntity() -> ModelEntity {
        let entity = ModelEntity()
        entity.name = name ?? "node"
        entity.transform.matrix = localTransform

        if let mesh {
            do {
                let meshResource = try mesh.buildMeshResource(name: name)
                entity.model = ModelComponent(mesh: meshResource, materials: [material])
            } catch {
                print("Failed to generate mesh for node '\(name ?? "?")': \(error)")
            }
        }

        for child in children {
            entity.addChild(child.buildEntity())
        }
        return entity
    }

    /// Build a RealityKit material using properties from the Collada file
    private var material: SimpleMaterial {
        var newMaterial = SimpleMaterial()
        if let diffuseColor {
            newMaterial.color.tint = .init(
                red: CGFloat(diffuseColor.r),
                green: CGFloat(diffuseColor.g),
                blue: CGFloat(diffuseColor.b),
                alpha: CGFloat(diffuseColor.a)
            )
        }
        return newMaterial
    }
}

extension Collada.RawMesh {
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

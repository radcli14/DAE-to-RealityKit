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
    
    /// A set of root `RawNode` objects representing the base element or elements in the assembly, which themselves may have child nodes.
    public struct RawScene: Sendable {
        public var rootNodes: [RawNode]
        public init(rootNodes: [RawNode]) { self.rootNodes = rootNodes }
    }
    
    /// A single node in the assembly, which stores transform, mesh, material, and child relationships in the assembly.
    public struct RawNode: Sendable, Identifiable {
        public var id: String { name ?? uuid }
        private let uuid = UUID().uuidString

        public var name: String?
        /// The node's local transform relative to its parent
        public var localTransform: simd_float4x4
        public var mesh: RawMesh?
        public var diffuseColor: ColorRGBA?
        public var children: [RawNode]

        public init(
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
    public struct RawMesh: Sendable {
        public var positions: [SIMD3<Float>]
        public var normals: [SIMD3<Float>]? = nil
        public var uvs: [SIMD2<Float>]? = nil
        public var indices: [UInt32]
        public init(positions: [SIMD3<Float>], normals: [SIMD3<Float>]? = nil, uvs: [SIMD2<Float>]? = nil, indices: [UInt32]) {
            self.positions = positions
            self.normals = normals
            self.uvs = uvs
            self.indices = indices
        }
    }
}

extension Collada.RawNode {
    /// Convert the node data into a RealityKit `ModelEntity`
    @MainActor
    func buildEntity() -> ModelEntity {
        let entity = ModelEntity()
        entity.name = name ?? "node"
        entity.transform.matrix = localTransform

        // Attempt to construct a mesh with material, if success, add as a model component
        if let mesh {
            do {
                let meshResource = try mesh.buildMeshResource(name: name)
                entity.model = ModelComponent(mesh: meshResource, materials: [material])
            } catch {
                print("Failed to generate mesh for node '\(name ?? "?")': \(error)")
            }
        }

        // Recursively generate entities for all of the children of this node
        for child in children {
            let childEntity = child.buildEntity()
            entity.addChild(childEntity)
        }
        return entity
    }
    
    /// Build a RealityKit material using properties from the Collada file
    var material: SimpleMaterial {
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
        if let normals = normals {
            descriptor.normals = MeshBuffer(normals)
        }
        if let uvs {
            descriptor.textureCoordinates = MeshBuffer(uvs)
        }
        return try MeshResource.generate(from: [descriptor])
    }
}

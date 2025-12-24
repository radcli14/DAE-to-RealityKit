//
//  SCNGeometry+Extensions.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 12/20/25.
//

import Foundation
import RealityKit
import SceneKit

public extension SCNGeometry {

    /// An array of `MeshDescriptor` derived from the `positions` array and primitive indices contained in the `submeshes`
    @MainActor var descriptors: [MeshDescriptor] {
        
        // Get the computed properties first, so they aren't computed multiple times inside the map
        guard let positions = sources.vertices
        else {
            print("⚠️ Missing required geometry vertices")
            return []
        }
        let textureCoordinates = sources.textureCoordinates
        let normals = sources.normals

        print("📊 Geometry has \(positions.count) vertices, \(elements.count) elements")
        
        // Map the mesh descriptors from the submeshes
        return elements.enumerated().map { (index, element) in
            // Initialize the descriptor with positions
            var descriptor = MeshDescriptor(name: (name ?? "dae") + "_\(index)")
            descriptor.positions = .init(positions)
            
            print("  Element[\(index)]: \(element.primitiveCount) primitives")
            
            // Make sure the coordinates and normals are dimensionally consistent with the positions
            if let textureCoordinates, textureCoordinates.count == positions.count {
                descriptor.textureCoordinates = .init(textureCoordinates)
            } else {
                print("  ⚠️ Texture coordinate count (\(textureCoordinates?.count ?? 0)) doesn't match vertex count (\(positions.count))")
            }
            
            if let normals, normals.count == positions.count {
                descriptor.normals = .init(normals)
            } else {
                print("  ⚠️ Normal count (\(normals?.count ?? 0)) doesn't match vertex count (\(positions.count))")
            }
            
            // Add primitives from the submesh
            let primitives = element.primitives
            if let triangles = primitives {
                descriptor.primitives = triangles
                print("  ✓ Added primitives successfully")
            } else {
                print("  ⚠️ Could not generate primitives for element[\(index)]")
            }
            
            return descriptor
        }
    }
    
    /// Asynchrnously onbtain a RealityKit `MeshResource` derived from the meshes in this model
    @MainActor func getMeshResource() async -> MeshResource? {
        do {
            let sendableDescriptors = UnsafeSendableDescriptors(descriptors: descriptors)
            return try await MeshResource(from: sendableDescriptors.descriptors)
        } catch {
            print("SCNGeometry.getMeshResource() failed because \(error.localizedDescription)")
            return nil
        }
    }
    
    @MainActor var rkMaterials: [PhysicallyBasedMaterial] {
        materials.compactMap { $0.rkMaterial }
    }
}

// TODO: I don't like the wrappers below, but it was a correction for "sending self.materials risks causing data races"

/// Wrapper to make non-Sendable descriptors transferable across actor boundaries
struct UnsafeSendableDescriptors: @unchecked Sendable {
    let descriptors: [MeshDescriptor]
}

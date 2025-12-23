//
//  SCNNode.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 12/20/25.
//

import Foundation
import RealityKit
import SceneKit

@MainActor
public extension SCNNode {
    /// Recursively find all geometry nodes in this node's hierarchy
    var geometryNodes: [SCNNode] {
        var result: [SCNNode] = []
        
        // Add self if it has geometry
        if geometry != nil {
            result.append(self)
        }
        
        // Get child geometry nodes
        for child in childNodes {
            result.append(contentsOf: child.geometryNodes)
        }
        
        return result
    }
    
    // - MARK: RealityKit
    
    var descriptors: [MeshDescriptor] {
        geometryNodes.flatMap { $0.descriptors }
    }
    
    var rkMaterials: [PhysicallyBasedMaterial] {
        geometryNodes.flatMap { $0.rkMaterials }
    }
    
    func getMeshResource() async -> MeshResource? {
        do {
            let sendableDescriptors = UnsafeSendableDescriptors(descriptors: descriptors)
            return try await MeshResource(from: sendableDescriptors.descriptors)
        } catch {
            print("SCNGeometry.getMeshResource() failed because \(error.localizedDescription)")
            return nil
        }
    }
}

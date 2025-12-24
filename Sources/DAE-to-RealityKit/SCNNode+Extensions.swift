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

    func getModelEntity(recursive: Bool = true) async -> ModelEntity {
        // Build this entity
        var entity: ModelEntity
        if let geometry, let mesh = await geometry.getMeshResource() {
            entity = ModelEntity(
                mesh: mesh,
                materials: geometry.rkMaterials
            )
        } else {
            entity = ModelEntity()
        }
        
        // Set the transform
        entity.transform.translation = self.simdPosition
        entity.transform.rotation = self.simdOrientation
        entity.transform.scale = self.simdScale
        
        // Early return if not in recursive mode
        guard recursive else { return entity }
        
        // Add child entities
        for node in childNodes {
            let childEntity = await node.getModelEntity(recursive: recursive)
            childEntity.setParent(entity)
        }
        
        return entity
    }
}

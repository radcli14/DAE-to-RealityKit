//
//  ModelEntity+DAE.swift
//  Model3DLoader
//
//  Created by Eliott Radcliffe on 12/18/25.
//

import Foundation
import RealityKit
import SceneKit

public extension ModelEntity {
    @MainActor
    static func fromDAEAsset(
        data: Data
    ) async -> ModelEntity? {
        print("🔍 Loading DAE from data (\(data.count) bytes)")
        
        let source = SCNSceneSource(data: data, options: [
            SCNSceneSource.LoadingOption.checkConsistency: true
        ])
        
        guard let scene = source?.scene(options: nil) else { return nil }
        print("    - Scene (from source):", scene)
        
        return await ModelEntity.fromSCNScene(scene)
    }
    
    /// Create a ModelEntity from a DAE (COLLADA) file at the specified URL
    /// - Parameter url: The URL to the .dae file (can be a file URL, bundle resource, etc.)
    /// - Returns: A ModelEntity if the file was successfully loaded and converted, nil otherwise
    @MainActor
    static func fromDAEAsset(url: URL) async -> ModelEntity? {
        do {
            // Load the scene from the URL
            print("🔍 Loading DAE file from: \(url.path)")
            let scene = try SCNScene(url: url, options: nil)
            
            // Convert the scene to a ModelEntity
            return await fromSCNScene(scene)
        } catch {
            // Attempt a fallback to using the data directly
            if let data = try? Data(contentsOf: url) {
                return await ModelEntity.fromDAEAsset(data: data)
            }
            print("❌ Failed to load DAE file: \(error)")
            return nil
        }
    }
    
    /// Create a ModelEntity from an SCNScene (such as one loaded from a .dae file)
    @MainActor
    static func fromSCNScene(_ scene: SCNScene) async -> ModelEntity? {

        print("🔍 Converting SCNScene to ModelEntity...")

        guard let meshResource = await scene.rootNode.getMeshResource() else {
            print("❌ Failed to create mesh resource")
            return nil
        }
        
        print("✅ Successfully created mesh resource")
        
        return ModelEntity(
            mesh: meshResource,
            materials: scene.rootNode.rkMaterials
        )
    }
}

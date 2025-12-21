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
        // Create temporary file URL
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("dae")

        do {
            // Write data to temporary file
            try data.write(to: tempURL)

            // Load using existing URL-based method
            let entity = await ModelEntity.fromDAEAsset(url: tempURL)

            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempURL)

            return entity
        } catch {
            print("Error in fromDAEAsset(data:): \(error.localizedDescription)")
            
            // Cleanup on error
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
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
            print("❌ Failed to load DAE file: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Create a ModelEntity from an SCNScene (such as one loaded from a .dae file)
    @MainActor
    static func fromSCNScene(_ scene: SCNScene) async -> ModelEntity? {
        let rootNode = scene.rootNode
        print("🔍 Converting SCNScene to ModelEntity...")
        rootNode.unpack()
        
        // Get all geometry nodes from the scene
        let geometryNodes = rootNode.geometryNodes
        guard !geometryNodes.isEmpty else {
            print("⚠️ No geometry found in scene")
            return nil
        }
        
        print("📦 Found \(geometryNodes.count) geometry node(s)")
        
        // For now, let's handle the first geometry node
        // TODO: Combine multiple geometries into a single entity
        guard let firstGeometry = geometryNodes.first?.geometry else { return nil }
        
        firstGeometry.unpack()
        
        guard let meshResource = await firstGeometry.getMeshResource() else {
            print("❌ Failed to create mesh resource")
            return nil
        }
        
        print("✅ Successfully created mesh resource")
        
        return ModelEntity(
            mesh: meshResource,
            materials: firstGeometry.rkMaterials
        )
    }
}

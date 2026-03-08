//
//  ModelEntity+DAE.swift
//  Model3DLoader
//
//  Created by Eliott Radcliffe on 12/18/25.
//

import Foundation
import RealityKit
import SceneKit

public struct DAEImportOptions: Sendable {
    public enum Loader: Sendable {
        case sceneKit
        case custom
    }
    public var loader: Loader
    public init(loader: Loader = .sceneKit) { self.loader = loader }
}

public extension ModelEntity {
    @MainActor
    static func fromDAEAsset(
        data: Data,
        options: DAEImportOptions = .init()
    ) async -> ModelEntity? {
        print("🔍 Loading DAE from data (\(data.count) bytes)")
        
        switch options.loader {
        case .custom:
            // TODO: Implement custom COLLADA parser path using XMLCoder
            // Placeholder for upcoming RawScene -> ModelEntity conversion
            return await ModelEntity.fromCustomDAEData(data)
        case .sceneKit:
            break
        }
        
        guard let source = SCNSceneSource(data: data, options: [
            SCNSceneSource.LoadingOption.checkConsistency: true
        ]) else {
            print("❌ SCNSceneSource failed to initialize from data")
            return nil
        }
        
        let scene: SCNScene
        do {
            scene = try source.scene(options: nil)
        } catch {
            print("❌ SCNSceneSource.scene(options:) failed: \(error)")
            return nil
        }
        print("    - Scene (from source):", scene)
        
        return await ModelEntity.fromSCNScene(scene)
    }
    
    /// Create a ModelEntity from a DAE (COLLADA) file at the specified URL
    /// - Parameter url: The URL to the .dae file (can be a file URL, bundle resource, etc.)
    /// - Returns: A ModelEntity if the file was successfully loaded and converted, nil otherwise
    @MainActor
    static func fromDAEAsset(url: URL, options: DAEImportOptions = .init()) async -> ModelEntity? {
        do {
            // Load the scene from the URL
            print("🔍 Loading DAE file from: \(url.path)")
            let scene = try SCNScene(url: url, options: nil)
            
            // Convert the scene to a ModelEntity
            return await fromSCNScene(scene)
        } catch {
            // Attempt a fallback to using the data directly
            if let data = try? Data(contentsOf: url) {
                return await ModelEntity.fromDAEAsset(data: data, options: options)
            }
            print("❌ Failed to load DAE file: \(error)")
            return nil
        }
    }
    
    /// Create a ModelEntity from an SCNScene (such as one loaded from a .dae file)
    @MainActor
    static func fromSCNScene(_ scene: SCNScene) async -> ModelEntity? {
        print("🔍 Converting SCNScene to ModelEntity...")
        return await scene.rootNode.getModelEntity()
    }
    
    @MainActor
    private static func fromCustomDAEData(_ data: Data) async -> ModelEntity? {
        let parser = ColladaParser()
        do {
            let raw = try parser.parse(data: data)
            // Build ModelEntity hierarchy from RawScene
            let root = ModelEntity()
            for node in raw.rootNodes {
                let child = buildEntity(from: node)
                root.addChild(child)
            }
            return root
        } catch {
            print("❌ Custom COLLADA parse failed: \(error)")
            return nil
        }
    }
    
    @MainActor
    private static func buildEntity(from node: RawNode) -> ModelEntity {
        let entity = ModelEntity()
        entity.name = node.name ?? "node"
        entity.transform.matrix = node.transform
        for child in node.children {
            let childEntity = buildEntity(from: child)
            entity.addChild(childEntity)
        }
        return entity
    }
}


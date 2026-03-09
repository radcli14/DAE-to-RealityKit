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
        /// Use SceneKit to load (works for bundle-compiled SCN/DAE files)
        case sceneKit
        /// Use the custom XMLCoder-based COLLADA parser (works for raw XML DAE files)
        case custom
        /// Auto-detect: inspect the data to choose the right parser, with fallback
        case auto
    }
    public var loader: Loader
    public init(loader: Loader = .auto) { self.loader = loader }
}

public extension ModelEntity {

    /// Create a ModelEntity from DAE data bytes
    @MainActor
    static func fromDAEAsset(
        data: Data,
        options: DAEImportOptions = .init()
    ) async -> ModelEntity? {
        let loader = options.loader == .auto ? detectDAELoader(for: data) : options.loader
        print("Loading DAE from data (\(data.count) bytes) with \(loader) loader")

        switch loader {
        case .custom:
            let result = await fromDataUsingCustomDAEParser(data)
            if result != nil { return result }
            // Fallback to SceneKit if custom parser failed and caller used auto
            if options.loader == .auto {
                print("Custom parser failed, falling back to SceneKit")
                return await fromDataUsingSceneKitDAEParser(data)
            }
            return nil

        case .sceneKit, .auto:
            let result = await fromDataUsingSceneKitDAEParser(data)
            if result != nil { return result }
            // Fallback to custom parser if SceneKit failed and caller used auto
            if options.loader == .auto {
                print("SceneKit failed, falling back to custom parser")
                return await fromDataUsingCustomDAEParser(data)
            }
            return nil
        }
    }

    /// Create a ModelEntity from a DAE (COLLADA) file at the specified URL.
    /// Works with bundle resources (Xcode-compiled SCN) and raw XML DAE files.
    @MainActor
    static func fromDAEAsset(url: URL, options: DAEImportOptions = .init()) async -> ModelEntity? {
        print("Loading DAE file from: \(url.path)")

        // If explicitly custom, go straight to data-based parsing
        if options.loader == .custom {
            guard let data = try? Data(contentsOf: url) else {
                print("Failed to read data from: \(url.path)")
                return nil
            }
            return await fromDAEAsset(data: data, options: options)
        }

        // For .sceneKit or .auto, try SCNScene(url:) first since it handles
        // both raw DAE (macOS) and Xcode-compiled SCN transparently
        if options.loader == .sceneKit || options.loader == .auto {
            do {
                let scene = try SCNScene(url: url, options: nil)
                if let entity = await fromSCNScene(scene) {
                    return entity
                }
            } catch {
                print("SCNScene(url:) failed: \(error.localizedDescription)")
            }
        }

        // Read data and try data-based loading (with auto-detection or explicit loader)
        guard let data = try? Data(contentsOf: url) else {
            print("Failed to read data from: \(url.path)")
            return nil
        }
        return await fromDAEAsset(data: data, options: options)
    }

    /// Create a ModelEntity from an SCNScene (such as one loaded from a .dae file)
    @MainActor
    static func fromSCNScene(_ scene: SCNScene) async -> ModelEntity? {
        return await scene.rootNode.getModelEntity()
    }

    // MARK: - Data Format Detection

    /// Inspect the first bytes to determine the best loader.
    /// - Binary plist (bplist) → Xcode-compiled SCN → use SceneKit
    /// - XML declaration (<?xml) → raw COLLADA → use custom parser
    private static func detectDAELoader(for data: Data) -> DAEImportOptions.Loader {
        guard data.count >= 6 else { return .sceneKit }

        // Binary plist: starts with "bplist"
        let bplist: [UInt8] = [0x62, 0x70, 0x6C, 0x69, 0x73, 0x74] // "bplist"
        let header = [UInt8](data.prefix(6))
        if header == bplist {
            return .sceneKit
        }

        // XML: starts with "<?xml" (possibly after a BOM)
        if let prefix = String(data: data.prefix(64), encoding: .utf8),
           prefix.contains("<?xml") || prefix.contains("<COLLADA") {
            return .custom
        }

        // Unknown format, default to SceneKit
        return .sceneKit
    }

    // MARK: - Parser Implementations

    @MainActor
    private static func fromDataUsingSceneKitDAEParser(_ data: Data) async -> ModelEntity? {
        guard let source = SCNSceneSource(data: data, options: [
            SCNSceneSource.LoadingOption.checkConsistency: true
        ]) else {
            print("SCNSceneSource failed to initialize from data")
            return nil
        }

        let scene: SCNScene
        do {
            scene = try source.scene(options: nil)
        } catch {
            print("SCNSceneSource.scene(options:) failed: \(error)")
            return nil
        }

        return await fromSCNScene(scene)
    }

    @MainActor
    private static func fromDataUsingCustomDAEParser(_ data: Data) async -> ModelEntity? {
        let parser = ColladaParser()
        do {
            let raw = try parser.parse(data: data)
            let root = ModelEntity()
            for node in raw.rootNodes {
                let child = node.buildEntity()
                root.addChild(child)
            }
            return root
        } catch {
            print("Custom COLLADA parse failed: \(error)")
            return nil
        }
    }
}


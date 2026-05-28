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

public enum DAEImportError: Error {
    /// Could not read the file at the given URL.
    case dataReadFailed(URL)
    /// SceneKit failed to load the asset. The associated error is the underlying SceneKit failure.
    case sceneKitLoadFailed(Error)
    /// The custom COLLADA parser failed. The associated error is the underlying parse failure.
    case customParserFailed(Error)
}

public extension ModelEntity {

    /// Creates a `ModelEntity` from raw DAE (COLLADA) data.
    ///
    /// The `options` parameter controls which parser is used. With the default `.auto` loader
    /// the data is inspected to choose the best parser, with automatic fallback to the other
    /// parser on failure. Use `.custom` or `.sceneKit` to force a specific parser.
    ///
    /// - Throws: `DAEImportError` if both parsers fail.
    @MainActor
    static func fromDAEAsset(
        data: Data,
        options: DAEImportOptions = .init()
    ) async throws -> ModelEntity {
        let loader = options.loader == .auto ? detectDAELoader(for: data) : options.loader
        print("Loading DAE from data (\(data.count) bytes) with \(loader) loader")

        switch loader {
        case .custom:
            do {
                return try await fromDataUsingCustomDAEParser(data)
            } catch {
                guard options.loader == .auto else { throw error }
                print("Custom parser failed (\(error)), falling back to SceneKit")
                return try await fromDataUsingSceneKitDAEParser(data)
            }

        case .sceneKit, .auto:
            do {
                return try await fromDataUsingSceneKitDAEParser(data)
            } catch {
                guard options.loader == .auto else { throw error }
                print("SceneKit failed (\(error)), falling back to custom parser")
                return try await fromDataUsingCustomDAEParser(data)
            }
        }
    }

    /// Creates a `ModelEntity` from a DAE (COLLADA) file at the given URL.
    ///
    /// Works with Xcode-compiled SCN bundle resources and raw XML DAE files. With the default
    /// `.auto` loader the URL path is tried via `SCNScene(url:)` first, falling back to the
    /// custom COLLADA parser on failure.
    ///
    /// The source URL is forwarded to the custom parser so that relative texture references
    /// in `<library_images>` can be resolved — either to sibling local files (for `file://`
    /// sources) or to remote network resources (for `http(s)://` sources).
    ///
    /// - Throws: `DAEImportError` if all applicable parsers fail.
    @MainActor
    static func fromDAEAsset(url: URL, options: DAEImportOptions = .init()) async throws -> ModelEntity {
        print("Loading DAE file from: \(url.path)")

        if options.loader == .custom {
            guard let data = try? Data(contentsOf: url) else {
                throw DAEImportError.dataReadFailed(url)
            }
            return try await fromDataUsingCustomDAEParser(data, sourceURL: url)
        }

        // For .sceneKit or .auto, try SCNScene(url:) first — handles both raw DAE (macOS)
        // and Xcode-compiled SCN transparently.
        if options.loader == .sceneKit || options.loader == .auto {
            do {
                let scene = try SCNScene(url: url, options: nil)
                return await fromSCNScene(scene)
            } catch {
                if options.loader == .sceneKit {
                    throw DAEImportError.sceneKitLoadFailed(error)
                }
                print("SCNScene(url:) failed: \(error.localizedDescription)")
            }
        }

        // .auto fallback: SceneKit failed, so try the custom parser.
        // Pass the source URL so relative texture paths can still be resolved.
        guard let data = try? Data(contentsOf: url) else {
            throw DAEImportError.dataReadFailed(url)
        }
        return try await fromDataUsingCustomDAEParser(data, sourceURL: url)
    }

    /// Creates a `ModelEntity` from a loaded `SCNScene`.
    @MainActor
    static func fromSCNScene(_ scene: SCNScene) async -> ModelEntity {
        await scene.rootNode.getModelEntity()
    }

    // MARK: - Data Format Detection

    /// Inspects the first bytes of data to select the best loader.
    /// - Binary plist (`bplist`) → Xcode-compiled SCN → SceneKit
    /// - XML prefix (`<?xml` or `<COLLADA`) → raw COLLADA → custom parser
    private static func detectDAELoader(for data: Data) -> DAEImportOptions.Loader {
        guard data.count >= 6 else { return .sceneKit }

        let bplist: [UInt8] = [0x62, 0x70, 0x6C, 0x69, 0x73, 0x74] // "bplist"
        if [UInt8](data.prefix(6)) == bplist { return .sceneKit }

        if let prefix = String(data: data.prefix(64), encoding: .utf8),
           prefix.contains("<?xml") || prefix.contains("<COLLADA") {
            return .custom
        }

        return .sceneKit
    }

    // MARK: - Parser Implementations

    @MainActor
    private static func fromDataUsingSceneKitDAEParser(_ data: Data) async throws -> ModelEntity {
        guard let source = SCNSceneSource(data: data, options: [
            SCNSceneSource.LoadingOption.checkConsistency: true
        ]) else {
            throw DAEImportError.sceneKitLoadFailed(
                NSError(domain: "DAEImport", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "SCNSceneSource failed to initialize from data"])
            )
        }

        let scene: SCNScene
        do {
            scene = try source.scene(options: nil)
        } catch {
            throw DAEImportError.sceneKitLoadFailed(error)
        }

        return await fromSCNScene(scene)
    }

    /// - Parameter sourceURL: Optional origin of the DAE data; forwarded to the parser so that
    ///   relative texture paths in `<library_images>` can be resolved to absolute local or remote URLs.
    @MainActor
    private static func fromDataUsingCustomDAEParser(
        _ data: Data,
        sourceURL: URL? = nil
    ) async throws -> ModelEntity {
        let parser = Collada.Parser()
        do {
            let raw = try parser.parse(data: data, sourceURL: sourceURL)
            let root = ModelEntity()
            for node in raw.rootNodes {
                root.addChild(await node.buildEntity())
            }
            return root
        } catch {
            throw DAEImportError.customParserFailed(error)
        }
    }
}

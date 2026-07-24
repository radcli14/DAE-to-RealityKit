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
    /// A parser reported success but produced nothing renderable (no `ModelComponent` anywhere in the
    /// entity tree) — the model would be silently invisible. Thrown so `.auto` falls back to the other
    /// parser instead of returning an empty entity.
    case noRenderableGeometry
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
    /// `.auto` loader the file's CONTENT selects the parser (via `detectDAELoader`), exactly as the
    /// `Data` overload does, with automatic fallback to the other parser on failure.
    ///
    /// The source URL is forwarded to the custom parser so that relative texture references
    /// in `<library_images>` can be resolved — either to sibling local files (for `file://`
    /// sources) or to remote network resources (for `http(s)://` sources).
    ///
    /// - Throws: `DAEImportError` if all applicable parsers fail.
    @MainActor
    static func fromDAEAsset(url: URL, options: DAEImportOptions = .init()) async throws -> ModelEntity {
        print("Loading DAE file from: \(url.path)")

        // Read once, off the main actor — used both to sniff the format and to feed the parsers.
        let readTask = Task.detached(priority: .userInitiated) { try Data(contentsOf: url) }
        guard let data = try? await readTask.value else {
            throw DAEImportError.dataReadFailed(url)
        }

        // Route by CONTENT, not by platform. Previously `.auto` always tried `SCNScene(url:)` first
        // on non-iOS — even for raw XML COLLADA, which the sniffer sends straight to the custom
        // parser — so macOS took a SceneKit detour that iOS (where that block is compiled out) never
        // took. That asymmetry is why a raw DAE rendered on iOS but not on macOS.
        let loader = options.loader == .auto ? detectDAELoader(for: data) : options.loader

        switch loader {
        case .custom:
            do {
                return try await fromDataUsingCustomDAEParser(data, sourceURL: url)
            } catch {
                guard options.loader == .auto else { throw error }
                print("Custom parser failed (\(error)), falling back to SceneKit")
                return try await fromSceneKit(url: url, data: data)
            }

        case .sceneKit, .auto:
            do {
                return try await fromSceneKit(url: url, data: data)
            } catch {
                guard options.loader == .auto else { throw error }
                print("SceneKit failed (\(error)), falling back to custom parser")
                return try await fromDataUsingCustomDAEParser(data, sourceURL: url)
            }
        }
    }

    /// Creates a `ModelEntity` from a loaded `SCNScene`.
    @MainActor
    static func fromSCNScene(_ scene: SCNScene) async -> ModelEntity {
        await scene.rootNode.getModelEntity()
    }

    /// SceneKit load for a URL-backed asset: prefers `SCNScene(url:)` — the only path that handles
    /// Xcode-compiled SCN bundle resources — and falls back to the data-based scene source.
    ///
    /// A scene that loads but yields NO renderable geometry is treated as a failure so `.auto` can
    /// fall through to the custom parser. Without that check an empty SceneKit result became an
    /// empty `ModelEntity`: an invisible model, with no thrown error and no fallback.
    @MainActor
    private static func fromSceneKit(url: URL?, data: Data) async throws -> ModelEntity {
        // SCNScene(url:) always fails on iOS, so it is compiled out there entirely.
        #if !os(iOS)
        if let url, let scene = try? SCNScene(url: url, options: nil) {
            let entity = await fromSCNScene(scene)
            if containsRenderableMesh(entity) { return entity }
            print("SCNScene(url:) produced no renderable geometry — trying the data-based scene source")
        }
        #endif
        return try await fromDataUsingSceneKitDAEParser(data)
    }

    /// Whether anything in the entity tree will actually render. RealityKit draws only via
    /// `ModelComponent`, so a tree containing none anywhere is guaranteed invisible — the signal
    /// used to reject a "successful" but empty parse.
    internal static func containsRenderableMesh(_ entity: Entity) -> Bool {
        if entity.components.has(ModelComponent.self) { return true }
        return entity.children.contains { containsRenderableMesh($0) }
    }

    // MARK: - Data Format Detection

    /// Inspects the first bytes of data to select the best loader.
    /// - Binary plist (`bplist`) → Xcode-compiled SCN → SceneKit
    /// - XML prefix (`<?xml` or `<COLLADA`) → raw COLLADA → custom parser
    internal static func detectDAELoader(for data: Data) -> DAEImportOptions.Loader {
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

        // A scene can load "successfully" and still contain nothing renderable. Fail loudly instead
        // of returning an empty entity, so `.auto` falls back to the custom parser rather than
        // silently producing an invisible model.
        let entity = await fromSCNScene(scene)
        guard containsRenderableMesh(entity) else { throw DAEImportError.noRenderableGeometry }
        return entity
    }

    /// - Parameter sourceURL: Optional origin of the DAE data; forwarded to the parser so that
    ///   relative texture paths in `<library_images>` can be resolved to absolute local or remote URLs.
    @MainActor
    private static func fromDataUsingCustomDAEParser(
        _ data: Data,
        sourceURL: URL? = nil
    ) async throws -> ModelEntity {
        let rawScene: Collada.Parser.Scene
        do {
            rawScene = try await Task.detached(priority: .userInitiated) {
                try Collada.Parser().parse(data: data, sourceURL: sourceURL)
            }.value
        } catch {
            throw DAEImportError.customParserFailed(error)
        }
        let root = ModelEntity()
        for node in rawScene.rootNodes {
            root.addChild(await node.buildEntity())
        }
        return root
    }
}

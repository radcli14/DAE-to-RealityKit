import Testing
import Foundation
@preconcurrency import RealityKit
@preconcurrency import SceneKit
@testable import DAE_to_RealityKit


/// Recursively search the entity hierarchy for a ModelEntity that has a model component
@MainActor
func findModelEntity(in parent: Entity) -> ModelEntity? {
    if let model = parent as? ModelEntity, model.model != nil {
        return model
    }
    for child in parent.children {
        if let found = findModelEntity(in: child) {
            return found
        }
    }
    return nil
}

/// Verify that a loaded entity has a mesh with non-zero bounds and at least one material
@MainActor
func verifyEntityHasMesh(_ entity: Entity, label: String) {
    let modelEntity = findModelEntity(in: entity)
    #expect(modelEntity != nil, "\(label): Should find a child entity with a model component")

    guard let modelEntity else { return }

    let mesh = modelEntity.model?.mesh
    #expect(mesh != nil, "\(label): Model entity should have a mesh")

    let minBounds = mesh?.bounds.min
    let maxBounds = mesh?.bounds.max
    print("\(label) Min bounds: \(String(describing: minBounds))")
    print("\(label) Max bounds: \(String(describing: maxBounds))")

    #expect(minBounds != nil, "\(label): Entity should have min bounds")
    #expect(maxBounds != nil, "\(label): Entity should have max bounds")

    // Verify the mesh has non-zero extent (not a degenerate mesh)
    if let minBounds, let maxBounds {
        let extent = maxBounds - minBounds
        #expect(extent.x > 0 || extent.y > 0 || extent.z > 0,
                "\(label): Mesh should have non-zero extent")
    }

    // Verify materials were applied
    let materialCount = modelEntity.model?.materials.count ?? 0
    #expect(materialCount > 0, "\(label): Model should have at least one material")
    print("\(label) material count: \(materialCount)")
}


@Test func testLoadDaeFromData() async throws {
    guard let url = Bundle.module.url(forResource: "anymal_base", withExtension: "dae") else {
        Issue.record("Failed to get URL for test resource")
        return
    }

    #expect(FileManager.default.fileExists(atPath: url.path), "url: \(url.absoluteString) does not exist")

    let data = try Data(contentsOf: url)
    print("📦 Loaded \(data.count) bytes from bundle")

    let entity = try await ModelEntity.fromDAEAsset(data: data)
    await verifyEntityHasMesh(entity, label: "anymal_base (data)")
}


@Test func testLoadDaeFromURL() async throws {
    guard let url = Bundle.module.url(forResource: "anymal_base", withExtension: "dae") else {
        Issue.record("Failed to get URL for test resource")
        return
    }

    #expect(FileManager.default.fileExists(atPath: url.path), "url: \(url.absoluteString) does not exist")

    let entity = try await ModelEntity.fromDAEAsset(url: url)
    await verifyEntityHasMesh(entity, label: "anymal_base (url)")
}


@Test func testLoadLink1Dae() async throws {
    guard let url = Bundle.module.url(forResource: "link_1", withExtension: "dae") else {
        Issue.record("Failed to get URL for link_1.dae test resource")
        return
    }

    #expect(FileManager.default.fileExists(atPath: url.path), "url: \(url.absoluteString) does not exist")

    let entity = try await ModelEntity.fromDAEAsset(url: url)
    await verifyEntityHasMesh(entity, label: "link_1")

    let customEntity = try await ModelEntity.fromDAEAsset(url: url, options: .init(loader: .custom))
    await verifyEntityHasMesh(customEntity, label: "link_1 (custom url)")
}

@Test func testWriteAndReloadDAE() async throws {
    let entity = await MainActor.run { ModelEntity(mesh: .generateBox(size: 0.1)) }
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("dae")
    defer { try? FileManager.default.removeItem(at: tmpURL) }

    try await entity.writeDAEAsset(to: tmpURL)
    #expect(FileManager.default.fileExists(atPath: tmpURL.path), "DAE file should exist after write")

    let loaded = try await ModelEntity.fromDAEAsset(url: tmpURL)
    _ = loaded
}


@Test func testLoadLink1DaeFromRawData() async throws {
    guard let url = Bundle.module.url(forResource: "link_1", withExtension: "dae") else {
        Issue.record("Failed to get URL for link_1.dae test resource")
        return
    }

    let data = try Data(contentsOf: url)
    print("Loaded \(data.count) bytes of raw DAE data")

    // Load with explicit custom parser from raw Data
    let customEntity = try await ModelEntity.fromDAEAsset(data: data, options: .init(loader: .custom))
    await verifyEntityHasMesh(customEntity, label: "link_1 (custom data)")

    // Load with auto-detection from raw Data — should detect XML and use custom parser
    let autoEntity = try await ModelEntity.fromDAEAsset(data: data)
    await verifyEntityHasMesh(autoEntity, label: "link_1 (auto data)")
}


// MARK: - Duck.dae Material Tests

/// Parses Duck.dae and returns the first node with a material, or records a failure.
/// - Parameter sourceURL: Forwarded to the parser for texture URL resolution.
///   Pass the bundle file URL to resolve locally, or a remote URL to test remote resolution.
///   Defaults to `nil` (relative texture paths will not be resolved).
private func parseDuckMaterial(sourceURL: URL? = nil) throws -> Collada.Parser.Material? {
    guard let url = Bundle.module.url(forResource: "Duck", withExtension: "dae") else {
        Issue.record("Failed to get URL for Duck.dae test resource")
        return nil
    }
    let data = try Data(contentsOf: url)
    let scene = try Collada.Parser().parse(data: data, sourceURL: sourceURL)

    func findMaterial(in nodes: [Collada.Parser.Node]) -> Collada.Parser.Material? {
        for node in nodes {
            if let mat = node.material { return mat }
            if let found = findMaterial(in: node.children) { return found }
        }
        return nil
    }
    return findMaterial(in: scene.rootNodes)
}

@Test func testDuckMaterialTransparencyIsFullyOpaque() throws {
    guard let mat = try parseDuckMaterial() else { return }

    // Duck.dae uses COLLADA A_ONE convention: opacity = transparent.alpha × transparency
    // Both values are 1.0, so the duck must be fully opaque (no transparent blending).
    let transparentAlpha = mat.transparentColor?.a ?? 1.0
    let transparency = mat.transparency ?? 1.0
    let opacity = transparentAlpha * transparency

    #expect(opacity == 1.0, "Duck opacity should be 1.0 (fully opaque); got \(opacity)")
    #expect(mat.transparentColor?.a == 1.0, "Duck transparent alpha should be 1.0")
    #expect(mat.transparency == 1.0, "Duck transparency scalar should be 1.0")
}

@Test func testDuckMaterialEmissionIsBlack() throws {
    guard let mat = try parseDuckMaterial() else { return }

    // Duck has no self-illumination; emission should be black (r=g=b=0).
    let ec = mat.emissionColor
    #expect(ec?.r == 0.0, "Duck emission red should be 0")
    #expect(ec?.g == 0.0, "Duck emission green should be 0")
    #expect(ec?.b == 0.0, "Duck emission blue should be 0")
}

@Test func testDuckMaterialSpecularIsBlack() throws {
    guard let mat = try parseDuckMaterial() else { return }

    // Duck specular color is black (r=g=b=0).
    let sc = mat.specularColor
    #expect(sc?.r == 0.0, "Duck specular red should be 0")
    #expect(sc?.g == 0.0, "Duck specular green should be 0")
    #expect(sc?.b == 0.0, "Duck specular blue should be 0")
}

@Test func testDuckMaterialShininessValue() throws {
    guard let mat = try parseDuckMaterial() else { return }

    guard let shininess = mat.shininess else {
        Issue.record("Duck shininess should not be nil")
        return
    }
    #expect(abs(shininess - 0.3) < 0.001, "Duck shininess should be ~0.3; got \(shininess)")
}

@Test func testDuckMaterialTextureURLResolvesFromLocalSource() throws {
    // Supply the bundle file URL as the source so relative paths can be resolved.
    guard let daeURL = Bundle.module.url(forResource: "Duck", withExtension: "dae"),
          let mat = try parseDuckMaterial(sourceURL: daeURL) else { return }

    guard let textureURL = mat.diffuseTextureURL else {
        Issue.record("Duck diffuseTextureURL should not be nil when a local sourceURL is provided")
        return
    }
    #expect(textureURL.isFileURL,
            "Texture URL should be a file:// URL for a local source; got '\(textureURL)'")
    #expect(textureURL.lastPathComponent.contains("DuckCM"),
            "Texture filename should reference DuckCM; got '\(textureURL.lastPathComponent)'")
}

@Test func testDuckMaterialTextureURLResolvesFromRemoteSource() throws {
    // Parse local data but simulate a remote origin — no network call required.
    // Verifies that the URL construction logic (deletingLastPathComponent + appendingPathComponent)
    // produces the correct https:// texture URL for a remotely-streamed DAE.
    let remoteDAE = URL(string: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/sourceModels/Duck/Duck.dae")!
    guard let mat = try parseDuckMaterial(sourceURL: remoteDAE) else { return }

    guard let textureURL = mat.diffuseTextureURL else {
        Issue.record("Duck diffuseTextureURL should not be nil when a remote sourceURL is provided")
        return
    }
    let expectedBase = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/sourceModels/Duck"
    #expect(textureURL.absoluteString.hasPrefix(expectedBase),
            "Texture URL should be under the remote source directory; got '\(textureURL.absoluteString)'")
    #expect(textureURL.lastPathComponent.contains("DuckCM"),
            "Texture filename should reference DuckCM; got '\(textureURL.lastPathComponent)'")
}


// MARK: - Remote Streaming

@Test func testLoadDuckDaeFromRemoteURL() async throws {
    // Streams Duck.dae from the Khronos glTF sample repository.
    // The parser derives the texture URL from the source URL, then downloads DuckCM.png
    // asynchronously and applies it as a TextureResource on the material.
    let remoteURL = URL(string: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/sourceModels/Duck/Duck.dae")!

    let entity = try await ModelEntity.fromDAEAsset(url: remoteURL, options: .init(loader: .custom))
    await verifyEntityHasMesh(entity, label: "Duck (remote stream)")
}

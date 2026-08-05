import Testing
import Foundation
@preconcurrency import RealityKit
@preconcurrency import SceneKit
import XMLCoder
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


// MARK: - Duck.dae Tests (remote)

private let duckRemoteURL = URL(string: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/sourceModels/Duck/Duck.dae")!

/// Downloads Duck.dae from the Khronos repo and returns the first resolved material.
/// - Parameter sourceURL: Passed to the parser for texture URL resolution.
///   Defaults to `duckRemoteURL` so relative texture paths resolve to remote https:// URLs.
private func parseDuckMaterial(sourceURL: URL = duckRemoteURL) async throws -> Collada.Parser.Material? {
    let (data, _) = try await URLSession.shared.data(from: duckRemoteURL)
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

@Test func testDuckMaterialTransparencyIsFullyOpaque() async throws {
    guard let mat = try await parseDuckMaterial() else { return }

    // Duck.dae uses COLLADA A_ONE convention: opacity = transparent.alpha × transparency
    // Both values are 1.0, so the duck must be fully opaque (no transparent blending).
    let transparentAlpha = mat.transparentColor?.a ?? 1.0
    let transparency = mat.transparency ?? 1.0
    let opacity = transparentAlpha * transparency

    #expect(opacity == 1.0, "Duck opacity should be 1.0 (fully opaque); got \(opacity)")
    #expect(mat.transparentColor?.a == 1.0, "Duck transparent alpha should be 1.0")
    #expect(mat.transparency == 1.0, "Duck transparency scalar should be 1.0")
}

@Test func testDuckMaterialEmissionIsBlack() async throws {
    guard let mat = try await parseDuckMaterial() else { return }

    let ec = mat.emissionColor
    #expect(ec?.r == 0.0, "Duck emission red should be 0")
    #expect(ec?.g == 0.0, "Duck emission green should be 0")
    #expect(ec?.b == 0.0, "Duck emission blue should be 0")
}

@Test func testDuckMaterialSpecularIsBlack() async throws {
    guard let mat = try await parseDuckMaterial() else { return }

    let sc = mat.specularColor
    #expect(sc?.r == 0.0, "Duck specular red should be 0")
    #expect(sc?.g == 0.0, "Duck specular green should be 0")
    #expect(sc?.b == 0.0, "Duck specular blue should be 0")
}

@Test func testDuckMaterialShininessValue() async throws {
    guard let mat = try await parseDuckMaterial() else { return }

    guard let shininess = mat.shininess else {
        Issue.record("Duck shininess should not be nil")
        return
    }
    #expect(abs(shininess - 0.3) < 0.001, "Duck shininess should be ~0.3; got \(shininess)")
}

@Test func testDuckMaterialTextureURLResolvesFromRemoteSource() async throws {
    // Verifies that relative texture paths are correctly appended to the remote source directory,
    // producing an https:// URL for the DuckCM texture image.
    guard let mat = try await parseDuckMaterial() else { return }

    guard let textureURL = mat.diffuseTextureURL else {
        Issue.record("Duck diffuseTextureURL should not be nil when sourceURL is provided")
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
    let entity = try await ModelEntity.fromDAEAsset(url: duckRemoteURL, options: .init(loader: .custom))
    await verifyEntityHasMesh(entity, label: "Duck (remote stream)")
}


// MARK: - Raw XML COLLADA from a file URL (macOS routing regression)

/// Regression: a RAW XML COLLADA loaded from a file URL must render on every platform.
///
/// ARMOR writes mesh bytes to a UUID-named temp file and calls `fromDAEAsset(url:)`. The URL path
/// used to try `SCNScene(url:)` first on non-iOS regardless of content — for raw XML COLLADA that
/// fails (or worse, yields an empty scene), so the model silently did not render on macOS, while iOS
/// (where that block is compiled out) rendered fine. The loader now routes by CONTENT, matching the
/// `Data` overload, so both platforms take the custom parser for raw XML.
///
/// This deliberately does NOT load the bundle resource directly: a bundled `.dae` may be an
/// Xcode-compiled SCN (bplist), which would exercise the SceneKit path and miss the regression.
@MainActor
@Test func testLoadRawXMLColladaFromFileURL() async throws {
    guard let src = Bundle.module.url(forResource: "link_1", withExtension: "dae"),
          let data = try? Data(contentsOf: src) else {
        Issue.record("link_1.dae fixture is missing")
        return
    }

    // Guard the premise: if this fixture is not raw XML, the test proves nothing.
    let prefix = String(data: data.prefix(64), encoding: .utf8) ?? ""
    #expect(prefix.contains("<?xml") || prefix.contains("<COLLADA"),
            "fixture must be raw XML COLLADA for this regression to be meaningful")
    #expect(ModelEntity.detectDAELoader(for: data) == .custom,
            "raw XML COLLADA must be routed to the custom parser")

    // Mirror ARMOR exactly: raw bytes → UUID-named temp file → load by URL.
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("dae")
    try data.write(to: tmp)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let entity = try await ModelEntity.fromDAEAsset(url: tmp)
    #expect(ModelEntity.containsRenderableMesh(entity),
            "raw XML COLLADA from a file URL must produce renderable geometry")
    verifyEntityHasMesh(entity, label: "raw XML COLLADA from file URL")
}

/// `containsRenderableMesh` is the signal that rejects a "successful" but empty parse, so a silently
/// invisible model becomes a thrown `.noRenderableGeometry` and `.auto` falls back to the other parser.
@MainActor
@Test func testContainsRenderableMeshDetectsEmptyTrees() async throws {
    #expect(ModelEntity.containsRenderableMesh(Entity()) == false,
            "a bare entity has nothing to render")

    let emptyParent = Entity()
    emptyParent.addChild(Entity())
    #expect(ModelEntity.containsRenderableMesh(emptyParent) == false,
            "children without model components are still nothing to render")

    let withNestedMesh = Entity()
    let branch = Entity()
    branch.addChild(ModelEntity(mesh: .generateBox(size: 0.1)))
    withNestedMesh.addChild(branch)
    #expect(ModelEntity.containsRenderableMesh(withNestedMesh),
            "a mesh nested anywhere in the tree counts as renderable")
}

// MARK: - Shared-offset polylist inputs

/// Two `<input>` elements sharing one `offset` must not be treated as two index slots.
///
/// In COLLADA the *offset*, not an input's position in the list, selects which slot of each
/// vertex's index tuple that input reads — so N inputs can share fewer than N offsets, and the
/// real per-vertex stride is `max(offset) + 1`, not `inputs.count`. Using the count overruns
/// `<p>` by exactly the number of duplicated offsets and traps on an out-of-range index.
///
/// Found via `armor://gallery/unitree-h2-plus`: 4 of that robot's 32 DAE meshes
/// (left/right_wrist_pitch_link, left/right_wrist_yaw_link) declare VERTEX and NORMAL both at
/// `offset="0"`, giving 2 inputs over stride 1 — so the parser wanted 2× the indices the file
/// actually contains. The other 28 meshes use distinct offsets and always parsed fine.
@Test func testPolylistWithSharedInputOffsetsDoesNotOverrun() async throws {
    guard let url = Bundle.module.url(forResource: "shared_offset_polylist", withExtension: "dae") else {
        Issue.record("Failed to get URL for shared_offset_polylist.dae test resource")
        return
    }

    let entity = try await ModelEntity.fromDAEAsset(url: url, options: .init(loader: .custom))
    await verifyEntityHasMesh(entity, label: "shared_offset_polylist")
}

/// The stride helper itself, isolated from file loading: an input list's stride is driven by the
/// distinct offsets it declares, not by how many inputs there are.
@Test func testInputStrideUsesMaxOffsetNotInputCount() async throws {
    // VERTEX + NORMAL both at offset 0 → one index per vertex.
    #expect(Collada.Parser.indexStride(forOffsets: [0, 0]) == 1)
    // The ordinary case: each input has its own slot.
    #expect(Collada.Parser.indexStride(forOffsets: [0, 1, 2]) == 3)
    // Sparse/misordered offsets still size by the maximum.
    #expect(Collada.Parser.indexStride(forOffsets: [2, 0]) == 3)
    // Degenerate input: never report a zero stride, which would make every index calculation
    // collapse onto element 0 and loop forever at the call site.
    #expect(Collada.Parser.indexStride(forOffsets: []) == 1)
}

// MARK: - Document units and schema version

/// `<unit meter="0.01">` must scale geometry to meters.
///
/// The fixture's triangle spans 100 document units at `meter="0.01"`, so it must render 1 m
/// across. Ignoring the declaration renders it 100 m — the Unitree H2 Plus symptom, where
/// `head_pitch_link.dae` (the one centimeter file among its 32 meshes) came out ~100x oversized
/// and metres out of place.
///
/// World bounds, not `mesh.bounds`: the scale rides on the root node's transform, so the local
/// mesh bounds still read in raw document units. Measuring locally is what made this look
/// "unfixed" during development.
@Test func testCentimeterUnitScalesGeometryToMeters() async throws {
    guard let url = Bundle.module.url(forResource: "unit_centimeter_1_5_0", withExtension: "dae") else {
        Issue.record("Failed to get URL for unit_centimeter_1_5_0.dae test resource")
        return
    }

    let entity = try await ModelEntity.fromDAEAsset(url: url, options: .init(loader: .custom))
    let extents = await MainActor.run { entity.visualBounds(relativeTo: nil).extents }

    #expect(abs(extents.x - 1.0) < 0.001, "100 cm must render as 1 m, got \(extents.x)")
    #expect(abs(extents.y - 1.0) < 0.001, "100 cm must render as 1 m, got \(extents.y)")
}

/// The same fixture is COLLADA **1.5.0** (2008/03 namespace), not 1.4.1 (2005/11). Both parse
/// because `shouldProcessNamespaces` strips the namespace before element names are matched —
/// 28 of H2 Plus's 32 meshes are 1.5.0. If that decoder setting is ever removed, this fails
/// instead of silently breaking every Cinema 4D export.
@Test func testParsesCollada150Namespace() async throws {
    guard let url = Bundle.module.url(forResource: "unit_centimeter_1_5_0", withExtension: "dae") else {
        Issue.record("Failed to get URL for unit_centimeter_1_5_0.dae test resource")
        return
    }
    let raw = try String(contentsOf: url, encoding: .utf8)
    #expect(raw.contains("2008/03/COLLADASchema"), "fixture must be the 1.5.0 namespace for this test to mean anything")

    let entity = try await ModelEntity.fromDAEAsset(url: url, options: .init(loader: .custom))
    await verifyEntityHasMesh(entity, label: "collada 1.5.0")
}

/// `unitScale` reads `meter`, ignores the `name` label, defaults to 1 when absent, and refuses
/// values that would collapse or mirror the model.
///
/// Driven through real XML decoding rather than a hand-built struct, so it also covers the
/// `DynamicNodeDecoding` conformance that makes `meter`/`name` decode as ATTRIBUTES. Without
/// that, `Unit` decodes all-nil — indistinguishable from "no unit declared" — and a centimeter
/// document silently renders 100x too large with no error anywhere.
@Test func testUnitScaleParsing() async throws {
    func scale(_ unitElement: String) throws -> Float {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <COLLADA xmlns="http://www.collada.org/2008/03/COLLADASchema" version="1.5.0">
          <asset>\(unitElement)<up_axis>Y_UP</up_axis></asset>
        </COLLADA>
        """
        let decoder = XMLDecoder()
        decoder.trimValueWhitespaces = false
        decoder.shouldProcessNamespaces = true
        return try decoder.decode(Collada.self, from: Data(xml.utf8)).unitScale
    }

    #expect(try scale(#"<unit meter="0.01" name="centimeter"/>"#) == 0.01)
    #expect(try scale(#"<unit meter="0.001" name="millimeter"/>"#) == 0.001)
    #expect(try scale(#"<unit meter="1" name="meter"/>"#) == 1)
    // Absent <unit> means meters, per the specification.
    #expect(try scale("") == 1)
    // `meter` is authoritative; a mislabelled name must not override it.
    #expect(try scale(#"<unit meter="0.01" name="meter"/>"#) == 0.01)
    // Degenerate declarations are ignored rather than collapsing or mirroring the geometry.
    #expect(try scale(#"<unit meter="0" name="broken"/>"#) == 1)
    #expect(try scale(#"<unit meter="-1" name="broken"/>"#) == 1)
}

// MARK: - Multi-material geometry

/// A single `<geometry>` split into several `<polylist>` parts, each naming a different material
/// symbol, is ordinary COLLADA — it is how exporters represent a part with painted trim.
/// `unitree_ros`' H2 Plus `torso_link.dae` is exactly this shape: three polylists
/// (24 / 4112 / 17481 polygons) bound to a black material, a second black one, and a light
/// lavender one, with the LIGHT material covering ~81% of the surface.
///
/// This fixture reproduces that structure at three triangles: first bound symbol black, the
/// majority-surface material light.
@MainActor @Test func testMultiMaterialGeometryKeepsEveryMaterial() async throws {
    guard let url = Bundle.module.url(forResource: "multi_material", withExtension: "dae") else {
        Issue.record("Failed to get URL for test resource")
        return
    }
    let entity = try await ModelEntity.fromDAEAsset(url: url, options: .init(loader: .custom))
    let model = try #require(findModelEntity(in: entity)?.model)

    // Three bound materials, so three materials on the model — one per part.
    #expect(model.materials.count == 3, "each <polylist>'s material must survive")
    #expect(model.mesh.contents.models.flatMap { Array($0.parts) }.count == 3,
            "the three polylists must stay separate mesh parts, not merge into one")
}

/// The visible symptom: the whole part rendering black. The parser bound only the FIRST
/// `<instance_material>` and applied it to the merged mesh, so H2 Plus' torso and head took the
/// black trim colour over their entire surface instead of the light body colour.
@MainActor @Test func testMultiMaterialGeometryDoesNotPaintEverythingWithTheFirstMaterial() async throws {
    guard let url = Bundle.module.url(forResource: "multi_material", withExtension: "dae") else {
        Issue.record("Failed to get URL for test resource")
        return
    }
    let entity = try await ModelEntity.fromDAEAsset(url: url, options: .init(loader: .custom))
    let model = try #require(findModelEntity(in: entity)?.model)

    let tints = model.materials.compactMap { ($0 as? PhysicallyBasedMaterial)?.baseColor.tint }
    let isBlack: (CGColor) -> Bool = { c in
        guard let comps = c.components, comps.count >= 3 else { return false }
        return comps[0] < 0.01 && comps[1] < 0.01 && comps[2] < 0.01
    }
    #expect(tints.contains { !isBlack($0.cgColor) },
            "the light body material (0.79 0.82 0.93) must appear somewhere — all-black means the first bound material was applied to the whole merged mesh")
}

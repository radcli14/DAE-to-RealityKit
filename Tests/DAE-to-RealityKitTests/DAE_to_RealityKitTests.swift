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

    let entity = await ModelEntity.fromDAEAsset(data: data)
    #expect(entity != nil, "Entity should be loaded successfully")
    guard let entity else { return }

    await verifyEntityHasMesh(entity, label: "anymal_base (data)")
}


@Test func testLoadDaeFromURL() async throws {
    guard let url = Bundle.module.url(forResource: "anymal_base", withExtension: "dae") else {
        Issue.record("Failed to get URL for test resource")
        return
    }

    #expect(FileManager.default.fileExists(atPath: url.path), "url: \(url.absoluteString) does not exist")

    let entity = await ModelEntity.fromDAEAsset(url: url)
    #expect(entity != nil, "Entity failed to load from \(url.absoluteString)")
    guard let entity else {
        print("⚠️ URL-based entity load failed (likely due to sandbox permissions)")
        return
    }

    await verifyEntityHasMesh(entity, label: "anymal_base (url)")
}


@Test func testLoadLink1Dae() async throws {
    guard let url = Bundle.module.url(forResource: "link_1", withExtension: "dae") else {
        Issue.record("Failed to get URL for link_1.dae test resource")
        return
    }

    #expect(FileManager.default.fileExists(atPath: url.path), "url: \(url.absoluteString) does not exist")

    let entity = await ModelEntity.fromDAEAsset(url: url)
    #expect(entity != nil, "Entity should be loaded successfully from link_1.dae")
    guard let entity else { return }

    await verifyEntityHasMesh(entity, label: "link_1")
}

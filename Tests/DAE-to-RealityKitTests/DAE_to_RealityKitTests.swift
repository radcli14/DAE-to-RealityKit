import Testing
import Foundation
@preconcurrency import RealityKit
@preconcurrency import SceneKit
@testable import DAE_to_RealityKit


@Test func testLoadDaeFromData() async throws {
    // Get the URL of a test .dae file in the test bundle
    guard let url = Bundle.module.url(forResource: "shiny", withExtension: "dae") else {
        Issue.record("Failed to get URL for test resource")
        return
    }
    
    // Verify that the file exists
    #expect(FileManager.default.fileExists(atPath: url.path), "url: \(url.absoluteString) does not exist")
    
    // Load the data from the bundle (this should work even with sandbox restrictions)
    let data = try Data(contentsOf: url)
    print("📦 Loaded \(data.count) bytes from bundle")
    
    // Test loading from Data (which writes to cache directory internally)
    let entity = await ModelEntity.fromDAEAsset(data: data)
    
    #expect(entity != nil, "Entity should be loaded successfully")
    
    let minBounds = await entity?.model?.mesh.bounds.min
    let maxBounds = await entity?.model?.mesh.bounds.max
    print("Min bounds: \(String(describing: minBounds))")
    print("Max bounds: \(String(describing: maxBounds))")
    
    // Verify that we got some bounds (adjust expected values based on your actual model)
    #expect(minBounds != nil, "Entity should have min bounds")
    #expect(maxBounds != nil, "Entity should have max bounds")
}


@Test func testLoadDaeFromURL() async throws {
    // Get the URL of a test .dae file in the test bundle
    guard let url = Bundle.module.url(forResource: "shiny", withExtension: "dae") else {
        Issue.record("Failed to get URL for test resource")
        return
    }

    // Verify that the file exists
    #expect(FileManager.default.fileExists(atPath: url.path), "url: \(url.absoluteString) does not exist")

    // Try loading directly from URL (may fail due to sandbox permissions)
    let entity = await ModelEntity.fromDAEAsset(url: url)
    #expect(entity != nil, "Entity failed to load from \(url.absoluteString)")
    
    // Note: This test might fail in sandboxed environments
    // If it does, the Data-based test above should still work
    guard let entity else {
        print("⚠️ URL-based entity load failed (likely due to sandbox permissions)")
        return
    }

    let minBounds = await entity.model?.mesh.bounds.min
    let maxBounds = await entity.model?.mesh.bounds.max
    print("Min bounds: \(String(describing: minBounds))")
    print("Max bounds: \(String(describing: maxBounds))")
    
    #expect(minBounds != nil, "Entity should have min bounds")
    #expect(maxBounds != nil, "Entity should have max bounds")
}

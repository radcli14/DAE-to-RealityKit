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

public extension SCNNode {
    /// Recursively find all geometry nodes in this node's hierarchy
    var geometryNodes: [SCNNode] {
        var result: [SCNNode] = []
        if geometry != nil {
            result.append(self)
        }
        for child in childNodes {
            result.append(contentsOf: child.geometryNodes)
        }
        return result
    }
    
    /// Debug method to print the node hierarchy
    func unpack(indent: String = "") {
        print("\(indent)📦 Node: \(name ?? "unnamed")")
        if let geometry = geometry {
            print("\(indent)  └─ Geometry: \(geometry.name ?? "unnamed"), \(geometry.elements.count) elements")
        }
        for child in childNodes {
            child.unpack(indent: indent + "  ")
        }
    }
}

public extension SCNGeometry {
    func unpack() {
        elements.enumerated().forEach { i, element in
            print("  * geometry.elements[\(i)]:", element)
            //print("  * element.primitives:", element.primitives)
            print("    > element.primitiveCount:", element.primitiveCount)
            print("    > element.primitiveType:", element.primitiveType)
            print("    > element.bytesPerIndex:", element.bytesPerIndex)
            print("    > element.indicesChannelCount:", element.indicesChannelCount)
            
        }
        /*sources.enumerated().forEach { i, source in
            print("  sources[\(i)]:", source)
            
        }*/
        print("  * sources.vertices?.count:", sources.vertices?.count ?? 0)
        print("  * sources.normals?.count:", sources.normals?.count ?? 0)
        print("  * sources.textureCoordinates?.count:", sources.textureCoordinates?.count ?? 0)
    }
    
    /// An array of `MeshDescriptor` derived from the `positions` array and primitive indices contained in the `submeshes`
    @MainActor var descriptors: [MeshDescriptor] {
        
        // Get the computed properties first, so they aren't computed multiple times inside the map
        guard let positions = sources.vertices,
              let textureCoordinates = sources.textureCoordinates,
              let normals = sources.normals
        else {
            print("⚠️ Missing required geometry sources")
            return []
        }

        print("📊 Geometry has \(positions.count) vertices, \(elements.count) elements")
        
        // Map the mesh descriptors from the submeshes
        return elements.enumerated().map { (index, element) in
            // Initialize the descriptor with positions
            var descriptor = MeshDescriptor(name: (name ?? "dae") + "_\(index)")
            descriptor.positions = .init(positions)
            
            print("  Element[\(index)]: \(element.primitiveCount) primitives")
            
            // Make sure the coordinates and normals are dimensionally consistent with the positions
            if textureCoordinates.count == positions.count {
                descriptor.textureCoordinates = .init(textureCoordinates)
            } else {
                print("  ⚠️ Texture coordinate count (\(textureCoordinates.count)) doesn't match vertex count (\(positions.count))")
            }
            
            if normals.count == positions.count {
                descriptor.normals = .init(normals)
            } else {
                print("  ⚠️ Normal count (\(normals.count)) doesn't match vertex count (\(positions.count))")
            }
            
            // Add primitives from the submesh
            let primitives = element.primitives
            if let triangles = primitives {
                descriptor.primitives = triangles
                print("  ✓ Added primitives successfully")
            } else {
                print("  ⚠️ Could not generate primitives for element[\(index)]")
            }
            
            return descriptor
        }
    }
    
    /// Asynchrnously onbtain a RealityKit `MeshResource` derived from the meshes in this model
    @MainActor func getMeshResource() async -> MeshResource? {
        do {
            let sendableDescriptors = UnsafeSendableDescriptors(descriptors: descriptors)
            return try await MeshResource(from: sendableDescriptors.descriptors)
        } catch {
            print("SCNGeometry.getMeshResource() failed because \(error.localizedDescription)")
            return nil
        }
    }
    
    @MainActor var rkMaterials: [PhysicallyBasedMaterial] {
        materials.compactMap { $0.rkMaterial }
    }
    
    // TODO: I don't like the wrappers below, but it was a correction for "sending self.materials risks causing data races"

    /// Wrapper to make non-Sendable descriptors transferable across actor boundaries
    private struct UnsafeSendableDescriptors: @unchecked Sendable {
        let descriptors: [MeshDescriptor]
    }
}

public extension SCNMaterial {
    @MainActor var rkMaterial: PhysicallyBasedMaterial? {
        var material = PhysicallyBasedMaterial()
        
        if let color = diffuse.uiColor {
            material.baseColor = .init(tint: color)
        } /*else if let image = diffuse.uiImage {
            material.baseColor = .init(texture: .init(<#T##resource: TextureResource##TextureResource#>)
        }*/
        
        return material
    }
}

#if os(ios)
public extension SCNMaterialProperty {
    var uiColor: UIColor? {
        contents as? UIColor
    }
    
    var uiImage: UIImage? {
        contents as? UIImage
    }
}
#endif
#if os(macOS)
public extension SCNMaterialProperty {
    var uiColor: NSColor? {
        contents as? NSColor
    }
    
    var uiImage: NSImage? {
        contents as? NSImage
    }
}
#endif


public extension SCNGeometrySource {
    var hasFloat3Array: Bool {
        semantic == .vertex || semantic == .normal
    }
    
    var hasFloat2Array: Bool {
        semantic == .texcoord
    }
    
    /// Unpacks the array of `SIMD3<Float>` from this source's `Data`
    func getFloat3Array() -> [SIMD3<Float>] {
        guard hasFloat3Array else { return [] }
        
        // Validate data format expectations
        guard componentsPerVector == 3,
              dataStride >= MemoryLayout<Float>.stride * 3,
              bytesPerComponent == MemoryLayout<Float>.stride else {
            print("⚠️ Unexpected data format for Float3 array:")
            print("   componentsPerVector: \(componentsPerVector) (expected 3)")
            print("   dataStride: \(dataStride) (expected >= 12)")
            print("   bytesPerComponent: \(bytesPerComponent) (expected 4)")
            return []
        }
        
        var result = [SIMD3<Float>]()
        result.reserveCapacity(vectorCount)
        
        data.withUnsafeBytes { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else { return }
            
            // Start at the data offset (in bytes)
            let startPointer = baseAddress.advanced(by: dataOffset)
            
            // Loop through each of the vectors
            for i in 0 ..< vectorCount  {
                // Calculate byte offset for this vector (dataStride is in bytes)
                let byteOffset = i * dataStride
                let vectorPointer = startPointer
                    .advanced(by: byteOffset)
                    .assumingMemoryBound(to: Float.self)

                // Unpack this vector data into the SIMD3<Float>
                result.append(.init(
                    x: vectorPointer[0],
                    y: vectorPointer[1],
                    z: vectorPointer[2]
                ))
            }
        }
        return result
    }
    
    /// Unpacks the array of `SIMD2<Float>` from this source's `Data`
    func getFloat2Array() -> [SIMD2<Float>] {
        guard hasFloat2Array else { return [] }
        
        // Validate data format expectations
        guard componentsPerVector == 2,
              dataStride >= MemoryLayout<Float>.stride * 2,
              bytesPerComponent == MemoryLayout<Float>.stride else {
            print("⚠️ Unexpected data format for Float2 array:")
            print("   componentsPerVector: \(componentsPerVector) (expected 2)")
            print("   dataStride: \(dataStride) (expected >= 8)")
            print("   bytesPerComponent: \(bytesPerComponent) (expected 4)")
            return []
        }
        
        var result = [SIMD2<Float>]()
        result.reserveCapacity(vectorCount)
        
        data.withUnsafeBytes { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else { return }
            
            // Start at the data offset (in bytes)
            let startPointer = baseAddress.advanced(by: dataOffset)
            
            // Loop through each of the vectors
            for i in 0 ..< vectorCount  {
                // Calculate byte offset for this vector (dataStride is in bytes)
                let byteOffset = i * dataStride
                let vectorPointer = startPointer
                    .advanced(by: byteOffset)
                    .assumingMemoryBound(to: Float.self)

                // Unpack this vector data into the SIMD2<Float>
                result.append(.init(
                    x: vectorPointer[0],
                    y: vectorPointer[1]
                ))
            }
        }
        return result
    }
}

public extension [SCNGeometrySource] {
    var vertices: [SIMD3<Float>]? {
        filter { $0.semantic == .vertex }.first?.getFloat3Array()
    }
    
    var normals: [SIMD3<Float>]? {
        filter { $0.semantic == .normal }.first?.getFloat3Array()
    }
    
    var textureCoordinates: [SIMD2<Float>]? {
        filter { $0.semantic == .texcoord }.first?.getFloat2Array()
    }
}

public extension SCNGeometryElement {
    var indices: [UInt32] {
        var result = [UInt32]()
        
        data.withUnsafeBytes { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else { return }

            switch bytesPerIndex {
            case 2:
                // Data is 16-bit (UInt16), so we read and convert to UInt32
                let pointer = baseAddress.assumingMemoryBound(to: UInt16.self)
                for i in 0..<indexCount {
                    // Read the 16-bit index and cast it up to 32-bit
                    result.append(UInt32(pointer[i]))
                }
            
            case 4:
                // Data is already 32-bit (UInt32)
                let pointer = baseAddress.assumingMemoryBound(to: UInt32.self)
                for i in 0..<indexCount {
                    result.append(pointer[i])
                }
            
            default:
                // Handle unsupported types (e.g., .invalid)
                print("SCNGeometryElement bytesPerIndex \(bytesPerIndex) not supported for unpacking indices.")
                return
            }
        }
        
        print("    > indices.count:", result.count)
        if !result.isEmpty {
            print("    > indices range: \(result.min()!) ... \(result.max()!)")
        }
        return result
    }
    
    var indexCount: Int {
        switch primitiveType {
        case .triangles: primitiveCount * 3
        case .polygon: primitiveCount
        default: 0
        }
    }
    
    @MainActor var primitives: MeshDescriptor.Primitives? {
        var geometryString = ""
        switch primitiveType {
        case .triangles: return .triangles(indices)
        case .polygon: geometryString = "polygon"
        case .triangleStrip: geometryString = "triangleStrip"
        case .line: geometryString = "line"
        case .point: geometryString = "point"
        @unknown default:
            geometryString = "???"
        }
        print("SCNGeometryElement primitiveType: \(geometryString) is unknown or not handled, returning nil")
        return nil
    }
}

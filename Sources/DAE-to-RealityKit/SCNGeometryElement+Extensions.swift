//
//  SCNGeometryElement+Extensions.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 12/20/25.
//

import Foundation
import RealityKit
import SceneKit


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
        case .triangleStrip: primitiveCount + 2
        case .polygon:
            // For polygons, the total index count is the total number of bytes
            // divided by bytesPerIndex — SceneKit stores all vertex indices contiguously
            data.count / bytesPerIndex
        default: 0
        }
    }

    @MainActor var primitives: MeshDescriptor.Primitives? {
        switch primitiveType {
        case .triangles:
            return .triangles(indices)
        case .polygon:
            // All polygons in DAE polylist with vcount=3 are triangles.
            // Treat them as triangles since RealityKit MeshDescriptor supports that.
            let allIndices = indices
            if allIndices.count == primitiveCount * 3 {
                // All faces are triangles
                return .triangles(allIndices)
            } else {
                // Mixed polygon — triangulate by fan triangulation
                return triangulatedPolygons()
            }
        case .triangleStrip:
            // Convert triangle strip to individual triangles
            let allIndices = indices
            guard allIndices.count >= 3 else { return nil }
            var triangles = [UInt32]()
            triangles.reserveCapacity((allIndices.count - 2) * 3)
            for i in 0..<(allIndices.count - 2) {
                if i % 2 == 0 {
                    triangles.append(allIndices[i])
                    triangles.append(allIndices[i + 1])
                    triangles.append(allIndices[i + 2])
                } else {
                    // Swap winding order for odd triangles
                    triangles.append(allIndices[i + 1])
                    triangles.append(allIndices[i])
                    triangles.append(allIndices[i + 2])
                }
            }
            return .triangles(triangles)
        default:
            print("SCNGeometryElement primitiveType \(primitiveType.rawValue) not supported")
            return nil
        }
    }

    /// Triangulate polygons using fan triangulation for mixed polygon meshes
    @MainActor private func triangulatedPolygons() -> MeshDescriptor.Primitives? {
        // Read the polygon vertex counts from the data
        // For polygon type, SceneKit stores all indices contiguously
        // We need to know the vertex count per polygon — unfortunately SCeneKit
        // doesn't directly expose vcount, but all indices are in the data buffer.
        // Since we can't get per-polygon counts from SCNGeometryElement directly,
        // and the common case from DAE polylist is all-triangles (vcount=3),
        // we'll attempt to treat them all as triangles.
        let allIndices = indices
        if allIndices.count % 3 == 0 {
            return .triangles(allIndices)
        }
        print("  ⚠️ Polygon mesh with non-triangle faces cannot be triangulated automatically")
        return nil
    }
}

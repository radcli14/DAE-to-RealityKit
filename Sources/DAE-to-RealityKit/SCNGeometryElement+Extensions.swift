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

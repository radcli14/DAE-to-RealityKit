//
//  SCNGeometrySource+Extensions.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 12/20/25.
//

import Foundation
import SceneKit


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

//
//  Transforms.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import simd

extension Collada {
    struct Transforms {
        enum UpAxis: String, Sendable {
            case x = "X_UP"
            case y = "Y_UP"
            case z = "Z_UP"

            static func from(_ string: String?) -> UpAxis { UpAxis(rawValue: string ?? "Y_UP") ?? .y }
        }

        enum AxisConversion {
            /// Convert from given COLLADA up-axis to RealityKit's Y-up
            static func toYUp(from up: UpAxis) -> simd_float4x4 {
                switch up {
                case .y: return matrix_identity_float4x4
                case .z:
                    // Rotate -90 degrees around X to bring Z-up to Y-up
                    let angle: Float = -.pi / 2
                    let c = cos(angle), s = sin(angle)
                    return simd_float4x4(SIMD4(1, 0, 0, 0),
                                         SIMD4(0, c, s, 0),
                                         SIMD4(0, -s, c, 0),
                                         SIMD4(0, 0, 0, 1))
                case .x:
                    // Rotate +90 degrees around Z to bring X-up to Y-up
                    let angle: Float = .pi / 2
                    let c = cos(angle), s = sin(angle)
                    return simd_float4x4(SIMD4(c, s, 0, 0),
                                         SIMD4(-s, c, 0, 0),
                                         SIMD4(0,  0, 1, 0),
                                         SIMD4(0,  0, 0, 1))
                }
            }
        }
    }
}

extension Collada {
    var rootTransform: simd_float4x4 {
        let up = Transforms.UpAxis.from(asset?.upAxis)
        return Transforms.AxisConversion.toYUp(from: up)
    }
}

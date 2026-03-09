//
//  Transforms.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import simd

extension Collada {
    /// Utilities for coordinate system conversion between COLLADA and RealityKit.
    ///
    /// COLLADA 1.4.1, Section 7.1.1 defines three possible up-axis orientations via
    /// `<up_axis>`: `Y_UP`, `Z_UP`, or `X_UP`. RealityKit uses Y-up, so axis
    /// conversion may be required when importing assets authored in other conventions.
    struct Transforms {
        /// The up-axis orientation of a COLLADA document.
        ///
        /// Corresponds to the `<up_axis>` element value within `<asset>`.
        /// Defaults to `Y_UP` per the COLLADA specification when absent.
        enum UpAxis: String, Sendable {
            case x = "X_UP"
            case y = "Y_UP"
            case z = "Z_UP"

            /// Creates an ``UpAxis`` from the raw string, defaulting to `.y` if nil or unrecognized.
            static func from(_ string: String?) -> UpAxis { UpAxis(rawValue: string ?? "Y_UP") ?? .y }
        }

        /// Provides rotation matrices to convert from a given COLLADA up-axis to RealityKit's Y-up.
        enum AxisConversion {
            /// Returns a rotation matrix that transforms coordinates from the given up-axis to Y-up.
            /// - Parameter up: The source coordinate system's up-axis.
            /// - Returns: A `simd_float4x4` rotation matrix (identity for Y-up).
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
    /// Computes the root transform matrix to convert from the document's up-axis to RealityKit's Y-up.
    var rootTransform: simd_float4x4 {
        let up = Transforms.UpAxis.from(asset?.upAxis)
        return Transforms.AxisConversion.toYUp(from: up)
    }
}

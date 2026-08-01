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
    /// Meters per document distance unit, from `<asset><unit meter="…">`.
    ///
    /// Defaults to 1 when the element is absent (the COLLADA default: the document is already in
    /// meters), and ignores a non-positive or non-finite declaration rather than collapsing or
    /// mirroring the whole model.
    var unitScale: Float {
        guard let meter = asset?.unit?.meter, meter.isFinite, meter > 0 else { return 1 }
        return Float(meter)
    }

    /// A uniform scale matrix converting the document's distance unit to meters, or identity when
    /// the document is already in meters.
    ///
    /// `<unit meter="0.01" name="centimeter">` means one unit in the file equals 0.01 m, so
    /// coordinates must be SCALED BY that factor to reach meters. Ignoring it renders a
    /// centimeter-authored file 100× too large — exactly what Unitree H2 Plus's
    /// `head_pitch_link.dae` (a Cinema 4D export, and the only centimeter file among its 32
    /// meshes) did: a head 100× oversized and metres below the robot.
    var unitScaleTransform: simd_float4x4 {
        let scale = unitScale
        guard scale != 1 else { return matrix_identity_float4x4 }
        return simd_float4x4(diagonal: SIMD4(scale, scale, scale, 1))
    }

    /// The up-axis rotation that would bring this document into RealityKit's Y-up.
    ///
    /// ⚠️ **Deliberately NOT applied by the parser**, and it never has been: `makeNode` threads it
    /// down as `parentWorldTransform` but stores only each node's own `localTransform`, so the
    /// value is computed and discarded at every level. Enabling it is a real behavioural change,
    /// not a bug fix — consumers of this package have only ever seen unrotated geometry and may
    /// compensate downstream (ARMOR, for one, deliberately keeps URDF meshes Z-up and applies its
    /// own Z-up→Y-up conversion in the scene graph, so rotating here would double-correct and
    /// tip every existing robot on its side). Left inert on purpose; the unit scale above is
    /// applied separately and independently precisely so fixing the scale bug does not smuggle in
    /// this rotation.
    var rootTransform: simd_float4x4 {
        let up = Transforms.UpAxis.from(asset?.upAxis)
        return Transforms.AxisConversion.toYUp(from: up)
    }
}

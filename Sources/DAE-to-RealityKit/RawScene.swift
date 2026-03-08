//
//  RawScene.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import simd

public struct RawScene: Sendable {
    public var rootNodes: [RawNode]
    public init(rootNodes: [RawNode]) { self.rootNodes = rootNodes }
}

public struct RawNode: Sendable, Identifiable {
    public var id: String { name ?? uuid }
    private let uuid = UUID().uuidString

    public var name: String?
    public var transform: simd_float4x4
    public var children: [RawNode]
    // Future: geometry refs, materials, etc.

    public init(name: String?, transform: simd_float4x4, children: [RawNode] = []) {
        self.name = name
        self.transform = transform
        self.children = children
    }
}

public enum UpAxis: String, Sendable {
    case x = "X_UP"
    case y = "Y_UP"
    case z = "Z_UP"

    public static func from(_ string: String?) -> UpAxis { UpAxis(rawValue: string ?? "Y_UP") ?? .y }
}

public enum AxisConversion {
    // Convert from given COLLADA up-axis to RealityKit's Y-up
    public static func toYUp(from up: UpAxis) -> simd_float4x4 {
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
            // Rotate +90 degrees around Z then swap X/Y if needed; simple approach:
            let angle: Float = .pi / 2
            let c = cos(angle), s = sin(angle)
            return simd_float4x4(SIMD4(c, -s, 0, 0),
                                 SIMD4(s,  c, 0, 0),
                                 SIMD4(0,  0, 1, 0),
                                 SIMD4(0,  0, 0, 1))
        }
    }
}


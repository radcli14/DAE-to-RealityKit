//
//  RawScene.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import RealityKit
import simd

/// Stores the positions, normals, uvs, and indices arrays representing a mesh
public struct RawMesh: Sendable {
    public var positions: [SIMD3<Float>]
    public var normals: [SIMD3<Float>]? = nil
    public var uvs: [SIMD2<Float>]? = nil
    public var indices: [UInt32]
    public init(positions: [SIMD3<Float>], normals: [SIMD3<Float>]? = nil, uvs: [SIMD2<Float>]? = nil, indices: [UInt32]) {
        self.positions = positions
        self.normals = normals
        self.uvs = uvs
        self.indices = indices
    }
}

/// A set of root `RawNode` objects representing the base element or elements in the assembly, which themselves may have child nodes.
public struct RawScene: Sendable {
    public var rootNodes: [RawNode]
    public init(rootNodes: [RawNode]) { self.rootNodes = rootNodes }
}

/// A single node in the assembly, which stores transform, mesh, material, and child relationships in the assembly.
public struct RawNode: Sendable, Identifiable {
    public var id: String { name ?? uuid }
    private let uuid = UUID().uuidString

    public var name: String?
    /// The node's local transform relative to its parent
    public var localTransform: simd_float4x4
    public var mesh: RawMesh?
    public var diffuseColor: ColorRGBA?
    public var children: [RawNode]

    public init(
        name: String?,
        localTransform: simd_float4x4,
        mesh: RawMesh? = nil,
        diffuseColor: ColorRGBA? = nil,
        children: [RawNode] = []
    ) {
        self.name = name
        self.localTransform = localTransform
        self.mesh = mesh
        self.diffuseColor = diffuseColor
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
    /// Convert from given COLLADA up-axis to RealityKit's Y-up
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


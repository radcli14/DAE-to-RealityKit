//
//  ColladaParser.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import XMLCoder
import simd

public enum ColladaParserError: Error {
    case decodeFailed(Error)
}

public struct ColladaParser {
    public init() {}

    public func parse(data: Data) throws -> RawScene {
        let decoder = XMLDecoder()
        decoder.trimValueWhitespaces = true
        decoder.shouldProcessNamespaces = false

        do {
            let collada = try decoder.decode(Collada.self, from: data)
            let up = UpAxis.from(collada.asset?.upAxis)
            let rootTransform = AxisConversion.toYUp(from: up)

            // Build node hierarchy from the first visual scene referenced in <scene>
            let nodes = buildNodes(from: collada, applying: rootTransform)
            return RawScene(rootNodes: nodes)
        } catch {
            throw ColladaParserError.decodeFailed(error)
        }
    }

    private func buildNodes(from collada: Collada, applying root: simd_float4x4) -> [RawNode] {
        guard let lib = collada.libraryVisualScenes else { return [] }
        // Resolve visual scene by instance URL if provided
        let sceneId = collada.scene?.instanceVisualScene?.url.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let visualScene: VisualScene?
        if let id = sceneId {
            visualScene = lib.visualScenes.first { $0.visualSceneId == id }
        } else {
            visualScene = lib.visualScenes.first
        }
        guard let vs = visualScene else { return [] }
        return vs.nodes.map { node in
            makeRawNode(node, parentTransform: root)
        }
    }

    private func makeRawNode(_ node: Node, parentTransform: simd_float4x4) -> RawNode {
        let local = matrix(from: node)
        let world = parentTransform * local
        let children = (node.children ?? []).map { makeRawNode($0, parentTransform: world) }
        return RawNode(name: node.name ?? node.nodeId, transform: world, children: children)
    }

    private func matrix(from node: Node) -> simd_float4x4 {
        // Prefer <matrix> if provided; otherwise compose TRS
        if let m = node.matrix?.values, m.count == 16 {
            // COLLADA matrices are column-major; convert Double -> Float
            let f = m.map { Float($0) }
            return simd_float4x4(columns: (
                SIMD4(f[0], f[1], f[2], f[3]),
                SIMD4(f[4], f[5], f[6], f[7]),
                SIMD4(f[8], f[9], f[10], f[11]),
                SIMD4(f[12], f[13], f[14], f[15])
            ))
        }
        // Basic TRS composition (translate, rotate axes, scale). This is a simplified approach.
        var result = matrix_identity_float4x4
        if let t = node.translate?.first?.values, t.count >= 3 {
            result.columns.3 = SIMD4(Float(t[0]), Float(t[1]), Float(t[2]), 1)
        }
        if let s = node.scale?.first?.values, s.count >= 3 {
            let sx = Float(s[0]), sy = Float(s[1]), sz = Float(s[2])
            let S = simd_float4x4(SIMD4(sx,0,0,0), SIMD4(0,sy,0,0), SIMD4(0,0,sz,0), SIMD4(0,0,0,1))
            result = result * S
        }
        if let rotations = node.rotate {
            for r in rotations {
                let v = r.values
                if v.count >= 4 {
                    let axis = SIMD3(Float(v[0]), Float(v[1]), Float(v[2]))
                    let angle = Float(v[3]) * Float.pi / 180.0
                    result = result * rotationMatrix(axis: axis, angle: angle)
                }
            }
        }
        return result
    }

    private func rotationMatrix(axis: SIMD3<Float>, angle: Float) -> simd_float4x4 {
        let a = simd_normalize(axis)
        let c = cos(angle)
        let s = sin(angle)
        let t = 1 - c
        let x = a.x, y = a.y, z = a.z
        return simd_float4x4(
            SIMD4(t*x*x + c,   t*x*y - s*z, t*x*z + s*y, 0),
            SIMD4(t*x*y + s*z, t*y*y + c,   t*y*z - s*x, 0),
            SIMD4(t*x*z - s*y, t*y*z + s*x, t*z*z + c,   0),
            SIMD4(0, 0, 0, 1)
        )
    }
}


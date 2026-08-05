//
//  RawScene.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import simd

extension Collada.Parser {

    /// The parsed scene, containing a hierarchy of nodes ready for RealityKit entity conversion.
    ///
    /// Represents the intermediate result of parsing a COLLADA document: a tree of nodes
    /// with resolved transforms, extracted mesh geometry, and material properties.
    struct Scene: Sendable {
        /// The top-level nodes in the scene hierarchy, corresponding to the root
        /// `<node>` elements within the active `<visual_scene>`.
        var rootNodes: [Node]
    }

    /// A parsed scene graph node with resolved transform, mesh, material, and children.
    ///
    /// Each node corresponds to a `<node>` element from the COLLADA visual scene,
    /// with its geometry, material bindings, and transform already resolved from the
    /// various library references.
    struct Node: Sendable, Identifiable {
        var id: String { name ?? uuid }
        private let uuid = UUID().uuidString

        var name: String?
        /// The node's local transform relative to its parent
        var localTransform: simd_float4x4
        var mesh: Mesh?
        /// The node's first bound material. Used for mesh parts that name no symbol, name a symbol
        /// the document never binds, or come from geometry with no `<bind_material>` at all.
        var material: Material?
        /// Every `<instance_material>` binding on this node, keyed by the `symbol` its primitives
        /// reference. A single `<geometry>` split into several `<polylist>`s — the ordinary way an
        /// exporter represents one part with painted trim — binds a different material per symbol.
        var materialsBySymbol: [String: Material]
        var children: [Node]

        init(
            name: String?,
            localTransform: simd_float4x4,
            mesh: Mesh? = nil,
            material: Material? = nil,
            materialsBySymbol: [String: Material] = [:],
            children: [Node] = []
        ) {
            self.name = name
            self.localTransform = localTransform
            self.mesh = mesh
            self.material = material
            self.materialsBySymbol = materialsBySymbol
            self.children = children
        }

        /// The COLLADA material a given mesh part should render with, falling back to the node's
        /// first binding when the part names no symbol or names an unbound one.
        func material(for part: Mesh.Part) -> Material? {
            part.materialSymbol.flatMap { materialsBySymbol[$0] } ?? material
        }
    }

    /// Extracted mesh geometry with de-interleaved vertex attributes and triangle indices.
    ///
    /// Contains the vertex data extracted from COLLADA `<source>` elements and indexed by
    /// `<triangles>` or `<polylist>` primitives. Ready for conversion to a RealityKit `MeshResource`.
    struct Mesh: Sendable {
        /// One `<triangles>` or `<polylist>` primitive, kept separate from its siblings so the
        /// material bound to its symbol can be applied to just its faces.
        ///
        /// Vertices are NOT shared between parts: COLLADA indexes each primitive's attributes
        /// independently, and de-interleaving them produces a fresh run of vertices per primitive
        /// anyway. Each part therefore owns its slice outright and its `indices` are local to it.
        struct Part: Sendable {
            /// The `material` attribute of the source primitive, matched against the node's
            /// `<instance_material symbol="…">` bindings. `nil` when the primitive names none.
            var materialSymbol: String?
            /// Vertex positions in 3D space, extracted from the `POSITION` semantic source.
            var positions: [SIMD3<Float>]
            /// Per-vertex normals, extracted from the `NORMAL` semantic source. `nil` if not present.
            var normals: [SIMD3<Float>]? = nil
            /// Per-vertex texture coordinates, from the `TEXCOORD` semantic source. `nil` if absent.
            var uvs: [SIMD2<Float>]? = nil
            /// Triangle vertex indices into this part's own positions/normals/uvs arrays.
            var indices: [UInt32]
        }

        /// The mesh's primitives, in document order.
        var parts: [Part]

        /// Every part's vertices concatenated, in part order. Retained because callers predating
        /// per-part materials read the mesh as one flat buffer; the render path uses `parts`.
        var positions: [SIMD3<Float>] { parts.flatMap(\.positions) }
        /// As `positions`, or `nil` when no part carries normals.
        var normals: [SIMD3<Float>]? {
            let merged = parts.flatMap { $0.normals ?? [] }
            return merged.isEmpty ? nil : merged
        }
        /// As `positions`, or `nil` when no part carries texture coordinates.
        var uvs: [SIMD2<Float>]? {
            let merged = parts.flatMap { $0.uvs ?? [] }
            return merged.isEmpty ? nil : merged
        }
        /// Indices rebased onto the concatenated `positions` buffer.
        var indices: [UInt32] {
            var result: [UInt32] = []
            var base: UInt32 = 0
            for part in parts {
                result.append(contentsOf: part.indices.map { $0 + base })
                base += UInt32(part.positions.count)
            }
            return result
        }
    }

    /// Resolved material properties extracted from COLLADA effects and the texture pipeline.
    ///
    /// Maps COLLADA shading model properties (from `<phong>`, `<lambert>`, or `<blinn>`)
    /// to a flat structure suitable for conversion to RealityKit's `PhysicallyBasedMaterial`.
    struct Material: Sendable {
        /// Diffuse color from the effect's shading model (`<diffuse>` → `<color>`).
        var diffuseColor: Collada.ColorRGBA?
        /// Resolved URL for the diffuse texture, if the effect uses `<diffuse>` → `<texture>`.
        /// May be a local `file://` URL or a remote `http(s)://` URL when the source DAE was fetched remotely.
        var diffuseTextureURL: URL?
        /// Decoded image bytes for textures embedded as base64 data URIs in `<init_from>`.
        /// Set when the DAE was produced by `writeDAEAsset`; nil for path-based textures.
        var diffuseTextureData: Data?
        /// Self-illumination color from the effect's `<emission>` property.
        var emissionColor: Collada.ColorRGBA?
        /// Ambient color from the effect's `<ambient>` property.
        var ambientColor: Collada.ColorRGBA?
        /// Specular highlight color from the effect's `<specular>` property.
        var specularColor: Collada.ColorRGBA?
        /// Shininess exponent from the effect (typically 0–128). Converted to roughness as `1 - (shininess / 128)`.
        var shininess: Float?
        /// The `<transparent>` color from the effect. In A_ONE mode (COLLADA default) the alpha
        /// channel indicates opaqueness: alpha=1 is fully opaque, alpha=0 is transparent.
        var transparentColor: Collada.ColorRGBA?
        /// Scalar multiplier from `<transparency>`. Final opacity = `transparent.alpha × transparency`.
        var transparency: Float?
    }
}

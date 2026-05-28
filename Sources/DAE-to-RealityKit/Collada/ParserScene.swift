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
        var material: Material?
        var children: [Node]

        init(
            name: String?,
            localTransform: simd_float4x4,
            mesh: Mesh? = nil,
            material: Material? = nil,
            children: [Node] = []
        ) {
            self.name = name
            self.localTransform = localTransform
            self.mesh = mesh
            self.material = material
            self.children = children
        }
    }

    /// Extracted mesh geometry with de-interleaved vertex attributes and triangle indices.
    ///
    /// Contains the vertex data extracted from COLLADA `<source>` elements and indexed by
    /// `<triangles>` or `<polylist>` primitives. Ready for conversion to a RealityKit `MeshResource`.
    struct Mesh: Sendable {
        /// Vertex positions in 3D space, extracted from the `POSITION` semantic source.
        var positions: [SIMD3<Float>]
        /// Per-vertex normals, extracted from the `NORMAL` semantic source. `nil` if not present.
        var normals: [SIMD3<Float>]? = nil
        /// Per-vertex texture coordinates, extracted from the `TEXCOORD` semantic source. `nil` if not present.
        var uvs: [SIMD2<Float>]? = nil
        /// Triangle vertex indices into the positions/normals/uvs arrays.
        var indices: [UInt32]
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

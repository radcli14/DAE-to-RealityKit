//
//  RawScene.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import RealityKit
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
        /// Resolved file path for the diffuse texture, if the effect uses `<diffuse>` → `<texture>`.
        var diffuseTexturePath: String?
        /// Self-illumination color from the effect's `<emission>` property.
        var emissionColor: Collada.ColorRGBA?
        /// Ambient color from the effect's `<ambient>` property.
        var ambientColor: Collada.ColorRGBA?
        /// Specular highlight color from the effect's `<specular>` property.
        var specularColor: Collada.ColorRGBA?
        /// Shininess exponent from the effect (typically 0–128). Converted to roughness as `1 - (shininess / 128)`.
        var shininess: Float?
        /// Transparency value (0 = opaque, 1 = fully transparent) from the effect's `<transparency>` property.
        var transparency: Float?
    }
}

// MARK: - Entity Building

extension Collada.Parser.Node {
    /// Converts this parsed node and its children into a RealityKit `ModelEntity` hierarchy.
    ///
    /// Creates a `ModelEntity` with the node's local transform, generates a `MeshResource`
    /// from the mesh data (if present), applies a `PhysicallyBasedMaterial` from the
    /// material properties, and recursively builds child entities.
    @MainActor
    func buildEntity() -> ModelEntity {
        let entity = ModelEntity()
        entity.name = name ?? "node"
        entity.transform.matrix = localTransform

        if let mesh {
            do {
                let meshResource = try mesh.buildMeshResource(name: name)
                entity.model = ModelComponent(mesh: meshResource, materials: [buildMaterial()])
            } catch {
                print("Failed to generate mesh for node '\(name ?? "?")': \(error)")
            }
        }

        for child in children {
            entity.addChild(child.buildEntity())
        }
        return entity
    }

    /// Builds a RealityKit `PhysicallyBasedMaterial` from the parsed COLLADA material properties.
    ///
    /// Maps COLLADA shading properties to PBR parameters:
    /// - Diffuse color → `baseColor.tint`
    /// - Emission color → `emissiveColor` + `emissiveIntensity`
    /// - Shininess → `roughness` (inverted: `1 - shininess/128`)
    /// - Specular color → `specular` (using luminance)
    /// - Transparency → `blending` with alpha opacity
    private func buildMaterial() -> PhysicallyBasedMaterial {
        var pbr = PhysicallyBasedMaterial()

        if let mat = material {
            // Base color (diffuse)
            if let dc = mat.diffuseColor {
                pbr.baseColor.tint = .init(
                    red: CGFloat(dc.r),
                    green: CGFloat(dc.g),
                    blue: CGFloat(dc.b),
                    alpha: CGFloat(dc.a)
                )
            }

            // Emissive color
            if let ec = mat.emissionColor, (ec.r > 0 || ec.g > 0 || ec.b > 0) {
                pbr.emissiveColor = .init(
                    color: .init(
                        red: CGFloat(ec.r),
                        green: CGFloat(ec.g),
                        blue: CGFloat(ec.b),
                        alpha: 1.0
                    )
                )
                pbr.emissiveIntensity = 1.0
            }

            // Roughness derived from shininess
            // COLLADA shininess typically ranges 0–128; higher = shinier = lower roughness
            if let shininess = mat.shininess {
                let clamped = min(max(shininess, 0), 128)
                pbr.roughness = .init(floatLiteral: 1.0 - (clamped / 128.0))
            }

            // Specular
            if let sc = mat.specularColor {
                // Use the luminance of the specular color as the specular scale
                let luminance = 0.2126 * sc.r + 0.7152 * sc.g + 0.0722 * sc.b
                pbr.specular = .init(floatLiteral: luminance)
            }

            // Transparency (COLLADA: 1.0 = fully transparent, RealityKit: alpha blending)
            if let transparency = mat.transparency, transparency > 0 {
                pbr.blending = .transparent(opacity: .init(floatLiteral: 1.0 - transparency))
            }
        }

        return pbr
    }
}

extension Collada.Parser.Mesh {
    /// Generates a RealityKit `MeshResource` from the parsed vertex data.
    ///
    /// Creates a `MeshDescriptor` with positions, triangle indices, and optionally
    /// normals and texture coordinates, then generates the mesh resource.
    @MainActor
    func buildMeshResource(name: String? = nil) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: name ?? "mesh")
        descriptor.positions = MeshBuffer(positions)
        descriptor.primitives = .triangles(indices)
        if let normals {
            descriptor.normals = MeshBuffer(normals)
        }
        if let uvs {
            descriptor.textureCoordinates = MeshBuffer(uvs)
        }
        return try MeshResource.generate(from: [descriptor])
    }
}

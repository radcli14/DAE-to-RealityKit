//
//  Collada.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import XMLCoder

// MARK: - COLLADA 1.4.1 Schema

/// Root structure representing a COLLADA 1.4.1 document (`<COLLADA>` element).
///
/// Maps directly to the top-level `<COLLADA>` XML element defined in the
/// [COLLADA 1.4.1 schema](https://www.khronos.org/files/collada_spec_1_4.pdf), Section 7.1.
/// Contains the asset metadata, library sections for images, effects, materials, geometries,
/// visual scenes, and the scene binding that selects the default visual scene.
struct Collada: Codable, Equatable {
    /// The COLLADA schema version (e.g. `"1.4.1"`), specified as an XML attribute.
    let version: String?
    /// Metadata about the document, including the coordinate system's up-axis.
    let asset: Asset?
    /// Collection of image assets referenced by effects for texture mapping (`<library_images>`).
    let libraryImages: LibraryImages?
    /// Collection of rendering effects defining shading models and parameters (`<library_effects>`).
    let libraryEffects: LibraryEffects?
    /// Collection of materials that bind effect instances to geometry (`<library_materials>`).
    let libraryMaterials: LibraryMaterials?
    /// Collection of geometric primitives (meshes) (`<library_geometries>`).
    let libraryGeometries: LibraryGeometries?
    /// Collection of visual scenes defining node hierarchies and transforms (`<library_visual_scenes>`).
    let libraryVisualScenes: LibraryVisualScenes?
    /// The scene binding that selects which visual scene to instantiate (`<scene>`).
    let scene: Scene?

    enum CodingKeys: String, CodingKey {
        case version
        case asset
        case libraryImages = "library_images"
        case libraryEffects = "library_effects"
        case libraryMaterials = "library_materials"
        case libraryGeometries = "library_geometries"
        case libraryVisualScenes = "library_visual_scenes"
        case scene
    }
}

extension Collada: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "version": return .attribute
        default: return .element
        }
    }
}

extension Collada: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "version": return .attribute
        default: return .element
        }
    }
}

// MARK: - Asset

extension Collada {
    /// Metadata about the COLLADA document (`<asset>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.1.1, the `<asset>` element can contain contributor info,
    /// creation date, and importantly the `<up_axis>` which defines the coordinate system orientation.
    struct Asset: Codable, Equatable {
        /// The up-axis of the coordinate system (e.g. `"Y_UP"`, `"Z_UP"`, `"X_UP"`).
        /// Defaults to `"Y_UP"` per the COLLADA specification when absent.
        let upAxis: String?

        enum CodingKeys: String, CodingKey {
            case upAxis = "up_axis"
        }
    }
}

// MARK: - Scene Binding

extension Collada {
    /// The scene binding element (`<scene>`) that selects which visual scene to render.
    ///
    /// Per COLLADA 1.4.1, Section 7.1.6, the `<scene>` element instantiates a visual scene
    /// from the library by URL reference.
    struct Scene: Codable, Equatable {
        /// Reference to the visual scene to instantiate (`<instance_visual_scene>`).
        let instanceVisualScene: InstanceVisualScene?

        enum CodingKeys: String, CodingKey {
            case instanceVisualScene = "instance_visual_scene"
        }
    }

    /// A reference to a visual scene by URL (`<instance_visual_scene>` element).
    ///
    /// The `url` attribute is a URI fragment (e.g. `"#MyScene"`) pointing to a
    /// `<visual_scene>` in `<library_visual_scenes>`.
    struct InstanceVisualScene: Codable, Equatable {
        /// URI fragment referencing a `<visual_scene>` id (e.g. `"#Scene"`).
        let url: String
    }
}

extension Collada.InstanceVisualScene: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

extension Collada.InstanceVisualScene: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        return .attribute
    }
}

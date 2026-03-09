//
//  Collada.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import XMLCoder

// MARK: - COLLADA 1.4.1 Schema

struct Collada: Codable, Equatable {
    let version: String?
    let asset: Asset?
    let libraryImages: LibraryImages?
    let libraryEffects: LibraryEffects?
    let libraryMaterials: LibraryMaterials?
    let libraryGeometries: LibraryGeometries?
    let libraryVisualScenes: LibraryVisualScenes?
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

// MARK: - Asset

extension Collada {
    struct Asset: Codable, Equatable {
        let upAxis: String?

        enum CodingKeys: String, CodingKey {
            case upAxis = "up_axis"
        }
    }
}

// MARK: - Scene Binding

extension Collada {
    struct Scene: Codable, Equatable {
        let instanceVisualScene: InstanceVisualScene?

        enum CodingKeys: String, CodingKey {
            case instanceVisualScene = "instance_visual_scene"
        }
    }

    struct InstanceVisualScene: Codable, Equatable {
        let url: String
    }
}

extension Collada.InstanceVisualScene: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

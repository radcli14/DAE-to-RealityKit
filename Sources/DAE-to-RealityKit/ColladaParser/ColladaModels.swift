//
//  ColladaModels.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import XMLCoder

// MARK: - COLLADA 1.4.1 Schema

public struct Collada: Codable, Equatable {
    public let version: String?
    public let asset: Asset?
    public let libraryEffects: LibraryEffects?
    public let libraryMaterials: LibraryMaterials?
    public let libraryGeometries: LibraryGeometries?
    public let libraryVisualScenes: LibraryVisualScenes?
    public let scene: Scene?

    enum CodingKeys: String, CodingKey {
        case version
        case asset
        case libraryEffects = "library_effects"
        case libraryMaterials = "library_materials"
        case libraryGeometries = "library_geometries"
        case libraryVisualScenes = "library_visual_scenes"
        case scene
    }
}

extension Collada: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "version": return .attribute
        default: return .element
        }
    }
}

// MARK: - Asset

public struct Asset: Codable, Equatable {
    public let upAxis: String?

    enum CodingKeys: String, CodingKey {
        case upAxis = "up_axis"
    }
}

// MARK: - Scene Binding

extension Collada {
    public struct Scene: Codable, Equatable {
        public let instanceVisualScene: InstanceVisualScene?
        
        enum CodingKeys: String, CodingKey {
            case instanceVisualScene = "instance_visual_scene"
        }
    }
    
    public struct InstanceVisualScene: Codable, Equatable {
        public let url: String
    }
}

extension Collada.InstanceVisualScene: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

// MARK: - Materials

public struct LibraryMaterials: Codable, Equatable {
    public let materials: [Material]?

    enum CodingKeys: String, CodingKey {
        case materials = "material"
    }
}

public struct Material: Codable, Equatable {
    public let materialId: String?
    public let name: String?
    public let instanceEffect: InstanceEffect?

    enum CodingKeys: String, CodingKey {
        case materialId = "id"
        case name
        case instanceEffect = "instance_effect"
    }
}

extension Material: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

public struct InstanceEffect: Codable, Equatable {
    public let url: String
}

extension InstanceEffect: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

// MARK: - Visual Scenes

public struct LibraryVisualScenes: Codable, Equatable {
    public let visualScenes: [VisualScene]

    enum CodingKeys: String, CodingKey {
        case visualScenes = "visual_scene"
    }
}

public struct VisualScene: Codable, Equatable, Identifiable {
    public var id: String? { visualSceneId }

    public let visualSceneId: String?
    public let name: String?
    public let nodes: [ColladaNode]

    enum CodingKeys: String, CodingKey {
        case visualSceneId = "id"
        case name
        case nodes = "node"
    }
}

extension VisualScene: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

/// Renamed from `Node` to avoid collisions with Foundation
public struct ColladaNode: Codable, Equatable, Identifiable {
    public var id: String? { nodeId }

    public let nodeId: String?
    public let sid: String?
    public let name: String?
    public let type: String?
    public let matrix: ColladaMatrix4x4?
    public let translate: [ColladaVector3]?
    public let rotate: [ColladaRotation]?
    public let scale: [ColladaVector3]?
    public let instanceGeometry: [InstanceGeometry]?
    public let children: [ColladaNode]?

    enum CodingKeys: String, CodingKey {
        case nodeId = "id"
        case sid, name, type
        case matrix
        case translate, rotate, scale
        case instanceGeometry = "instance_geometry"
        case children = "node"
    }
}

extension ColladaNode: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "sid", "name", "type": return .attribute
        default: return .element
        }
    }
}

/// Decodes a whitespace-separated 16-value matrix string
public struct ColladaMatrix4x4: Codable, Equatable {
    public let values: [Double]
    public let sid: String?

    enum CodingKeys: String, CodingKey {
        case values = ""
        case sid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sid = try container.decodeIfPresent(String.self, forKey: .sid)
        let text = try container.decode(String.self, forKey: .values)
        values = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
    }
}

extension ColladaMatrix4x4: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

/// Decodes a whitespace-separated 3-value vector string
public struct ColladaVector3: Codable, Equatable {
    public let sid: String?
    public let values: [Double]

    enum CodingKeys: String, CodingKey {
        case sid
        case values = ""
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sid = try container.decodeIfPresent(String.self, forKey: .sid)
        let text = try container.decode(String.self, forKey: .values)
        values = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
    }
}

extension ColladaVector3: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

/// Decodes a whitespace-separated 4-value rotation (axis x y z + angle in degrees)
public struct ColladaRotation: Codable, Equatable {
    public let sid: String?
    public let values: [Double]

    enum CodingKeys: String, CodingKey {
        case sid
        case values = ""
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sid = try container.decodeIfPresent(String.self, forKey: .sid)
        let text = try container.decode(String.self, forKey: .values)
        values = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
    }
}

extension ColladaRotation: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

public struct InstanceGeometry: Codable, Equatable {
    public let url: String
    public let name: String?
    public let bindMaterial: BindMaterial?

    enum CodingKeys: String, CodingKey {
        case url, name
        case bindMaterial = "bind_material"
    }
}

extension InstanceGeometry: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "url", "name": return .attribute
        default: return .element
        }
    }
}

public struct BindMaterial: Codable, Equatable {
    public let techniqueCommon: BindMaterialTechniqueCommon?

    enum CodingKeys: String, CodingKey {
        case techniqueCommon = "technique_common"
    }
}

public struct BindMaterialTechniqueCommon: Codable, Equatable {
    public let instanceMaterials: [InstanceMaterial]?

    enum CodingKeys: String, CodingKey {
        case instanceMaterials = "instance_material"
    }
}

public struct InstanceMaterial: Codable, Equatable {
    public let symbol: String
    public let target: String
}

extension InstanceMaterial: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

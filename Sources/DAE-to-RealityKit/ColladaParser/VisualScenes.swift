//
//  VisualScenes.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import XMLCoder

// MARK: - Visual Scenes

extension Collada {
    struct LibraryVisualScenes: Codable, Equatable {
        let visualScenes: [VisualScene]

        enum CodingKeys: String, CodingKey {
            case visualScenes = "visual_scene"
        }
    }

    struct VisualScene: Codable, Equatable, Identifiable {
        var id: String? { visualSceneId }

        let visualSceneId: String?
        let name: String?
        let nodes: [Node]

        enum CodingKeys: String, CodingKey {
            case visualSceneId = "id"
            case name
            case nodes = "node"
        }
    }
}

extension Collada {
    struct Node: Codable, Equatable, Identifiable {
        var id: String? { nodeId }

        let nodeId: String?
        let sid: String?
        let name: String?
        let type: String?
        let matrix: Matrix4x4?
        let translate: [Vector3]?
        let rotate: [Rotation]?
        let scale: [Vector3]?
        let instanceGeometry: [InstanceGeometry]?
        let children: [Node]?

        enum CodingKeys: String, CodingKey {
            case nodeId = "id"
            case sid, name, type
            case matrix
            case translate, rotate, scale
            case instanceGeometry = "instance_geometry"
            case children = "node"
        }
    }

    struct InstanceGeometry: Codable, Equatable {
        let url: String
        let name: String?
        let bindMaterial: BindMaterial?

        enum CodingKeys: String, CodingKey {
            case url, name
            case bindMaterial = "bind_material"
        }
    }

    struct BindMaterial: Codable, Equatable {
        let techniqueCommon: TechniqueCommon?

        enum CodingKeys: String, CodingKey {
            case techniqueCommon = "technique_common"
        }

        struct TechniqueCommon: Codable, Equatable {
            let instanceMaterials: [InstanceMaterial]?

            enum CodingKeys: String, CodingKey {
                case instanceMaterials = "instance_material"
            }
        }
    }

    struct InstanceMaterial: Codable, Equatable {
        let symbol: String
        let target: String
    }
}

// MARK: - Transform Types

extension Collada {
    /// Decodes a whitespace-separated 16-value matrix string
    struct Matrix4x4: Codable, Equatable {
        let values: [Double]
        let sid: String?

        enum CodingKeys: String, CodingKey {
            case values = ""
            case sid
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sid = try container.decodeIfPresent(String.self, forKey: .sid)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        }
    }

    /// Decodes a whitespace-separated 3-value vector string
    struct Vector3: Codable, Equatable {
        let sid: String?
        let values: [Double]

        enum CodingKeys: String, CodingKey {
            case sid
            case values = ""
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sid = try container.decodeIfPresent(String.self, forKey: .sid)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        }
    }

    /// Decodes a whitespace-separated 4-value rotation (axis x y z + angle in degrees)
    struct Rotation: Codable, Equatable {
        let sid: String?
        let values: [Double]

        enum CodingKeys: String, CodingKey {
            case sid
            case values = ""
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sid = try container.decodeIfPresent(String.self, forKey: .sid)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        }
    }
}

// MARK: - DynamicNodeDecoding

extension Collada.VisualScene: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

extension Collada.Node: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "sid", "name", "type": return .attribute
        default: return .element
        }
    }
}

extension Collada.InstanceGeometry: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "url", "name": return .attribute
        default: return .element
        }
    }
}

extension Collada.InstanceMaterial: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

extension Collada.Matrix4x4: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

extension Collada.Vector3: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

extension Collada.Rotation: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

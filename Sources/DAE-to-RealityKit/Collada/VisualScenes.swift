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
    /// Container for visual scene definitions (`<library_visual_scenes>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.9, `<library_visual_scenes>` holds `<visual_scene>`
    /// elements that define the node hierarchies, transforms, and geometry/material bindings.
    struct LibraryVisualScenes: Codable, Equatable {
        /// The visual scene elements contained in this library.
        let visualScenes: [VisualScene]

        enum CodingKeys: String, CodingKey {
            case visualScenes = "visual_scene"
        }
    }

    /// A visual scene (`<visual_scene>` element) defining a hierarchical node graph.
    ///
    /// Per COLLADA 1.4.1, Section 7.9.1, a visual scene is a directed acyclic graph of
    /// nodes, each carrying transforms, geometry instances, and material bindings.
    /// The active scene is selected by `<scene>` → `<instance_visual_scene>`.
    struct VisualScene: Codable, Equatable, Identifiable {
        var id: String? { visualSceneId }

        /// Unique identifier for this visual scene, referenced by `<instance_visual_scene>`.
        let visualSceneId: String?
        /// Human-readable name for the visual scene.
        let name: String?
        /// Top-level nodes in this scene's hierarchy.
        let nodes: [Node]

        enum CodingKeys: String, CodingKey {
            case visualSceneId = "id"
            case name
            case nodes = "node"
        }
    }
}

extension Collada {
    /// A node in the scene graph (`<node>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.9.2, a `<node>` defines a transform (via `<matrix>`,
    /// or TRS elements `<translate>`, `<rotate>`, `<scale>`), geometry instances, and
    /// child nodes forming a hierarchical scene graph.
    struct Node: Codable, Equatable, Identifiable {
        var id: String? { nodeId }

        /// Unique identifier for this node.
        let nodeId: String?
        /// Scoped identifier for targeting this node (e.g. in animations).
        let sid: String?
        /// Human-readable name for the node.
        let name: String?
        /// Node type: `"NODE"` (transform) or `"JOINT"` (skeleton joint).
        let type: String?
        /// A 4×4 transformation matrix (`<matrix>` element), row-major order.
        let matrix: Matrix4x4?
        /// Translation components (`<translate>` elements).
        let translate: [Vector3]?
        /// Rotation components (`<rotate>` elements), each as axis + angle in degrees.
        let rotate: [Rotation]?
        /// Scale components (`<scale>` elements).
        let scale: [Vector3]?
        /// Geometry instances bound to this node (`<instance_geometry>` elements).
        let instanceGeometry: [InstanceGeometry]?
        /// Child nodes forming the sub-hierarchy.
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

    /// A geometry instance (`<instance_geometry>` element) binding a geometry to a node.
    ///
    /// Per COLLADA 1.4.1, Section 7.9.3, `<instance_geometry>` references a geometry by URL
    /// and optionally binds materials via `<bind_material>`.
    struct InstanceGeometry: Codable, Equatable {
        /// URI fragment referencing a `<geometry>` id (e.g. `"#mesh0"`).
        let url: String
        /// Human-readable name for this geometry instance.
        let name: String?
        /// Material binding for this geometry instance.
        let bindMaterial: BindMaterial?

        enum CodingKeys: String, CodingKey {
            case url, name
            case bindMaterial = "bind_material"
        }
    }

    /// Material binding container (`<bind_material>` element).
    ///
    /// Connects material symbols used in geometry primitives to concrete material definitions.
    struct BindMaterial: Codable, Equatable {
        /// The common technique containing material instance bindings.
        let techniqueCommon: TechniqueCommon?

        enum CodingKeys: String, CodingKey {
            case techniqueCommon = "technique_common"
        }

        /// Common technique wrapper for material instance bindings.
        struct TechniqueCommon: Codable, Equatable {
            /// Material instance bindings mapping symbols to material targets.
            let instanceMaterials: [InstanceMaterial]?

            enum CodingKeys: String, CodingKey {
                case instanceMaterials = "instance_material"
            }
        }
    }

    /// A material instance binding (`<instance_material>` element).
    ///
    /// Maps a material `symbol` (used in `<triangles material="...">`) to a concrete
    /// `<material>` in `<library_materials>` via the `target` URI fragment.
    struct InstanceMaterial: Codable, Equatable {
        /// The material symbol as referenced by primitive elements.
        let symbol: String
        /// URI fragment referencing a `<material>` id (e.g. `"#material0"`).
        let target: String
    }
}

// MARK: - Transform Types

extension Collada {
    /// A 4×4 transformation matrix (`<matrix>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.9.4, the `<matrix>` element contains 16 float values
    /// in row-major order. During parsing, these are transposed to column-major for
    /// compatibility with `simd_float4x4`.
    struct Matrix4x4: Codable, Equatable {
        /// The 16 matrix values in row-major order as read from the XML.
        let values: [Double]
        /// Optional scoped identifier for animation targeting.
        let sid: String?

        enum CodingKeys: String, CodingKey {
            case values = ""
            case sid
        }

        init(values: [Double], sid: String? = nil) {
            self.values = values
            self.sid = sid
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sid = try container.decodeIfPresent(String.self, forKey: .sid)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(sid, forKey: .sid)
            try container.encode(values.map { String($0) }.joined(separator: " "), forKey: .values)
        }
    }

    /// A 3-component vector (`<translate>` or `<scale>` element).
    ///
    /// Decodes a whitespace-separated string of 3 float values (e.g. `"1.0 2.0 3.0"`).
    /// Used for both `<translate>` (position offset) and `<scale>` (axis scaling).
    struct Vector3: Codable, Equatable {
        /// Optional scoped identifier for animation targeting.
        let sid: String?
        /// The X, Y, Z components.
        let values: [Double]

        enum CodingKeys: String, CodingKey {
            case sid
            case values = ""
        }

        init(sid: String? = nil, values: [Double]) {
            self.sid = sid
            self.values = values
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sid = try container.decodeIfPresent(String.self, forKey: .sid)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(sid, forKey: .sid)
            try container.encode(values.map { String($0) }.joined(separator: " "), forKey: .values)
        }
    }

    /// An axis-angle rotation (`<rotate>` element).
    ///
    /// Decodes a whitespace-separated string of 4 float values: the rotation axis (X, Y, Z)
    /// followed by the angle in degrees. Per COLLADA 1.4.1, multiple `<rotate>` elements
    /// on a node are composed in document order.
    struct Rotation: Codable, Equatable {
        /// Optional scoped identifier for animation targeting (e.g. `"rotateX"`).
        let sid: String?
        /// The axis (indices 0–2) and angle in degrees (index 3).
        let values: [Double]

        enum CodingKeys: String, CodingKey {
            case sid
            case values = ""
        }

        init(sid: String? = nil, values: [Double]) {
            self.sid = sid
            self.values = values
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sid = try container.decodeIfPresent(String.self, forKey: .sid)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(sid, forKey: .sid)
            try container.encode(values.map { String($0) }.joined(separator: " "), forKey: .values)
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

// MARK: - DynamicNodeEncoding

extension Collada.VisualScene: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

extension Collada.Node: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "id", "sid", "name", "type": return .attribute
        default: return .element
        }
    }
}

extension Collada.InstanceGeometry: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "url", "name": return .attribute
        default: return .element
        }
    }
}

extension Collada.InstanceMaterial: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        return .attribute
    }
}

extension Collada.Matrix4x4: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

extension Collada.Vector3: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

extension Collada.Rotation: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

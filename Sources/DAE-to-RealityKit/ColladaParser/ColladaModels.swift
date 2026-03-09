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

public struct Scene: Codable, Equatable {
    public let instanceVisualScene: InstanceVisualScene?

    enum CodingKeys: String, CodingKey {
        case instanceVisualScene = "instance_visual_scene"
    }
}

public struct InstanceVisualScene: Codable, Equatable {
    public let url: String
}

extension InstanceVisualScene: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

// MARK: - Effects

public struct LibraryEffects: Codable, Equatable {
    public let effects: [Effect]?

    enum CodingKeys: String, CodingKey {
        case effects = "effect"
    }
}

public struct Effect: Codable, Equatable {
    public let effectId: String?
    public let profileCommon: ProfileCommon?

    enum CodingKeys: String, CodingKey {
        case effectId = "id"
        case profileCommon = "profile_COMMON"
    }
}

extension Effect: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

public struct ProfileCommon: Codable, Equatable {
    public let technique: EffectTechnique?

    enum CodingKeys: String, CodingKey {
        case technique
    }
}

public struct EffectTechnique: Codable, Equatable {
    public let sid: String?
    public let phong: PhongShading?
    public let lambert: LambertShading?
    public let blinn: BlinnShading?

    enum CodingKeys: String, CodingKey {
        case sid, phong, lambert, blinn
    }

    /// Returns the diffuse color from whichever shading model is present
    public var diffuseColor: ColorRGBA? {
        phong?.diffuse?.color ?? lambert?.diffuse?.color ?? blinn?.diffuse?.color
    }
}

extension EffectTechnique: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

public struct PhongShading: Codable, Equatable {
    public let diffuse: ColorProperty?
}

public struct LambertShading: Codable, Equatable {
    public let diffuse: ColorProperty?
}

public struct BlinnShading: Codable, Equatable {
    public let diffuse: ColorProperty?
}

public struct ColorProperty: Codable, Equatable {
    public let color: ColorRGBA?
}

/// Decodes a whitespace-separated "R G B A" string into individual components
public struct ColorRGBA: Codable, Equatable, Sendable {
    public let r: Float
    public let g: Float
    public let b: Float
    public let a: Float

    enum CodingKeys: String, CodingKey {
        case value = ""
    }

    public init(r: Float, g: Float, b: Float, a: Float) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .value)
        let parts = text.split(whereSeparator: \.isWhitespace).compactMap { Float($0) }
        guard parts.count >= 4 else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Expected 4 color components, got \(parts.count)")
            )
        }
        r = parts[0]; g = parts[1]; b = parts[2]; a = parts[3]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("\(r) \(g) \(b) \(a)", forKey: .value)
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

// MARK: - Geometries

public struct LibraryGeometries: Codable, Equatable {
    public let geometries: [Geometry]

    enum CodingKeys: String, CodingKey {
        case geometries = "geometry"
    }
}

public struct Geometry: Codable, Equatable, Identifiable {
    public var id: String? { geometryId }

    public let geometryId: String?
    public let name: String?
    public let mesh: ColladaMesh?

    enum CodingKeys: String, CodingKey {
        case geometryId = "id"
        case name
        case mesh
    }
}

extension Geometry: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

/// Renamed from `Mesh` to avoid collisions with RealityKit's `MeshResource.Mesh`
public struct ColladaMesh: Codable, Equatable {
    public let sources: [Source]
    public let vertices: Vertices?
    public let triangles: [Triangles]?
    public let polylist: [Polylist]?

    enum CodingKeys: String, CodingKey {
        case sources = "source"
        case vertices
        case triangles
        case polylist
    }
}

public struct Source: Codable, Equatable, Identifiable {
    public var id: String? { sourceId }

    public let sourceId: String?
    public let floatArray: Collada.FloatArray?
    public let techniqueCommon: SourceTechniqueCommon?

    enum CodingKeys: String, CodingKey {
        case sourceId = "id"
        case floatArray = "float_array"
        case techniqueCommon = "technique_common"
    }
}

extension Source: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

public struct SourceTechniqueCommon: Codable, Equatable {
    public let accessor: Accessor
}

public struct Accessor: Codable, Equatable {
    public let source: String
    public let count: Int
    public let stride: Int?
    public let params: [Param]?

    enum CodingKeys: String, CodingKey {
        case source, count, stride
        case params = "param"
    }
}

extension Accessor: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "source", "count", "stride": return .attribute
        default: return .element
        }
    }
}

public struct Param: Codable, Equatable {
    public let name: String?
    public let type: String?
}

extension Param: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

public struct Vertices: Codable, Equatable {
    public let id: String?
    public let inputs: [Input]

    enum CodingKeys: String, CodingKey {
        case id
        case inputs = "input"
    }
}

extension Vertices: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

public struct Input: Codable, Equatable {
    public let semantic: String
    public let source: String
    public let offset: Int?
    public let set: Int?
}

extension Input: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        // All Input fields are XML attributes
        return .attribute
    }
}

public struct Triangles: Codable, Equatable {
    public let count: Int
    public let material: String?
    public let inputs: [Input]
    public let p: Collada.IndexArray

    enum CodingKeys: String, CodingKey {
        case count, material
        case inputs = "input"
        case p
    }
}

extension Triangles: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "count", "material": return .attribute
        default: return .element
        }
    }
}

public struct Polylist: Codable, Equatable {
    public let count: Int
    public let material: String?
    public let inputs: [Input]
    public let vcount: Collada.IndexArray?
    public let p: Collada.IndexArray

    enum CodingKeys: String, CodingKey {
        case count, material
        case inputs = "input"
        case vcount, p
    }
}

extension Polylist: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "count", "material": return .attribute
        default: return .element
        }
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

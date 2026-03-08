//
//  ColladaModels.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/8/26.
//

import Foundation
import XMLCoder

// MARK: - COLLADA 1.4.1 minimal schema for geometry and visual scenes

public struct Collada: Codable, Equatable {
    public let version: String?
    public let asset: Asset?
    public let libraryGeometries: LibraryGeometries?
    public let libraryVisualScenes: LibraryVisualScenes?
    public let scene: Scene?

    enum CodingKeys: String, CodingKey {
        case version = "version"
        case asset = "asset"
        case libraryGeometries = "library_geometries"
        case libraryVisualScenes = "library_visual_scenes"
        case scene = "scene"
    }
}

extension Collada: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        // Default element decoding
        return .element
    }
}

// MARK: Asset
public struct Asset: Codable, Equatable {
    public let upAxis: String?

    enum CodingKeys: String, CodingKey {
        case upAxis = "up_axis"
    }
}

// MARK: Scene binding
public struct Scene: Codable, Equatable {
    public let instanceVisualScene: InstanceVisualScene?

    enum CodingKeys: String, CodingKey {
        case instanceVisualScene = "instance_visual_scene"
    }
}

public struct InstanceVisualScene: Codable, Equatable {
    public let url: String

    enum CodingKeys: String, CodingKey {
        case url = "url"
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
    public let mesh: Mesh?

    enum CodingKeys: String, CodingKey {
        case geometryId = "id"
        case name = "name"
        case mesh = "mesh"
    }
}

public struct Mesh: Codable, Equatable {
    public let sources: [Source]
    public let vertices: Vertices?
    public let triangles: [Triangles]?
    public let polylist: [Polylist]?

    enum CodingKeys: String, CodingKey {
        case sources = "source"
        case vertices = "vertices"
        case triangles = "triangles"
        case polylist = "polylist"
    }
}

public struct Source: Codable, Equatable, Identifiable {
    public var id: String? { sourceId }

    public let sourceId: String?
    public let floatArray: FloatArray?
    public let techniqueCommon: TechniqueCommon?

    enum CodingKeys: String, CodingKey {
        case sourceId = "id"
        case floatArray = "float_array"
        case techniqueCommon = "technique_common"
    }

    public struct TechniqueCommon: Codable, Equatable {
        public let accessor: Accessor

        enum CodingKeys: String, CodingKey {
            case accessor = "accessor"
        }
    }
}

public struct FloatArray: Codable, Equatable {
    public let id: String?
    public let count: Int
    public let values: [Float]

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case count = "count"
        case values = "_"
    }
}

public struct Accessor: Codable, Equatable {
    public let source: String
    public let count: Int
    public let stride: Int?
    public let params: [Param]?

    enum CodingKeys: String, CodingKey {
        case source = "source"
        case count = "count"
        case stride = "stride"
        case params = "param"
    }
}

public struct Param: Codable, Equatable {
    public let name: String?
    public let type: String?
}

public struct Vertices: Codable, Equatable {
    public let id: String?
    public let inputs: [Input]

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case inputs = "input"
    }
}

public struct Input: Codable, Equatable {
    public let semantic: String
    public let source: String
    public let offset: Int?
    public let set: Int?

    enum CodingKeys: String, CodingKey {
        case semantic = "semantic"
        case source = "source"
        case offset = "offset"
        case set = "set"
    }
}

public struct Triangles: Codable, Equatable {
    public let count: Int
    public let material: String?
    public let inputs: [Input]
    public let p: IndexArray

    enum CodingKeys: String, CodingKey {
        case count = "count"
        case material = "material"
        case inputs = "input"
        case p = "p"
    }
}

public struct Polylist: Codable, Equatable {
    public let count: Int
    public let material: String?
    public let inputs: [Input]
    public let vcount: IndexArray?
    public let p: IndexArray

    enum CodingKeys: String, CodingKey {
        case count = "count"
        case material = "material"
        case inputs = "input"
        case vcount = "vcount"
        case p = "p"
    }
}

public struct IndexArray: Codable, Equatable {
    public let values: [Int]

    enum CodingKeys: String, CodingKey {
        case values = "_"
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
    public let nodes: [Node]

    enum CodingKeys: String, CodingKey {
        case visualSceneId = "id"
        case name = "name"
        case nodes = "node"
    }
}

public struct Node: Codable, Equatable, Identifiable {
    public var id: String? { nodeId }

    public let nodeId: String?
    public let sid: String?
    public let name: String?
    public let type: String?
    public let matrix: Matrix4x4?
    public let translate: [Vector3]?
    public let rotate: [Rotation]?
    public let scale: [Vector3]?
    public let instanceGeometry: [InstanceGeometry]?
    public let children: [Node]?

    enum CodingKeys: String, CodingKey {
        case nodeId = "id"
        case sid = "sid"
        case name = "name"
        case type = "type"
        case matrix = "matrix"
        case translate = "translate"
        case rotate = "rotate"
        case scale = "scale"
        case instanceGeometry = "instance_geometry"
        case children = "node"
    }
}

public struct Matrix4x4: Codable, Equatable {
    public let values: [Double]
    public let sid: String?

    enum CodingKeys: String, CodingKey {
        case values = "_"
        case sid = "sid"
    }
}

public struct Vector3: Codable, Equatable {
    public let values: [Double]

    enum CodingKeys: String, CodingKey {
        case values = "_"
    }
}

public struct Rotation: Codable, Equatable {
    public let values: [Double]

    enum CodingKeys: String, CodingKey {
        case values = "_"
    }
}

public struct InstanceGeometry: Codable, Equatable {
    public let url: String
    public let bindMaterial: BindMaterial?

    enum CodingKeys: String, CodingKey {
        case url = "url"
        case bindMaterial = "bind_material"
    }

    public struct BindMaterial: Codable, Equatable {
        public let techniqueCommon: TechniqueCommon?

        enum CodingKeys: String, CodingKey {
            case techniqueCommon = "technique_common"
        }

        public struct TechniqueCommon: Codable, Equatable {
            public let instanceMaterials: [InstanceMaterial]?

            enum CodingKeys: String, CodingKey {
                case instanceMaterials = "instance_material"
            }
        }
    }
}

public struct InstanceMaterial: Codable, Equatable {
    public let symbol: String
    public let target: String

    enum CodingKeys: String, CodingKey {
        case symbol = "symbol"
        case target = "target"
    }
}

// Helper to decode whitespace-separated lists into arrays
extension KeyedDecodingContainer {
    public func decode(_ type: [Float].Type, forKey key: K) throws -> [Float] {
        let string = try self.decode(String.self, forKey: key)
        return string.split{ $0 == " " || $0 == "\n" || $0 == "\t" }.compactMap { Float($0) }
    }

    public func decode(_ type: [Double].Type, forKey key: K) throws -> [Double] {
        let string = try self.decode(String.self, forKey: key)
        return string.split{ $0 == " " || $0 == "\n" || $0 == "\t" }.compactMap { Double($0) }
    }

    public func decode(_ type: [Int].Type, forKey key: K) throws -> [Int] {
        let string = try self.decode(String.self, forKey: key)
        return string.split{ $0 == " " || $0 == "\n" || $0 == "\t" }.compactMap { Int($0) }
    }
}

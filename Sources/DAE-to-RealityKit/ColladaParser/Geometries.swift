//
//  File.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import XMLCoder

// MARK: - Geometries

extension Collada {
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
            case name
            case mesh
        }
    }
}

extension Collada.Geometry {
    public struct Mesh: Codable, Equatable {
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

    public struct Param: Codable, Equatable {
        public let name: String?
        public let type: String?
    }

    public struct Vertices: Codable, Equatable {
        public let id: String?
        public let inputs: [Input]

        enum CodingKeys: String, CodingKey {
            case id
            case inputs = "input"
        }
    }

    public struct Input: Codable, Equatable {
        public let semantic: String
        public let source: String
        public let offset: Int?
        public let set: Int?
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
}

// MARK: - DynamicNodeDecoding

extension Collada.Geometry: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Source: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Accessor: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "source", "count", "stride": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Param: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

extension Collada.Geometry.Vertices: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Input: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        // All Input fields are XML attributes
        return .attribute
    }
}

extension Collada.Geometry.Triangles: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "count", "material": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Polylist: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "count", "material": return .attribute
        default: return .element
        }
    }
}

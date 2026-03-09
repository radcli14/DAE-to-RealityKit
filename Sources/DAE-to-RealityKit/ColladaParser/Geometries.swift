//
//  Geometries.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import XMLCoder

// MARK: - Geometries

extension Collada {
    struct LibraryGeometries: Codable, Equatable {
        let geometries: [Geometry]

        enum CodingKeys: String, CodingKey {
            case geometries = "geometry"
        }
    }

    struct Geometry: Codable, Equatable, Identifiable {
        var id: String? { geometryId }

        let geometryId: String?
        let name: String?
        let mesh: Mesh?

        enum CodingKeys: String, CodingKey {
            case geometryId = "id"
            case name
            case mesh
        }
    }
    
    /// Builds the geometry map for this `Collada` object, which is a dictionary of `String` to `Collada.Geometry`
    var geometryMap: [String: Geometry] {
        guard let libraryGeometries else { return [:] }
        var map: [String: Geometry] = [:]
        for geo in libraryGeometries.geometries {
            if let geoId = geo.geometryId {
                map[geoId] = geo
            }
        }
        return map
    }
}

extension Collada.Geometry {
    struct Mesh: Codable, Equatable {
        let sources: [Source]
        let vertices: Vertices?
        let triangles: [Triangles]?
        let polylist: [Polylist]?

        enum CodingKeys: String, CodingKey {
            case sources = "source"
            case vertices
            case triangles
            case polylist
        }
    }

    struct Source: Codable, Equatable, Identifiable {
        var id: String? { sourceId }

        let sourceId: String?
        let floatArray: Collada.FloatArray?
        let techniqueCommon: TechniqueCommon?

        enum CodingKeys: String, CodingKey {
            case sourceId = "id"
            case floatArray = "float_array"
            case techniqueCommon = "technique_common"
        }
    }

    struct TechniqueCommon: Codable, Equatable {
        let accessor: Accessor
    }

    struct Accessor: Codable, Equatable {
        let source: String
        let count: Int
        let stride: Int?
        let params: [Param]?

        enum CodingKeys: String, CodingKey {
            case source, count, stride
            case params = "param"
        }
    }

    struct Param: Codable, Equatable {
        let name: String?
        let type: String?
    }

    struct Vertices: Codable, Equatable {
        let id: String?
        let inputs: [Input]

        enum CodingKeys: String, CodingKey {
            case id
            case inputs = "input"
        }
    }

    struct Input: Codable, Equatable {
        let semantic: String
        let source: String
        let offset: Int?
        let set: Int?
    }

    struct Triangles: Codable, Equatable {
        let count: Int
        let material: String?
        let inputs: [Input]
        let p: Collada.IndexArray

        enum CodingKeys: String, CodingKey {
            case count, material
            case inputs = "input"
            case p
        }
    }

    struct Polylist: Codable, Equatable {
        let count: Int
        let material: String?
        let inputs: [Input]
        let vcount: Collada.IndexArray?
        let p: Collada.IndexArray

        enum CodingKeys: String, CodingKey {
            case count, material
            case inputs = "input"
            case vcount, p
        }
    }
}

// MARK: - DynamicNodeDecoding

extension Collada.Geometry: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Source: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Accessor: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "source", "count", "stride": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Param: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

extension Collada.Geometry.Vertices: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Input: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

extension Collada.Geometry.Triangles: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "count", "material": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Polylist: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "count", "material": return .attribute
        default: return .element
        }
    }
}

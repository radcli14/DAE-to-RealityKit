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
    /// Container for geometric primitives (`<library_geometries>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.6, `<library_geometries>` holds `<geometry>` elements,
    /// each of which contains a `<mesh>` defining vertex data and primitives.
    struct LibraryGeometries: Codable, Equatable {
        /// The geometry elements contained in this library.
        let geometries: [Geometry]

        enum CodingKeys: String, CodingKey {
            case geometries = "geometry"
        }
    }

    /// A geometry definition (`<geometry>` element) containing mesh data.
    ///
    /// Per COLLADA 1.4.1, Section 7.6.1, a `<geometry>` wraps a `<mesh>` element
    /// that contains the vertex sources, index data, and primitive descriptions.
    /// Nodes in the visual scene reference geometries via `<instance_geometry>`.
    struct Geometry: Codable, Equatable, Identifiable {
        var id: String? { geometryId }

        /// Unique identifier for this geometry, referenced by `<instance_geometry>` URL attributes.
        let geometryId: String?
        /// Human-readable name for the geometry.
        let name: String?
        /// The mesh data containing sources, vertices, and primitives.
        let mesh: Mesh?

        enum CodingKeys: String, CodingKey {
            case geometryId = "id"
            case name
            case mesh
        }
    }
    
    /// Builds a lookup table mapping geometry IDs to their ``Geometry`` objects.
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
    /// A mesh definition (`<mesh>` element) containing vertex sources and primitives.
    ///
    /// Per COLLADA 1.4.1, Section 7.6.2, a `<mesh>` contains `<source>` elements providing
    /// raw data (positions, normals, UVs), a `<vertices>` element mapping semantics to sources,
    /// and primitive elements (`<triangles>` or `<polylist>`) that index into the data.
    struct Mesh: Codable, Equatable {
        /// Data sources containing float arrays (positions, normals, texture coordinates).
        let sources: [Source]
        /// The vertex input mapping that connects semantics to data sources.
        let vertices: Vertices?
        /// Triangle primitive sets, each with its own material binding and index buffer.
        let triangles: [Triangles]?
        /// Polygon list primitive sets, with variable vertex counts per polygon.
        let polylist: [Polylist]?

        enum CodingKeys: String, CodingKey {
            case sources = "source"
            case vertices
            case triangles
            case polylist
        }
    }

    /// A data source (`<source>` element) providing typed array data with accessor metadata.
    ///
    /// Per COLLADA 1.4.1, Section 7.6.3, each `<source>` contains a `<float_array>` of raw
    /// values and a `<technique_common>` with an `<accessor>` describing how to interpret
    /// the array (stride, parameter names like X/Y/Z or S/T).
    struct Source: Codable, Equatable, Identifiable {
        var id: String? { sourceId }

        /// Unique identifier for this source, referenced by `<input>` elements.
        let sourceId: String?
        /// The raw float data array (`<float_array>` element).
        let floatArray: Collada.FloatArray?
        /// Access pattern describing how to read the float array.
        let techniqueCommon: TechniqueCommon?

        enum CodingKeys: String, CodingKey {
            case sourceId = "id"
            case floatArray = "float_array"
            case techniqueCommon = "technique_common"
        }
    }

    /// Common technique wrapper for accessor metadata (`<technique_common>` element).
    struct TechniqueCommon: Codable, Equatable {
        /// Describes how to read elements from the parent source's data array.
        let accessor: Accessor
    }

    /// Describes how to read structured elements from a data array (`<accessor>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.6.4, the accessor defines which array to read from,
    /// how many elements exist, the stride between elements, and named parameters
    /// describing each component (e.g. X, Y, Z for positions or S, T for texture coordinates).
    struct Accessor: Codable, Equatable {
        /// URI reference to the data array this accessor reads from.
        let source: String
        /// The number of elements (e.g. vertices) accessible.
        let count: Int
        /// Number of values per element (e.g. 3 for XYZ, 2 for ST). Defaults to 1.
        let stride: Int?
        /// Named parameters describing each component within an element.
        let params: [Param]?

        enum CodingKeys: String, CodingKey {
            case source, count, stride
            case params = "param"
        }
    }

    /// A named parameter within an accessor (`<param>` element).
    struct Param: Codable, Equatable {
        /// Parameter name (e.g. `"X"`, `"Y"`, `"Z"`, `"S"`, `"T"`).
        let name: String?
        /// Data type (e.g. `"float"`).
        let type: String?
    }

    /// The vertex input declaration (`<vertices>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.6.5, `<vertices>` maps semantic meanings
    /// (e.g. `"POSITION"`) to data sources. Primitive elements reference vertices
    /// by their `id` using the `"VERTEX"` semantic.
    struct Vertices: Codable, Equatable {
        /// Unique identifier, referenced by primitive `<input>` elements with `semantic="VERTEX"`.
        let id: String?
        /// Input connections mapping semantics to data sources.
        let inputs: [Input]

        enum CodingKeys: String, CodingKey {
            case id
            case inputs = "input"
        }
    }

    /// An input connection (`<input>` element) mapping a semantic to a data source.
    ///
    /// Per COLLADA 1.4.1, Section 7.6.6, inputs appear in both `<vertices>` (unshared)
    /// and primitive elements like `<triangles>` (shared, with offset).
    struct Input: Codable, Equatable {
        /// The semantic meaning (e.g. `"POSITION"`, `"NORMAL"`, `"TEXCOORD"`, `"VERTEX"`).
        let semantic: String
        /// URI reference to the data source or vertices element.
        let source: String
        /// Index offset within the interleaved `<p>` index array (shared inputs only).
        let offset: Int?
        /// Texture coordinate set index (used when `semantic` is `"TEXCOORD"`).
        let set: Int?
    }

    /// A set of triangle primitives (`<triangles>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.6.7, `<triangles>` defines indexed triangle geometry
    /// with interleaved indices in the `<p>` element. Each group of `inputCount` values
    /// in `<p>` defines one vertex of a triangle.
    struct Triangles: Codable, Equatable {
        /// Number of triangles in this set.
        let count: Int
        /// Material symbol binding (matched against `<instance_material>` in the visual scene).
        let material: String?
        /// Input connections defining which data feeds into each vertex.
        let inputs: [Input]
        /// Interleaved index array referencing source data for each vertex.
        let p: Collada.IndexArray

        enum CodingKeys: String, CodingKey {
            case count, material
            case inputs = "input"
            case p
        }
    }

    /// A set of polygon list primitives (`<polylist>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.6.8, `<polylist>` is similar to `<triangles>` but
    /// supports polygons with varying vertex counts. The `<vcount>` element specifies
    /// the number of vertices per polygon. During parsing, polygons are triangulated
    /// using a fan decomposition.
    struct Polylist: Codable, Equatable {
        /// Number of polygons in this set.
        let count: Int
        /// Material symbol binding.
        let material: String?
        /// Input connections defining which data feeds into each vertex.
        let inputs: [Input]
        /// Per-polygon vertex counts (e.g. `[4, 3, 4]` for a quad, triangle, quad).
        let vcount: Collada.IndexArray?
        /// Interleaved index array, with groups sized by `vcount` entries times input count.
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

// MARK: - DynamicNodeEncoding

extension Collada.Geometry: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Source: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Accessor: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "source", "count", "stride": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Param: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        return .attribute
    }
}

extension Collada.Geometry.Vertices: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Input: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        return .attribute
    }
}

extension Collada.Geometry.Triangles: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "count", "material": return .attribute
        default: return .element
        }
    }
}

extension Collada.Geometry.Polylist: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "count", "material": return .attribute
        default: return .element
        }
    }
}

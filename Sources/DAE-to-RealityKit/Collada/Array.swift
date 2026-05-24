//
//  Array.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import XMLCoder

// MARK: - Whitespace-Separated Array Wrapper Types

extension Collada {
    /// A float data array (`<float_array>` element) decoded from a whitespace-separated string.
    ///
    /// Per COLLADA 1.4.1, Section 7.6.3, `<float_array>` stores raw numeric data
    /// (vertex positions, normals, texture coordinates, etc.) as a space-delimited string.
    /// The `count` attribute declares the expected number of values.
    struct FloatArray: Codable, Equatable {
        /// Unique identifier for this array, referenced by `<accessor>` source attributes.
        let id: String?
        /// The declared number of float values.
        let count: Int
        /// The parsed float values.
        let values: [Float]

        enum CodingKeys: String, CodingKey {
            case id, count
            case values = ""
        }

        init(id: String?, count: Int, values: [Float]) {
            self.id = id
            self.count = count
            self.values = values
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            count = try container.decode(Int.self, forKey: .count)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Float($0) }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(count, forKey: .count)
            try container.encode(values.map { String($0) }.joined(separator: " "), forKey: .values)
        }
    }

    /// An integer index array decoded from a whitespace-separated string (e.g. `"0 1 2 3"`).
    ///
    /// Used for `<p>` (primitive index) and `<vcount>` (vertex count) elements within
    /// `<triangles>` and `<polylist>` primitives.
    struct IndexArray: Codable, Equatable {
        /// The parsed integer index values.
        let values: [Int]

        enum CodingKeys: String, CodingKey {
            case values = ""
        }

        init(values: [Int]) {
            self.values = values
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(values.map { String($0) }.joined(separator: " "), forKey: .values)
        }
    }
}

extension Collada.FloatArray: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "count": return .attribute
        default: return .element
        }
    }
}

extension Collada.FloatArray: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "id", "count": return .attribute
        default: return .element
        }
    }
}

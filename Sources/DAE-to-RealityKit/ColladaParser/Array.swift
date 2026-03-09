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
    /// Decodes a whitespace-separated string of floats (e.g. "1.0 2.0 3.0") into [Float]
    public struct FloatArray: Codable, Equatable {
        public let id: String?
        public let count: Int
        public let values: [Float]
        
        enum CodingKeys: String, CodingKey {
            case id, count
            case values = ""
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            count = try container.decode(Int.self, forKey: .count)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Float($0) }
        }
    }
    
    /// Decodes a whitespace-separated string of integers (e.g. "0 1 2 3") into [Int]
    public struct IndexArray: Codable, Equatable {
        public let values: [Int]
        
        enum CodingKeys: String, CodingKey {
            case values = ""
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let text = try container.decode(String.self, forKey: .values)
            values = text.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
        }
    }
}


extension Collada.FloatArray: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "count": return .attribute
        default: return .element
        }
    }
}

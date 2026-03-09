//
//  Color.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation

extension Collada {
    /// Decodes a whitespace-separated "R G B A" string into individual components
    struct ColorRGBA: Codable, Equatable, Sendable {
        let r: Float
        let g: Float
        let b: Float
        let a: Float

        enum CodingKeys: String, CodingKey {
            case value = ""
        }

        init(r: Float, g: Float, b: Float, a: Float) {
            self.r = r; self.g = g; self.b = b; self.a = a
        }

        init(from decoder: Decoder) throws {
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

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("\(r) \(g) \(b) \(a)", forKey: .value)
        }
    }
}

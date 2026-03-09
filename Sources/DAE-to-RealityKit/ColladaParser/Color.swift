//
//  Color.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//


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

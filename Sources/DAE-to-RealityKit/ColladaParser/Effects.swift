//
//  File.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import XMLCoder

// MARK: - Effects

extension Collada {
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
}

extension Collada.Effect {
    public struct Technique: Codable, Equatable {
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
    
    public struct ProfileCommon: Codable, Equatable {
        public let technique: Technique?

        enum CodingKeys: String, CodingKey {
            case technique
        }
    }
}

extension Collada.Effect.Technique {
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
}

// - MARK: DynamicNodeDecoding

extension Collada.Effect: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

extension Collada.Effect.Technique: DynamicNodeDecoding {
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

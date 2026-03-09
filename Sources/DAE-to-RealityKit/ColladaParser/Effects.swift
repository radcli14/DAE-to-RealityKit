//
//  Effects.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import XMLCoder

// MARK: - Effects

extension Collada {
    struct LibraryEffects: Codable, Equatable {
        let effects: [Effect]?

        enum CodingKeys: String, CodingKey {
            case effects = "effect"
        }
    }

    struct Effect: Codable, Equatable {
        let effectId: String?
        let profileCommon: ProfileCommon?

        enum CodingKeys: String, CodingKey {
            case effectId = "id"
            case profileCommon = "profile_COMMON"
        }
    }
}

extension Collada.Effect {
    struct Technique: Codable, Equatable {
        let sid: String?
        let phong: PhongShading?
        let lambert: LambertShading?
        let blinn: BlinnShading?

        enum CodingKeys: String, CodingKey {
            case sid, phong, lambert, blinn
        }

        /// Returns the diffuse color from whichever shading model is present
        var diffuseColor: Collada.ColorRGBA? {
            phong?.diffuse?.color ?? lambert?.diffuse?.color ?? blinn?.diffuse?.color
        }
    }

    struct ProfileCommon: Codable, Equatable {
        let technique: Technique?

        enum CodingKeys: String, CodingKey {
            case technique
        }
    }
}

extension Collada.Effect.Technique {
    struct PhongShading: Codable, Equatable {
        let diffuse: ColorProperty?
    }

    struct LambertShading: Codable, Equatable {
        let diffuse: ColorProperty?
    }

    struct BlinnShading: Codable, Equatable {
        let diffuse: ColorProperty?
    }

    struct ColorProperty: Codable, Equatable {
        let color: Collada.ColorRGBA?
    }
}

// MARK: - DynamicNodeDecoding

extension Collada.Effect: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

extension Collada.Effect.Technique: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

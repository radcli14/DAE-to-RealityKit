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

        /// The active shading model, whichever is present
        private var shading: ShadingProperties? {
            phong ?? lambert ?? blinn
        }

        var diffuseColor: Collada.ColorRGBA? { shading?.diffuse?.color }
        var diffuseTexture: TextureReference? { shading?.diffuse?.texture }
        var emissionColor: Collada.ColorRGBA? { shading?.emission?.color }
        var ambientColor: Collada.ColorRGBA? { shading?.ambient?.color }
        var specularColor: Collada.ColorRGBA? { shading?.specular?.color }
        var shininess: Float? { shading?.shininess?.float }
        var transparency: Float? { shading?.transparency?.float }
        var indexOfRefraction: Float? { shading?.indexOfRefraction?.float }
    }

    struct ProfileCommon: Codable, Equatable {
        let newparams: [NewParam]?
        let technique: Technique?

        enum CodingKeys: String, CodingKey {
            case newparams = "newparam"
            case technique
        }
    }

    /// Resolves a sampler reference to the image id it ultimately points to
    struct NewParam: Codable, Equatable {
        let sid: String?
        let surface: Surface?
        let sampler2D: Sampler2D?

        enum CodingKeys: String, CodingKey {
            case sid, surface, sampler2D
        }

        struct Surface: Codable, Equatable {
            let initFrom: String?

            enum CodingKeys: String, CodingKey {
                case initFrom = "init_from"
            }
        }

        struct Sampler2D: Codable, Equatable {
            let source: String?
        }
    }
}

// MARK: - Shading Properties (shared across Phong/Lambert/Blinn)

/// Protocol allowing Technique to access properties from any shading model
protocol ShadingProperties {
    var emission: Collada.Effect.Technique.ColorOrTextureProperty? { get }
    var ambient: Collada.Effect.Technique.ColorOrTextureProperty? { get }
    var diffuse: Collada.Effect.Technique.ColorOrTextureProperty? { get }
    var specular: Collada.Effect.Technique.ColorOrTextureProperty? { get }
    var shininess: Collada.Effect.Technique.FloatProperty? { get }
    var transparency: Collada.Effect.Technique.FloatProperty? { get }
    var indexOfRefraction: Collada.Effect.Technique.FloatProperty? { get }
}

extension Collada.Effect.Technique {
    struct PhongShading: Codable, Equatable, ShadingProperties {
        let emission: ColorOrTextureProperty?
        let ambient: ColorOrTextureProperty?
        let diffuse: ColorOrTextureProperty?
        let specular: ColorOrTextureProperty?
        let shininess: FloatProperty?
        let transparency: FloatProperty?
        let indexOfRefraction: FloatProperty?

        enum CodingKeys: String, CodingKey {
            case emission, ambient, diffuse, specular, shininess, transparency
            case indexOfRefraction = "index_of_refraction"
        }
    }

    struct LambertShading: Codable, Equatable, ShadingProperties {
        let emission: ColorOrTextureProperty?
        let ambient: ColorOrTextureProperty?
        let diffuse: ColorOrTextureProperty?
        let specular: ColorOrTextureProperty?
        let shininess: FloatProperty?
        let transparency: FloatProperty?
        let indexOfRefraction: FloatProperty?

        enum CodingKeys: String, CodingKey {
            case emission, ambient, diffuse, specular, shininess, transparency
            case indexOfRefraction = "index_of_refraction"
        }
    }

    struct BlinnShading: Codable, Equatable, ShadingProperties {
        let emission: ColorOrTextureProperty?
        let ambient: ColorOrTextureProperty?
        let diffuse: ColorOrTextureProperty?
        let specular: ColorOrTextureProperty?
        let shininess: FloatProperty?
        let transparency: FloatProperty?
        let indexOfRefraction: FloatProperty?

        enum CodingKeys: String, CodingKey {
            case emission, ambient, diffuse, specular, shininess, transparency
            case indexOfRefraction = "index_of_refraction"
        }
    }

    /// A property that can hold either a color or a texture reference
    struct ColorOrTextureProperty: Codable, Equatable {
        let color: Collada.ColorRGBA?
        let texture: TextureReference?
        let float: Float?
    }

    /// A property that holds a single float value (shininess, transparency, etc.)
    struct FloatProperty: Codable, Equatable {
        let float: Float?

        enum CodingKeys: String, CodingKey {
            case float
        }
    }

    /// A reference to a texture sampler
    struct TextureReference: Codable, Equatable {
        let texture: String
        let texcoord: String?
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

extension Collada.Effect.NewParam: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

extension Collada.Effect.NewParam.Surface: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "type": return .attribute
        default: return .element
        }
    }
}

extension Collada.Effect.Technique.TextureReference: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

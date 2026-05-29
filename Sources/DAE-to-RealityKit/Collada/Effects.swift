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
    /// Container for rendering effects (`<library_effects>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.5, `<library_effects>` holds `<effect>` elements
    /// that define shading models, colors, and texture references.
    struct LibraryEffects: Codable, Equatable {
        /// The effect elements contained in this library.
        let effects: [Effect]?

        enum CodingKeys: String, CodingKey {
            case effects = "effect"
        }
    }

    /// A rendering effect (`<effect>` element) containing profiles with shading techniques.
    ///
    /// Per COLLADA 1.4.1, Section 7.5.1, an `<effect>` groups one or more profiles.
    /// This implementation supports the `<profile_COMMON>` profile, which provides
    /// fixed-function shading models (Phong, Lambert, Blinn).
    struct Effect: Codable, Equatable {
        /// Unique identifier for this effect, referenced by materials via `<instance_effect>`.
        let effectId: String?
        /// The common profile containing the shading technique (`<profile_COMMON>`).
        let profileCommon: ProfileCommon?

        enum CodingKeys: String, CodingKey {
            case effectId = "id"
            case profileCommon = "profile_COMMON"
        }
    }
}

extension Collada.Effect {
    /// A shading technique within a profile (`<technique>` element under `<profile_COMMON>`).
    ///
    /// Per COLLADA 1.4.1, Section 7.5.4, a technique contains exactly one shading model:
    /// `<phong>`, `<lambert>`, or `<blinn>`. This struct provides unified access to
    /// whichever model is present via the ``ShadingProperties`` protocol.
    struct Technique: Codable, Equatable {
        /// Scoped identifier for this technique.
        let sid: String?
        /// Phong shading model, if present (`<phong>` element).
        let phong: PhongShading?
        /// Lambert shading model, if present (`<lambert>` element).
        let lambert: LambertShading?
        /// Blinn shading model, if present (`<blinn>` element).
        let blinn: BlinnShading?

        enum CodingKeys: String, CodingKey {
            case sid, phong, lambert, blinn
        }

        /// The active shading model, whichever is present.
        private var shading: ShadingProperties? {
            phong ?? lambert ?? blinn
        }

        /// The diffuse color from the active shading model.
        var diffuseColor: Collada.ColorRGBA? { shading?.diffuse?.color }
        /// The diffuse texture reference from the active shading model.
        var diffuseTexture: TextureReference? { shading?.diffuse?.texture }
        /// The emission (self-illumination) color from the active shading model.
        var emissionColor: Collada.ColorRGBA? { shading?.emission?.color }
        /// The ambient color from the active shading model.
        var ambientColor: Collada.ColorRGBA? { shading?.ambient?.color }
        /// The specular highlight color from the active shading model.
        var specularColor: Collada.ColorRGBA? { shading?.specular?.color }
        /// The shininess exponent from the active shading model.
        var shininess: Float? { shading?.shininess?.float }
        /// The `<transparent>` color (A_ONE convention: alpha=1 → opaque, alpha=0 → transparent).
        var transparentColor: Collada.ColorRGBA? { shading?.transparent?.color }
        /// Scalar multiplier from `<transparency>`. Opacity = `transparent.alpha × transparency`.
        var transparency: Float? { shading?.transparency?.float }
        /// The index of refraction for the material surface.
        var indexOfRefraction: Float? { shading?.indexOfRefraction?.float }
    }

    /// The common rendering profile (`<profile_COMMON>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.5.2, `<profile_COMMON>` defines fixed-function
    /// rendering parameters. It contains `<newparam>` elements for texture pipeline
    /// parameters and a single `<technique>` with the shading model.
    struct ProfileCommon: Codable, Equatable {
        /// Parameter declarations for texture pipeline resolution (`<newparam>` elements).
        let newparams: [NewParam]?
        /// The shading technique containing the material's shading model.
        let technique: Technique?

        enum CodingKeys: String, CodingKey {
            case newparams = "newparam"
            case technique
        }
    }

    /// A named parameter declaration (`<newparam>` element) within a profile.
    ///
    /// Per COLLADA 1.4.1, Section 7.5.3, `<newparam>` defines parameters that form
    /// the texture resolution pipeline: a `<sampler2D>` references a `<surface>`,
    /// which in turn references an `<image>` via `<init_from>`.
    struct NewParam: Codable, Equatable {
        /// The scoped identifier used to reference this parameter from texture elements.
        let sid: String?
        /// Surface definition, linking to an image (`<surface>` element).
        let surface: Surface?
        /// 2D texture sampler referencing a surface (`<sampler2D>` element).
        let sampler2D: Sampler2D?

        enum CodingKeys: String, CodingKey {
            case sid, surface, sampler2D
        }

        /// A surface resource (`<surface>` element) that wraps an image reference.
        struct Surface: Codable, Equatable {
            /// Surface type (e.g. `"2D"`), encoded as an XML attribute (`type="2D"`).
            let type: String?
            /// The image ID this surface initializes from (`<init_from>` element).
            let initFrom: String?

            enum CodingKeys: String, CodingKey {
                case type
                case initFrom = "init_from"
            }
        }

        /// A 2D texture sampler (`<sampler2D>` element) that references a surface parameter.
        struct Sampler2D: Codable, Equatable {
            /// The `sid` of the `<newparam>` containing the `<surface>` to sample from.
            let source: String?
        }
    }
}

// MARK: - Shading Properties (shared across Phong/Lambert/Blinn)

/// Shared interface for COLLADA fixed-function shading models.
///
/// COLLADA 1.4.1 defines three shading models under `<profile_COMMON>`:
/// Phong (Section 7.5.4.1), Lambert (Section 7.5.4.2), and Blinn (Section 7.5.4.3).
/// All three share the same set of optical properties; this protocol provides
/// uniform access regardless of which model is present.
protocol ShadingProperties {
    var emission: Collada.Effect.Technique.ColorOrTextureProperty? { get }
    var ambient: Collada.Effect.Technique.ColorOrTextureProperty? { get }
    var diffuse: Collada.Effect.Technique.ColorOrTextureProperty? { get }
    var specular: Collada.Effect.Technique.ColorOrTextureProperty? { get }
    var shininess: Collada.Effect.Technique.FloatProperty? { get }
    /// The transparent color/texture (`<transparent>`). In A_ONE mode (default) the alpha
    /// channel indicates opaqueness: alpha=1 means fully opaque, alpha=0 means transparent.
    var transparent: Collada.Effect.Technique.ColorOrTextureProperty? { get }
    /// Scalar multiplier on `<transparent>`. Combined as `opacity = transparent.alpha × transparency`.
    var transparency: Collada.Effect.Technique.FloatProperty? { get }
    var indexOfRefraction: Collada.Effect.Technique.FloatProperty? { get }
}

extension Collada.Effect.Technique {
    /// Phong shading model (`<phong>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.5.4.1, Phong uses specular highlights
    /// computed with the Phong reflection model.
    struct PhongShading: Codable, Equatable, ShadingProperties {
        let emission: ColorOrTextureProperty?
        let ambient: ColorOrTextureProperty?
        let diffuse: ColorOrTextureProperty?
        let specular: ColorOrTextureProperty?
        let shininess: FloatProperty?
        let transparent: ColorOrTextureProperty?
        let transparency: FloatProperty?
        let indexOfRefraction: FloatProperty?

        enum CodingKeys: String, CodingKey {
            case emission, ambient, diffuse, specular, shininess, transparent, transparency
            case indexOfRefraction = "index_of_refraction"
        }
    }

    /// Lambert shading model (`<lambert>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.5.4.2, Lambert is a diffuse-only shading model
    /// that does not include specular highlights.
    struct LambertShading: Codable, Equatable, ShadingProperties {
        let emission: ColorOrTextureProperty?
        let ambient: ColorOrTextureProperty?
        let diffuse: ColorOrTextureProperty?
        let specular: ColorOrTextureProperty?
        let shininess: FloatProperty?
        let transparent: ColorOrTextureProperty?
        let transparency: FloatProperty?
        let indexOfRefraction: FloatProperty?

        enum CodingKeys: String, CodingKey {
            case emission, ambient, diffuse, specular, shininess, transparent, transparency
            case indexOfRefraction = "index_of_refraction"
        }
    }

    /// Blinn shading model (`<blinn>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.5.4.3, Blinn uses the Blinn-Phong half-vector
    /// model for specular highlights, which is computationally cheaper than Phong.
    struct BlinnShading: Codable, Equatable, ShadingProperties {
        let emission: ColorOrTextureProperty?
        let ambient: ColorOrTextureProperty?
        let diffuse: ColorOrTextureProperty?
        let specular: ColorOrTextureProperty?
        let shininess: FloatProperty?
        let transparent: ColorOrTextureProperty?
        let transparency: FloatProperty?
        let indexOfRefraction: FloatProperty?

        enum CodingKeys: String, CodingKey {
            case emission, ambient, diffuse, specular, shininess, transparent, transparency
            case indexOfRefraction = "index_of_refraction"
        }
    }

    /// A shading property that can hold a color value, a texture reference, or a float.
    ///
    /// In the COLLADA schema, properties like `<diffuse>`, `<emission>`, and `<ambient>`
    /// can contain either a `<color>` element, a `<texture>` element, or a `<float>`.
    struct ColorOrTextureProperty: Codable, Equatable {
        /// The RGBA color value, if specified as `<color>`.
        let color: Collada.ColorRGBA?
        /// A reference to a texture sampler, if specified as `<texture>`.
        let texture: TextureReference?
        /// A scalar float value, if specified as `<float>`.
        let float: Float?
    }

    /// A shading property that holds a single scalar float value.
    ///
    /// Used for properties like `<shininess>`, `<transparency>`, and `<index_of_refraction>`
    /// which wrap their value in a `<float>` child element.
    struct FloatProperty: Codable, Equatable {
        let float: Float?

        enum CodingKeys: String, CodingKey {
            case float
        }
    }

    /// A reference to a texture sampler (`<texture>` element within a shading property).
    ///
    /// The `texture` attribute names a `<newparam>` `sid` that defines a `<sampler2D>`,
    /// forming the first link in the COLLADA texture resolution chain.
    struct TextureReference: Codable, Equatable {
        /// The `sid` of the `<newparam>` containing the sampler to use.
        let texture: String
        /// The texture coordinate set semantic (e.g. `"TEX0"`).
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

// MARK: - DynamicNodeEncoding

extension Collada.Effect: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "id": return .attribute
        default: return .element
        }
    }
}

extension Collada.Effect.Technique: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

extension Collada.Effect.NewParam: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "sid": return .attribute
        default: return .element
        }
    }
}

extension Collada.Effect.NewParam.Surface: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "type": return .attribute
        default: return .element
        }
    }
}

extension Collada.Effect.Technique.TextureReference: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        return .attribute
    }
}

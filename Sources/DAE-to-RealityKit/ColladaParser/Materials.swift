//
//  Materials.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import XMLCoder

// MARK: - Materials

extension Collada {
    /// Container for material definitions (`<library_materials>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.8, `<library_materials>` holds `<material>` elements
    /// that bind named materials to their rendering effects.
    struct LibraryMaterials: Codable, Equatable {
        /// The material elements contained in this library.
        let materials: [Material]?

        enum CodingKeys: String, CodingKey {
            case materials = "material"
        }
    }

    /// A material definition (`<material>` element) that binds to an effect.
    ///
    /// Per COLLADA 1.4.1, Section 7.8.1, a `<material>` instantiates an `<effect>`
    /// via `<instance_effect>`. Geometry nodes reference materials by ID through
    /// `<instance_material>` bindings in the visual scene.
    struct Material: Codable, Equatable {
        /// Unique identifier for this material, referenced by `<instance_material>` target attributes.
        let materialId: String?
        /// Human-readable name for the material.
        let name: String?
        /// Reference to the effect that defines this material's rendering properties.
        let instanceEffect: InstanceEffect?

        enum CodingKeys: String, CodingKey {
            case materialId = "id"
            case name
            case instanceEffect = "instance_effect"
        }
    }

    /// A reference to an effect (`<instance_effect>` element).
    ///
    /// The `url` attribute is a URI fragment (e.g. `"#effect0"`) pointing to an
    /// `<effect>` in `<library_effects>`.
    struct InstanceEffect: Codable, Equatable {
        /// URI fragment referencing an `<effect>` id.
        let url: String
    }
}

// MARK: - DynamicNodeDecoding

extension Collada.Material: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

extension Collada.InstanceEffect: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
}

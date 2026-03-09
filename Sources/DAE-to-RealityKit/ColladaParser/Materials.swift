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
    struct LibraryMaterials: Codable, Equatable {
        let materials: [Material]?

        enum CodingKeys: String, CodingKey {
            case materials = "material"
        }
    }

    struct Material: Codable, Equatable {
        let materialId: String?
        let name: String?
        let instanceEffect: InstanceEffect?

        enum CodingKeys: String, CodingKey {
            case materialId = "id"
            case name
            case instanceEffect = "instance_effect"
        }
    }

    struct InstanceEffect: Codable, Equatable {
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

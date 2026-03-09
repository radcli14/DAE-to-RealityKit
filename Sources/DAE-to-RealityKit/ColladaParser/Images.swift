//
//  Images.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import XMLCoder

extension Collada {
    struct LibraryImages: Codable, Equatable {
        let images: [Image]?

        enum CodingKeys: String, CodingKey {
            case images = "image"
        }
    }

    struct Image: Codable, Equatable {
        let imageId: String?
        let name: String?
        let initFrom: String?

        enum CodingKeys: String, CodingKey {
            case imageId = "id"
            case name
            case initFrom = "init_from"
        }
    }
    
    var imageMap: [String: String] {
        guard let images = libraryImages?.images else { return [:] }
        var map: [String: String] = [:]
        for image in images {
            if let imageId = image.imageId, let path = image.initFrom {
                map[imageId] = path
            }
        }
        return map
    }
}

extension Collada.Image: DynamicNodeDecoding {
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

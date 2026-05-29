//
//  Images.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 3/9/26.
//

import Foundation
import XMLCoder

extension Collada {
    /// Container for image assets (`<library_images>` element).
    ///
    /// Per COLLADA 1.4.1, Section 7.7, `<library_images>` holds `<image>` elements
    /// that define texture file references used by effects.
    struct LibraryImages: Codable, Equatable {
        /// The image elements contained in this library.
        let images: [Image]?

        enum CodingKeys: String, CodingKey {
            case images = "image"
        }
    }

    /// An image asset (`<image>` element) referencing an external texture file.
    ///
    /// Per COLLADA 1.4.1, Section 7.7.1, each `<image>` provides a file path via its
    /// `<init_from>` child element. Effects reference images through the texture pipeline:
    /// `<texture>` → `<sampler2D>` → `<surface>` → `<image>`.
    struct Image: Codable, Equatable {
        /// Unique identifier for this image, used for cross-referencing from surfaces.
        let imageId: String?
        /// Human-readable name for the image.
        let name: String?
        /// File path or URI to the image resource (`<init_from>` element).
        let initFrom: String?

        enum CodingKeys: String, CodingKey {
            case imageId = "id"
            case name
            case initFrom = "init_from"
        }
    }
    
    /// Builds a lookup table mapping image IDs to their file paths for texture resolution.
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

extension Collada.Image: DynamicNodeEncoding {
    static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key.stringValue {
        case "id", "name": return .attribute
        default: return .element
        }
    }
}

//
//  SCNMaterialProperty+Extensions.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 12/20/25.
//

import Foundation
import SceneKit


#if os(iOS)
public extension SCNMaterialProperty {
    var uiColor: UIColor? {
        contents as? UIColor
    }
    
    var uiImage: UIImage? {
        contents as? UIImage
    }
    
    var cgImage: CGImage? {
        uiImage?.cgImage
    }
}

public extension UIImage {
    var cgImage: CGImage? {
        // UIImage already has a cgImage property
        return self.cgImage
    }
}
#endif

#if os(macOS)
public extension SCNMaterialProperty {
    var uiColor: NSColor? {
        contents as? NSColor
    }
    
    var uiImage: NSImage? {
        contents as? NSImage
    }
    
    var cgImage: CGImage? {
        uiImage?.cgImage
    }
}

public extension NSImage {
    var cgImage: CGImage? {
        // NSImage doesn't have a direct cgImage property, so we need to extract it
        var imageRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        return cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
    }
}
#endif

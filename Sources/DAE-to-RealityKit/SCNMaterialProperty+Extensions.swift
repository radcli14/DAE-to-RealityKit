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
        if let color = contents as? UIColor {
            return color
        } else if let obj = contents as AnyObject?, CFGetTypeID(obj) == CGColor.typeID {
            return UIColor(cgColor: obj as! CGColor)
        }
        return nil
    }

    var uiImage: UIImage? {
        contents as? UIImage
    }

    var cgImage: CGImage? {
        uiImage?.cgImage
    }
}
#endif

#if os(macOS)
public extension SCNMaterialProperty {
    var uiColor: NSColor? {
        if let color = contents as? NSColor {
            return color
        } else if let obj = contents as AnyObject?, CFGetTypeID(obj) == CGColor.typeID {
            return NSColor(cgColor: obj as! CGColor)
        }
        return nil
    }

    var uiImage: NSImage? {
        contents as? NSImage
    }

    var cgImage: CGImage? {
        if let nsImage = uiImage {
            var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
            return nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        }
        return nil
    }
}
#endif

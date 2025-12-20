//
//  SCNNode.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 12/20/25.
//

import Foundation
import SceneKit

public extension SCNNode {
    /// Recursively find all geometry nodes in this node's hierarchy
    var geometryNodes: [SCNNode] {
        var result: [SCNNode] = []
        if geometry != nil {
            result.append(self)
        }
        for child in childNodes {
            result.append(contentsOf: child.geometryNodes)
        }
        return result
    }
    
    /// Debug method to print the node hierarchy
    func unpack(indent: String = "") {
        print("\(indent)📦 Node: \(name ?? "unnamed")")
        if let geometry = geometry {
            print("\(indent)  └─ Geometry: \(geometry.name ?? "unnamed"), \(geometry.elements.count) elements")
        }
        for child in childNodes {
            child.unpack(indent: indent + "  ")
        }
    }
}

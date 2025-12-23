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
}

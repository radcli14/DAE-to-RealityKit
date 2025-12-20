//
//  SCNMaterial+Extensions.swift
//  DAE-to-RealityKit
//
//  Created by Eliott Radcliffe on 12/20/25.
//

import Foundation
import RealityKit
import SceneKit

public extension SCNMaterial {
    @MainActor var rkMaterial: PhysicallyBasedMaterial? {
        var material = PhysicallyBasedMaterial()
        var hasAnyProperty = false
        
        // Debug: Print all material property contents
        print("  🔍 Material Debug Info:")
        print("    diffuse.contents: \(String(describing: diffuse.contents))")
        print("    specular.contents: \(String(describing: specular.contents))")
        print("    reflective.contents: \(String(describing: reflective.contents))")
        print("    emission.contents: \(String(describing: emission.contents))")
        print("    transparent.contents: \(String(describing: transparent.contents))")
        print("    metalness.contents: \(String(describing: metalness.contents))")
        print("    roughness.contents: \(String(describing: roughness.contents))")
        print("    normal.contents: \(String(describing: normal.contents))")
        print("    ambientOcclusion.contents: \(String(describing: ambientOcclusion.contents))")
        print("    selfIllumination.contents: \(String(describing: selfIllumination.contents))")
        print("    multiply.contents: \(String(describing: multiply.contents))")
        print("    shininess: \(shininess)")
        print("    transparency: \(transparency)")
        print("    lightingModel: \(lightingModel.rawValue)")
        
        // Base Color (from diffuse property)
        if let color = diffuse.uiColor {
            material.baseColor = .init(tint: color)
            hasAnyProperty = true
            print("  ✓ Applied base color (solid)")
        } else if let cgImage = diffuse.cgImage {
            if let textureResource = try? TextureResource(image: cgImage, options: .init(semantic: .color)) {
                material.baseColor = .init(texture: .init(textureResource))
                hasAnyProperty = true
                print("  ✓ Applied base color (texture)")
            }
        }
        
        // Normal Map
        if let cgImage = normal.cgImage {
            if let textureResource = try? TextureResource(image: cgImage, options: .init(semantic: .normal)) {
                material.normal = .init(texture: .init(textureResource))
                hasAnyProperty = true
                print("  ✓ Applied normal map")
            }
        }
        
        // Roughness (numeric value, color, or texture)
        if let roughnessNumber = roughness.contents as? NSNumber {
            material.roughness = .init(floatLiteral: roughnessNumber.floatValue)
            hasAnyProperty = true
            print("  ✓ Applied roughness value: \(roughnessNumber.floatValue)")
        } else if let roughnessColor = roughness.uiColor {
            // Extract grayscale value from color (using red component as they're all equal)
            var red: CGFloat = 0
            roughnessColor.getRed(&red, green: nil, blue: nil, alpha: nil)
            let roughnessValue = Float(red)
            material.roughness = .init(floatLiteral: roughnessValue)
            hasAnyProperty = true
            print("  ✓ Applied roughness from color: \(roughnessValue)")
        } else if let cgImage = roughness.cgImage {
            if let textureResource = try? TextureResource(image: cgImage, options: .init(semantic: .raw)) {
                material.roughness = .init(texture: .init(textureResource))
                hasAnyProperty = true
                print("  ✓ Applied roughness (texture)")
            }
        }
        
        // Specular (numeric value, color, or texture)
        if let specularNumber = specular.contents as? NSNumber {
            material.specular = .init(floatLiteral: specularNumber.floatValue)
            hasAnyProperty = true
            print("  ✓ Applied specular value: \(specularNumber.floatValue)")
        } else if let specularColor = specular.uiColor {
            var red: CGFloat = 0
            specularColor.getRed(&red, green: nil, blue: nil, alpha: nil)
            let specularValue = Float(red)
            material.specular = .init(floatLiteral: specularValue)
            hasAnyProperty = true
            print("  ✓ Applied specular from color: \(specularValue)")
        } else if let cgImage = specular.cgImage {
            if let textureResource = try? TextureResource(image: cgImage, options: .init(semantic: .raw)) {
                material.specular = .init(texture: .init(textureResource))
                hasAnyProperty = true
                print("  ✓ Applied specular (texture)")
            }
        }
        
        // Reflective (from COLLADA reflectivity)
        if let reflectivityNumber = reflective.contents as? NSNumber {
            material.clearcoat = .init(floatLiteral: reflectivityNumber.floatValue)
            hasAnyProperty = true
            print("  ✓ Applied clearcoat from reflectivity: \(reflectivityNumber.floatValue)")
        } else if let reflectiveColor = reflective.uiColor {
            var red: CGFloat = 0
            reflectiveColor.getRed(&red, green: nil, blue: nil, alpha: nil)
            let reflectiveValue = Float(red)
            material.clearcoat = .init(floatLiteral: reflectiveValue)
            hasAnyProperty = true
            print("  ✓ Applied clearcoat from reflective color: \(reflectiveValue)")
        } else if let cgImage = reflective.cgImage {
            if let textureResource = try? TextureResource(image: cgImage, options: .init(semantic: .raw)) {
                material.clearcoat = .init(texture: .init(textureResource))
                hasAnyProperty = true
                print("  ✓ Applied clearcoat (texture)")
            }
        }
        
        // Metallic (numeric value, color, or texture)
        if let metallicNumber = metalness.contents as? NSNumber {
            material.metallic = .init(floatLiteral: metallicNumber.floatValue)
            hasAnyProperty = true
            print("  ✓ Applied metallic value: \(metallicNumber.floatValue)")
        } else if let metallicColor = metalness.uiColor {
            var red: CGFloat = 0
            metallicColor.getRed(&red, green: nil, blue: nil, alpha: nil)
            let metallicValue = Float(red)
            material.metallic = .init(floatLiteral: metallicValue)
            hasAnyProperty = true
            print("  ✓ Applied metallic from color: \(metallicValue)")
        } else if let cgImage = metalness.cgImage {
            if let textureResource = try? TextureResource(image: cgImage, options: .init(semantic: .raw)) {
                material.metallic = .init(texture: .init(textureResource))
                hasAnyProperty = true
                print("  ✓ Applied metallic (texture)")
            }
        }
        
        // Try using shininess as a fallback for specular/roughness
        if shininess > 0 {
            // Shininess typically ranges from 0-1000+, normalize it
            // Higher shininess = lower roughness
            let normalizedShininess = min(shininess / 1000.0, 1.0)
            let roughnessValue = 1.0 - Float(normalizedShininess)
            material.roughness = .init(floatLiteral: roughnessValue)
            hasAnyProperty = true
            print("  ✓ Applied roughness from shininess: \(roughnessValue) (shininess: \(shininess))")
        }
        
        // Return nil if no properties were set
        guard hasAnyProperty else {
            print("  ⚠️ No material properties found, returning nil")
            return nil
        }
        
        return material
    }
}

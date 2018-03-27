//
//  ARObjectUtils.swift
//  ARAtomicLab
//
//  Created by Mike He on 2018/3/27.
//  Copyright © 2018年 Deyuan He. All rights reserved.
//

import UIKit
import SceneKit

class AtomUtil {
    public static func makeAtom(name: String, radius: Double, color: UIColor) -> SCNNode {
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = SCNBillboardAxis.Y
        let atomNameTag = SCNText(string: name, extrusionDepth: 0.005)
        atomNameTag.font = UIFont(name: "Courier", size: 0.15)
        atomNameTag.alignmentMode = kCAAlignmentCenter
        atomNameTag.firstMaterial?.diffuse.contents = color
        atomNameTag.firstMaterial?.specular.contents = UIColor.white
        atomNameTag.firstMaterial?.isDoubleSided = true
        atomNameTag.chamferRadius = CGFloat(Float(radius + 0.03))
        let (minBound, maxBound) = atomNameTag.boundingBox
        let atomNameTagNode = SCNNode(geometry: atomNameTag)
        atomNameTagNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, Float(radius + 0.035))
        atomNameTagNode.scale = SCNVector3(0.2, 0.2, 0.2)
        atomNameTagNode.position = SCNVector3(0, Float(radius + 0.005), 0)
        let sphere = SCNSphere(radius: CGFloat(radius))
        sphere.firstMaterial?.diffuse.contents = color
        let sphereNode = SCNNode(geometry: sphere)
        let wrapperNode = SCNNode()
        wrapperNode.addChildNode(atomNameTagNode)
        wrapperNode.addChildNode(sphereNode)
        wrapperNode.constraints = [constraint]
        return wrapperNode
    }
    
    public static func generateElectronNodes(count: Int, courseRadius: Double) -> SCNNode? {
        if count != 0 {
            let degree: Double = 2.0 * .pi / Double(count)
            let wrapper: SCNNode = SCNNode()
            for i in 0..<count {
                let material = SCNSphere(radius: 0.002)
                material.firstMaterial?.diffuse.contents = UIColor.blue
                let electron = SCNNode(geometry: material)
                electron.position = SCNVector3(courseRadius * sin(Double(i) * degree), 0, courseRadius * cos(Double(i) * degree))
                wrapper.addChildNode(electron.clone())
            }
            return wrapper
        } else { return nil }
    }
    
    public static func makeAtomWithElectrons(name: String, radius: Double, color: UIColor, numberOfElectrons: Int, electronOrbitRadius: Double, position: SCNVector3) -> SCNNode? {
        let atomNode = self.makeAtom(name: name, radius: radius, color: color)
        let animation = CABasicAnimation(keyPath: "rotation")
        animation.keyPath = "rotation"
        animation.toValue = SCNVector4Make(0, 1, 0, .pi * 2)
        animation.duration = 2.5
        animation.repeatCount = .greatestFiniteMagnitude
        guard let wrappedElectron = self.generateElectronNodes(count: numberOfElectrons, courseRadius: electronOrbitRadius) else {
            return nil
        }
        wrappedElectron.addAnimation(animation, forKey: "rotating")
        let wrapperNode = SCNNode()
        wrapperNode.addChildNode(atomNode)
        wrapperNode.addChildNode(wrappedElectron)
        wrapperNode.name = "electrons"
        wrapperNode.position = position
        return wrapperNode
    }
}

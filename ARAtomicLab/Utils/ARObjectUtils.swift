//
//  ARObjectUtils.swift
//  ARAtomicLab
//
//  Created by Mike He on 2018/3/27.
//  Copyright © 2018 Deyuan He. All rights reserved.
//

import UIKit
import SceneKit

class AtomUtils {
    static let sqr = {(x: Float) in x * x}
    public static func calcDistance(fi: SCNNode, se: SCNNode) -> Float {
        return sqrt(sqr(fi.position.x - se.position.x) + sqr(fi.position.y - se.position.y) + sqr(fi.position.z - se.position.z))
    }
    
    public static func centerOfTwo(fi: SCNNode, se: SCNNode) -> SCNVector3 {
        return SCNVector3((fi.position.x + se.position.x) / 2.0, (fi.position.y + se.position.y) / 2.0, (fi.position.z + se.position.z) / 2.0)
    }
    
    public static func paddingPointForSmallerAtom(centerPos: SCNVector3, smallerAtomPosition: SCNVector3, smallerAtomRadius: Float) -> SCNVector3 {
        let (a, b, c, d, e, f) = (centerPos.x, centerPos.y, centerPos.z, smallerAtomPosition.x, smallerAtomPosition.y, smallerAtomPosition.z)
        let (m, n, p) = (a - d, b - e, c - f)
        let k = smallerAtomRadius * sqrt(1.0 / (sqr(m) + sqr(n) + sqr(p)))
        return SCNVector3(a + m * k, b + n * k, c + p * k)
    }
    
    public static func makeTextNode(msg: String) -> SCNNode {
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = SCNBillboardAxis.Y
        let text = SCNText(string: msg, extrusionDepth: 0.005)
        text.font = UIFont(name: "Courier", size: 0.15)
        text.alignmentMode = kCAAlignmentCenter
        text.firstMaterial?.diffuse.contents = UIColor.white
        text.firstMaterial?.specular.contents = UIColor.white
        text.firstMaterial?.isDoubleSided = true
        let textNode = SCNNode(geometry: text)
        textNode.scale = SCNVector3(0.2, 0.2, 0.2)
        return textNode
    }
    
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
        atomNameTagNode.name = "atomNameTag"
        let sphere = SCNSphere(radius: CGFloat(radius))
        sphere.firstMaterial?.diffuse.contents = color
        let sphereNode = SCNNode(geometry: sphere)
        let wrapperNode = SCNNode()
        wrapperNode.addChildNode(atomNameTagNode)
        wrapperNode.addChildNode(sphereNode)
        wrapperNode.constraints = [constraint]
        return wrapperNode
    }
    
    public static func makeAtomWithoutTag(radius: Double, color: UIColor) -> SCNNode {
        let material = SCNSphere(radius: CGFloat(radius))
        material.firstMaterial?.diffuse.contents = color
        let resultNode = SCNNode(geometry: material)
        return resultNode
    }
    
    public static func makeCombinedAtoms(primaryAtom: SCNNode, secondaryAtoms: [SCNNode: Int], arcRadius: Float, radiusToPrimAtom: Float, position: SCNVector3, startOffset: Float?) -> SCNNode {
        let secondaryWrapper = SCNNode()
        let wrappedCombinedAtoms = SCNNode()
        var i = 1
        var offset: Float = 0.0
        if let unwrap = startOffset {
            offset = unwrap
        }
        for (instance, count) in secondaryAtoms {
            for _ in 1...count {
                let clone = instance.clone()
                clone.position = SCNVector3(radiusToPrimAtom * sin(Float(i) * (arcRadius + offset)), 0, radiusToPrimAtom * cos(Float(i) * (arcRadius + offset)))
                secondaryWrapper.addChildNode(clone)
                i += 1
            }
        }
        wrappedCombinedAtoms.position = position
        wrappedCombinedAtoms.addChildNode(primaryAtom)
        wrappedCombinedAtoms.addChildNode(secondaryWrapper)
        return wrappedCombinedAtoms
    }
    
    public static func makeCombinedAtomsBy(name: String, position: SCNVector3) -> SCNNode? {
        if name == "H2O" {
            let pNode = makeAtomWithoutTag(radius: Constants.atomRadius["O"]!, color: .red)
            let sNode = makeAtomWithoutTag(radius: Constants.atomRadius["H"]!, color: .white)
            let retNode = makeCombinedAtoms(primaryAtom: pNode, secondaryAtoms: [sNode:2], arcRadius: Float(108.0 / 180.0 * .pi), radiusToPrimAtom: Float(Constants.atomRadius["O"]!), position: position, startOffset: nil)
            return retNode
        } else if name == "CO2" {
            let pNode = makeAtomWithoutTag(radius: Constants.atomRadius["C"]!, color: Constants.atomColor["C"]!)
            let sNode = makeAtomWithoutTag(radius: Constants.atomRadius["O"]!, color: Constants.atomColor["O"]!)
            let retNode = makeCombinedAtoms(primaryAtom: pNode, secondaryAtoms: [sNode:2], arcRadius: Float(1.0 * .pi), radiusToPrimAtom: Float(Constants.atomRadius["C"]!) + Float(Constants.atomRadius["C"]! / 2.0), position: position, startOffset: nil)
            return retNode
        }
        return nil
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
        let animation = TaggedCABasicAnimation(keyPath: "rotation")
        animation.keyPath = "rotation"
        animation.toValue = SCNVector4Make(0, 1, 0, .pi * 2)
        animation.duration = 2.5
        animation.repeatCount = .greatestFiniteMagnitude
        guard let wrappedElectron = self.generateElectronNodes(count: numberOfElectrons, courseRadius: electronOrbitRadius) else {
            return nil
        }
        wrappedElectron.addAnimation(animation, forKey: "rotating")
        animation.animatedObject = wrappedElectron
        let wrapperNode = SCNNode()
        let electronAnimatedWrapper = SCNNode()
        electronAnimatedWrapper.name = "electrons"
        electronAnimatedWrapper.addChildNode(wrappedElectron)
        wrapperNode.addChildNode(electronAnimatedWrapper)
        wrapperNode.addChildNode(atomNode)
        wrapperNode.position = position
        wrapperNode.name = name
        return wrapperNode
    }
}

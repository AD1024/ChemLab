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
    
    /// - pow(x, 2)
    static let sqr = {(x: Float) in x * x}
    
    ///  calculate the euclidean metric
    ///
    ///  - parameter fi: the position of the first node
    ///  - parameter se: the position of the second node
    ///
    ///  - returns:  the euclidean metric between two nodes
    public static func calcDistance(fi: SCNNode, se: SCNNode) -> Float {
        return sqrt(sqr(fi.position.x - se.position.x) + sqr(fi.position.y - se.position.y) + sqr(fi.position.z - se.position.z))
    }
    
    
    ///  calculate the center point between two 3D points
    ///
    ///  - parameter fi: the position of the first node
    ///  - parameter se: the position of the second node
    ///
    ///  - returns:  the center point between two nodes
    public static func centerOfTwo(fi: SCNNode, se: SCNNode) -> SCNVector3 {
        return SCNVector3((fi.position.x + se.position.x) / 2.0, (fi.position.y + se.position.y) / 2.0, (fi.position.z + se.position.z) / 2.0)
    }
    
    ///  calculate the padding distance between two points
    ///
    ///  NOTE: this is done for two-atom reaction. If two atom fly to the center point, they will overlap with each other;
    ///        therefore, a padding distance of {largerAtomRadius} is necessary. This calculation is derived by solving equations in a 3D coordinate.
    ///         MAGIC OF MATHEMATICS!!!
    ///
    ///  - parameter centerPos:           The position of the center between two nodes
    ///  - parameter smallerAtomPosition: The position of the smaller one
    ///  - parameter largerAtomRadius:    The radius(padding distance) between
    ///
    ///  - returns:  the euclidean metric between two nodes
    public static func paddingPointForSmallerAtom(centerPos: SCNVector3, smallerAtomPosition: SCNVector3, largerAtomRadius: Float) -> SCNVector3 {
        let (a, b, c, d, e, f) = (centerPos.x, centerPos.y, centerPos.z, smallerAtomPosition.x, smallerAtomPosition.y, smallerAtomPosition.z)
        let (m, n, p) = (a - d, b - e, c - f)
        let k = largerAtomRadius * sqrt(1.0 / (sqr(m) + sqr(n) + sqr(p)))
        return SCNVector3(a + m * k, b + n * k, c + p * k)
    }
    
    ///  Create an text ARObject
    ///
    ///  - parameter msg: the text to present
    ///
    ///  - returns: The constructed node **WITHOUT** position
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
    
    
    ///  Create an atom with name tag at its top
    ///
    ///  - parameter name:   the name of the atom(it will be presented at the top of the node)
    ///  - parameter radius: the radius of the sphere
    ///  - parameter color:  the color of the atom
    ///
    ///  - returns:  the wrapped node containing the tag and the atom
    public static func makeAtom(name: String, radius: Double, color: UIColor) -> SCNNode {
        let constraint = SCNBillboardConstraint()
        
        // Setup the textNode
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
        
        // Setup the atom itself
        let sphere = SCNSphere(radius: CGFloat(radius))
        sphere.firstMaterial?.diffuse.contents = color
        let sphereNode = SCNNode(geometry: sphere)
        let wrapperNode = SCNNode()
        wrapperNode.addChildNode(atomNameTagNode)
        wrapperNode.addChildNode(sphereNode)
        wrapperNode.constraints = [constraint]
        return wrapperNode
    }
    
    ///  Create an atom without name tag
    ///
    ///  - parameter radius: the radius of the atom
    ///  - parameter color:  the color of the atom
    ///
    ///  - returns: the constructed atom node **WITHOUT** position property
    public static func makeAtomWithoutTag(radius: Double, color: UIColor) -> SCNNode {
        let material = SCNSphere(radius: CGFloat(radius))
        material.firstMaterial?.diffuse.contents = color
        let resultNode = SCNNode(geometry: material)
        return resultNode
    }
    
    ///  Create atoms combined together
    ///
    ///  - parameter primaryAtom:      the primary atom(for instance: the primary of CO2 is C)
    ///  - parameter secondaryAtoms:   the atoms surrounding the primary one
    ///  - parameter arcRadius:        the radius of arc between each secondary atom
    ///  - parameter radiusToPrimAtom: the distance toward the primary atom
    ///  - parameter position:         the coordinate of the combined node
    ///  - parameter startOffset:      the radius offset of the starting secondary atom
    ///
    ///  - returns:  the euclidean metric between two nodes
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
                // p = (sin(x), cos(y)) * r
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
    
    ///  Make combined atoms for corresponding molecules
    ///
    ///  - parameter name:     the name of the molecule
    ///  - parameter position: the position of the node
    ///
    ///  - returns:  the combined atoms model
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
    
    ///  Create surrounding electrons
    ///
    ///  - parameter count:        number of electrons
    ///  - parameter courseRadius: the radius of electron course
    ///
    ///  - returns:  surrounding electrons
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
    
    ///  Create atom model with electrons
    ///
    ///  - parameter name:                 the name of atom
    ///  - parameter radius:               the radius of the atom
    ///  - parameter color:                the color of the atom
    ///  - parameter numberOfElectrons:    the number of electrons surrounding the atom
    ///  - parameter electronOrbitRadius:  the radius of electron course
    ///  - parameter position:             the position of generated model
    ///
    ///  - returns:  the euclidean metric between two nodes
    public static func makeAtomWithElectrons(name: String, radius: Double, color: UIColor, numberOfElectrons: Int, electronOrbitRadius: Double, position: SCNVector3) -> SCNNode? {
        let atomNode = self.makeAtom(name: name, radius: radius, color: color)
        let animation = TaggedCABasicAnimation(keyPath: "rotation")
        animation.keyPath = "rotation"
        // rotate at y-axis
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

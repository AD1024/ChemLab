//
//  AnimationToolKit.swift
//  ARAtomicLab
//
//  Created by Mike He on 2018/3/27.
//  Copyright © 2018 Deyuan He. All rights reserved.
//

import Foundation
import SceneKit

public class TaggedCABasicAnimation: CABasicAnimation {
    public var animatedObject: SCNNode?
}

class CABasicAnimationBuilder {
    private static var template = CABasicAnimation()
    private static func initialize() {
        self.template = CABasicAnimation()
    }
    
    public static func setKeyPath(_ keyPath: String) -> CABasicAnimationBuilder.Type {
        self.template.keyPath = keyPath
        return self
    }
    
    public static func setDuration(_ duration: Float) -> CABasicAnimationBuilder.Type {
        self.template.duration = CFTimeInterval(duration)
        return self
    }
    
    public static func setFromValue(_ fromValue: Any?) -> CABasicAnimationBuilder.Type {
        self.template.fromValue = fromValue
        return self
    }
    
    public static func setToValue(_ toValue: Any?) -> CABasicAnimationBuilder.Type {
        self.template.toValue = toValue
        return self
    }
    
    public static func setRepeatCount(_ repeatCount: Float) -> CABasicAnimationBuilder.Type {
        self.template.repeatCount = repeatCount
        return self
    }
    
    public static func setFillMode(_ fillMode: String) -> CABasicAnimationBuilder.Type {
        self.template.fillMode = fillMode
        return self
    }
    
    public static func isRemovedOnCompletion(_ isRemoved: Bool) -> CABasicAnimationBuilder.Type {
        self.template.isRemovedOnCompletion = isRemoved
        return self
    }
    
    public static func build() -> CABasicAnimation {
        let result = self.template.copy() as! CABasicAnimation
        self.initialize()
        return result
    }
}

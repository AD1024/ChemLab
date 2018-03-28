//
//  Constants.swift
//  ARAtomicLab
//
//  Created by Mike He on 2018/3/28.
//  Copyright © 2018年 Deyuan He. All rights reserved.
//
import SceneKit

class Constants {
    public static var atomList: [String] = ["H", "O", "C", "Cl", "Na"]
    public static var atomRadius: [String:Double] = ["H": 0.005, "O": 0.010, "C": 0.008, "Cl": 0.015, "Na": 0.006]
    public static let electronCourseRadius: [String:Double] = ["H": 0.010, "O": 0.015, "C": 0.013, "Cl": 0.020, "Na": 0.011]
    public static let atomColor: [String:UIColor] = ["H": .white, "O": .red, "Cl": .green, "Na": .purple, "C": .black]
    public static let electronCount: [String:Int] = ["H": 1, "O": 2, "C": 4, "Cl": 7, "Na": 1]
}

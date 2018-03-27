//
//  ReactionUtil.swift
//  ARAtomicLab
//
//  Created by Mike He on 2018/3/27.
//  Copyright © 2018年 Deyuan He. All rights reserved.
//

import Foundation

class ReactionDetector {
    private static let supportedReactions: [Int:([String:Int], String)] = [4799450059693178067: (["H": 1, "O": 2], "H2O"), 4799450059696380453: (["C": 1, "O": 2], "CO2"), 4799450059696052203:(["H": 1, "Cl": 1], "HCl"), 4799450044604533411: (["Na": 1, "Cl": 1], "NaCl")] //H2O CO2 HCl NaCl
    private static func hashReaction(_ currentHeap: PriorityQueue<String>) -> Int {
        var ans = ""
        while currentHeap.size() > 0 {
            ans = ans + currentHeap.pop()!
        }
        print(ans)
        return ans.hashValue
    }
    
    public static func detectReaction(currentHeap: PriorityQueue<String>) -> ([String: Int], String)? {
        if let reaction = supportedReactions[self.hashReaction(currentHeap)] {
            return reaction
        }
        return nil
    }
    
    public static func translateReaction(atomSet: Set<String>) -> String {
        if atomSet == Set(["H", "Cl"]) {
            return "HCl"
        }
        if atomSet == Set(["Na", "Cl"]) {
            return "NaCl"
        }
        if atomSet == Set(["H", "O", "O"]) {
            return "H2O"
        }
        if atomSet == Set(["C", "O", "O"]) {
            return "CO2"
        }
        return "Unknown"
    }
}

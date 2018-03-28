//
//  ReactionUtil.swift
//  ARAtomicLab
//
//  Created by Mike He on 2018/3/27.
//  Copyright © 2018 Deyuan He. All rights reserved.
//

import Foundation

class ReactionDetector {
    private static let supportedReactions: [Int:([String:Int], String)] = [4799450059693178067: (["H": 2, "O": 1], "H2O"), 4799450059696380453: (["C": 1, "O": 2], "CO2"), 4799450059696052203:(["H": 1, "Cl": 1], "HCl"), 4799450044604533411: (["Na": 1, "Cl": 1], "NaCl")] //H2O CO2 HCl NaCl
    private static let reactionDict: [(String, [String:Int])] = [
        ("HCl", ["H": 1, "Cl": 1]), ("H2O", ["H": 2, "O": 1]), ("CO2", ["C": 1, "O": 2]), ("NaCl", ["Na": 1, "Cl": 1]), ("H2", ["H": 2])
    ]
    private static let primaryAtomDict: [Set<String>:String] = [
        ["H", "O"]: "O", ["C", "O"]: "C", ["H"]: "H"
    ]
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
    
    private static func validForReaction(atomName: String, remainingCount: Int, reaction: [String:Int]) -> Bool {
        if reaction[atomName] != nil {
            return remainingCount >= reaction[atomName]!
        }
        return false
    }
    
    public static func detectReaction(_ atomAdded: [String:Int]) -> [([String: Int], String)] {
        var detectedReaction: [([String:Int], String)] = []
        var copyOfAtomAdded: [String:Int] = [:]
        for (atom, count) in atomAdded {
            copyOfAtomAdded[atom] = count
        }
        for (product, requirement) in reactionDict {
            var canReact = true
            for (atom, count) in requirement {
                if (copyOfAtomAdded[atom] == nil) {
                    canReact = false
                    break
                }
                if(copyOfAtomAdded[atom]! < count) {
                    canReact = false
                    break
                }
            }
            if canReact {
                while canReact {
                    detectedReaction.append((requirement, product))
                    for (atom, count) in requirement {
                        copyOfAtomAdded[atom]! -= count
                        if copyOfAtomAdded[atom]! < count {
                            canReact = false
                        }
                    }
                }
            }
        }
        print(detectedReaction)
        return detectedReaction
    }
    
    public static func getReactionPrimaryAtom(reactant: Set<String>) -> String? {
        return primaryAtomDict[reactant]
    }
}

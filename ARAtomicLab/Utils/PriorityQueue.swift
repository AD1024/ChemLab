//
//  PriorityQueue.swift
//  ARAtomicLab
//
//  Created by Mike He on 2018/3/27.
//  Copyright © 2018 Deyuan He. All rights reserved.
//
//  Depreacted class; the first reaction detecting algorithm uses this datastructure to maintain added atoms

class PriorityQueue<T> where T: Comparable {
    private var content: [T] = []
    private let lson = {(x: Int) in return (x << 1) + 1}
    private let rson = {(x: Int) in return (x << 1) + 2}
    private let fa = {(x: Int) in return (x - 1) >> 1}
    private var compare = {(x: T, y: T) in return x < y}
    
    init(){
        self.content = []
    }
    
    init(data: [T]) {
        self.content = data
    }
    
    init(compareFunc: @escaping (T, T) -> Bool) {
        self.compare = compareFunc
    }
    
    public func clone() -> PriorityQueue {
        return PriorityQueue(data: self.content)
    }
    
    public func insert(data: T) {
        content.append(data)
        self.pushUp(position: content.count - 1)
    }
    
    public func clear() {
        self.content.removeAll()
    }
    
    public func size() -> Int {
        return content.count
    }
    
    public func top() -> T {
        return content[0]
    }
    
    public func pop() -> T?{
        guard let last = content.last else {
            fatalError("Poping empty queue")
        }
        let ret = content[0]
        content[0] = last
        content.popLast()
        self.pushDown()
        return ret
    }
    
    private func pushUp(position: Int) {
        var i = position
        while(i != 0) {
            if compare(content[i], content[fa(i)]) {
                let t = content[i]
                content[i] = content[fa(i)]
                content[fa(i)] = t
                i = fa(i)
            } else { break }
        }
    }
    
    private func pushDown() {
        var i = 0
        while lson(i) < content.count {
            var k = i
            let l = lson(i)
            let r = rson(i)
            if compare(content[l], content[k]) {
                k = l
            }
            if r < content.count && compare(content[r], content[k]) {
                k = r
            }
            if k != i {
                let t = content[k]
                content[k] = content[i]
                content[i] = t
                i = k
            } else { break }
        }
    }
}


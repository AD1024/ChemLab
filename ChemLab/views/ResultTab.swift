//
//  ResultTab.swift
//  ChemLab
//
//  Created by Mike He on 2018/3/23.
//  Copyright © 2018年 Deyuan He. All rights reserved.
//

import Foundation
import UIKit


class ResultTab: UIView {
    @IBOutlet weak var carName: UILabel!
    @IBOutlet var contentView: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func initialize() {
        Bundle.main.loadNibNamed("ResultTab", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    }
}

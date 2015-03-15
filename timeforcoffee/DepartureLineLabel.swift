//
//  DepartureLineLabel.swift
//  timeforcoffee
//
//  Created by Jan Hug on 15.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit

class DepartureLineLabel: UILabel, UITableViewDelegate {
    
    let linesWithSymbol = ["ICN", "EN", "ICN", "TGV", "RX", "EC", "IC", "SC", "CNL", "ICE", "IR"]
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.clipsToBounds = true
        self.layer.cornerRadius = 4
        self.textAlignment = NSTextAlignment.Center
        self.baselineAdjustment = UIBaselineAdjustment.AlignCenters
        self.adjustsFontSizeToFitWidth = true
    }

    override func drawTextInRect(rect: CGRect) {
        return super.drawTextInRect(UIEdgeInsetsInsetRect(rect, UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)))
    }
    
    func setStyle(type: String, text: String, bg: String, fg: String) {
        self.text = text
        self.layer.borderWidth = 0
        
        if (contains(linesWithSymbol, text) == true) {
            self.font = UIFont(name: "trainsymbol", size: 20)
            self.textColor = UIColor.whiteColor()
            self.backgroundColor = UIColor.redColor()
        } else {
            self.font = UIFont(name: "HelveticaNeue-Bold", size: 18)
            self.textColor = UIColor(netHexString: fg)
            
            if (bg != "#ffffff") {
                self.backgroundColor = UIColor(netHexString: bg)
            } else {
                self.backgroundColor = UIColor.whiteColor()
                self.layer.borderColor = UIColor.lightGrayColor().CGColor
                self.layer.borderWidth = 0.5
            }
        }
    }
    
}

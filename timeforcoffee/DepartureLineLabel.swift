//
//  DepartureLineLabel.swift
//  timeforcoffee
//
//  Created by Jan Hug on 15.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import UIKit
import timeforcoffeeKit

class DepartureLineLabel: UILabel, UITableViewDelegate {
    
    let linesWithSymbol = ["ICN", "EN", "ICN", "TGV", "RX", "EC", "IC", "SC", "CNL", "ICE", "IR"]
    var fontsize:CGFloat       { get { return 18.0}}
    var cornerradius: CGFloat  { get { return 4.0}}
    var insets: CGFloat        { get { return 5.0}}
    var linelabelClickedCallback:(() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.clipsToBounds = true
        self.layer.cornerRadius = cornerradius
        self.textAlignment = NSTextAlignment.Center
        self.baselineAdjustment = UIBaselineAdjustment.AlignCenters
        self.adjustsFontSizeToFitWidth = true

        let tapGesture = UITapGestureRecognizer(target: self, action: "favoriteDepartureClicked")
        tapGesture.numberOfTapsRequired = 1
        self.addGestureRecognizer(tapGesture)
    }

    func favoriteDepartureClicked() {
        if let callback = linelabelClickedCallback {
            self.toggleIcon(callback)
        }
    }
    
    override func drawTextInRect(rect: CGRect) {
        return super.drawTextInRect(UIEdgeInsetsInsetRect(rect, UIEdgeInsets(top: insets, left: insets, bottom: insets, right: insets)))
    }
    
    func setStyle(style: String, departure: TFCDeparture) {
        self.text = departure.getLine()
        self.layer.borderWidth = 0
        if (linesWithSymbol.contains(departure.getLine()) == true) {
            self.font = UIFont(name: "trainsymbol", size: 20)
            self.textColor = UIColor.whiteColor()
            self.backgroundColor = UIColor.redColor()
        } else {
            self.font = UIFont(name: "HelveticaNeue-Bold", size: fontsize)
            if (departure.getLine() == "RE") {
                self.textColor = UIColor.redColor()
            } else {
                self.textColor = UIColor(netHexString: departure.colorFg!)
            }
            
            if (departure.colorBg != "#ffffff") {
                self.backgroundColor = UIColor(netHexString: departure.colorBg!)
            } else {
                if (departure.type == "train") {
                    self.backgroundColor = UIColor.whiteColor()
                    if (style == "normal") {
                        self.layer.borderColor = UIColor.lightGrayColor().CGColor
                        self.layer.borderWidth = 0.5
                    }
                } else {
                    self.backgroundColor = UIColor(netHexString: "#eeeeee")
                }
            }
        }
    }

    internal func toggleIcon(completion: (() -> Void)?) {

//        button.imageView?.alpha = 1.0
        self.transform = CGAffineTransformMakeScale(1, 1);

        UIView.animateWithDuration(0.2,
            delay: 0.0,
            options: UIViewAnimationOptions.CurveLinear,
            animations: {
                self.transform = CGAffineTransformMakeScale(0.1, 0.1);
                self.alpha = 0.0
                return
            }, completion: { (finished:Bool) in
                UIView.animateWithDuration(0.2,
                    animations: {
                        self.transform = CGAffineTransformMakeScale(1, 1);
                        self.alpha = 1.0
                        return
                    }, completion: { (finished:Bool) in
                        completion?()
                        return
                })
        })
        
    }
    

    
}

final class DepartureLineLabelForToday: DepartureLineLabel {
    override var fontsize:CGFloat      { get { return 10.0}}
    override var cornerradius: CGFloat { get { return 1.0}}
    override var insets: CGFloat       { get { return 1.0}}

}


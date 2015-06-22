//
//  StationRow.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import WatchKit
import timeforcoffeeKit

class StationRow: NSObject {
    
    @IBOutlet weak var destinationLabel: WKInterfaceLabel!
    @IBOutlet weak var depatureLabel: WKInterfaceLabel!
    @IBOutlet weak var minutesLabel: WKInterfaceLabel!
    
    @IBOutlet weak var numberLabel: WKInterfaceLabel!
    
    @IBOutlet weak var topGroup: WKInterfaceGroup!
    
    @IBOutlet weak var numberGroup: WKInterfaceGroup!

    func drawCell(departure: TFCDeparture, station: TFCStation ) {
        let to = departure.getDestination(station)
        let name = departure.getLine()                // doesn't work yet  with the font;(
        let helvetica = UIFont(name: "HelveticaNeue-Bold", size: 18.0)!
        var fontAttrs = [NSFontAttributeName : helvetica]
        var attrString = NSAttributedString(string: name, attributes: fontAttrs)
        if (departure.colorBg != nil) {
            if let group = self.numberGroup {
                group.setBackgroundColor(UIColor(netHexString:(departure.colorBg)!))
            }
            if let label = self.numberLabel {
                label.setTextColor(UIColor(netHexString:(departure.colorFg)!))
            }
        }
        if let numberLabel = self.numberLabel {
            numberLabel.setAttributedText(attrString)
        }
        if let label = self.destinationLabel {
            label.setText(to)
        }
        if let label = self.depatureLabel {
            let (departureTimeAttr, departureTimeString) = departure.getDepartureTime()
            if (departureTimeAttr != nil) {
                label.setAttributedText(departureTimeAttr)
            } else {
                label.setText(departureTimeString)
            }
        }
        if let label = self.minutesLabel {
            label.setText(departure.getMinutes())
        }
        if (topGroup != nil) {
            topGroup.setHidden(false)
        }
    }

    func setHidden() {
        topGroup.setHidden(true)
    }
}
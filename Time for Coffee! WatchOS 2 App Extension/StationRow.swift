//
//  StationRow.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import WatchKit
import timeforcoffeeKitWatch

class StationRow: NSObject {

    @IBOutlet weak var destinationLabel: WKInterfaceLabel?
    @IBOutlet weak var depatureLabel: WKInterfaceLabel?
    @IBOutlet weak var minutesLabel: WKInterfaceLabel?

    @IBOutlet weak var numberLabel: WKInterfaceLabel?

    @IBOutlet weak var topGroup: WKInterfaceGroup?

    @IBOutlet weak var numberGroup: WKInterfaceGroup?

    func drawCell(_ departure: TFCDeparture, station: TFCStation ) {
        let to = departure.getDestination(station)
        let name = departure.getLine()
        /* let helvetica = UIFont(name: "HelveticaNeue-Bold", size: 18.0)!
        var fontAttrs = [NSFontAttributeName : helvetica]
        var attrString = NSAttributedString(string: name, attributes: fontAttrs)*/
        if let group = self.numberGroup, let bg = departure.colorBg {
            group.setBackgroundColor(UIColor(netHexString:bg))
        }

        if let label = self.numberLabel, let fg = departure.colorFg {
            label.setTextColor(UIColor(netHexString:fg))
        }

        if let numberLabel = self.numberLabel {
            numberLabel.setText(name)
        }

        if let label = self.destinationLabel {
            label.setText(to)
        }

        let (departureTimeAttr, departureTimeString) = departure.getDepartureTime(false)
        if let label = self.depatureLabel {
            if (departureTimeAttr != nil) {
                label.setAttributedText(departureTimeAttr)
            } else {
                label.setText(departureTimeString)
            }
        }
        let minutes = departure.getMinutes()
        if let label = self.minutesLabel {
            label.setText(minutes)
        }
        if (topGroup != nil) {
            topGroup?.setHidden(false)
        }
    }

    func setHidden() {
        topGroup?.setHidden(true)
    }
}

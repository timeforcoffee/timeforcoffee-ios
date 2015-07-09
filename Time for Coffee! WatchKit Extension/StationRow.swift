//
//  StationRow.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import WatchKit
import timeforcoffeeWatchKit

class StationRow: NSObject {

    @IBOutlet weak var destinationLabel: WKInterfaceLabel!
    @IBOutlet weak var depatureLabel: WKInterfaceLabel!
    @IBOutlet weak var minutesLabel: WKInterfaceLabel!

    @IBOutlet weak var numberLabel: WKInterfaceLabel!
    
    @IBOutlet weak var topGroup: WKInterfaceGroup!
    
    @IBOutlet weak var numberGroup: WKInterfaceGroup!

    var to: String?
    var name: String?
    var departureTime: String?
    var minutes: String?
    var plannedDepartureTime: String?

    func drawCell(departure: TFCDeparture, station: TFCStation ) {
        let to = departure.getDestination(station)
        let name = departure.getLine()
        var redrawAll = false
        let plannedDepartureTime = departure.getScheduledTime()
        if (plannedDepartureTime != self.plannedDepartureTime) {
            self.plannedDepartureTime = plannedDepartureTime
            redrawAll = true
        }
        if (redrawAll || name != self.name) {
           /* let helvetica = UIFont(name: "HelveticaNeue-Bold", size: 18.0)!
            var fontAttrs = [NSFontAttributeName : helvetica]
            var attrString = NSAttributedString(string: name, attributes: fontAttrs)*/
            if (departure.colorBg != nil) {
                if let group = self.numberGroup {
                    group.setBackgroundColor(UIColor(netHexString:(departure.colorBg)!))
                }
                if let label = self.numberLabel {
                    label.setTextColor(UIColor(netHexString:(departure.colorFg)!))
                }
            }
            if let numberLabel = self.numberLabel {
                numberLabel.setText(name)
            }
            self.name = name
        }
        if (redrawAll || self.to != to) {
            if let label = self.destinationLabel {
                label.setText(to)
            }
            self.to = to
        }

        let (departureTimeAttr, departureTimeString) = departure.getDepartureTime(false)
        var departureTime: String?
        if (departureTimeAttr != nil) {
            departureTime = departureTimeAttr?.string
        } else {
            departureTime = departureTimeString
        }
        if (redrawAll ||  departureTime != self.departureTime) {
            if let label = self.depatureLabel {
                if (departureTimeAttr != nil) {
                    label.setAttributedText(departureTimeAttr)
                } else {
                    label.setText(departureTimeString)
                }
            }
            self.departureTime = departureTime
        }
        let minutes = departure.getMinutes()
        if (redrawAll || minutes != self.minutes) {
            if let label = self.minutesLabel {
                label.setText(minutes)
            }
            self.minutes = minutes
        }
        if (topGroup != nil) {
            topGroup.setHidden(false)
        }
    }

    func setHidden() {
        topGroup.setHidden(true)
    }
}
//
//  GlanceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation
import timeforcoffeeKit


class GlanceController: WKInterfaceController {
    
    @IBOutlet weak var minutesLabel: WKInterfaceLabel!
    @IBOutlet weak var destinationLabel: WKInterfaceLabel!
    @IBOutlet weak var numberGroup: WKInterfaceGroup!
    @IBOutlet weak var departureLabel: WKInterfaceLabel!
    @IBOutlet weak var numberLabel: WKInterfaceLabel!
    @IBOutlet weak var stationLabel: WKInterfaceLabel!

    @IBOutlet weak var stationsTable: WKInterfaceTable!

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        println("are we here??")
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        
        super.willActivate()
        func handleReply(stations: TFCStations?) {
            for (station) in stations! {
                station.updateDepartures(nil)
                let departures = station.getFilteredDepartures()
                if(departures?.count > 0) {
                    var i = 0
                    stationLabel.setText(station.getName(true))
                    stationsTable.setNumberOfRows(min(3,(departures?.count)!), withRowType: "station")
                    for (secondDepature) in departures! {
                        if let sr = stationsTable.rowControllerAtIndex(i) as! StationRow? {
                            let to = secondDepature.getDestination(station)
                            let name = secondDepature.getLine()                // doesn't work yet  with the font;(
                            let helvetica = UIFont(name: "HelveticaNeue-Bold", size: 18.0)!
                            var fontAttrs = [NSFontAttributeName : helvetica]
                            var attrString = NSAttributedString(string: name, attributes: fontAttrs)
                            if let numberLabel = sr.numberLabel {
                                numberLabel.setAttributedText(attrString)
                            }
                            if let label = sr.destinationLabel {
                                label.setText(to)
                            }
                            if let label = sr.depatureLabel {
                                let (departureTimeAttr, departureTimeString) = secondDepature.getDepartureTime()
                                if (departureTimeAttr != nil) {
                                    label.setAttributedText(departureTimeAttr)
                                } else {
                                    label.setText(departureTimeString)
                                }
                            }
                            if let label = sr.minutesLabel {
                                label.setText(secondDepature.getMinutes())
                            }
                            if (secondDepature.colorBg != nil) {
                                if let group = sr.numberGroup {
                                    group.setBackgroundColor(UIColor(netHexString:(secondDepature.colorBg)!))
                                }
                                if let label = sr.numberLabel {
                                    label.setTextColor(UIColor(netHexString:(secondDepature.colorFg)!))
                                }
                            }
                            i++
                            if (i >= 3) {
                                break;
                            }

                        }
                    }
                    break;
                }
            }
        }
        TFCWatchData.sharedInstance.getStations(handleReply, stopWithFavorites: true)

        stationLabel.setText("Loading ...");
        //stationsTable.setNumberOfRows(0, withRowType: "station")

     /*   minutesLabel.setText("")
        destinationLabel.setText("")
        departureLabel.setText("");
        numberLabel.setText("")
        numberLabel.setTextColor(UIColor.whiteColor())
        numberGroup.setBackgroundColor(UIColor.clearColor())*/
        
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
}

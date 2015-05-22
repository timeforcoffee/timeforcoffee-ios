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
                var dobreak = false
                if(departures?.count > 0) {
                    //todo only ask for one depature
                    if let firstDepature = departures?[0] {
                        let to = firstDepature.getDestination(station)

                        minutesLabel.setText("in \(firstDepature.getMinutes()!)")
                        destinationLabel.setText("To \(to)");
                        stationLabel.setText(station.getName(true))
                        let (departureTimeAttr, departureTimeString) = firstDepature.getDepartureTime()
                        if (departureTimeAttr != nil) {
                            departureLabel.setAttributedText(departureTimeAttr)
                        } else {
                            departureLabel.setText(departureTimeString)
                        }
                        numberLabel.setText(firstDepature.getLine())
                        numberLabel.setTextColor(UIColor(netHexString:(firstDepature.colorFg)!))
                        numberGroup.setBackgroundColor(UIColor(netHexString:(firstDepature.colorBg)!))
                        println("\(to)")
                        dobreak = true
                    }

                    if(departures?.count > 1) {

                        if let secondDepature = departures?[1] {
                            stationsTable.setNumberOfRows(1, withRowType: "station")
                           // for (deptstation) in departures2 {
                                if let sr = stationsTable.rowControllerAtIndex(0) as! StationRow? {
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
                                    
                                }                          
                          //  }
                        }
                    }
                    if (dobreak) {
                        break;
                    }
                }
            }
        }
        TFCWatchData.sharedInstance.getStations(handleReply, stopWithFavorites: true)

        minutesLabel.setText("")
        stationLabel.setText("Loading ...");
        destinationLabel.setText("")
        departureLabel.setText("");
        numberLabel.setText("")
        numberLabel.setTextColor(UIColor.whiteColor())
        numberGroup.setBackgroundColor(UIColor.clearColor())
        
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
}

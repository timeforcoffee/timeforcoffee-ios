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
    @IBOutlet weak var depatureLabel: WKInterfaceLabel!
    @IBOutlet weak var numberLabel: WKInterfaceLabel!
    
    var networkErrorMsg: String?
    
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
                    //todo only ask for one depature
                    if let firstDepature = departures?[0] {
                        let to = firstDepature.getDestination(station)

                        minutesLabel.setText(firstDepature.getMinutes())
                        destinationLabel.setText(to);
                        depatureLabel.setText(firstDepature.getTimeString());
                        numberLabel.setText(firstDepature.getLine())
                        numberLabel.setTextColor(UIColor(netHexString:(firstDepature.colorFg)!))
                        numberGroup.setBackgroundColor(UIColor(netHexString:(firstDepature.colorBg)!))
                        println("\(to)")
                        break
                    }
                }
            }
        }
      //  WKInterfaceController.openParentApplication(["module":"location"], handleReply)
        TFCWatchData.sharedInstance.getStations(handleReply, stopWithFavorites: true)

        minutesLabel.setText("6'")
        destinationLabel.setText("Röntgenstrasse");
        depatureLabel.setText("In 6' / 16:59");
        numberLabel.setText("12")
        numberLabel.setTextColor(UIColor.whiteColor())
        numberGroup.setBackgroundColor(UIColor.greenColor())
        
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
}

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

    @IBOutlet weak var infoGroup: WKInterfaceGroup!
    @IBOutlet weak var infoLabel: WKInterfaceLabel!


    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)

        // Configure interface objects here.
        self.stationsTable.setNumberOfRows(3, withRowType: "station")
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        
        super.willActivate()
        func handleReply(stations: TFCStations?) {
            infoGroup.setHidden(true)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                for (station) in stations! {
                    station.updateDepartures(nil)
                    let departures = station.getFilteredDepartures()
                    if(departures?.count > 0) {
                        var i = 0
                        self.stationLabel.setText(station.getName(true))
                        for (departure) in departures! {
                            if let sr = self.stationsTable.rowControllerAtIndex(i) as! StationRow? {
                                sr.drawCell(departure, station: station)
                                i++
                                if (i >= 3) {
                                    break;
                                }
                            }
                        }
                        if (i < 3) {
                            for j in i...2 {
                                if let sr = self.stationsTable.rowControllerAtIndex(j) as! StationRow? {
                                    sr.setHidden()
                                }
                            }
                        }
                        self.updateUserActivity("ch.opendata.timeforcoffee.station", userInfo: ["name": station.name, "st_id": station.st_id], webpageURL: nil)

                        break;
                    }
                }
            }
        }

        func errorReply(text: String) {
            stationLabel.setText("Time for Coffee!");
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }
        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: errorReply, stopWithFavorites: true)

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

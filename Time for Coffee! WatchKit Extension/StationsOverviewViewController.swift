//
//  StationsOverviewViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.04.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation
import timeforcoffeeKit

class StationsOverviewViewController: WKInterfaceController {

    @IBOutlet weak var stationsTable: WKInterfaceTable!

    @IBOutlet weak var infoGroup: WKInterfaceGroup!
    @IBOutlet weak var infoLabel: WKInterfaceLabel!


    var stations:[TFCStation] = []

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        NSLog("awake StationsOverviewViewController")
    }

    override func willActivate() {
        
        func handleReply(stations: TFCStations?) {
            if (stations == nil) {
                return
            }
            let maxStations = min(5, (stations?.count())! - 1)
            let ctxStations = stations?[0...maxStations]
            stationsTable.setNumberOfRows(ctxStations!.count, withRowType: "stations")
            var i = 0;
            self.stations = []
            for (station) in ctxStations! {
                self.stations.append(station)
                if let sr = stationsTable.rowControllerAtIndex(i) as! StationsRow? {
                    sr.stationLabel.setText(station.getName(true))
                }
                i++
            }
        }
        func errorReply(text: String) {
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }


        TFCWatchData.sharedInstance.getStations(handleReply, errorReply: errorReply, stopWithFavorites: false)
    }

    override func table(table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int) {
        NSLog("station \(stations[rowIndex].st_id)")
        self.dismissController()

        NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitSelectStation", object: nil, userInfo: ["index": rowIndex])

    }
}


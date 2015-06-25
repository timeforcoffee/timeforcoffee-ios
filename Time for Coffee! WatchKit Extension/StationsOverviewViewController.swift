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

    var numberOfRows: Int = 0

    @IBOutlet weak var stationsTable: WKInterfaceTable!

    @IBOutlet weak var infoGroup: WKInterfaceGroup!
    @IBOutlet weak var infoLabel: WKInterfaceLabel!

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        NSLog("awake StationsOverviewViewController")
    }

    override func willActivate() {
        self.setTitle("Nearby Stations")

        func handleReply(stations: TFCStations?) {
            if (stations == nil || stations?.count() == nil) {
                return
            }
            infoGroup.setHidden(true)
            let maxStations = min(5, (stations?.count())! - 1)
            let ctxStations = stations?[0...maxStations]
            if (self.numberOfRows != ctxStations!.count) {
                stationsTable.setNumberOfRows(ctxStations!.count, withRowType: "stations")
                self.numberOfRows = ctxStations!.count
            }
            var i = 0;
            for (station) in ctxStations! {
                if let sr = stationsTable.rowControllerAtIndex(i) as! StationsRow? {
                    sr.drawCell(station)
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
        let row = table.rowControllerAtIndex(rowIndex) as! StationsRow
        if let station = row.station {
            NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitSelectStation", object: nil, userInfo: ["st_id": station.st_id, "name": station.name])
        }

    }
}


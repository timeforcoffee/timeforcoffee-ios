//
//  StationsOverviewViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 13.04.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation

class StationsOverviewViewController: WKInterfaceController {

    var numberOfRows: Int = 0

    @IBOutlet weak var stationsTable: WKInterfaceTable!

    @IBOutlet weak var infoGroup: WKInterfaceGroup!
    @IBOutlet weak var infoLabel: WKInterfaceLabel!
    var activatedOnce = false
    var activated = false

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        DLog("awakeWithContext")
        stationsTable.setNumberOfRows(10, withRowType: "stations")
        self.numberOfRows = 10

    }

    override func willActivate() {
        super.willActivate()
        DLog("willActivate")
        self.activated = true
        if (activatedOnce) {
            getStations()
        }
    }

    override func didAppear() {
        DLog("didAppear")
        super.didAppear()
        if (!activatedOnce) {
            self.setTitle("Nearby Stations")
            self.addMenuItemWithItemIcon(WKMenuItemIcon.Resume, title: "Reload", action: #selector(StationsOverviewViewController.contextButtonReload))
            activatedOnce = true
            getStations()
        }
       // getStations()
   }

    override func willDisappear() {
        super.willDisappear()
    }

    override func didDeactivate() {
        DLog("didDeactivate")
        self.activated = false
        super.didDeactivate()
    }

    func contextButtonReload() {
        if let ud =  NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee") {
            ud.setValue(nil, forKey: "lastFirstStationId")
        }
        getStations()
        TFCDataStore.sharedInstance.requestAllDataFromPhone()
    }

    private func getStations() {
        func handleReply(stations: TFCStations?) {
            if (stations == nil || stations?.count() == nil) {
                return
            }
            if (self.activated) {
                WKInterfaceDevice.currentDevice().playHaptic(WKHapticType.Click)
                infoGroup.setHidden(true)

                if let stations = stations {
                    let ctxStations = Array(stations.prefix(10))
                    if (self.numberOfRows != ctxStations.count) {
                        stationsTable.setNumberOfRows(ctxStations.count, withRowType: "stations")
                        self.numberOfRows = ctxStations.count
                    }
                    var i = 0;
                    for (station) in ctxStations {
                        if let sr = stationsTable.rowControllerAtIndex(i) as? StationsRow {
                            sr.drawCell(station)
                        }
                        i += 1
                    }
                }
            }
        }
        func errorReply(text: String) {
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }

        watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: false)
    }

    override func table(table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int) {
        let row = table.rowControllerAtIndex(rowIndex) as? StationsRow
        if let station = row?.station {
            TFCWatchDataFetch.sharedInstance.fetchDepartureDataForStation(station)
            NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitSelectStation", object: nil, userInfo: ["st_id": station.st_id, "name": station.name])
        }
        
    }
}


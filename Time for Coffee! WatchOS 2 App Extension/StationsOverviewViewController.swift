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
    var appActive = false
    var appStarted = false
    var appeared = false

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        DLog("awakeWithContext")
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "appDidBecomeActive:",
            name: "TFCWatchkitDidBecomeActive",
            object: nil)
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "appDidResignActive:",
            name: "TFCWatchkitDidResignActive",
            object: nil)

        stationsTable.setNumberOfRows(6, withRowType: "stations")
        self.numberOfRows = 6

    }

    func appDidBecomeActive(notification: NSNotification) {
        DLog("appDidBecomeActive")
        if (!self.appActive) { //sometimes this is called twice...
            self.appActive = true
            // since this will be called before didAppear on the first run
            //  let didAppear handle it, otherwise, if we're coming from
            //  hibernation, do it here
            if (appStarted && appeared) {
                getStations()
            }
            if (!appStarted) {
                appStarted = true
            }
        }
    }

    func appDidResignActive(notification: NSNotification) {
        self.appActive = false
        DLog("appDidResignActive")
    }

    override func willActivate() {
        super.willActivate()
        DLog("willActivate")
    }

    override func didAppear() {
        DLog("didAppear")
        super.didAppear()
        self.appeared = true
        if (!activatedOnce) {
            self.setTitle("Nearby Stations")
            self.addMenuItemWithItemIcon(WKMenuItemIcon.Resume, title: "Reload", action: "contextButtonReload")
            activatedOnce = true
        }
        getStations()
   }

    override func willDisappear() {
        super.willDisappear()
        self.appeared = false
    }

    override func didDeactivate() {
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
            if (self.appeared && self.appActive) {
                 WKInterfaceDevice.currentDevice().playHaptic(WKHapticType.Click)
                 infoGroup.setHidden(true)
                 let maxStations = min(5, (stations?.count())! - 1)
                 let ctxStations = stations?[0...maxStations]
                 if (self.numberOfRows != ctxStations!.count) {
                     stationsTable.setNumberOfRows(ctxStations!.count, withRowType: "stations")
                     self.numberOfRows = ctxStations!.count
                  }
                 var i = 0;
                 if let ctxStations = ctxStations {
                     for (station) in ctxStations {
                         if let sr = stationsTable.rowControllerAtIndex(i) as! StationsRow? {
                             sr.drawCell(station)
                         }
                         i++
                     }
                     if let stations = stations {
                         watchdata.updateComplication(stations)
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
        let row = table.rowControllerAtIndex(rowIndex) as! StationsRow
        if let station = row.station {
            NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitSelectStation", object: nil, userInfo: ["st_id": station.st_id, "name": station.name])
        }
        
    }
}


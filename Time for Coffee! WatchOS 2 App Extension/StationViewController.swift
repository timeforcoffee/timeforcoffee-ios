//
//  InterfaceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation

class StationViewController: WKInterfaceController, TFCDeparturesUpdatedProtocol {
    @IBOutlet weak var stationsTable: WKInterfaceTable!
    var station: TFCStation?
    var lastShownStationId: String?
    var pageNumber: Int?
    var numberOfRows: Int = 0
    var initTable = false
    var active = false
    var appeared = false
    var userActivity: [String:String]?

    @IBOutlet weak var infoGroup: WKInterfaceGroup!
    @IBOutlet weak var infoLabel: WKInterfaceLabel!

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()

    override init () {
        super.init()
        NSLog("init page")

    }
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        NSLog("awake page")
        if (context == nil) {
            stationsTable.setNumberOfRows(10, withRowType: "station")
            self.numberOfRows = 10
            NSNotificationCenter.defaultCenter().addObserver(
                self,
                selector: "selectStation:",
                name: "TFCWatchkitSelectStation",
                object: nil)
            getStation()

        } else {
            let c = context as! TFCPageContext
            self.station = c.station
            self.pageNumber = c.pageNumber
        }

    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "TFCWatchkitSelectStation", object: nil)
    }

    private func getStation() {
        func handleReply(stations: TFCStations?) {
            if (stations == nil || stations?.count() == nil) {
                return
            }
            infoGroup.setHidden(true)
            if let station = stations?[0] {
                var station2 = station
                if let uA = self.userActivity {
                    station2 = TFCStation.initWithCache(uA["name"]!, id: uA["st_id"]!, coord: nil)
                    self.userActivity = nil
                }
                if (self.station?.st_id != station2.st_id) {
                    self.initTable = true
                }
                self.station = station2
                self.setStationValues()
                watchdata.updateComplication(stations!)
            }
        }
        func errorReply(text: String) {
            NSLog("errorReply")
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }

        watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: true)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        NSLog("willActivate page")
        self.active = true
        if (self.appeared) {
            setStationValues()
        }
    }

    override func didAppear() {
        self.appeared = true
        setStationValues()
    }

    override func willDisappear() {
        self.appeared = false
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        NSLog("StationView: didDeactivate")

        super.didDeactivate()
        self.active = false
    }

    private func setStationValues() {
        if (station == nil) {
            // infoGroup.setHidden(false)
            getStation()
            return
        }

        if let title = station?.getName(true) {
            self.setTitle(title)
            self.lastShownStationId = station?.st_id
        }

        if (self.lastShownStationId != station?.st_id || self.initTable || !(station?.getDepartures()?.count > 0)) {
            infoGroup.setHidden(false)
            infoLabel.setText("Loading ...")
            stationsTable.setNumberOfRows(10, withRowType: "station")
            self.numberOfRows = 10
        }
        self.initTable = false
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.station?.updateDepartures(self)
            self.displayDepartures(self.station)
            self.clearAllMenuItems()
            if (self.station?.isFavorite() == true) {
                self.addMenuItemWithItemIcon(WKMenuItemIcon.Decline, title: "Unfavorite Station", action: "contextButtonFavorite")
            } else {
                self.addMenuItemWithItemIcon(WKMenuItemIcon.Add, title: "Favorite Station", action: "contextButtonFavorite")
            }

            self.addMenuItemWithItemIcon(WKMenuItemIcon.Resume, title: "Reload", action: "contextButtonReload")
            self.addMenuItemWithItemIcon(WKMenuItemIcon.Maybe, title: "Map", action: Selector("contextButtonMap"))
            if let station2 = self.station {
            self.updateUserActivity("ch.opendata.timeforcoffee.station", userInfo: station2.getAsDict(), webpageURL: station2.getWebLink())
            }
        }
    }

    func selectStation(notification: NSNotification) {
        if (notification.userInfo == nil) {
            self.getStation()
        } else {
            let uI:[String:String]? = notification.userInfo as? [String:String]
            if let st_id = uI?["st_id"] {
                if (self.station == nil) {
                    self.station = TFCStation.initWithCache((uI?["name"])! , id: st_id, coord: nil)
                    self.initTable = true
                } else if let self_st_id = self.station?.st_id {
                    if (self_st_id != st_id) {
                        self.station = TFCStation.initWithCache((uI?["name"])! , id: st_id, coord: nil)
                        self.initTable = true
                    }
                }
            }
            if (self.active) {
                self.setStationValues()
            }
        }
        self.becomeCurrentPage()
    }

    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        if (self.appeared && self.active) {
            let displayed = self.displayDepartures(forStation)
            if (displayed) {
                WKInterfaceDevice.currentDevice().playHaptic(WKHapticType.Click)
                NSLog("played haptic in Stations \(self.appeared)")
            }
        }
    }

    private func displayDepartures(station: TFCStation?) -> Bool {
        if (station == nil) {
            return false
        }
        var returnValue = false
        let departures = station?.getFilteredDepartures(10)
        var i = 0;
        if let departures2 = departures {
            if (self.numberOfRows != departures2.count || self.initTable == true) {
                stationsTable.setNumberOfRows(departures2.count, withRowType: "station")
                self.numberOfRows = departures2.count
                self.initTable = false
            }
            infoGroup.setHidden(true)
            for (deptstation) in departures2 {
                if (station?.st_id != self.station?.st_id) {
                    continue
                }
                returnValue = true
                if let sr = stationsTable.rowControllerAtIndex(i) as! StationRow? {
                    sr.drawCell(deptstation, station: station!)
                }
                i++
            }
        }
        return returnValue
    }

    func departuresStillCached(context: Any?, forStation: TFCStation?) {
        departuresUpdated(nil, context: context, forStation: forStation)
    }

    func contextButtonReload() {
        func reload(stations: TFCStations?) {
            setStationValues()
        }
        func errorReply(text: String) {
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }

        TFCDataStore.sharedInstance.requestAllDataFromPhone()
        NSLog("send requestAllDataFromPhone")
        watchdata.getStations(reload, errorReply: errorReply, stopWithFavorites: false)
    }

    func contextButtonMap() {
        self.presentControllerWithName("MapPage", context: self.station)
    }

    func contextButtonFavorite() {
        self.station?.toggleFavorite()
        setStationValues()
    }

    override func handleUserActivity(userInfo: [NSObject : AnyObject]!) {
        if (userInfo.keys.first == "CLKLaunchedTimelineEntryDateKey") {
            NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitSelectStation", object: nil, userInfo: nil)
        } else {
            let uI:[String:String]? = userInfo as? [String:String]
            NSLog("handleUserActivity StationViewController")
            NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitSelectStation", object: nil, userInfo: uI)
        }
    }
    
}

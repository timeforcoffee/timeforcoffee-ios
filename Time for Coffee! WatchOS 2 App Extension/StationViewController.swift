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
    var activated:Bool = false
    var lastShownStationId: String? {
        didSet {
            TFCWatchDataFetch.sharedInstance.setLastViewedStation(station)
        }
    }
    var pageNumber: Int?
    var numberOfRows: Int = 0
    var initTable = false
    var userActivity: [String:String]?

    @IBOutlet weak var infoGroup: WKInterfaceGroup!
    @IBOutlet weak var infoLabel: WKInterfaceLabel!

    lazy var watchdata: TFCWatchData = {
        return TFCWatchData()
    }()

    override init () {
        super.init()
        DLog("init page")

    }
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        DLog("awakeWithContext")
        if (context == nil) {
            stationsTable.setNumberOfRows(5, withRowType: "station")
            self.numberOfRows = 5
            NSNotificationCenter.defaultCenter().addObserver(
                self,
                selector: #selector(StationViewController.selectStation(_:)),
                name: "TFCWatchkitSelectStation",
                object: nil)
            NSNotificationCenter.defaultCenter().addObserver(
                self,
                selector: #selector(StationViewController.updateCurrentStation(_:)),
                name: "TFCWatchkitUpdateCurrentStation",
                object: nil)
        } else {
            if let c = context as? TFCPageContext {
                self.station = c.station
                self.pageNumber = c.pageNumber
            }
        }

    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "TFCWatchkitSelectStation", object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "TFCWatchkitUpdateCurrentStation", object: nil)
    }

    private func getStation() {
        func handleReply(stations: TFCStations?) {
            if (stations == nil || stations?.count() == nil) {
                return
            }
            infoGroup.setHidden(true)
            if let station = stations?.getStation(0) {
                var station2:TFCStation? = station
                if let uA = self.userActivity, name = uA["name"], st_id = uA["st_id"]{
                    station2 = TFCStation.initWithCacheId(st_id, name: name)
                    self.userActivity = nil
                }
                if (self.station?.st_id != station2?.st_id) {
                    self.initTable = true
                }
                self.station = station2
                DLog("getStation", toFile: true)
                self.setStationValues()
            }
        }
        func errorReply(text: String) {
            DLog("errorReply")
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }

        watchdata.getStations(handleReply, errorReply: errorReply, stopWithFavorites: true)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        DLog("willActivate", toFile: true)
        var doSetValues = true
        if #available(watchOSApplicationExtension 3.0, *) {
            let state = WKExtension.sharedExtension().applicationState
            if (state == .Inactive) {
                DLog("WKExtension = Inactive", toFile: true)
                doSetValues = false
            } else if (state == .Active) {
                DLog("WKExtension = Active", toFile: true)
            } else {
                DLog("WKExtension = Background", toFile: true)
            }
        }
        if (doSetValues) {
            setStationValues()
        }
        self.activated = true
    }

    override func didAppear() {
        DLog("didAppear", toFile: true)
        super.didAppear()
    }

    override func willDisappear() {
        DLog("willDisappear")
        super.willDisappear()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        DLog("didDeactivate", toFile: true)
        self.activated = false
        super.didDeactivate()
    }

    private func setStationValues() {
        let isInBackground:Bool

        if #available(watchOSApplicationExtension 3.0, *) {
            isInBackground = (WKExtension.sharedExtension().applicationState == .Background)
        } else {
            isInBackground = false
        }
        DLog("setStationValues. isInBackground: \(isInBackground)", toFile: true)

        if (station == nil) {
            // infoGroup.setHidden(false)
            if let laststation = TFCWatchDataFetch.sharedInstance.getLastViewedStation() {
                self.station = laststation
                self.lastShownStationId = laststation.st_id
            } else {
                if (isInBackground) {
                    return
                }
                getStation()
                return
            }
        }

        var drawAsNewStation = false

        let isNewStation = (self.lastShownStationId != station?.st_id)
        DLog("\(self.lastShownStationId) != \(station?.st_id) || \(self.initTable) || \(station?.getDepartures()?.count)", toFile: true)
        if (!isInBackground && (isNewStation || self.initTable || !(station?.getDepartures()?.count > 0))) {
            DLog("Load new station", toFile: true)
            drawAsNewStation = true
            infoGroup.setHidden(false)
            infoLabel.setText("Loading ...")
            stationsTable.setNumberOfRows(5, withRowType: "station")
            self.numberOfRows = 5
        }
        if let title = station?.getName(true) {
            self.setTitle(title)
            self.lastShownStationId = station?.st_id
        }
        self.initTable = false
        self.station?.removeObsoleteDepartures()
        self.displayDepartures(self.station)
        if drawAsNewStation {
            self.clearAllMenuItems()
            if (self.station?.isFavorite() == true) {
                self.addMenuItemWithItemIcon(WKMenuItemIcon.Decline, title: "Unfavorite Station", action: #selector(StationViewController.contextButtonFavorite))
            } else {
                self.addMenuItemWithItemIcon(WKMenuItemIcon.Add, title: "Favorite Station", action: #selector(StationViewController.contextButtonFavorite))
            }
            self.addMenuItemWithItemIcon(WKMenuItemIcon.Resume, title: "Reload", action: #selector(StationViewController.contextButtonReload))
            self.addMenuItemWithItemIcon(WKMenuItemIcon.Maybe, title: "Map", action: #selector(StationViewController.contextButtonMap))
        }
        if (!isInBackground) {
            if let station2 = self.station {
                self.updateUserActivity("ch.opendata.timeforcoffee.station", userInfo: station2.getAsDict(), webpageURL: station2.getWebLink())
            }
        }
    }


    func updateCurrentStation(notification: NSNotification) {
        DLog("updateCurrentStation", toFile: true)
        if (self.activated) {
            dispatch_async(dispatch_get_main_queue()) {
                // reload station from cache
                DLog("count before for \(self.station?.name): \(self.station?.getDepartures()?.count)", toFile: true)
                if let st_id = self.station?.st_id {
                    self.station = TFCStation.initWithCacheId(st_id)
                }
                DLog("count after for \(self.station?.name): \(self.station?.getDepartures()?.count)", toFile: true)
                self.departuresUpdated(nil, context: nil, forStation: self.station)
            }
        }
    }

    func selectStation(notification: NSNotification) {
        DLog("selectStation", toFile: true)
        if (notification.userInfo == nil) {
            station = nil
        } else {
            let uI:[String:String]? = notification.userInfo as? [String:String]
            if let st_id = uI?["st_id"] {
                if (self.station == nil) {
                    self.station = TFCStation.initWithCacheId(st_id)
                    self.initTable = true
                } else if let self_st_id = self.station?.st_id {
                    if (self_st_id != st_id) {
                        self.station = TFCStation.initWithCacheId(st_id)
                        self.initTable = true
                    }
                }
            }
        }

        self.becomeCurrentPage()
    }

    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        DLog("departuresUpdated for \(forStation?.name)", toFile: true)
        let displayed = self.displayDepartures(forStation)
        let context2:[String:String]? = context as? [String:String]
        if (displayed && context2?["cached"] != "true") {
            if (self.activated) {
                WKInterfaceDevice.currentDevice().playHaptic(WKHapticType.Click)
                DLog("played haptic in Stations ")
            }
        }

    }

    private func displayDepartures(station: TFCStation?) -> Bool {
        DLog("displayDepartures for \(station?.name)", toFile: true)
        if (station == nil) {
            DLog("end displayDepartures. returnValue: station == nil", toFile: true)

            return false
        }
        var returnValue = false
        let departures = station?.getFilteredDepartures(5)
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
                if let sr = stationsTable.rowControllerAtIndex(i) as? StationRow, station = station {
                    sr.drawCell(deptstation, station: station)
                }
                i += 1
            }
        }
        DLog("end displayDepartures. returnValue: \(returnValue)", toFile: true)
        return returnValue
    }

    func departuresStillCached(context: Any?, forStation: TFCStation?) {
        DLog("departuresStillCached", toFile: true)
        departuresUpdated(nil, context: ["cached": "true"], forStation: forStation)
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
        DLog("send requestAllDataFromPhone")
        watchdata.getStations(reload, errorReply: errorReply, stopWithFavorites: false)
    }

    func contextButtonMap() {
        self.presentControllerWithName("MapPage", context: self.station)
    }

    func contextButtonFavorite() {
        self.station?.toggleFavorite()
        setStationValues()
    }
}

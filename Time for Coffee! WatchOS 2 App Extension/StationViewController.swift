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
    @IBOutlet weak var stationsTable: WKInterfaceTable?
    var station: TFCStation?
    var activated:Bool = false
    var lastShownStationId: String? {
        didSet {
            TFCWatchDataFetch.sharedInstance.setLastViewedStation(station)
        }
    }
    var pageNumber: Int?
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

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        DLog("awakeWithContext")
        if (context == nil) {
            stationsTable?.setNumberOfRows(2, withRowType: "station")
            DLog("setNumberOfRows: 2")
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(StationViewController.selectStation(_:)),
                name: NSNotification.Name(rawValue: "TFCWatchkitSelectStation"),
                object: nil)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(StationViewController.updateCurrentStation(_:)),
                name: NSNotification.Name(rawValue: "TFCWatchkitUpdateCurrentStation"),
                object: nil)
        } else {
            if let c = context as? TFCPageContext {
                self.station = c.station
                self.pageNumber = c.pageNumber
            }
        }

    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "TFCWatchkitSelectStation"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "TFCWatchkitUpdateCurrentStation"), object: nil)
    }

    fileprivate func getStation() {
        func handleReply(_ stations: TFCStations?) {
            if (stations == nil || stations?.count() == nil) {
                return
            }
            infoGroup.setHidden(true)
            if let station = stations?.getStation(0) {
                var station2:TFCStation? = station
                if let uA = self.userActivity, let name = uA["name"], let st_id = uA["st_id"]{
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
        func errorReply(_ text: String) {
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
        let state = WKExtension.shared().applicationState
        if (state == .inactive) {
            DLog("WKExtension = Inactive", toFile: true)
        } else if (state == .active) {
            DLog("WKExtension = Active", toFile: true)
        } else {
            DLog("WKExtension = Background", toFile: true)

        }
        setStationValues()
        self.activated = true
        if (state != .background) {
            TFCWatchDataFetch.sharedInstance.fetchDepartureData()
        }

    }

    override func didAppear() {
        DLog("didAppear", toFile: true)
        let state = WKExtension.shared().applicationState
        if (state == .inactive) {
            DLog("WKExtension = Inactive", toFile: true)
        } else if (state == .active) {
            DLog("WKExtension = Active", toFile: true)
        } else {
            DLog("WKExtension = Background", toFile: true)
        }
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

    fileprivate func setStationValues() {
        let isInBackground:Bool

        isInBackground = (WKExtension.shared().applicationState == .background)
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
        let departuresCount = station?.getDepartures()?.count
        DLog("\(String(describing: self.lastShownStationId)) != \(String(describing: station?.st_id)) || \(self.initTable) || \(String(describing: departuresCount))", toFile: true)
        if (!isInBackground && (isNewStation || self.initTable || !(departuresCount != nil && departuresCount! > 0))) {
            DLog("Load new station", toFile: true)
            drawAsNewStation = true
            infoGroup.setHidden(false)
            infoLabel.setText("Loading ...")
            stationsTable?.setHidden(true)
        }
        if let title = station?.getName(true) {
            self.setTitle(title)
            self.lastShownStationId = station?.st_id
        }
        self.initTable = false
        let _ = self.station?.removeObsoleteDepartures()
        let _ = self.displayDepartures(self.station)
        if drawAsNewStation {
            self.clearAllMenuItems()
            if (self.station?.isFavorite() == true) {
                self.addMenuItem(with: WKMenuItemIcon.decline, title: "Unfavorite Station", action: #selector(StationViewController.contextButtonFavorite))
            } else {
                self.addMenuItem(with: WKMenuItemIcon.add, title: "Favorite Station", action: #selector(StationViewController.contextButtonFavorite))
            }
            self.addMenuItem(with: WKMenuItemIcon.resume, title: "Reload", action: #selector(StationViewController.contextButtonReload))
            self.addMenuItem(with: WKMenuItemIcon.maybe, title: "Map", action: #selector(StationViewController.contextButtonMap))
        }
        if (!isInBackground) {
            if let station2 = self.station {
                self.updateUserActivity("ch.opendata.timeforcoffee.station", userInfo: station2.getAsDict(), webpageURL: station2.getWebLink())
            }
        }
    }


    @objc func updateCurrentStation(_ notification: Notification) {
        DLog("updateCurrentStation", toFile: true)
        if (self.activated) {
            DispatchQueue.main.async {
                // reload station from cache
             //   DLog("count before for \(String(describing: self.station?.name)): \(String(describing: self.station?.getDepartures()?.count))", toFile: true)
                if let st_id = self.station?.st_id {
                    self.station = TFCStation.initWithCacheId(st_id)
                }
             //   DLog("count after for \(String(describing: self.station?.name)): \(String(describing: self.station?.getDepartures()?.count))", toFile: true)
                self.departuresUpdated(nil, context: nil, forStation: self.station)
            }
        }
    }

    @objc func selectStation(_ notification: Notification) {
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
        if let station = self.station {
            DLog("call fetchDepartureDataForStation")
            TFCWatchDataFetch.sharedInstance.fetchDepartureDataForStation(station)
        }

    }

    func departuresUpdated(_ error: Error?, context: Any?, forStation: TFCStation?) {
        DLog("departuresUpdated for \(String(describing: forStation?.name))", toFile: true)
        let displayed = self.displayDepartures(forStation)
        let context2:[String:String]? = context as? [String:String]
        if (displayed && context2?["cached"] != "true") {
            if (self.activated) {
                WKInterfaceDevice.current().play(WKHapticType.click)
               // DLog("played haptic in Stations ")
            }
        }

    }

    fileprivate func displayDepartures(_ station: TFCStation?) -> Bool {
        DLog("displayDepartures for \(String(describing: station?.name))", toFile: true)
        if (station == nil) {
            DLog("end displayDepartures. returnValue: station == nil", toFile: true)

            return false
        }
        var returnValue = false
        let departures = station?.getFilteredDepartures(nil, fallbackToAll: true)?.prefix(10)
        var i = 0;
        if let departures2 = departures {
            if (self.stationsTable?.numberOfRows != departures2.count || self.initTable == true) {
                self.adjustTableSize(newCount: departures2.count)
                self.initTable = false
            }
            infoGroup.setHidden(true)
            stationsTable?.setHidden(false)
            for (deptstation) in departures2 {
                if (station?.st_id != self.station?.st_id) {
                    continue
                }
                returnValue = true
                if let sT = stationsTable, i < sT.numberOfRows {
                    if let sr = stationsTable?.rowController(at: i) as? StationRow, let station = station {
                        sr.drawCell(deptstation, station: station)
                    }
                }
                i += 1
            }
        }
        DLog("end displayDepartures. returnValue: \(returnValue)", toFile: true)
        return returnValue
    }

    fileprivate func adjustTableSize(newCount: Int) {
        DLog("adjustTableSize to: \(newCount)")
        if let oldCount = stationsTable?.numberOfRows {
            let delta = newCount - oldCount
            if delta > 0 {
                let rowChangeRange = Range(uncheckedBounds: (lower: oldCount, upper: newCount))
                let rowChangeIndexSet = IndexSet(integersIn:rowChangeRange)
                stationsTable?.insertRows(
                    at: rowChangeIndexSet,
                    withRowType: "station"
                ) }
            else if delta < 0 {
                let rowChangeRange = Range(uncheckedBounds: (lower: newCount, upper: oldCount))
                let rowChangeIndexSet = IndexSet(integersIn:rowChangeRange)

                stationsTable?.removeRows(at: rowChangeIndexSet)
            }

        } else {
            stationsTable?.setNumberOfRows(newCount, withRowType: "station")
        }
    }


    func departuresStillCached(_ context: Any?, forStation: TFCStation?) {
        DLog("departuresStillCached", toFile: true)
        departuresUpdated(nil, context: ["cached": "true"], forStation: forStation)
    }

    @objc func contextButtonReload() {
        func reload(_ stations: TFCStations?) {
            setStationValues()
        }
        func errorReply(_ text: String) {
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }

        TFCDataStore.sharedInstance.requestAllDataFromPhone()
        DLog("send requestAllDataFromPhone")
        watchdata.getStations(reload, errorReply: errorReply, stopWithFavorites: false)
    }

    @objc func contextButtonMap() {
        self.presentController(withName: "MapPage", context: self.station)
    }

    @objc func contextButtonFavorite() {
        self.station?.toggleFavorite()
        setStationValues()
    }
}

//
//  InterfaceController.swift
//  Time for Coffee! WatchKit Extension
//
//  Created by Christian Stocker on 02.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import WatchKit
import Foundation
import timeforcoffeeKit

class StationViewController: WKInterfaceController, TFCDeparturesUpdatedProtocol {
    @IBOutlet weak var stationsTable: WKInterfaceTable!
    var station: TFCStation?
    var pageNumber: Int?
    var numberOfRows: Int = 0
    var initTable = false
    @IBOutlet weak var infoGroup: WKInterfaceGroup!
    @IBOutlet weak var infoLabel: WKInterfaceLabel!
    
    override init () {
        super.init()
        println("init page")
        
    }
    override func awakeWithContext(context: AnyObject?) {
      super.awakeWithContext(context)
        NSLog("awake page")
        let c = context as! TFCPageContext
        self.station = c.station
        self.pageNumber = c.pageNumber

        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "selectStation:",
            name: "TFCWatchkitSelectStation",
            object: nil)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        NSLog("willActivate page")
        setStationValues()
    }

    private func setStationValues() {
        self.setTitle(station?.getName(true))
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
        }
    }

    func selectStation(notification: NSNotification) {
        let uI:[String:String]? = notification.userInfo as? [String:String]
        if let st_id = uI?["st_id"] {
            if let self_st_id = self.station?.st_id {
                if (self_st_id != st_id) {
                    self.station = TFCStation.initWithCache((uI?["name"])! , id: st_id, coord: nil)
                    self.initTable = true
                }
            }
        }
        self.becomeCurrentPage()
    }

    func departuresUpdated(error: NSError?, context: Any?, forStation: TFCStation?) {
        self.displayDepartures(forStation)
    }

    private func displayDepartures(station: TFCStation?) {
        if (station == nil) {
            return
        }
        let departures = station?.getFilteredDepartures(10)
        var i = 0;
        if let departures2 = departures {
            if (self.numberOfRows != departures2.count || self.initTable == true) {
                stationsTable.setNumberOfRows(departures2.count, withRowType: "station")
                self.numberOfRows = departures2.count
                self.initTable = false
            }
            for (deptstation) in departures2 {
                if let sr = stationsTable.rowControllerAtIndex(i) as! StationRow? {
                    sr.drawCell(deptstation, station: station!)
                }
                i++
            }
        }
    }

    func departuresStillCached(context: Any?, forStation: TFCStation?) {
        departuresUpdated(nil, context: context, forStation: forStation)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func contextButtonReload() {
        func reload(stations: TFCStations?) {
            infoGroup.setHidden(true)
            setStationValues()
        }
        func errorReply(text: String) {
            infoGroup.setHidden(false)
            infoLabel.setText(text)
        }

        TFCWatchData.sharedInstance.getStations(reload, errorReply: errorReply, stopWithFavorites: false)
    }

    func contextButtonMap() {
        self.presentControllerWithName("MapPage", context: self.station)
    }

    func contextButtonFavorite() {
        self.station?.toggleFavorite()
        setStationValues()
    }
}

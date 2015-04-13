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
        let watchdata = TFCWatchData.sharedInstance
        if let stationFromWatchData = watchdata.stations?.getStation(self.pageNumber!) {
            if (stationFromWatchData.st_id != self.station?.st_id) {
                self.station = stationFromWatchData
            }
        }
        self.setTitle(station?.getName(true))
        station?.updateDepartures(self)
        self.displayDepartures(station)

    }
    func selectStation(notification: NSNotification) {
        let uI:[String:Int]? = notification.userInfo as? [String:Int]
        if let st_id = uI?["index"] {
            if (st_id == self.pageNumber) {
                setStationValues()
                self.becomeCurrentPage()
            }
        }
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
            stationsTable.setNumberOfRows(departures2.count, withRowType: "station")
            for (deptstation) in departures2 {
                if let sr = stationsTable.rowControllerAtIndex(i) as! StationRow? {
                    let to = deptstation.getDestination(station!)
                    let name = deptstation.getLine()                // doesn't work yet  with the font;(
                    let helvetica = UIFont(name: "HelveticaNeue-Bold", size: 18.0)!
                    var fontAttrs = [NSFontAttributeName : helvetica]
                    var attrString = NSAttributedString(string: name, attributes: fontAttrs)
                    if let numberLabel = sr.numberLabel {
                        numberLabel.setAttributedText(attrString)
                    }
                    if let label = sr.destinationLabel {
                        label.setText(to)
                    }
                    if let label = sr.depatureLabel {
                        label.setText(deptstation.getTimeString())
                    }
                    if let label = sr.minutesLabel {
                        label.setText(deptstation.getMinutes())
                    }
                    if (deptstation.colorBg != nil) {
                        if let group = sr.numberGroup {
                            group.setBackgroundColor(UIColor(netHexString:(deptstation.colorBg)!))
                        }
                        if let label = sr.numberLabel {
                            label.setTextColor(UIColor(netHexString:(deptstation.colorFg)!))
                        }
                    }

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
    @IBAction func contextButtionStations() {
        self.presentControllerWithName("StationsOverviewPage", context: nil)
    }
    @IBAction func contextButtonReload() {
        func reload(stations: TFCStations?) {
            setStationValues()
        }
        TFCWatchData.sharedInstance.getStations(reload, stopWithFavorites: false)
        /*NSNotificationCenter.defaultCenter().postNotificationName("TFCWatchkitReloadPages", object: nil) */
    }
}

//
//  TFCVisits.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 22.10.15.
//  Copyright © 2015 opendata.ch. All rights reserved.
//

import Foundation
import timeforcoffeeKit
import CoreLocation
import WatchConnectivity

class TFCVisits: NSObject, TFCLocationManagerDelegate, TFCStationsUpdatedProtocol {
    private lazy var locManager: TFCLocationManager? = { return TFCLocationManager(delegate: self)}()

    lazy var stations: TFCStations = {return TFCStations(delegate: self)}()
    var callback: ((text: String) -> ())? = nil

    override init() {

        super.init()
        if (willReceive()) {
            locManager?.startReceivingVisits()
        } else {
            locManager?.stopReceivingVisits()
        }
    }

    convenience init(callback: ((text: String) -> ())) {
        self.init()
        self.callback = callback
    }

    internal func willReceive() -> Bool {
        if #available(iOS 9, *) {
            if (WCSession.isSupported()) {
                let wcsession = WCSession.defaultSession()
                if (wcsession.complicationEnabled == true) {
                    return true
                }
            }
        }
        return false
    }

    func locationDenied(manager: CLLocationManager, err: NSError) {
    }

    func locationFixed(coord: CLLocation?) {
    }

    func locationStillTrying(manager: CLLocationManager, err: NSError) {
    }

    func locationVisit(coord: CLLocationCoordinate2D, date: NSDate, arrival: Bool) -> Bool {
        DLog("TFCVisits locationVisit updateStations")
        self.stations.updateStations()
        if let callback = self.callback {
            callback(text: "Visit. Date: \(date) arrival: \(arrival) lat: \(coord.latitude.roundToPlaces(3)), lng: \(coord.longitude.roundToPlaces(3)) ")
        }
        return true
    }

    func stationsUpdated(error: String?, favoritesOnly: Bool, context: Any?) {
        if (favoritesOnly == false) { // wait for all stations, should be fast anyway with the DB lookup nowadays (in Switzerland at least) and doesn't matter in this case how fast it is
            DLog("TFCVisits stationsUpdate")
            if self.stations.count() > 0 {
                DLog("first station is \(self.stations[0].name)", toFile: true)
                if let callback = self.callback {
                    callback(text:"first station is \(self.stations[0].name)")
                }
                TFCDataStore.sharedInstance.sendComplicationUpdate(self.stations[0])
            }
        }

    }
}


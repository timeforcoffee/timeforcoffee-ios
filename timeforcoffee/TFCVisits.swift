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

    var geofenceUpdated = false
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
        return TFCDataStore.sharedInstance.complicationEnabled()
    }

    func locationDenied(manager: CLLocationManager, err: NSError) {
    }

    func locationFixed(coord: CLLocation?) {
        //Update geofences once per app start
        if (!geofenceUpdated) {
            if (TFCFavorites.sharedInstance.stations.count > 0) {
                   TFCFavorites.sharedInstance.updateGeofences()
            }
            geofenceUpdated = true
        }
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

    func regionVisit(region: CLCircularRegion) {
        if (region.identifier == "__updateGeofences__") {
            self.callback?(text: "update geofences call. coord: \(self.locManager?.currentLocation) Date: \(NSDate())")
            TFCFavorites.sharedInstance.updateGeofences()
            return
        }
        let station = TFCStation.initWithCacheId(region.identifier)
        self.callback?(text: "visited fence for \(station.name). Date: \(NSDate())")
        self.stations.updateStations()
    }

    func stationsUpdated(error: String?, favoritesOnly: Bool, context: Any?) {
        if (favoritesOnly == false) { // wait for all stations, should be fast anyway with the DB lookup nowadays (in Switzerland at least) and doesn't matter in this case how fast it is
            DLog("TFCVisits stationsUpdate")
            if let station = self.stations.first {
                DLog("first station is \(station)", toFile: true)
                if let callback = self.callback {
                    callback(text:"first station is \(station.name)")
                }
                TFCDataStore.sharedInstance.sendComplicationUpdate(station)
            }
        }
    }
}


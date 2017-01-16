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

    private var lastWasRegionVisit = false

    private var geofenceUpdated = false

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
                DLog("just before updateGeofences", toFile:true)
                TFCFavorites.sharedInstance.updateGeofences()
            }
            geofenceUpdated = true
        }
    }

    func locationStillTrying(manager: CLLocationManager, err: NSError) {
    }

    func locationVisit(coord: CLLocationCoordinate2D, date: NSDate, arrival: Bool) -> Bool {
        if arrival {
            DLog("TFCVisits locationVisit updateStations")
            self.stations.updateStations()
            if let callback = self.callback {
                callback(text: "Visit. Date: \(date) arrival: \(arrival) lat: \(coord.latitude.roundToPlaces(3)), lng: \(coord.longitude.roundToPlaces(3)) ")
            }
            DLog("just before updateGeofences", toFile:true)
            TFCFavorites.sharedInstance.updateGeofences(force: false)
        }
        return true
    }

    func regionVisit(region: CLCircularRegion) {
        if (region.identifier == "__updateGeofences__") {
            DLog("update geofences call", toFile: true)
            self.callback?(text: "update geofences call. radius: \(region.radius). coord: \(self.locManager?.currentLocation) Date: \(NSDate())")
            DLog("just before updateGeofences", toFile:true)
            TFCFavorites.sharedInstance.updateGeofences(force: false)
            return
        }
        lastWasRegionVisit = true
        if let station = TFCStation.initWithCacheId(region.identifier) {
            DLog("visited fence for \(station.name)", toFile: true)
            DLog("fence: currentLocation: \(locManager?.currentLocation)")
            self.callback?(text: "visited fence for \(station.name). radius: \(region.radius). Date: \(NSDate())")
            self.stations.updateStations()
            DLog("just before updateGeofences", toFile:true)
            TFCFavorites.sharedInstance.updateGeofences(force: false)
        }
    }

    func stationsUpdated(error: String?, favoritesOnly: Bool, context: Any?) {
        if (favoritesOnly == false) { // wait for all stations, should be fast anyway with the DB lookup nowadays (in Switzerland at least) and doesn't matter in this case how fast it is
            DLog("TFCVisits stationsUpdate")
            if let station = self.stations.getStation(0) {
                var doComplicationUpdate = true
                // don't update complication, if the first staion is not a favorite and we're coming from a region update
                // this can happen when we hardly touch a region perimeter but are out of it again when we have the first station
                // the implemented code can lead to false assumptions (since several events can happen at one time), but this would only
                // lead to do a non favorite complication update which shouldn't be done for optimization reasons and not the other way
                // round. We can live with that
                if (lastWasRegionVisit && !station.isFavorite()) {
                    doComplicationUpdate = false
                    DLog("region visit but nearest station \(station.name) is not a favorite. not sending complication update", toFile: true)
                }
                DLog("first station is \(station)", toFile: true)
                if (doComplicationUpdate) {
                    TFCDataStore.sharedInstance.sendComplicationUpdate(station, coord: TFCLocationManagerBase.getCurrentLocation()?.coordinate)
                }
            }
        }
        self.lastWasRegionVisit = false
    }
}


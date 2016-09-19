//
//  TFCFaforites.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 20.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

final public class TFCFavorites: NSObject {

    public class var sharedInstance: TFCFavorites {
        struct Static {
            static let instance: TFCFavorites = TFCFavorites()
        }
        return Static.instance
    }

    var lastGeofenceUpdate:CLLocation? = nil

    public lazy var stations: [String: TFCStation] = { [unowned self] in
        return self.getCurrentFavoritesFromDefaults()
        }()
    
    private struct objects {
        static let  dataStore: TFCDataStore? = TFCDataStore()
    }

    private var temporarlyRemovedStations = false
    private var needsSave = false

    override init() {
        super.init()
    }

    func repopulateFavorites() {
        temporarlyRemovedStations = false
        self.stations = getCurrentFavoritesFromDefaults()
    }

    public func getSearchRadius() -> Int {
        var favoritesSearchRadius =
        TFCDataStore.sharedInstance.getUserDefaults()?.integerForKey("favoritesSearchRadius")

        if (favoritesSearchRadius == nil || favoritesSearchRadius == 0) {
            favoritesSearchRadius = 1000
        }
        return favoritesSearchRadius!
    }

    private func getCurrentFavoritesFromDefaults() -> [String: TFCStation] {
        var st: [String: TFCStation]?
        if let unarchivedObject = objects.dataStore?.objectForKey("favorites2") as? NSData {
            NSKeyedUnarchiver.setClass(TFCStation.classForKeyedUnarchiver(), forClassName: "timeforcoffeeKit.TFCStation")
            NSKeyedUnarchiver.setClass(TFCStation.classForKeyedUnarchiver(), forClassName: "timeforcoffeeWatchKit.TFCStation")
            NSKeyedUnarchiver.setClass(TFCStation.classForKeyedUnarchiver(), forClassName: "Time_for_Coffee__WatchOS_2_App_Extension.TFCStation")
            st = NSKeyedUnarchiver.unarchiveObjectWithData(unarchivedObject) as? [String: TFCStation]
        }
        let cache = TFCCache.objects.stations
        guard st != nil else { return [:] }
        // get if from the cache, if it's already there.
        for (st_id, _) in st! {
            // trim id since we sometimes saved this wrong

            let trimmed_id = st_id.replace("^0*", template: "")
            if (trimmed_id != st_id) {
                DLog("Trim favourite ID \(st_id)")
                st![trimmed_id] = st![st_id]
                st![trimmed_id]?.st_id = trimmed_id
                st!.removeValueForKey(st_id)
                needsSave = true
            }
            var newStation: TFCStation? = cache.objectForKey(trimmed_id) as? TFCStation
            if (newStation?.name == "unknown") {
                newStation = TFCStation.initWithCacheId(trimmed_id)
                needsSave = true
            }
            if (newStation != nil && newStation?.coord != nil) {
                st![trimmed_id] = newStation
            }
        }
        return st!

    }

    func removeTemporarly(st_id: String) {
        temporarlyRemovedStations = true
        stations.removeValueForKey(st_id)
    }

    func unset(st_id: String?) {
        if let st_id = st_id {
            if (temporarlyRemovedStations) {
                repopulateFavorites()
            }
            stations.removeValueForKey(st_id)
            self.saveFavorites()
        }
    }

    func unset(station station: TFCStation?) {
        unset(station?.st_id)
    }

    func set(station: TFCStation?) {
        if let station = station {
            if (temporarlyRemovedStations) {
                repopulateFavorites()
            }
            stations[station.st_id] = station
            self.saveFavorites()
        }
    }

    func isFavorite(st_id: String?) -> Bool {
        if let st_id = st_id, station = self.stations[st_id] {
            if (station.isFavorite() == true) {
                return true
            }
        }
        return false
    }


    private func saveFavorites() {
        for (_, station) in stations {
            station.serializeDepartures = false
        }
        let archivedFavorites = NSKeyedArchiver.archivedDataWithRootObject(stations)
        for (_, station) in stations {
            station.serializeDepartures = true
            //make sure all favorites are indexed
            station.setStationSearchIndex()
        }
        objects.dataStore?.setObject(archivedFavorites , forKey: "favorites2")
    }

    public func getByDistance() -> [TFCStation]? {
        if (self.stations.count > 0) {
            var stations = Array(self.stations.values)
            stations.sortInPlace({ $0.calculatedDistance < $1.calculatedDistance })
            return stations
        }
        return nil
    }

    public func updateGeofences(force force:Bool = true) {
        if #available(iOSApplicationExtension 9.0, *) {
            #if os(iOS)
                dispatch_async(dispatch_get_main_queue()) {

                let currLoc = TFCLocationManager.getCurrentLocation()

                // don't update geofences, if we didn't move more than 1km from last one
                if let lastGeofenceUpdate = self.lastGeofenceUpdate, currLoc = currLoc {
                    if (!force && currLoc.distanceFromLocation(lastGeofenceUpdate) < 1000) {
                        return
                    }
                }
                self.lastGeofenceUpdate = currLoc

                let locationManager = CLLocationManager()

                let monitoredRegions = locationManager.monitoredRegions


                for region in monitoredRegions {
                    if let circularRegion = region as? CLCircularRegion {
                        locationManager.stopMonitoringForRegion(circularRegion)
                    }
                }
                if TFCDataStore.sharedInstance.complicationEnabled() {
                    self.repopulateFavorites()
                    let favCount = self.stations.count
                    // if we have no favourites, no need to update geofences
                    if (favCount == 0) {
                        return
                    }
                    if (!force) {
                        // don't update monitored regions, if we have less than 20 favs.
                        // no need as they all fit into it
                        if (favCount < 20 && monitoredRegions.count != (favCount + 1)) {
                            return
                        }
                    }
                    var maxDistance:Double = 0.0
                    if let stations = self.getByDistance() {
                        let maxStations:Int = 19
                        var nearestStationWithinRadius:TFCStation? = nil
                        let radius = 700.0
                        var nearestDistance:Double = radius
                        for station in stations.prefix(maxStations) {
                            if let coord = station.coord {
                                let region = CLCircularRegion(center: coord.coordinate, radius: radius, identifier: station.st_id)
                                if let currLoc = currLoc {
                                    let distance = currLoc.distanceFromLocation(coord)
                                    if (distance < radius) {
                                        if (distance < nearestDistance ) {
                                            nearestStationWithinRadius = station
                                            nearestDistance = distance
                                        }
                                    }
                                }
                                region.notifyOnExit = false
                                region.notifyOnEntry = true
                                locationManager.startMonitoringForRegion(region)
                                if let distance = station.calculatedDistance {
                                    maxDistance = max(maxDistance, distance)
                                }
                            }
                        }
                        if let stationUpdate = nearestStationWithinRadius {
                            TFCDataStore.sharedInstance.sendComplicationUpdate(stationUpdate, coord: currLoc?.coordinate)
                        }
                        if (maxDistance > 0.0) {
                            if let currLoc = currLoc {
                                let radius:Double
                                let radiusDecrease:Double = 3000
                                if ((maxDistance - radiusDecrease) < 0) {
                                    radius = maxDistance
                                } else {
                                    radius = maxDistance - radiusDecrease
                                }
                                let region = CLCircularRegion(center: currLoc.coordinate, radius: radius, identifier: "__updateGeofences__")
                                region.notifyOnExit = true
                                region.notifyOnEntry = false
                                locationManager.startMonitoringForRegion(region)

                            }
                        }
                    }
                } else {
                }
                }
            #endif
        }
    }
}

extension Array {
    //  stations.find{($0 as TFCStation).st_id == st_id}
    func indexOf(includedElement: Element -> Bool) -> Int? {
        for (idx, element) in self.enumerate() {
            if includedElement(element) {
                return idx
            }
        }
        return nil
    }

    func getObject(includedElement: Element -> Bool) -> Element? {
        for (_, element) in self.enumerate() {
            if includedElement(element) {
                return element
            }
        }
        return nil
    }
}

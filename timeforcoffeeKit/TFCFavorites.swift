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

    public var doGeofences = true
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

    public func repopulateFavorites() {
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
        objects.dataStore?.synchronize()
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
                if (self.doGeofences) {
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
                        DLog("updateGeofences", toFile: true)
                        let monitoredRegions = locationManager.monitoredRegions

                        var nearbyFavorites:[String:TFCStation] = [:]
                        var maxDistance:Double = 0.0
                        let radius = 1000.0
                        var nearestStationId:String? = nil
                        if TFCDataStore.sharedInstance.complicationEnabled() {
                            DLog("# of favorite stations before \(self.stations.count)", toFile: true)
                            self.repopulateFavorites()
                            DLog("# of favorite stations after \(self.stations.count)", toFile: true)
                            if let stations = self.getByDistance() {
                                #if DEBUG
                                    let maxStations:Int = 10
                                #else
                                    let maxStations:Int = 19
                                #endif
                                nearestStationId = stations.first?.st_id
                                for station in stations.prefix(maxStations) {
                                    nearbyFavorites[station.st_id] = station
                                    if let distance = station.calculatedDistance {
                                        maxDistance = max(maxDistance, distance)
                                    }
                                }
                            }
                        } else {
                            DLog("complication not enabled", toFile: true)
                        }


                        for region in monitoredRegions {
                            if let circularRegion = region as? CLCircularRegion {
                                if (circularRegion.identifier == "__updateGeofences__" || nearbyFavorites[region.identifier] == nil) {

                                    DLog("Delete geofence \(circularRegion.identifier) with radius \(circularRegion.radius)", toFile: true)
                                    locationManager.stopMonitoringForRegion(circularRegion)
                                } else {
                                    if nearbyFavorites[circularRegion.identifier]?.calculatedDistance < radius {
                                        DLog("geofence DEBUG for \(circularRegion.radius) is within radius, update it later", toFile: true)
                                        locationManager.stopMonitoringForRegion(circularRegion)
                                    } else if circularRegion.radius < radius {
                                        DLog("geofence DEBUG for \(circularRegion.radius) has smaller radius, update it later", toFile: true)
                                        locationManager.stopMonitoringForRegion(circularRegion)
                                    } else {
                                        nearbyFavorites.removeValueForKey(circularRegion.identifier)
                                    }
                                }
                            }
                        }
                        var first = true
                        var nearestStationWithinRadius:TFCStation? = nil

                        for (_, station) in nearbyFavorites {
                            if let coord = station.coord {

                                let distance = currLoc?.distanceFromLocation(coord)
                                var stationRadius = radius
                                if let distance = distance {
                                    var nearestDistance:Double = radius
                                    if (distance < radius) {
                                        DLog("we are within geofence")
                                        if (!first) {
                                            maxDistance = radius
                                        }
                                        if (distance < nearestDistance ) {
                                            nearestStationWithinRadius = station
                                            // use the standard radius for the nearest Station
                                            nearestDistance = distance
                                            first = false
                                        }
                                        // if we have another station within this radius
                                        // set that station radius 200 m less than distance
                                        // but max 200m, so that we get a hit, when we get closer
                                        // but not for the nearest station
                                        if (station.st_id != nearestStationId) {
                                            stationRadius = max(200, distance - 200.0)
                                        }
                                        // and set an exit radius for the standard radius
                                    }
                                }
                                let region = CLCircularRegion(center: coord.coordinate, radius: stationRadius, identifier: station.st_id)
                                DLog("add Geofence for \(station.name) with distance: \(distance) and radius \(stationRadius)", toFile: true)

                                region.notifyOnExit = false
                                region.notifyOnEntry = true
                                locationManager.startMonitoringForRegion(region)
                            }
                        }
                        if let stationUpdate = nearestStationWithinRadius {
                            DLog("we are within \(stationUpdate.name), send update", toFile: true)
                            TFCDataStore.sharedInstance.sendComplicationUpdate(stationUpdate, coord: currLoc?.coordinate)
                        }
                        if (maxDistance > 0.0) {
                            if let currLoc = currLoc {
                                DLog("maxDistance: \(maxDistance)")
                                let exitradius:Double
                                let radiusDecrease:Double = 3000
                                if ((maxDistance - radiusDecrease) < 2000) {
                                    // if all stations are within 5 km, try to set a radius just before the furthest stations but at least to 1km
                                    //  otherwise set it to the maxdistance of the furthest station
                                    // Not sure this makes much sense... could also be removed and just set it to maxDistance
                                    if ((maxDistance - (radius + 100)) > 1000) {
                                        exitradius = maxDistance - (radius + 100)
                                    } else {
                                        exitradius = maxDistance
                                    }
                                } else {
                                    if (maxDistance > locationManager.maximumRegionMonitoringDistance) {
                                        exitradius = locationManager.maximumRegionMonitoringDistance
                                    } else{
                                        exitradius = maxDistance - radiusDecrease
                                    }
                                }

                                let region = CLCircularRegion(center: currLoc.coordinate, radius: exitradius, identifier: "__updateGeofences__")
                                region.notifyOnExit = true
                                region.notifyOnEntry = false
                                locationManager.startMonitoringForRegion(region)
                                DLog("add Geofence exit update for radius \(exitradius) and coord \(currLoc)", toFile: true)
                            }
                        }
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

//
//  TFCStations.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 25.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

public class TFCStations {
    var stations:[TFCStation]?

    //struct here, because "class var" is not yet supported
    private struct favorite {
        static var s: TFCFavorites = TFCFavorites.sharedInstance
        static var inStationsArray: [String: Bool] = [:]
        static var userDefaults: NSUserDefaults? = TFCDataStore.sharedInstance.getUserDefaults()
    }

    public init() {
        favorite.s.repopulateFavorites()
    }

    public func count() -> Int? {
        if (stations == nil) {
            return nil
        }
        return stations!.count
    }

    public func clear() {
        stations = nil
    }
    public func empty() {
        stations = []
    }

    public func addWithJSON(allResults: JSONValue) {
        addWithJSON(allResults, append: false)
    }

    public func addWithJSON(allResults: JSONValue, append: Bool) {
        if (!append || stations == nil) {
            stations = []
            favorite.inStationsArray = [:]
        }
        // Create an empty array of Albums to append to from this list
        // Store the results in our table data array
        if allResults["stations"].array?.count>0 {
            if let results = allResults["stations"].array {
                for result in results {
                    var id = String(result["id"].integer!)
                    if (favorite.inStationsArray[id] == nil) {
                        var name = result["name"].string
                        var longitude: Double? = nil
                        var latitude: Double? = nil
                        if (result["coordinate"]["y"].double != nil) {
                            longitude = result["coordinate"]["y"].double
                            latitude = result["coordinate"]["x"].double
                        } else {
                            longitude = result["location"]["lng"].double
                            latitude = result["location"]["lat"].double
                        }
                        var Clocation: CLLocation?
                        if (longitude != nil && latitude != nil) {
                            Clocation = CLLocation(latitude: latitude!, longitude: longitude!)
                        }
                        var newStation = TFCStation.initWithCache(name!, id: id, coord: Clocation)
                        stations!.append(newStation)
                    }
                }
            }
        }
    }

    public func getStation(index: Int) -> TFCStation {
        if (stations == nil || index + 1 > stations!.count) {
            return TFCStation()
        }
        return stations![index]
    }

    class func isFavoriteStation(index: String) -> Bool {
        if (favorite.s.stations[index] != nil) {
            return true
        }
        return false
    }

    public func addNearbyFavorites(location: CLLocation) -> Bool {
        if (self.stations == nil) {
            self.stations = []
            favorite.inStationsArray = [:]
        }
        var hasNearbyFavs = false
        var removeFromFavorites: [String] = []
        var favDistance = 1000.0
        if (location.horizontalAccuracy > 500.0) {
            NSLog("horizontalAccuracy > 500: \(location.horizontalAccuracy)")
            favDistance = location.horizontalAccuracy + 500.0
        }
        for (st_id, station) in favorite.s.stations {
            var distance = location.distanceFromLocation(station.coord)
            if (distance < favDistance) {
                hasNearbyFavs = true
                if (favorite.inStationsArray[station.st_id] != true) {
                    station.calculatedDistance = Int(distance)
                    self.stations!.append(station)
                    favorite.inStationsArray[station.st_id] = true
                }
            } else {
                removeFromFavorites.append(st_id)
            }
        }
        // for memory reasons...
        for (st_id) in removeFromFavorites {
            favorite.s.removeTemporarly(st_id)
        }

        if (hasNearbyFavs) {
            self.stations!.sort({ $0.calculatedDistance < $1.calculatedDistance })
            return true
        }
        return false
    }

    public func loadFavorites(location: CLLocation?) {
        self.stations = []
        for (st_id, station) in favorite.s.stations {
            if (location != nil) {
                let distance = Int(location?.distanceFromLocation(station.coord) as Double!)
                station.calculatedDistance = distance
            }
            self.stations?.append(station)
        }
        if (location != nil) {
            self.stations!.sort({ $0.calculatedDistance < $1.calculatedDistance })
        }
    }
}

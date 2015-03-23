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
        static var userDefaults: NSUserDefaults? =  NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
    }

    public init() {
        // can be removed, when everyone moved to the new way of storing favorites
        populateFavoriteStationsOld()
        favorite.s.repopulateFavorites()
    }

    public func count() -> Int? {
        if (stations == nil) {
            return nil
        }
        return stations!.count
    }

    public func addWithJSON(allResults: JSONValue) {
        addWithJSON(allResults, append: false)
    }
    public func clear () {
        stations = nil
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

    public class func getStationById(st_id: String) -> TFCStation {
        return TFCStation(name: "", id: st_id, coord: nil)
    }

    public class func isFavoriteStation(index: String) -> Bool {
        if (favorite.s.stations[index] != nil) {
            return true
        }
        return false
    }

    public func addNearbyFavorites(location: CLLocation) -> Bool {
        favorite.inStationsArray = [:]
        if (self.stations == nil) {
            self.stations = []
        }
        var hasNearbyFavs = false
        var removeFromFavorites: [String] = []
        for (st_id, station) in favorite.s.stations {
            var distance = Int(location.distanceFromLocation(station.coord) as Double!)
            if (distance < 1000) {
                hasNearbyFavs = true
                station.calculatedDistance = distance
                self.stations!.append(station)
                favorite.inStationsArray[station.st_id] = true
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

    public class func setFavoriteStation(station: TFCStation) {
        station.setFavorite()
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

    /*** OLD WAY TO STORE FAVS, can be removed some day ***/

    func populateFavoriteStationsOld() {
        if (favorite.userDefaults?.objectForKey("favoriteStations") == nil) {
            return
        }
        var favoriteStationsDict = TFCStations.getFavoriteStationsDict()
        var stations:[String: TFCStation] = [:]
        for (st_id, station) in favoriteStationsDict {
            let lat = NSString(string:station["latitude"]!).doubleValue
            let long = NSString(string:station["longitude"]!).doubleValue
            var Clocation = CLLocation(latitude: lat, longitude: long)
            let station: TFCStation = TFCStation.initWithCache(station["name"]!, id: station["st_id"]!, coord: Clocation)

            //FIXME: can be removed in a few days, st_id can start with 00 or not sometimes
            //then back to just
            // self.favoriteStations[st_id] = station

            let st_id_fixed = String(st_id.toInt()!)
            station.st_id = st_id_fixed
            stations[st_id_fixed] = station
            favorite.s.set(station)
        }
        favorite.userDefaults?.removeObjectForKey("favoriteStations")

    }

    public class func getFavoriteStationsDict() -> [String: [String: String]] {
        var favoriteStationsShared: [String: [String: String]]? = favorite.userDefaults?.objectForKey("favoriteStations")? as [String: [String: String]]?

        if (favoriteStationsShared == nil) {
            favoriteStationsShared = [:]
        }
        return favoriteStationsShared!
    }

    /*** END OLD WAY TO STORE FAVS, can be removed some day ***/


    public class func getUserDefaults() -> NSUserDefaults? {
        return favorite.userDefaults
    }

}

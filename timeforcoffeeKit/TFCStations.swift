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
    private struct favorites {
            static var stations: [String: TFCStation] = [:]
            static var inStationsArray: [String: Bool] = [:]
            static var userDefaults: NSUserDefaults? =  NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
    }
    public init() {
        populateFavoriteStations()
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
            favorites.inStationsArray = [:]
        }
        // Create an empty array of Albums to append to from this list
        // Store the results in our table data array
        if allResults["stations"].array?.count>0 {
            if let results = allResults["stations"].array {
                for result in results {
                    var id = String(result["id"].integer!)
                    if (favorites.inStationsArray[id] == nil) {
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
        if (favorites.stations[index] != nil) {
            return true
        }
        return false
    }

    public func addNearbyFavorites(location: CLLocation) -> Bool {
        favorites.inStationsArray = [:]
        if (self.stations == nil) {
            self.stations = []
        }
        var removeFromFavorites: [String] = []
        for (st_id, station) in favorites.stations {
            var distance = Int(location.distanceFromLocation(station.coord) as Double!)
            if (distance < 1000) {
                station.calculatedDistance = distance
                self.stations!.append(station)
                favorites.inStationsArray[station.st_id] = true
            } else {
                station.removeFromCache()
                removeFromFavorites.append(st_id)
            }
        }

        for (st_id) in removeFromFavorites {
            favorites.stations.removeValueForKey(st_id)
        }
        
        if (favorites.inStationsArray.count > 0) {
            self.stations!.sort({ $0.calculatedDistance < $1.calculatedDistance })
            return true
        }
        return false
    }

    public class func unsetFavoriteStation(station: TFCStation) {
        TFCStations.unsetFavoriteStation(station.st_id)
    }

    public class func unsetFavoriteStation(st_id: String) {
        var favoriteStationsDict = TFCStations.getFavoriteStationsDict()
        favoriteStationsDict[st_id] = nil
        favorites.stations[st_id] = nil
        TFCStations.saveFavoriteStations(favoriteStationsDict)
    }

    public class func setFavoriteStation(station: TFCStation) {
        var favoriteStationsDict = TFCStations.getFavoriteStationsDict()
        if (station.coord == nil) {
            println("Coordinates not set for station, don't save it as fav")
        } else {
            favoriteStationsDict[station.st_id] =  [
                "name": station.name,
                "st_id": station.st_id,
                "latitude": station.coord!.coordinate.latitude.description,
                "longitude": station.coord!.coordinate.longitude.description
            ]
            
            favorites.stations[station.st_id] = station
            TFCStations.saveFavoriteStations(favoriteStationsDict)
        }
    }

    class func saveFavoriteStations(favoriteStationsDict: [String: [String: String]]) {
        favorites.userDefaults?.setObject(favoriteStationsDict, forKey: "favoriteStations")
        TFCStations.getUserDefaults()?.setObject(NSDate(), forKey: "settingsLastUpdate")
    }

    func populateFavoriteStations() {
        var favoriteStationsDict = TFCStations.getFavoriteStationsDict()
        println("populate")
        favorites.stations = [:]
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
            favorites.stations[st_id_fixed] = station
        }
    }
    
    public func loadFavorites(location: CLLocation?) {
        self.stations = []
        for (st_id,station) in favorites.stations {
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


    public class func getFavoriteStationsDict() -> [String: [String: String]] {
        var favoriteStationsShared: [String: [String: String]]? = favorites.userDefaults?.objectForKey("favoriteStations")?.mutableCopy() as [String: [String: String]]?

        if (favoriteStationsShared == nil) {
            favoriteStationsShared = [:]
        }
        return favoriteStationsShared!
    }

    public class func getUserDefaults() -> NSUserDefaults? {
        return favorites.userDefaults
    }

}

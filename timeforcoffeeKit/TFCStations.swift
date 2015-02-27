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
    var stations:[TFCStation] = []

    //struct here, because "class var" is not yet supported
    private struct favorites {
            static var stations: [String: TFCStation] = [:]
            static var inStationsArray: [String: Bool] = [:]
    }
    public init() {
        populateFavoriteStations()
    }

    public func count() -> Int {
        return stations.count
    }

    public func addWithJSON(allResults: JSONValue) {
        addWithJSON(allResults, append: false)
    }

    public func addWithJSON(allResults: JSONValue, append: Bool) {
        if (!append) {
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
                        var longitude = result["coordinate"]["y"].double
                        var latitude = result["coordinate"]["x"].double
                        var Clocation = CLLocation(latitude: latitude!, longitude: longitude!)
                        var newStation = TFCStation(name: name!, id: id, coord: Clocation)
                        stations.append(newStation)
                    }
                }
            }
        }
    }

    public func getStation(index: Int) -> TFCStation {
        return stations[index]
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
        for (st_id, station) in favorites.stations {
            var distance = Int(location.distanceFromLocation(station.coord) as Double!)
            if (distance < 1000) {
                station.calculatedDistance = distance
                self.stations.append(station)
                favorites.inStationsArray[station.st_id] = true
            }
        }
        if (favorites.inStationsArray.count > 0) {
            self.stations.sort({ $0.calculatedDistance < $1.calculatedDistance })
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
        favoriteStationsDict[station.st_id] =  [
        "name": station.name,
        "st_id": station.st_id,
        "latitude": station.coord.coordinate.latitude.description,
        "longitude": station.coord.coordinate.longitude.description
        ]
        
        //FIXME: fix longitude/Latitude if not set yet (when directly called on detail screen)
        // get it from http://transport.opendata.ch/v1/locations?query=8591341
        
        favorites.stations[station.st_id] = station
        TFCStations.saveFavoriteStations(favoriteStationsDict)
    }

    class func saveFavoriteStations(favoriteStationsDict: [String: [String: String]]) {
        var sharedDefaults = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
        sharedDefaults?.setObject(favoriteStationsDict, forKey: "favoriteStations")
    }

    func populateFavoriteStations() {
        var favoriteStationsDict = TFCStations.getFavoriteStationsDict()
        println("populate")
        println(favoriteStationsDict)
        favorites.stations = [:]
        for (st_id, station) in favoriteStationsDict {
            let lat = NSString(string:station["latitude"]!).doubleValue
            let long = NSString(string:station["longitude"]!).doubleValue
            var Clocation = CLLocation(latitude: lat, longitude: long)
            let station: TFCStation = TFCStation(name: station["name"]!, id: station["st_id"]!, coord: Clocation)

            //FIXME: can be removed in a few days, st_id can start with 00 or not sometimes
            //then back to just
            // self.favoriteStations[st_id] = station

            let st_id_fixed = String(st_id.toInt()!)
            station.st_id = st_id_fixed
            favorites.stations[st_id_fixed] = station
        }
    }


    class func getFavoriteStationsDict() -> [String: [String: String]] {
        var sharedDefaults = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
        var favoriteStationsShared: [String: [String: String]]? = sharedDefaults?.objectForKey("favoriteStations") as [String: [String: String]]?

        if (favoriteStationsShared == nil) {
            favoriteStationsShared = [:]
        }
        return favoriteStationsShared!
    }

}

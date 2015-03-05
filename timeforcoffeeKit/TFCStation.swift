//
//  Album.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

public class TFCStation {
    public var name: String
    public var coord: CLLocation?
    public var st_id: String
    public var distance: CLLocationDistance?
    public var calculatedDistance: Int?

    lazy var filteredLines:[String: [String: Bool]] = self.getFilteredLines()
    
    public init(name: String, id: String, coord: CLLocation?) {
        self.name = name
        self.st_id = id
        self.coord = coord
    }
    
    
    
    public class func isStations(results: JSONValue) -> Bool {
        if (results["stations"].array? != nil) {
            return true
        }
        return false
    }
    
    public func isFavorite() -> Bool {
        return TFCStations.isFavoriteStation(self.st_id);
    }
    
    public func getLongitude() -> Double? {
        return coord?.coordinate.longitude
    }

    public func getLatitude() -> Double? {
        return coord?.coordinate.latitude
    }
    
    public func getName(cityAfter: Bool) -> String {
        if (cityAfter && name.match(", ")) {
            let stationName = name.replace(".*, ", template: "")
            let cityName = name.replace(", .*", template: "")
            return "\(stationName) (\(cityName))"
        }
        return name
    }
    
    public func getNameWithStar() -> String {
        return getNameWithStar(false)
    }
    
    public func getNameWithStar(cityAfter: Bool) -> String {
        if self.isFavorite() {
            return "\(getName(cityAfter)) ★"
        }
        return getName(cityAfter)
    }
    
    public func getNameWithStarAndFilters() -> String {
        return getNameWithStar(false)
    }
    
    public func getNameWithStarAndFilters(cityAfter: Bool) -> String {
        if self.hasFilters() {
            return "\(getNameWithStar(cityAfter)) ✗"
        }
        return getNameWithStar(cityAfter)
    }
    
    public func hasFilters() -> Bool {
        return (filteredLines.count > 0)
    }
    
    public func isFiltered(departure: TFCDeparture) -> Bool {
        if (filteredLines[departure.getLine()] != nil) {
            if (filteredLines[departure.getLine()]?[departure.getDestination()] != nil) {
                return true
            }
        }
        return false
    }
    
    public func setFilter(departure: TFCDeparture) {
        var filteredLine = filteredLines[departure.getLine()]
        if (filteredLines[departure.getLine()] == nil) {
            filteredLines[departure.getLine()] = [:]
        }

        filteredLines[departure.getLine()]?[departure.getDestination()] = true
        saveFilteredLines()
    }
    
    public func unsetFilter(departure: TFCDeparture) {
        filteredLines[departure.getLine()]?[departure.getDestination()] = nil
        if((filteredLines[departure.getLine()] as [String: Bool]!).count == 0) {
            filteredLines[departure.getLine()] = nil
        }
        saveFilteredLines()

    }
        
    public func saveFilteredLines() {
        var sharedDefaults = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
        if (filteredLines.count > 0) {
            sharedDefaults?.setObject(filteredLines, forKey: "filtered\(st_id)")
        } else {
            sharedDefaults?.removeObjectForKey("filtered\(st_id)")
        }
    }
    
    func getFilteredLines() -> [String: [String: Bool]] {
        var sharedDefaults = NSUserDefaults(suiteName: "group.ch.liip.timeforcoffee")
        var filteredDestinationsShared: [String: [String: Bool]]? = sharedDefaults?.objectForKey("filtered\(st_id)") as [String: [String: Bool]]?
        
        if (filteredDestinationsShared == nil) {
            filteredDestinationsShared = [:]
        }
        return filteredDestinationsShared!
    }

}


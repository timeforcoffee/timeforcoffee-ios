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
    public var coord: CLLocation
    public var st_id: String
    public var distance: CLLocationDistance?
    public var calculatedDistance: Int?

    public init(name: String, id: String, coord: CLLocation?) {
        var coord2 = coord
        if (coord2 == nil) {
            coord2 = CLLocation(latitude: 0, longitude: 0)
        }
        self.name = name
        self.st_id = id
        self.coord = coord2!
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
    
    public func getNameWithStar() -> String {
        if self.isFavorite() {
            return "\(name) ★"
        }
        return name
    }
}


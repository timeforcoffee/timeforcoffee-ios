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

    public init(name: String, id: String, coord: CLLocation?) {
        self.name = name
        self.st_id = id
        self.coord = coord!
    }
    
    public class func isStations(results: JSONValue) -> Bool {
        if (results["stations"].array? != nil) {
            return true
        }
        return false
    }
}


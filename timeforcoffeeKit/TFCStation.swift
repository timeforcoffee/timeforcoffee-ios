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
    
    public class func withJSON(allResults: JSONValue) -> [TFCStation] {
        
        // Create an empty array of Albums to append to from this list
        var stations = [TFCStation]()
        // Store the results in our table data array
        if allResults["stations"].array?.count>0 {
            
            if let results = allResults["stations"].array {
                
                for result in results {
                    var name = result["name"].string
                    var id = result["id"].string
                    var longitude = result["coordinate"]["y"].double
                    var latitude = result["coordinate"]["x"].double
                    var Clocation = CLLocation(latitude: latitude!, longitude: longitude!)
                    var newStation = TFCStation(name: name!, id: id!, coord: Clocation)
                    stations.append(newStation)
                    
                }
            }
            
            
        }
        return stations
    }
}


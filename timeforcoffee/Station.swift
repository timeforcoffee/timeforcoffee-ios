//
//  Album.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

class Station {
    var name: String
    var distanceCalc: CLLocationDistance?
    var coord: CLLocation
    var distance: Double?
    var imageURL: String?

    init(name: String,  coord: CLLocation?, distance: Double?) {
        self.name = name
        self.coord = coord!
        self.distance = distance
    }
    class func stationsWithJSON(allResults: JSONValue) -> [Station] {
        
        // Create an empty array of Albums to append to from this list
        var stations = [Station]()
        // Store the results in our table data array
        if allResults["stations"].array?.count>0 {
            
            if let results = allResults["stations"].array {
                
                for result in results {
                    var name = result["name"].string
                    println(name);
                    var longitude = result["coordinate"]["x"].double
                    var latitude = result["coordinate"]["y"].double
                    var Clocation = CLLocation(latitude: latitude!, longitude: longitude!)
                    println(Clocation)
                    var distance =  result["distance"].double
                    println(distance);
                    var newStation = Station(name: name!, coord: Clocation, distance: distance)
                    stations.append(newStation)
                }
            }
            
            
        }
        return stations
    }
}


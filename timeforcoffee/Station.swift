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
    var name: String?
    var coord: CLLocation
    var imageURL: String?
    var st_id: String?
    var distance: CLLocationDistance?

    init(name: String, id: String, coord: CLLocation?) {
        self.name = name
        self.st_id = id
        self.coord = coord!
    }
    
    class func withJSON(allResults: JSONValue) -> [Station] {
        
        // Create an empty array of Albums to append to from this list
        var stations = [Station]()
        // Store the results in our table data array
        if allResults["stations"].array?.count>0 {
            
            if let results = allResults["stations"].array {
                
                for result in results {
                    var name = result["name"].string
                    var id = result["id"].string
                    var longitude = result["coordinate"]["y"].double
                    var latitude = result["coordinate"]["x"].double
                    var Clocation = CLLocation(latitude: latitude!, longitude: longitude!)
                    var newStation = Station(name: name!, id: id!, coord: Clocation)
                    stations.append(newStation)
                }
            }
            
            
        }
        return stations
    }
}


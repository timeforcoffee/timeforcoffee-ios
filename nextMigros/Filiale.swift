//
//  Album.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

class Filiale {
    var name: String
    var address: String
    var distance: CLLocationDistance?
    var coord: CLLocation
    var type: String
    var partnerId: String
    var imageURL: String?
    
    init(name: String, address: String, coord: CLLocation, type: String, partnerId: String) {
        self.name = name
        self.address = address
        self.coord = coord
        self.type = type
        self.partnerId = partnerId
    }
    class func albumsWithJSON(allResults: JSONValue) -> [Filiale] {
        
        // Create an empty array of Albums to append to from this list
        var filialen = [Filiale]()
        // Store the results in our table data array
        if allResults.array?.count>0 {
            
            if let results = allResults.array {
                
                for result in results {
                    
                    var name = result["name"].string
                    var address = ""
                    var longitude = result["location"]["longitude"].double
                    var latitude = result["location"]["latitude"].double
                    var Clocation = CLLocation(latitude: latitude!, longitude: longitude!)
                    var type =  result["location"]["type"].string
                    var partnerId = result["location"]["partnerId"].string
                    var newFiliale = Filiale(name: name!, address: address, coord: Clocation, type: type!, partnerId: partnerId!)
                    filialen.append(newFiliale)
                }
            }
            
            // Sometimes iTunes returns a collection, not a track, so we check both for the 'name'
            
        }
        return filialen
    }
}


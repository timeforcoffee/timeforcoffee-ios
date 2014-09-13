//
//  Album.swift
//  nextMigros
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

class Album {
    var name: String
    var address: String
    var distance: CLLocationDistance?
    var coord: CLLocation
    
    init(name: String, address: String, coord: CLLocation) {
        self.name = name
        self.address = address
        self.coord = coord
    }
    class func albumsWithJSON(allResults: JSONValue) -> [Album] {
        
        // Create an empty array of Albums to append to from this list
        var albums = [Album]()
        // Store the results in our table data array
        if allResults.array?.count>0 {
            
            if let results = allResults.array {
                
                for result in results {
                    
                    var name = result["name"].string
                    var address = ""
                    var longitude = result["location"]["longitude"].double
                    var latitude = result["location"]["latitude"].double
                    var Clocation = CLLocation(latitude: latitude!, longitude: longitude!)
         
                    var newAlbum = Album(name: name!, address: address, coord: Clocation)
                    albums.append(newAlbum)
                }
            }
            
            // Sometimes iTunes returns a collection, not a track, so we check both for the 'name'
            
        }
        return albums
    }
}


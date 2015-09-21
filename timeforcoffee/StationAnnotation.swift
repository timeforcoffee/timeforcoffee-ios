//
//  StationAnnotation.swift
//  timeforcoffee
//
//  Created by Raphael Neuenschwander on 21.09.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import MapKit

class StationAnnotation: NSObject, MKAnnotation {
    let title: String?
    let coordinate: CLLocationCoordinate2D
    let distance: String?
    
    init(title: String, distance: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.coordinate = coordinate
        self.distance = distance
    }
    
    var subtitle: String? {
        return distance
    }
    
    // Annotation callout "walking" button opens this mapItem in Maps app
    func mapItem() -> MKMapItem {
        let placeMark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placeMark)
        mapItem.name = title
        return mapItem
    }
}
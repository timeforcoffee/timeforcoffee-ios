//
//  TFCLocationManager.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.06.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

public final class TFCLocationManager: TFCLocationManagerBase {

    override func requestLocation() {
        self.locationManager.startUpdatingLocation()

/*  
        if #available(iOS 9, *) {
            self.locationManager.requestLocation()
        } else {
            self.locationManager.startUpdatingLocation()
        }*/
    }

    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.locationManagerBase(manager, didUpdateLocations: locations)
    }
}
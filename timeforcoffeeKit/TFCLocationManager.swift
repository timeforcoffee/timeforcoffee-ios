//
//  LocationManager.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation

public class TFCLocationManager: NSObject, CLLocationManagerDelegate {
    lazy var locationManager : CLLocationManager = self.lazyInitLocationManager()
    var locationFixAchieved : Bool = false
    var locationStatus : NSString = "Not Started"
    public var currentLocation: CLLocation?
    var seenError : Bool = false
    var delegate: TFCLocationManagerDelegate

    init(delegate: TFCLocationManagerDelegate) {
        self.delegate = delegate
    }
    
    func lazyInitLocationManager() -> CLLocationManager {
        seenError = false
        locationFixAchieved = false
        var lm = CLLocationManager()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.requestAlwaysAuthorization()
        return lm
    }

    
    public func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        self.locationManager.stopUpdatingLocation()
        if ((error) != nil) {
            if (seenError == false) {
                seenError = true
                print(error)
            }
        }
    }
    
    public func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        var coord: CLLocationCoordinate2D? = nil
        if (locationFixAchieved == false) {
            locationFixAchieved = true
            var locationArray = locations as NSArray
            var locationObj = locationArray.lastObject as CLLocation
            coord = locationObj.coordinate
            currentLocation = locationObj;
        }
        locationManager.stopUpdatingLocation()
        self.delegate.locationFixed(coord)

    }
    
    // authorization status
    public func locationManager(manager: CLLocationManager!,
        didChangeAuthorizationStatus status: CLAuthorizationStatus) {
            var shouldIAllow = false
            switch status {
            case CLAuthorizationStatus.Restricted:
                locationStatus = "Restricted Access to location"
            case CLAuthorizationStatus.Denied:
                locationStatus = "User denied access to location"
            case CLAuthorizationStatus.NotDetermined:
                locationStatus = "Status not determined"
            default:
                locationStatus = "Allowed to location Access"
                shouldIAllow = true
            }
            NSNotificationCenter.defaultCenter().postNotificationName("LabelHasbeenUpdated", object: nil)
            if (shouldIAllow == true) {
                NSLog("Location is allowed")
                // Start location services
                locationManager.startUpdatingLocation()
            } else {
                NSLog("Denied access: \(locationStatus)")
            }
    }
    
    public func refreshLocation() {
        locationFixAchieved = false
        locationManager.startUpdatingLocation()
    }

}

public protocol TFCLocationManagerDelegate {
    func locationFixed(coord: CLLocationCoordinate2D?)
}
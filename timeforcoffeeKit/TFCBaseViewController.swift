//
//  TFCBaseViewController.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

public class TFCBaseViewController: UIViewController, CLLocationManagerDelegate {
    var locationManager : CLLocationManager!
    var seenError : Bool = false
    var locationFixAchieved : Bool = false
    var locationStatus : NSString = "Not Started"
    public var currentLocation: CLLocation?
    
    public func initLocationManager() {
        seenError = false
        locationFixAchieved = false
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
//        locationManager.startUpdatingLocation()
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

    public func locationManagerFix(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) -> CLLocationCoordinate2D? {
        if (locationFixAchieved == false) {
            locationFixAchieved = true
            var locationArray = locations as NSArray
            var locationObj = locationArray.lastObject as CLLocation
            var coord = locationObj.coordinate
            currentLocation = locationObj;
            locationManager.stopUpdatingLocation()
            return coord
        }
        return nil
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
                NSLog("Location to Allowed")
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

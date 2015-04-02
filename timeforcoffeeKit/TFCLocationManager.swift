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
    private lazy var locationManager : CLLocationManager = self.lazyInitLocationManager()
    private var locationFixAchieved : Bool = false
    private var locationStatus : NSString = "Not Started"
    private var seenError : Bool = false
    private unowned var delegate: TFCLocationManagerDelegate

    public var currentLocation: CLLocation? {
        get {
            return classvar.currentLocation
        }
        set (location) {
            classvar.currentLocation = location
        }
    }

    private struct classvar {
        static var currentLocation: CLLocation?
    }

    public init(delegate: TFCLocationManagerDelegate) {
        self.delegate = delegate
    }
    
    private func lazyInitLocationManager() -> CLLocationManager {
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
                NSLog("LocationManager Error \(error)")
                // we often get errors on the simulator, this just sets the currentCoordinates to the liip office
                // in zurich when in the simulator
                #if (arch(i386) || arch(x86_64)) && os(iOS)
                NSLog("Set coordinates to Liip ZH...")
                currentLocation = CLLocation(latitude: 47.386142, longitude: 8.529163)
                locationManager.stopUpdatingLocation()
                self.delegate.locationFixed(currentLocation?.coordinate)
                #endif
            }
        }
    }
    
    public func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        var coord: CLLocationCoordinate2D? = nil
        if (currentLocation == nil || locationFixAchieved == false) {
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

    public class func getCurrentLocation() -> CLLocation? {
        return classvar.currentLocation
    }

}

public protocol TFCLocationManagerDelegate: class {
    func locationFixed(coord: CLLocationCoordinate2D?)
}

//
//  LocationManager.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 24.02.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


open class TFCLocationManagerBase: NSObject, CLLocationManagerDelegate {
    lazy var locationManager : CLLocationManager = self.lazyInitLocationManager()
    fileprivate var locationFixAchieved : Bool = false
    fileprivate var locationStatus : NSString = "Not Started"
    fileprivate var seenError : Bool = false
    weak var delegate: TFCLocationManagerDelegate?

    open var currentLocation: CLLocation? {
        get {
            return classvar.currentLocation
        }
        set (location) {
            TFCLocationManagerBase.setCurrentLocation(location)
        }
    }

    fileprivate struct classvar {
        static var currentLocation: CLLocation?
        static var _lastUpdateCurrentLocation: Date?
        static var currentLocationTimestamp: Date?
        static var currentPlacemark: CLPlacemark? {
            get {
                return _currentPlacemark;
            }
            set (placemark) {
                if let country = placemark?.isoCountryCode {
                    if (country != _currentCountry) {
                        UserDefaults(suiteName: "group.ch.opendata.timeforcoffee")?.setValue(country, forKey: "currentCountry")
                    }
                    _currentPlacemark = placemark
                }
            }
        }
        static var _currentPlacemark: CLPlacemark?
        static var _currentCountry: String?
    }

    public struct k {
        public static let AirplaneMode = "AirplaneMode?"
    }
    
    public init(delegate: TFCLocationManagerDelegate) {
        self.delegate = delegate
    }

    deinit {
        self.locationManager.stopUpdatingLocation()
        self.locationManager.delegate = nil
    }

    class func setCurrentLocation(_ location: CLLocation?, time:Date? = nil) {
        var newTimestamp = time
        if (location?.timestamp != nil) {
            newTimestamp = location?.timestamp
        }

        if classvar.currentLocation == nil {
            TFCLocationManagerBase.setCurrentLocation(location, time:time, force: true)
        } else if let newTimestamp = newTimestamp, let oldTimestamp = classvar.currentLocationTimestamp {
            if (newTimestamp > oldTimestamp) {
                TFCLocationManagerBase.setCurrentLocation(location, time:time, force: true)
            }
        } else {
            TFCLocationManagerBase.setCurrentLocation(location, time:time, force: true)
        }
    }

    class func setCurrentLocation(_ location: CLLocation?, time:Date? = nil, force:Bool) {
        guard force else { TFCLocationManagerBase.setCurrentLocation(location, time: time); return }

        classvar.currentLocation = location
        classvar._lastUpdateCurrentLocation = Date()

        if let timestamp = location?.timestamp {
            classvar.currentLocationTimestamp = timestamp
        } else if let time = time {
            classvar.currentLocationTimestamp = time
        } else {
            classvar.currentLocationTimestamp = Date()
        }

    }

    fileprivate func lazyInitLocationManager() -> CLLocationManager {
        seenError = false
        locationFixAchieved = false
        let lm = CLLocationManager()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if (CLLocationManager.locationServicesEnabled()) {
            self.getLocationRequest(lm)
        }
        return lm
    }

    func getLocationRequest(_ lm: CLLocationManager) {
        lm.requestWhenInUseAuthorization()
    }

    open func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async(execute: {
                DLog("LocationManager Error \(error) with code \(error)")
                #if !((arch(i386) || arch(x86_64)) && (os(iOS) || os(watchOS)))
                    if ((error as NSError).code == CLError.Code.locationUnknown.rawValue) {
                        DLog("LocationManager LocationUnknown")
                        self.delegate?.locationStillTrying(manager, err: error)
                        return
                    }
                #endif
                self.locationManager.stopUpdatingLocation()
                if (self.seenError == false ) {
                    self.seenError = true
                    // we often get errors on the simulator, this just sets the currentCoordinates to the liip office
                    // in zurich when in the simulator
                    #if (arch(i386) || arch(x86_64)) && (os(iOS) || os(watchOS))
                        DLog("Set coordinates to Liip ZH...")
                        self.currentLocation = CLLocation(latitude: 47.386142, longitude: 8.529163)
                        //currentLocation = CLLocation(latitude: 46.386142, longitude: 7.529163)
                        // random location in zurich
                         //self.currentLocation = CLLocation(latitude: 47.38 + (Double(arc4random_uniform(100)) / 7000.0), longitude: 8.529163 + (Double(arc4random_uniform(100)) / 7000.0))
                        self.locationManager.stopUpdatingLocation()
                        if (classvar.currentPlacemark == nil || classvar.currentPlacemark?.location?.distance(from: self.currentLocation!) > 1000) {
                            self.updateGeocodedPlacemark()
                        }

                        self.delegate?.locationFixed(self.currentLocation)
                        //self.delegate.locationDenied(manager)
                    #else
                        self.delegate?.locationDenied(manager, err: error)
                    #endif

                }
        })
    }

    open func locationManagerBase(_ manager: CLLocationManager, didUpdateLocations locations: [AnyObject]) {
        let locationArray = locations as NSArray
        if let locationObj = locationArray.lastObject as? CLLocation {
            self.currentLocation = locationObj;
        }
        DispatchQueue.main.async(execute: {
            if (self.locationFixAchieved == false) {
                self.locationFixAchieved = true
                //random location, sometimes needed for testing ...
                //self.currentLocation = CLLocation(latitude: 47.38 + (Double(arc4random_uniform(100)) / 7000.0), longitude: 8.53 + (Double(arc4random_uniform(100)) / 7000.0))
                if (classvar.currentPlacemark == nil || (self.currentLocation != nil && classvar.currentPlacemark?.location?.distance(from: self.currentLocation!) > 2000)) {
                    self.updateGeocodedPlacemark()
                }
                self.delegate?.locationFixed(self.currentLocation)
            } else {
                self.delegate?.locationFixed(nil)
            }
            self.locationManager.stopUpdatingLocation()
        })
    }
    
    // authorization status
    open func locationManager(_ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus) {
            var shouldIAllow = false
            switch status {
            case CLAuthorizationStatus.restricted:
                locationStatus = "Restricted Access to location"
            case CLAuthorizationStatus.denied:
                locationStatus = "User denied access to location"
            case CLAuthorizationStatus.notDetermined:
                locationStatus = "Status not determined"
            default:
                locationStatus = "Allowed to location Access"
                shouldIAllow = true
            }
            if (shouldIAllow == true) {
                DLog("Location is allowed")
                // Start location services
                self.requestLocation()
            } else {
                DLog("Denied access: \(locationStatus)")
            }
    }
    
    open func refreshLocation() {
        seenError = false
        locationFixAchieved = false
        DispatchQueue.main.async(execute: {
            self.requestLocation()
        })
    }

    open class func getCurrentLocation() -> CLLocation? {
        return classvar.currentLocation
    }
    
    func requestLocation() {

    }

    open func updateGeocodedPlacemark() {
        let geocoder = CLGeocoder()
        if let currentLoc = classvar.currentLocation {
            geocoder.reverseGeocodeLocation(currentLoc) { (places:[CLPlacemark]?, error:Error?) -> Void in
                if let place = places?.first {
                    classvar.currentPlacemark = place
                }
            }
        }
    }

    open class func getISOCountry() -> String? {
        if let country = UserDefaults(suiteName: "group.ch.opendata.timeforcoffee")?.string(forKey: "currentCountry") {
            return country
        } else {
            return "unknown"
        }
    }

    open func getLastLocation(_ notOlderThanSeconds: Int) -> CLLocation? {
        if (classvar._lastUpdateCurrentLocation?.timeIntervalSinceNow < TimeInterval(-notOlderThanSeconds)) {
            return nil
        }
        DLog("still cached since \(classvar._lastUpdateCurrentLocation) , \(currentLocation)")

        return currentLocation
    }
}

@objc public protocol TFCLocationManagerDelegate: class {
    func locationFixed(_ coord: CLLocation?)
    func locationDenied(_ manager: CLLocationManager, err: Error)
    func locationStillTrying(_ manager: CLLocationManager, err: Error)
    @objc optional func locationVisit(_ coord: CLLocationCoordinate2D, date: Date, arrival: Bool) -> Bool
    @objc optional func regionVisit(_ region: CLCircularRegion)
}

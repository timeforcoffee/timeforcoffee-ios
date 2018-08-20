//
//  TFCLocationManager.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 21.06.15.
//  Copyright © 2015 Christian Stocker. All rights reserved.
//

import Foundation
import CoreLocation
import WatchConnectivity

public final class TFCLocationManager: TFCLocationManagerBase {

    var pendingRegionCalls:[CLCircularRegion] = []

    override func requestLocation() {
        self.locationManager.startUpdatingLocation()

/*  
        if #available(iOS 9, *) {
            self.locationManager.requestLocation()
        } else {
            self.locationManager.startUpdatingLocation()
        }*/
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.locationManagerBase(manager, didUpdateLocations: locations)
        for region in pendingRegionCalls {
            self.delegate?.regionVisit?(region)
        }
        pendingRegionCalls.removeAll()
    }

    public func startReceivingVisits() {
        if (CLLocationManager.locationServicesEnabled()) {
            self.locationManager.startMonitoringVisits()
        }
    }
    public func stopReceivingVisits() {
        self.locationManager.stopMonitoringVisits()
    }

    public func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {

        if visit.departureDate == Date.distantFuture {
            DLog("did Visit received in")
            DLog("arrival Date: \(visit.arrivalDate)")
            DLog("arrival Loc: \(visit.coordinate)")

            let _ = self.delegate?.locationVisit?(visit.coordinate, date: visit.arrivalDate, arrival: true)
        } else {
            DLog("did Visit received gone")
            DLog("departed Date: \(visit.departureDate)")
            DLog("departed Loc: \(visit.coordinate)")
            if (self.delegate?.locationVisit?(visit.coordinate, date: visit.departureDate, arrival: false) == true) {
                DLog("delegate callback worked");
            } else {
                DLog("delegate callback didnt work");
            }

            // The visit is complete
        }
    }

    override func getLocationRequest(_ lm: CLLocationManager) {
        if #available(iOS 9, *) {
            if (WCSession.isSupported()) {
                let wcsession = WCSession.default
                if (wcsession.isComplicationEnabled == true) {
                    lm.requestAlwaysAuthorization()
                    return
                }
            }
        }
        super.getLocationRequest(lm)
    }

    func locationManager(_ manager: CLLocationManager!, monitoringDidFailForRegion region: CLRegion!, withError error: NSError!) {
        DLog("monitoringDidFailForRegion for fence \(region.identifier), error: \(String(describing: error))", toFile: true)
    }

    func locationManager(_ manager: CLLocationManager!, didEnterRegion region: CLRegion!) {
        DLog("fence entered \(String(describing: region))", toFile: true)
        if let region = region as? CLCircularRegion {
            if (self.delegate != nil) {
                self.pendingRegionCalls.append(region)
            }
        }
        self.requestLocation()
    }

    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        DLog("fence exit \(region)", toFile: true)
        if let region = region as? CLCircularRegion {
            if (region.identifier == "__updateGeofences__") {
                if (self.delegate != nil) {
                    self.pendingRegionCalls.append(region)
                }
            }
        }
        self.requestLocation()
    }
}


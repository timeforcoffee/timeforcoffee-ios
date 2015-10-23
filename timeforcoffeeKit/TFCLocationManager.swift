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

    public func startReceivingVisits() {
        DLog("TFCVisits init", toFile: true)
        if (CLLocationManager.locationServicesEnabled()) {
            self.locationManager.startMonitoringVisits()
        }
    }
    public func stopReceivingVisits() {
        self.locationManager.stopMonitoringVisits()
    }

    public func locationManager(manager: CLLocationManager, didVisit visit: CLVisit) {

        if visit.departureDate.isEqualToDate(NSDate.distantFuture()) {
            DLog("did Visit received in", toFile: true)
            DLog("arrival Date: \(visit.arrivalDate)", toFile: true)
            DLog("arrival Loc: \(visit.coordinate)", toFile: true)

            self.delegate.locationVisit?(visit.coordinate, date: visit.arrivalDate, arrival: true)
        } else {
            DLog("did Visit received gone", toFile: true)
            DLog("departed Date: \(visit.departureDate)", toFile: true)
            DLog("departed Loc: \(visit.coordinate)", toFile: true)
            if (self.delegate.locationVisit?(visit.coordinate, date: visit.departureDate, arrival: false) == true) {
                DLog("delegate callback worked", toFile: true);
            } else {
                DLog("delegate callback didnt work", toFile: true);
            }

            // The visit is complete
        }
    }

    override func getLocationRequest(lm: CLLocationManager) {
        if #available(iOS 9, *) {
            if (WCSession.isSupported()) {
                let wcsession = WCSession.defaultSession()
                if (wcsession.complicationEnabled == true) {
                    lm.requestAlwaysAuthorization()
                    return
                }
            }
        }
        super.getLocationRequest(lm)
    }

}


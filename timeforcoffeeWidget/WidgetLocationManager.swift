//
//  WidgetLocationManager.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import CoreLocation
import WidgetKit
import os.log

private let logger = Logger(subsystem: "ch.opendata.timeforcoffee.widget", category: "Location")

/// A simple location manager for widget use
/// Widgets have limited execution time, so this uses last known location when possible
class WidgetLocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?
    private var hasCompleted = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Get the current location (async wrapper)
    func getCurrentLocation() async -> CLLocation? {
        // First check if we have authorization
        let status = locationManager.authorizationStatus
        logger.debug("Location authorization status: \(String(describing: status.rawValue))")

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            logger.warning("No location permission - status: \(String(describing: status.rawValue))")
            return nil
        }

        // Try to get cached location first (within last 5 minutes)
        if let cachedLocation = locationManager.location,
           cachedLocation.timestamp.timeIntervalSinceNow > -300 {
            logger.debug("Using cached location: \(cachedLocation.coordinate.latitude), \(cachedLocation.coordinate.longitude)")
            return cachedLocation
        }

        logger.debug("Requesting fresh location...")

        // Request a fresh location
        return await withCheckedContinuation { continuation in
            hasCompleted = false
            completion = { location in
                continuation.resume(returning: location)
            }
            locationManager.requestLocation()

            // Timeout after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self, !self.hasCompleted else { return }
                self.hasCompleted = true
                logger.warning("Location request timed out, using cached: \(String(describing: self.locationManager.location))")
                self.completion?(self.locationManager.location)
                self.completion = nil
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !hasCompleted, let location = locations.last else { return }
        hasCompleted = true
        logger.debug("Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        completion?(location)
        completion = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        logger.error("Location error: \(error.localizedDescription)")
        // Return cached location on error
        completion?(locationManager.location)
        completion = nil
    }
}

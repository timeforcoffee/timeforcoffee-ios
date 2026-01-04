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
            // Try to use stored location as fallback
            return loadStoredLocation()
        }

        // Try to get cached location first (within last 5 minutes)
        if let cachedLocation = locationManager.location,
           cachedLocation.timestamp.timeIntervalSinceNow > -300 {
            logger.debug("Using cached location: \(cachedLocation.coordinate.latitude), \(cachedLocation.coordinate.longitude)")
            // Store for future fallback
            storeLocation(cachedLocation)
            return cachedLocation
        }

        logger.debug("Requesting fresh location...")

        // Request a fresh location
        let location = await withCheckedContinuation { continuation in
            hasCompleted = false
            completion = { location in
                continuation.resume(returning: location)
            }
            locationManager.requestLocation()

            // Timeout after 3 seconds (shorter for lock screen widgets)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self, !self.hasCompleted else { return }
                self.hasCompleted = true
                logger.warning("Location request timed out, using cached: \(String(describing: self.locationManager.location))")
                self.completion?(self.locationManager.location)
                self.completion = nil
            }
        }

        // Store successful location for fallback
        if let location = location {
            storeLocation(location)
            return location
        }

        // Final fallback: use stored location
        return loadStoredLocation()
    }

    // MARK: - Location Storage (for fallback when location unavailable)

    private let locationKey = "widgetLastKnownLocation"
    private let locationTimestampKey = "widgetLastKnownLocationTimestamp"

    private func storeLocation(_ location: CLLocation) {
        let defaults = UserDefaults(suiteName: "group.ch.opendata.timeforcoffee")
        defaults?.set(location.coordinate.latitude, forKey: "\(locationKey)_lat")
        defaults?.set(location.coordinate.longitude, forKey: "\(locationKey)_lon")
        defaults?.set(Date().timeIntervalSince1970, forKey: locationTimestampKey)
    }

    private func loadStoredLocation() -> CLLocation? {
        let defaults = UserDefaults(suiteName: "group.ch.opendata.timeforcoffee")
        guard let lat = defaults?.object(forKey: "\(locationKey)_lat") as? Double,
              let lon = defaults?.object(forKey: "\(locationKey)_lon") as? Double,
              let timestamp = defaults?.object(forKey: locationTimestampKey) as? Double else {
            logger.warning("No stored location available")
            return nil
        }

        // Accept stored location up to 1 hour old
        let age = Date().timeIntervalSince1970 - timestamp
        if age > 3600 {
            logger.warning("Stored location too old: \(age)s")
            return nil
        }

        logger.debug("Using stored fallback location: \(lat), \(lon) (age: \(Int(age))s)")
        return CLLocation(latitude: lat, longitude: lon)
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

//
//  DepartureTimelineProvider.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import WidgetKit
import SwiftUI
import CoreLocation
import os.log
import timeforcoffeeKit

private let logger = Logger(subsystem: "ch.opendata.timeforcoffee.widget", category: "Timeline")

/// Timeline provider for the departure widget with intent configuration
struct DepartureTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = DepartureEntry
    typealias Intent = DepartureWidgetConfigurationIntent

    private let locationManager = WidgetLocationManager()

    /// Provides a placeholder entry for the widget gallery
    func placeholder(in context: Context) -> DepartureEntry {
        DepartureEntry.placeholder
    }

    /// Provides a snapshot for the widget gallery and transient situations
    func snapshot(for configuration: DepartureWidgetConfigurationIntent, in context: Context) async -> DepartureEntry {
        if context.isPreview {
            // Show different placeholder based on configuration
            switch configuration.displayMode {
            case .nearbyStations:
                return DepartureEntry.nearbyPlaceholder
            case .nearbyStation, .specificStation, .nearestFavorite:
                return DepartureEntry.placeholder
            }
        }

        // Try to get real data for snapshot
        return await fetchEntry(for: configuration)
    }

    /// Provides a timeline of entries for the widget
    func timeline(for configuration: DepartureWidgetConfigurationIntent, in context: Context) async -> Timeline<DepartureEntry> {
        let currentEntry = await fetchEntry(for: configuration)

        // Create timeline entries
        var entries: [DepartureEntry] = []

        // Round to start of current minute for consistent minute-boundary updates
        let now = Date()
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minuteStart = calendar.date(from: nowComponents) ?? now

        // Dynamic refresh rate based on next departure
        let timelineMinutes = calculateRefreshInterval(for: currentEntry, from: now)

        for minuteOffset in stride(from: 0, to: timelineMinutes, by: 1) {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: minuteStart)!

            if currentEntry.viewMode == .singleStation {
                // Filter departures that have already left (departure must be in current minute or later)
                let validDepartures = currentEntry.departures.filter { departure in
                    departure.departureTime >= entryDate
                }

                let entry = DepartureEntry(
                    date: entryDate,
                    viewMode: .singleStation,
                    stationName: currentEntry.stationName,
                    stationId: currentEntry.stationId,
                    departures: validDepartures,
                    nearbyStations: [],
                    isPlaceholder: currentEntry.isPlaceholder,
                    errorMessage: currentEntry.errorMessage
                )
                entries.append(entry)
            } else {
                // Nearby stations mode - keep departures, view handles showing 0'
                let entry = DepartureEntry(
                    date: entryDate,
                    viewMode: .nearbyStations,
                    stationName: currentEntry.stationName,
                    stationId: currentEntry.stationId,
                    departures: [],
                    nearbyStations: currentEntry.nearbyStations,
                    isPlaceholder: currentEntry.isPlaceholder,
                    errorMessage: currentEntry.errorMessage
                )
                entries.append(entry)
            }
        }

        // Request refresh after timeline ends
        let refreshDate = calendar.date(byAdding: .minute, value: timelineMinutes, to: minuteStart)!
        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    /// Fetches an entry based on the widget configuration
    private func fetchEntry(for configuration: DepartureWidgetConfigurationIntent) async -> DepartureEntry {
        logger.debug("fetchEntry - displayMode: \(configuration.displayMode.rawValue)")

        switch configuration.displayMode {
        case .nearestFavorite:
            // Nearest favorite station mode - prefer nearby favorites with filters
            logger.debug("Nearest favorite mode - getting location")
            if let location = await locationManager.getCurrentLocation() {
                logger.debug("Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                return await WidgetDataFetcher.fetchDeparturesForNearestFavorite(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            logger.warning("No location for nearest favorite mode")
            return DepartureEntry.empty(message: NSLocalizedString("Location unavailable", comment: ""))

        case .nearbyStations:
            // Nearby stations mode - show multiple stations
            logger.debug("Nearby stations mode - getting location")
            if let location = await locationManager.getCurrentLocation() {
                logger.debug("Got location for nearby: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                return await WidgetDataFetcher.fetchNearbyStationsEntry(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            logger.warning("No location for nearby stations mode")
            return DepartureEntry.empty(message: NSLocalizedString("Location unavailable", comment: ""))

        case .specificStation:
            // Specific station mode - use the selected station
            if let station = configuration.station {
                logger.debug("Specific station mode: \(station.name)")
                return await WidgetDataFetcher.fetchDepartures(stationId: station.id, stationName: station.name)
            }
            // No station selected, show message
            logger.warning("Specific station mode but no station selected")
            return DepartureEntry.empty(message: NSLocalizedString("Edit widget to select a station", comment: ""))

        case .nearbyStation:
            // Nearest station mode - find closest station
            logger.debug("Nearest station mode - getting location")
            if let location = await locationManager.getCurrentLocation() {
                logger.debug("Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                return await WidgetDataFetcher.fetchDeparturesForNearestStation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            logger.warning("No location for nearest station mode")
            return DepartureEntry.empty(message: NSLocalizedString("Location unavailable", comment: ""))
        }
    }

    /// Calculates the refresh interval based on when the next departure is
    /// - Returns refresh interval in minutes (15-60)
    private func calculateRefreshInterval(for entry: DepartureEntry, from now: Date) -> Int {
        // Find the earliest departure time
        let nextDepartureTime: Date?

        if entry.viewMode == .singleStation {
            nextDepartureTime = entry.departures.first?.departureTime
        } else {
            // For nearby stations mode, find earliest across all stations
            nextDepartureTime = entry.nearbyStations
                .compactMap { $0.departures.first?.departureTime }
                .min()
        }

        // If no departures found, use longer interval
        guard let nextTime = nextDepartureTime else {
            logger.debug("No departures found, using 60 minute refresh")
            return 60
        }

        let minutesUntilNextDeparture = Int(nextTime.timeIntervalSince(now) / 60)
        logger.debug("Minutes until next departure: \(minutesUntilNextDeparture)")

        // Dynamic refresh strategy:
        // - Next departure in < 60 min: refresh every 15 min (frequent updates needed)
        // - Next departure in 1-2 hours: refresh every 30 min
        // - Next departure in > 2 hours: refresh every 60 min (night mode / low frequency)
        if minutesUntilNextDeparture < 60 {
            return 15
        } else if minutesUntilNextDeparture < 120 {
            return 30
        } else {
            return 60
        }
    }
}

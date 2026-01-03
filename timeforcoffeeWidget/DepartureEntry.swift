//
//  DepartureEntry.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import WidgetKit
import SwiftUI

/// View mode for the widget
enum WidgetViewMode: String, Codable {
    case singleStation
    case nearbyStations
}

/// Timeline entry for the departure widget
struct DepartureEntry: TimelineEntry {
    let date: Date
    let viewMode: WidgetViewMode

    // Single station mode
    let stationName: String
    let stationId: String
    let departures: [WidgetDeparture]

    // Nearby stations mode
    let nearbyStations: [NearbyStation]

    let isPlaceholder: Bool
    let errorMessage: String?

    init(
        date: Date,
        viewMode: WidgetViewMode = .singleStation,
        stationName: String,
        stationId: String,
        departures: [WidgetDeparture],
        nearbyStations: [NearbyStation] = [],
        isPlaceholder: Bool = false,
        errorMessage: String? = nil
    ) {
        self.date = date
        self.viewMode = viewMode
        self.stationName = stationName
        self.stationId = stationId
        self.departures = departures
        self.nearbyStations = nearbyStations
        self.isPlaceholder = isPlaceholder
        self.errorMessage = errorMessage
    }

    /// Sample entry for widget preview (single station)
    static var placeholder: DepartureEntry {
        DepartureEntry(
            date: Date(),
            viewMode: .singleStation,
            stationName: "Zurich HB",
            stationId: "8503000",
            departures: [
                WidgetDeparture(
                    id: "1",
                    line: "S3",
                    destination: "Wetzikon",
                    departureTime: Date().addingTimeInterval(180),
                    isRealtime: true,
                    colorFg: "#000000",
                    colorBg: "#FFCC00",
                    platform: "3"
                ),
                WidgetDeparture(
                    id: "2",
                    line: "IC5",
                    destination: "Geneve-Aeroport",
                    departureTime: Date().addingTimeInterval(420),
                    isRealtime: true,
                    colorFg: "#FFFFFF",
                    colorBg: "#FF0000",
                    platform: "7"
                ),
                WidgetDeparture(
                    id: "3",
                    line: "S8",
                    destination: "Pfaffikon SZ",
                    departureTime: Date().addingTimeInterval(600),
                    isRealtime: false,
                    colorFg: "#000000",
                    colorBg: "#87CEEB",
                    platform: "41"
                ),
                WidgetDeparture(
                    id: "4",
                    line: "IR36",
                    destination: "Basel SBB",
                    departureTime: Date().addingTimeInterval(780),
                    isRealtime: true,
                    colorFg: "#000000",
                    colorBg: "#FFFFFF",
                    platform: "12"
                )
            ],
            isPlaceholder: true
        )
    }

    /// Sample entry for nearby stations preview
    static var nearbyPlaceholder: DepartureEntry {
        DepartureEntry(
            date: Date(),
            viewMode: .nearbyStations,
            stationName: "",
            stationId: "",
            departures: [],
            nearbyStations: [
                NearbyStation(
                    id: "8503000",
                    name: "Zurich HB",
                    isFavorite: true,
                    firstDeparture: WidgetDeparture(
                        id: "1", line: "S3", destination: "Wetzikon",
                        departureTime: Date().addingTimeInterval(180),
                        isRealtime: true, colorFg: "#000000", colorBg: "#FFCC00", platform: nil
                    )
                ),
                NearbyStation(
                    id: "8591123",
                    name: "Zurich, Central",
                    isFavorite: false,
                    firstDeparture: WidgetDeparture(
                        id: "2", line: "31", destination: "Schlieren",
                        departureTime: Date().addingTimeInterval(120),
                        isRealtime: true, colorFg: "#FFFFFF", colorBg: "#0066CC", platform: nil
                    )
                ),
                NearbyStation(
                    id: "8591105",
                    name: "Zurich, Bahnhofquai",
                    isFavorite: false,
                    firstDeparture: WidgetDeparture(
                        id: "3", line: "4", destination: "Tiefenbrunnen",
                        departureTime: Date().addingTimeInterval(60),
                        isRealtime: true, colorFg: "#FFFFFF", colorBg: "#009933", platform: nil
                    )
                )
            ],
            isPlaceholder: true
        )
    }

    /// Empty entry when no station is configured
    static func empty(message: String? = nil) -> DepartureEntry {
        DepartureEntry(
            date: Date(),
            stationName: "",
            stationId: "",
            departures: [],
            isPlaceholder: false,
            errorMessage: message ?? NSLocalizedString("No station selected", comment: "")
        )
    }
}

/// A nearby station with its first departure
struct NearbyStation: Identifiable {
    let id: String
    let name: String
    let isFavorite: Bool
    let firstDeparture: WidgetDeparture?
}

/// A single departure for display in the widget
struct WidgetDeparture: Identifiable, Codable {
    let id: String
    let line: String
    let destination: String
    let departureTime: Date
    let isRealtime: Bool
    let colorFg: String
    let colorBg: String
    let platform: String?

    /// Minutes until departure (can be negative if departed)
    var minutesUntilDeparture: Int {
        let interval = departureTime.timeIntervalSinceNow
        return max(0, Int(interval / 60))
    }

    /// Formatted minutes string (e.g., "3'" or ">59'")
    var minutesDisplay: String {
        let minutes = minutesUntilDeparture
        if minutes >= 60 {
            return ">59'"
        }
        return "\(minutes)'"
    }
}

//
//  timeforcoffeeWidget.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import WidgetKit
import SwiftUI

/// The main widget configuration
struct TimeforcoffeeWidget: Widget {
    let kind: String = "ch.opendata.timeforcoffee.widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DepartureWidgetConfigurationIntent.self,
            provider: DepartureTimelineProvider()
        ) { entry in
            TimeforcoffeeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Departures")
        .description("Shows upcoming departures from stations.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// The widget entry view that renders based on widget family and view mode
struct TimeforcoffeeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DepartureEntry

    var body: some View {
        switch entry.viewMode {
        case .singleStation:
            singleStationView
        case .nearbyStations:
            nearbyStationsView
        }
    }

    @ViewBuilder
    private var singleStationView: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }

    @ViewBuilder
    private var nearbyStationsView: some View {
        switch family {
        case .systemSmall:
            SmallNearbyStationsView(entry: entry)
        case .systemMedium:
            MediumNearbyStationsView(entry: entry)
        case .systemLarge:
            LargeNearbyStationsView(entry: entry)
        default:
            MediumNearbyStationsView(entry: entry)
        }
    }
}

/// Widget bundle entry point
@main
struct TimeforcoffeeWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimeforcoffeeWidget()
    }
}

// MARK: - Deep Linking

extension DepartureEntry {
    /// URL for deep linking to the station in the main app
    var widgetURL: URL? {
        guard !stationId.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "timeforcoffee"
        components.host = "station"
        components.queryItems = [
            URLQueryItem(name: "id", value: stationId),
            URLQueryItem(name: "name", value: stationName)
        ]
        return components.url
    }
}

// MARK: - Previews

#Preview("Small - Station", as: .systemSmall) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.placeholder
}

#Preview("Small - Nearby", as: .systemSmall) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.nearbyPlaceholder
}

#Preview("Medium - Station", as: .systemMedium) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.placeholder
}

#Preview("Medium - Nearby", as: .systemMedium) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.nearbyPlaceholder
}

#Preview("Large - Station", as: .systemLarge) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.placeholder
}

#Preview("Large - Nearby", as: .systemLarge) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.nearbyPlaceholder
}

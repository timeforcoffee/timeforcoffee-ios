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
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

/// Nearby Stations widget - shows multiple nearby stations with their next departures
struct NearbyStationsWidget: Widget {
    let kind: String = "ch.opendata.timeforcoffee.nearbystations"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: NearbyStationsWidgetConfigurationIntent.self,
            provider: NearbyStationsTimelineProvider()
        ) { entry in
            TimeforcoffeeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Nearby Stations")
        .description("Shows multiple nearby stations with their next departures.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// The widget entry view that renders based on widget family and view mode
struct TimeforcoffeeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DepartureEntry

    var body: some View {
        switch family {
        // Lock screen widgets
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)

        // Home screen widgets
        default:
            switch entry.viewMode {
            case .singleStation:
                singleStationView
            case .nearbyStations:
                nearbyStationsView
            }
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
        NearbyStationsWidget()
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

// MARK: - Lock Screen Widget Previews

#Preview("Lock Screen - Inline", as: .accessoryInline) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.placeholder
}

#Preview("Lock Screen - Rectangular", as: .accessoryRectangular) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.placeholder
}

#Preview("Lock Screen - Rectangular Nearby", as: .accessoryRectangular) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.nearbyPlaceholder
}

#Preview("Lock Screen - Circular", as: .accessoryCircular) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.placeholder
}

//
//  LockScreenViews.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - Accessory Inline View

/// Lock screen inline widget - shows a single line of text
/// Example: "S3 Wetzikon 3'"
struct AccessoryInlineView: View {
    let entry: DepartureEntry

    var body: some View {
        if let errorMessage = entry.errorMessage {
            Text(errorMessage)
        } else if let departure = firstDeparture {
            Text("\(departure.line) \(departure.formattedDestination) \(departure.minutesDisplay(relativeTo: entry.date))")
        } else {
            Text("No departures")
        }
    }

    private var firstDeparture: WidgetDeparture? {
        switch entry.viewMode {
        case .singleStation:
            return entry.departures.first { $0.departureTime > entry.date.addingTimeInterval(-60) }
        case .nearbyStations:
            return entry.nearbyStations.first?.firstDeparture(relativeTo: entry.date)
        }
    }
}

// MARK: - Accessory Rectangular View

/// Lock screen rectangular widget - shows station name and 2-3 departures
struct AccessoryRectangularView: View {
    let entry: DepartureEntry

    var body: some View {
        if let errorMessage = entry.errorMessage {
            VStack(alignment: .leading) {
                Text(errorMessage)
                    .font(.headline)
            }
        } else {
            switch entry.viewMode {
            case .singleStation:
                singleStationContent
            case .nearbyStations:
                nearbyStationsContent
            }
        }
    }

    @ViewBuilder
    private var singleStationContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Station name header
            Text(entry.stationName)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            // Up to 2 departures
            ForEach(validDepartures.prefix(2)) { departure in
                AccessoryDepartureRow(departure: departure, entryDate: entry.date)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var nearbyStationsContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nearby")
                .font(.headline)
                .fontWeight(.semibold)

            // Show first 2 nearby stations
            ForEach(entry.nearbyStations.prefix(2)) { station in
                if let departure = station.firstDeparture(relativeTo: entry.date) {
                    HStack(spacing: 2) {
                        Text(departure.line)
                            .fontWeight(.bold)
                        Text(station.name)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(departure.minutesDisplay(relativeTo: entry.date))
                            .fontWeight(.semibold)
                            .layoutPriority(1)
                    }
                    .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var validDepartures: [WidgetDeparture] {
        entry.departures.filter { $0.departureTime > entry.date.addingTimeInterval(-60) }
    }
}

/// Compact departure row for rectangular accessory widget
struct AccessoryDepartureRow: View {
    let departure: WidgetDeparture
    let entryDate: Date

    var body: some View {
        HStack(spacing: 2) {
            Text(departure.line)
                .fontWeight(.bold)

            Text(departure.formattedDestination)
                .lineLimit(1)

            Spacer(minLength: 2)

            Text(departure.minutesDisplay(relativeTo: entryDate))
                .fontWeight(.semibold)
                .layoutPriority(1)
        }
        .font(.caption)
    }
}

// MARK: - Accessory Circular View

/// Lock screen circular widget - shows next departure in a circular gauge
struct AccessoryCircularView: View {
    let entry: DepartureEntry

    var body: some View {
        if let errorMessage = entry.errorMessage {
            ZStack {
                AccessoryWidgetBackground()
                Text("--")
                    .font(.title2)
                    .fontWeight(.bold)
            }
        } else if let departure = firstDeparture {
            Gauge(value: gaugeValue(for: departure)) {
                Text(departure.line)
                    .font(.caption2)
                    .fontWeight(.bold)
            } currentValueLabel: {
                Text(minutesText(for: departure))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "tram.fill")
                        .font(.caption)
                    Text("--")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var firstDeparture: WidgetDeparture? {
        switch entry.viewMode {
        case .singleStation:
            return entry.departures.first { $0.departureTime > entry.date.addingTimeInterval(-60) }
        case .nearbyStations:
            return entry.nearbyStations.first?.firstDeparture(relativeTo: entry.date)
        }
    }

    /// Gauge value from 0-1, where 1 is 0 minutes and 0 is 15+ minutes
    private func gaugeValue(for departure: WidgetDeparture) -> Double {
        let minutes = departure.minutesUntilDeparture(relativeTo: entry.date)
        let clamped = max(0, min(15, minutes))
        return 1.0 - (Double(clamped) / 15.0)
    }

    private func minutesText(for departure: WidgetDeparture) -> String {
        let minutes = departure.minutesUntilDeparture(relativeTo: entry.date)
        if minutes >= 60 {
            return ">59"
        }
        return "\(minutes)"
    }
}

// MARK: - Previews

#Preview("Inline", as: .accessoryInline) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.placeholder
}

#Preview("Rectangular - Nearby", as: .accessoryRectangular) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.nearbyPlaceholder
}

#Preview("Circular", as: .accessoryCircular) {
    TimeforcoffeeWidget()
} timeline: {
    DepartureEntry.placeholder
}

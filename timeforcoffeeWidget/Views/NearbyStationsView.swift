//
//  NearbyStationsView.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI
import WidgetKit

/// A row displaying a nearby station with its first departure
struct NearbyStationRowView: View {
    let station: NearbyStation
    let config: WidgetConfig
    let entryDate: Date

    var body: some View {
        Link(destination: stationURL) {
            HStack(spacing: config.spacing.elementSpacing) {
                // Station name (bold if favorite)
                Text(station.name)
                    .font(
                        .system(size: config.fontSize.content, weight: station.isFavorite ? .semibold : .regular)
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)

                Spacer(minLength: 4)

                // First departure info - use entryDate for accurate timeline display
                if let departure = station.firstDeparture(relativeTo: entryDate) {
                    LineBadgeView(
                        line: departure.line,
                        colorFg: departure.colorFg,
                        colorBg: departure.colorBg,
                        fontSize: config.fontSize.content - 3
                    )

                    Text(departure.minutesDisplay(relativeTo: entryDate))
                        .font(.system(size: config.fontSize.minutes, weight: .semibold, design: .rounded))
                        .foregroundColor(minutesColor(for: departure.minutesUntilDeparture(relativeTo: entryDate)))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .layoutPriority(1)
                } else {
                    Text("--")
                        .font(.system(size: config.fontSize.content))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, config.spacing.rowVerticalPadding)
        }
    }

    /// Color for minutes display based on urgency (matches DepartureRowView)
    private func minutesColor(for minutes: Int) -> Color {
        if minutes <= 2 {
            return .red
        } else if minutes <= 5 {
            return .orange
        }
        return .primary
    }

    private var stationURL: URL {
        var components = URLComponents()
        components.scheme = "timeforcoffee"
        components.host = "station"
        components.queryItems = [
            URLQueryItem(name: "id", value: station.id),
            URLQueryItem(name: "name", value: station.name),
        ]
        return components.url ?? URL(string: "timeforcoffee://nearby")!
    }
}

/// Small widget view for nearby stations
struct SmallNearbyStationsView: View {
    let entry: DepartureEntry
    private let config = WidgetConfig.smallNearby

    var body: some View {
        if let error = entry.errorMessage {
            errorView(message: error)
        } else if entry.nearbyStations.isEmpty {
            emptyView
        } else {
            contentView
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: config.spacing.rowSpacing) {
            // Title
            Text(NSLocalizedString("Nearby Stations", comment: ""))
                .font(.system(size: config.fontSize.title, weight: .semibold))
                .foregroundColor(.secondary)

            // Stations
            ForEach(entry.nearbyStations.prefix(config.limits.maxItems)) { station in
                NearbyStationRowView(station: station, config: config, entryDate: entry.date)
            }

            Spacer(minLength: 0)
        }
        .padding(config.spacing.padding)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text("No stations nearby")
                .font(.system(size: config.fontSize.secondary))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tram.fill")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)

            Text(message)
                .font(.system(size: config.fontSize.secondary))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Medium widget view for nearby stations
struct MediumNearbyStationsView: View {
    let entry: DepartureEntry
    private let config = WidgetConfig.mediumNearby

    var body: some View {
        if let error = entry.errorMessage {
            errorView(message: error)
        } else if entry.nearbyStations.isEmpty {
            emptyView
        } else {
            contentView
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: config.spacing.rowSpacing) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: config.fontSize.icon))
                    .foregroundColor(.accentColor)

                Text(NSLocalizedString("Nearby Stations", comment: ""))
                    .font(.system(size: config.fontSize.title, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(entry.date, style: .time)
                    .font(.system(size: config.fontSize.secondary))
                    .foregroundColor(.secondary)
            }
            Divider()
                .padding(.vertical, 2)

            // Stations
            ForEach(entry.nearbyStations.prefix(config.limits.maxItems)) { station in
                NearbyStationRowView(station: station, config: config, entryDate: entry.date)
            }

            Spacer(minLength: 0)
        }
        .padding(config.spacing.padding)
    }

    private var emptyView: some View {
        HStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Nearby Stations", comment: ""))
                    .font(.system(size: config.fontSize.title, weight: .semibold))
                    .foregroundColor(.primary)

                Text("No stations found nearby")
                    .font(.system(size: config.fontSize.content))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "tram.fill")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Time for Coffee!")
                    .font(.system(size: config.fontSize.title, weight: .semibold))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: config.fontSize.content))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Large widget view for nearby stations
struct LargeNearbyStationsView: View {
    let entry: DepartureEntry
    private let config = WidgetConfig.largeNearby

    var body: some View {
        if let error = entry.errorMessage {
            errorView(message: error)
        } else if entry.nearbyStations.isEmpty {
            emptyView
        } else {
            contentView
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: config.spacing.rowSpacing) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: config.fontSize.icon))
                    .foregroundColor(.accentColor)

                Text(NSLocalizedString("Nearby Stations", comment: ""))
                    .font(.system(size: config.fontSize.title, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(entry.date, style: .time)
                    .font(.system(size: config.fontSize.secondary))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Column headers
            HStack {
                Text(NSLocalizedString("Station", comment: ""))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text(NSLocalizedString("Line", comment: ""))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 40)

                Text(NSLocalizedString("Dep.", comment: ""))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 35, alignment: .trailing)
            }

            // Stations
            ForEach(entry.nearbyStations.prefix(config.limits.maxItems)) { station in
                NearbyStationRowView(station: station, config: config, entryDate: entry.date)
            }

            Spacer(minLength: 0)
        }
        .padding(config.spacing.padding)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(NSLocalizedString("Nearby Stations", comment: ""))
                    .font(.system(size: config.fontSize.title, weight: .semibold))
                    .foregroundColor(.primary)

                Text("No stations found nearby")
                    .font(.system(size: config.fontSize.content))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "tram.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Time for Coffee!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: config.fontSize.content))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Small - Nearby") {
    SmallNearbyStationsView(entry: DepartureEntry.nearbyPlaceholder)
        .previewContext(WidgetPreviewContext(family: .systemSmall))
}

#Preview("Medium - Nearby") {
    MediumNearbyStationsView(entry: DepartureEntry.nearbyPlaceholder)
        .previewContext(WidgetPreviewContext(family: .systemMedium))
}

#Preview("Large - Nearby") {
    LargeNearbyStationsView(entry: DepartureEntry.nearbyPlaceholder)
        .previewContext(WidgetPreviewContext(family: .systemLarge))
}

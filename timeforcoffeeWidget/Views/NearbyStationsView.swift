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
    var compact: Bool = false
    var large: Bool = false

    private var fontSize: CGFloat {
        if compact { return 13 }
        if large { return 15 }
        return 14
    }

    var body: some View {
        Link(destination: stationURL) {
            HStack(spacing: compact ? 4 : 8) {
                // Station name (bold if favorite)
                Text(station.name)
                    .font(.system(size: fontSize, weight: station.isFavorite ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)

                Spacer(minLength: 4)

                // First departure info
                if let departure = station.firstDeparture {
                    LineBadgeView(
                        line: departure.line,
                        colorFg: departure.colorFg,
                        colorBg: departure.colorBg,
                        size: compact ? .small : .small
                    )

                    Text(departure.minutesDisplay)
                        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(departure.minutesUntilDeparture <= 2 ? .red : .primary)
                        .frame(minWidth: compact ? 24 : 30, alignment: .trailing)
                } else {
                    Text("--")
                        .font(.system(size: fontSize))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, compact ? 3 : 4)
        }
    }

    private var stationURL: URL {
        var components = URLComponents()
        components.scheme = "timeforcoffee"
        components.host = "station"
        components.queryItems = [
            URLQueryItem(name: "id", value: station.id),
            URLQueryItem(name: "name", value: station.name)
        ]
        return components.url ?? URL(string: "timeforcoffee://nearby")!
    }
}

/// Small widget view for nearby stations (shows 2 stations)
struct SmallNearbyStationsView: View {
    let entry: DepartureEntry

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
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text(NSLocalizedString("Nearby", comment: ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            // Stations (up to 5)
            ForEach(entry.nearbyStations.prefix(5)) { station in
                NearbyStationRowView(station: station, compact: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text("No stations nearby")
                .font(.system(size: 12))
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
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Medium widget view for nearby stations (shows 4 stations like departure view)
struct MediumNearbyStationsView: View {
    let entry: DepartureEntry

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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)

                Text(NSLocalizedString("Nearby", comment: ""))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(entry.date, style: .time)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)

            // Stations (up to 4, matching departure view)
            ForEach(entry.nearbyStations.prefix(4)) { station in
                NearbyStationRowView(station: station, compact: false)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var emptyView: some View {
        HStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Nearby Stations", comment: ""))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("No stations found nearby")
                    .font(.system(size: 12))
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Large widget view for nearby stations (shows 9 stations)
struct LargeNearbyStationsView: View {
    let entry: DepartureEntry

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
        VStack(alignment: .leading, spacing: 2) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                Text(NSLocalizedString("Nearby Stations", comment: ""))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(entry.date, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Column headers
            HStack {
                Text(NSLocalizedString("Station", comment: ""))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text(NSLocalizedString("Next", comment: ""))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)

            Divider()

            // Stations (up to 9)
            ForEach(entry.nearbyStations.prefix(9)) { station in
                NearbyStationRowView(station: station, large: true)
                Divider()
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(NSLocalizedString("Nearby Stations", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text("No stations found nearby")
                    .font(.system(size: 14))
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
                    .font(.system(size: 14))
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

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

    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            // Favorite indicator
            if station.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: compact ? 8 : 10))
                    .foregroundColor(.yellow)
            }

            // Station name
            Text(station.name)
                .font(.system(size: compact ? 11 : 13, weight: station.isFavorite ? .semibold : .regular))
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
                    .font(.system(size: compact ? 12 : 14, weight: .semibold, design: .rounded))
                    .foregroundColor(departure.minutesUntilDeparture <= 2 ? .red : .primary)
                    .frame(minWidth: compact ? 24 : 30, alignment: .trailing)
            } else {
                Text("--")
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, compact ? 1 : 2)
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer(minLength: 2)

            // Stations (up to 2)
            ForEach(entry.nearbyStations.prefix(2)) { station in
                NearbyStationRowView(station: station, compact: true)
            }

            if entry.nearbyStations.count < 2 {
                Spacer()
            }
        }
        .padding(12)
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

/// Medium widget view for nearby stations (shows 4 stations)
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

            Divider()
                .padding(.vertical, 2)

            // Stations (up to 4)
            ForEach(entry.nearbyStations.prefix(4)) { station in
                NearbyStationRowView(station: station, compact: true)
            }

            if entry.nearbyStations.count < 4 {
                Spacer()
            }
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

/// Large widget view for nearby stations (shows 6 stations)
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
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text(NSLocalizedString("Nearby Stations", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(entry.date, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            // Column headers
            HStack(spacing: 8) {
                Text("Station")
                Spacer()
                Text("Next")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.bottom, 2)

            // Stations (up to 6)
            ForEach(entry.nearbyStations.prefix(6)) { station in
                NearbyStationRowView(station: station)
                if station.id != entry.nearbyStations.prefix(6).last?.id {
                    Divider()
                        .opacity(0.5)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
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

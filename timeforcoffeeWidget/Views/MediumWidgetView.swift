//
//  MediumWidgetView.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI
import WidgetKit

/// Medium widget view showing station name and departures
struct MediumWidgetView: View {
    let entry: DepartureEntry
    private let config = WidgetConfig.mediumDepartures

    var body: some View {
        if let error = entry.errorMessage {
            errorView(message: error)
        } else if entry.departures.isEmpty {
            emptyView
        } else {
            contentView
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: config.spacing.rowSpacing) {
            // Station name header
            HStack {
                Image(systemName: "tram.fill")
                    .font(.system(size: config.fontSize.icon))
                    .foregroundColor(.accentColor)

                Text(entry.stationName)
                    .font(.system(size: config.fontSize.title, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)

                Spacer()

                // Last updated time
                Text(entry.date, style: .time)
                    .font(.system(size: config.fontSize.secondary))
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.vertical, 2)

            // Departures
            ForEach(entry.departures.prefix(config.limits.maxItems)) { departure in
                DepartureRowView(departure: departure, config: config, entryDate: entry.date, stationName: entry.stationName)
            }

            if entry.departures.count < config.limits.maxItems {
                Spacer()
            }
        }
        .padding(config.spacing.padding)
        .widgetURL(entry.widgetURL)
    }

    private var emptyView: some View {
        HStack(spacing: 16) {
            Image(systemName: "tram")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.stationName)
                    .font(.system(size: config.fontSize.title, weight: .semibold))
                    .foregroundColor(.primary)

                Text("No upcoming departures")
                    .font(.system(size: config.fontSize.secondary))
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
                    .font(.system(size: config.fontSize.secondary))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Medium - With Departures") {
    MediumWidgetView(entry: DepartureEntry.placeholder)
        .previewContext(WidgetPreviewContext(family: .systemMedium))
}

#Preview("Medium - Empty") {
    MediumWidgetView(entry: DepartureEntry(
        date: Date(),
        stationName: "Zurich HB",
        stationId: "8503000",
        departures: []
    ))
    .previewContext(WidgetPreviewContext(family: .systemMedium))
}

#Preview("Medium - Error") {
    MediumWidgetView(entry: DepartureEntry.empty(message: "Tap to select a station"))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
}

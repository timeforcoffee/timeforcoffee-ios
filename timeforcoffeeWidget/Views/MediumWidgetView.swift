//
//  MediumWidgetView.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI
import WidgetKit

/// Medium widget view showing station name and 3-4 departures
struct MediumWidgetView: View {
    let entry: DepartureEntry

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
        VStack(alignment: .leading, spacing: 4) {
            // Station name header
            HStack {
                Image(systemName: "tram.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                Text(entry.stationName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)

                Spacer()

                // Last updated time
                Text(entry.date, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.vertical, 2)

            // Departures (up to 4)
            ForEach(entry.departures.prefix(4)) { departure in
                DepartureRowView(departure: departure, compact: true)
            }

            if entry.departures.count < 4 {
                Spacer()
            }
        }
        .padding(12)
        .widgetURL(entry.widgetURL)
    }

    private var emptyView: some View {
        HStack(spacing: 16) {
            Image(systemName: "tram")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.stationName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("No upcoming departures")
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

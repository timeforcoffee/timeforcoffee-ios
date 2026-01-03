//
//  SmallWidgetView.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI
import WidgetKit

/// Small widget view showing station name and departures
struct SmallWidgetView: View {
    let entry: DepartureEntry
    private let config = WidgetConfig.smallDepartures

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
            // Station name
            Text(entry.stationName)
                .font(.system(size: config.fontSize.content, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            // Departures
            ForEach(entry.departures.prefix(config.limits.maxItems)) { departure in
                CompactDepartureRowView(departure: departure, config: config)
            }

            Spacer(minLength: 0)
        }
        .padding(config.spacing.padding)
        .widgetURL(entry.widgetURL)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tram")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text("No departures")
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

#Preview("Small - With Departures") {
    SmallWidgetView(entry: DepartureEntry.placeholder)
        .previewContext(WidgetPreviewContext(family: .systemSmall))
}

#Preview("Small - Empty") {
    SmallWidgetView(entry: DepartureEntry(
        date: Date(),
        stationName: "Zurich HB",
        stationId: "8503000",
        departures: []
    ))
    .previewContext(WidgetPreviewContext(family: .systemSmall))
}

#Preview("Small - Error") {
    SmallWidgetView(entry: DepartureEntry.empty(message: "Tap to select a station"))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
}

//
//  SmallWidgetView.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI
import WidgetKit

/// Small widget view showing station name and 2 departures
struct SmallWidgetView: View {
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
        VStack(alignment: .leading, spacing: 6) {
            // Station name
            Text(entry.stationName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            Spacer(minLength: 2)

            // Departures (up to 2)
            ForEach(entry.departures.prefix(2)) { departure in
                CompactDepartureRowView(departure: departure)
            }

            if entry.departures.count < 2 {
                Spacer()
            }
        }
        .padding(12)
        .widgetURL(entry.widgetURL)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tram")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text("No departures")
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

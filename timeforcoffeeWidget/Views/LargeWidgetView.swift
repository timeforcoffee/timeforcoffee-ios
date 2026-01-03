//
//  LargeWidgetView.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI
import WidgetKit

/// Large widget view showing station name and departures with platform info
struct LargeWidgetView: View {
    let entry: DepartureEntry
    private let config = WidgetConfig.largeDepartures

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
                .padding(.vertical, 4)

            // Column headers
            HStack(spacing: 8) {
                Text("Line")
                    .frame(width: 36, alignment: .leading)
                Text("Destination")
                Spacer()
                Text("Pl.")
                    .frame(width: 24)
                Text("Dep.")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.bottom, 2)

            // Departures
            ForEach(entry.departures.prefix(config.limits.maxItems)) { departure in
                DepartureRowView(departure: departure, config: config, showPlatform: true)
            }

            Spacer(minLength: 0)
        }
        .padding(config.spacing.padding)
        .widgetURL(entry.widgetURL)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tram")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(entry.stationName)
                    .font(.system(size: config.fontSize.title, weight: .semibold))
                    .foregroundColor(.primary)

                Text("No upcoming departures")
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

#Preview("Large - With Departures") {
    LargeWidgetView(entry: DepartureEntry.placeholder)
        .previewContext(WidgetPreviewContext(family: .systemLarge))
}

#Preview("Large - Many Departures") {
    LargeWidgetView(entry: DepartureEntry(
        date: Date(),
        stationName: "Zurich HB",
        stationId: "8503000",
        departures: [
            WidgetDeparture(id: "1", line: "S3", destination: "Wetzikon", departureTime: Date().addingTimeInterval(120), isRealtime: true, colorFg: "#000000", colorBg: "#FFCC00", platform: "3"),
            WidgetDeparture(id: "2", line: "IC5", destination: "Geneve-Aeroport", departureTime: Date().addingTimeInterval(240), isRealtime: true, colorFg: "#FFFFFF", colorBg: "#FF0000", platform: "7"),
            WidgetDeparture(id: "3", line: "S8", destination: "Pfaffikon SZ", departureTime: Date().addingTimeInterval(360), isRealtime: false, colorFg: "#000000", colorBg: "#87CEEB", platform: "41"),
            WidgetDeparture(id: "4", line: "IR36", destination: "Basel SBB", departureTime: Date().addingTimeInterval(480), isRealtime: true, colorFg: "#000000", colorBg: "#FFFFFF", platform: "12"),
            WidgetDeparture(id: "5", line: "31", destination: "Schlieren Zentrum", departureTime: Date().addingTimeInterval(600), isRealtime: true, colorFg: "#FFFFFF", colorBg: "#0066CC", platform: nil),
            WidgetDeparture(id: "6", line: "RE", destination: "Olten", departureTime: Date().addingTimeInterval(720), isRealtime: false, colorFg: "#FF0000", colorBg: "#FFFFFF", platform: "8"),
            WidgetDeparture(id: "7", line: "S2", destination: "Ziegelbrucke", departureTime: Date().addingTimeInterval(840), isRealtime: true, colorFg: "#000000", colorBg: "#99CC00", platform: "31"),
            WidgetDeparture(id: "8", line: "IR13", destination: "Chur", departureTime: Date().addingTimeInterval(960), isRealtime: true, colorFg: "#000000", colorBg: "#FFFFFF", platform: "14")
        ]
    ))
    .previewContext(WidgetPreviewContext(family: .systemLarge))
}

#Preview("Large - Empty") {
    LargeWidgetView(entry: DepartureEntry(
        date: Date(),
        stationName: "Zurich HB",
        stationId: "8503000",
        departures: []
    ))
    .previewContext(WidgetPreviewContext(family: .systemLarge))
}

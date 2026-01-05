//
//  DepartureRowView.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI
import WidgetKit

/// A row displaying a single departure
struct DepartureRowView: View {
    let departure: WidgetDeparture
    let config: WidgetConfig
    let entryDate: Date
    var showPlatform: Bool = false
    var stationName: String? = nil

    var body: some View {
        HStack(spacing: config.spacing.elementSpacing) {
            // Line badge
            LineBadgeView(
                line: departure.line,
                colorFg: departure.colorFg,
                colorBg: departure.colorBg,
                fontSize: config.fontSize.content - 3
            )

            // Destination
            Text(departure.formattedDestination(forStationName: stationName))
                .font(.system(size: config.fontSize.content, weight: .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            Spacer(minLength: 0)

            // Platform (optional)
            if showPlatform, let platform = departure.platform, !platform.isEmpty {
                Text(platform)
                    .font(.system(size: config.fontSize.secondary, weight: .light))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 20)
            }

            // Minutes until departure
            Text(departure.minutesDisplay(relativeTo: entryDate))
                .font(.system(size: config.fontSize.minutes, weight: .semibold, design: .rounded))
                .foregroundColor(minutesColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.vertical, config.spacing.rowVerticalPadding)
    }

    private var minutesColor: Color {
        let minutes = departure.minutesUntilDeparture(relativeTo: entryDate)
        if minutes <= 2 {
            return .red
        } else if minutes <= 5 {
            return .orange
        }
        return .primary
    }
}

/// A compact departure row for small widgets (just line and minutes)
struct CompactDepartureRowView: View {
    let departure: WidgetDeparture
    let config: WidgetConfig
    let entryDate: Date
    var stationName: String? = nil

    var body: some View {
        HStack(spacing: config.spacing.elementSpacing) {
            LineBadgeView(
                line: departure.line,
                colorFg: departure.colorFg,
                colorBg: departure.colorBg,
                fontSize: config.fontSize.content - 3
            )

            Text(departure.formattedDestination(forStationName: stationName))
                .font(.system(size: config.fontSize.content))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            Spacer(minLength: 0)

            Text(departure.minutesDisplay(relativeTo: entryDate))
                .font(.system(size: config.fontSize.minutes, weight: .semibold, design: .rounded))
                .foregroundColor(departure.minutesUntilDeparture(relativeTo: entryDate) <= 2 ? .red : .primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.vertical, config.spacing.rowVerticalPadding)
    }
}

#Preview("Regular Row") {
    VStack(spacing: 4) {
        DepartureRowView(
            departure: WidgetDeparture(
                id: "1",
                line: "S3",
                destination: "Wetzikon",
                departureTime: Date().addingTimeInterval(180),
                isRealtime: true,
                colorFg: "#000000",
                colorBg: "#FFCC00",
                platform: "3"
            ),
            config: .mediumDepartures,
            entryDate: Date(),
            showPlatform: true
        )
        DepartureRowView(
            departure: WidgetDeparture(
                id: "2",
                line: "IC5",
                destination: "Geneve-Aeroport",
                departureTime: Date().addingTimeInterval(120),
                isRealtime: true,
                colorFg: "#FFFFFF",
                colorBg: "#FF0000",
                platform: "7"
            ),
            config: .mediumDepartures,
            entryDate: Date(),
            showPlatform: true
        )
        DepartureRowView(
            departure: WidgetDeparture(
                id: "3",
                line: "RE",
                destination: "Olten via Brugg",
                departureTime: Date().addingTimeInterval(600),
                isRealtime: false,
                colorFg: "#000000",
                colorBg: "#FFFFFF",
                platform: nil
            ),
            config: .mediumDepartures,
            entryDate: Date()
        )
    }
    .padding()
}

#Preview("Compact Row") {
    VStack(spacing: 4) {
        CompactDepartureRowView(
            departure: WidgetDeparture(
                id: "1",
                line: "S3",
                destination: "Wetzikon",
                departureTime: Date().addingTimeInterval(180),
                isRealtime: true,
                colorFg: "#000000",
                colorBg: "#FFCC00",
                platform: nil
            ),
            config: .smallDepartures,
            entryDate: Date()
        )
        CompactDepartureRowView(
            departure: WidgetDeparture(
                id: "2",
                line: "31",
                destination: "Schlieren",
                departureTime: Date().addingTimeInterval(60),
                isRealtime: true,
                colorFg: "#FFFFFF",
                colorBg: "#0066CC",
                platform: nil
            ),
            config: .smallDepartures,
            entryDate: Date()
        )
    }
    .padding()
    .frame(width: 150)
}

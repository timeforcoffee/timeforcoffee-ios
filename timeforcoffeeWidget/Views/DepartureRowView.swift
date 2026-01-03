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
    var compact: Bool = false
    var showPlatform: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            // Line badge
            LineBadgeView(
                line: departure.line,
                colorFg: departure.colorFg,
                colorBg: departure.colorBg,
                size: compact ? .small : .medium
            )

            // Destination
            Text(departure.destination)
                .font(.system(size: compact ? 12 : 14, weight: .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            Spacer(minLength: 4)

            // Platform (optional)
            if showPlatform, let platform = departure.platform, !platform.isEmpty {
                Text(platform)
                    .font(.system(size: compact ? 10 : 12, weight: .light))
                    .foregroundColor(.secondary)
                    .frame(minWidth: compact ? 16 : 20)
            }

            // Minutes until departure
            VStack(alignment: .trailing, spacing: 0) {
                Text(departure.minutesDisplay)
                    .font(.system(size: compact ? 14 : 16, weight: .semibold, design: .rounded))
                    .foregroundColor(minutesColor)

                // Realtime indicator
                if !departure.isRealtime {
                    Text("~")
                        .font(.system(size: compact ? 8 : 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: compact ? 28 : 36, alignment: .trailing)
        }
        .padding(.vertical, compact ? 2 : 4)
    }

    private var minutesColor: Color {
        let minutes = departure.minutesUntilDeparture
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

    var body: some View {
        HStack(spacing: 4) {
            LineBadgeView(
                line: departure.line,
                colorFg: departure.colorFg,
                colorBg: departure.colorBg,
                size: .small
            )

            Text(departure.destination)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)

            Spacer(minLength: 2)

            Text(departure.minutesDisplay)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(departure.minutesUntilDeparture <= 2 ? .red : .primary)
        }
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
            )
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
            )
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
            )
        )
    }
    .padding()
    .frame(width: 150)
}

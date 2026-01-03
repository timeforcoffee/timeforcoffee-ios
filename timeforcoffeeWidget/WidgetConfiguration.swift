//
//  WidgetConfiguration.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI
import WidgetKit

let smallFont = 15.0
let largerFont = 16.0

/// Centralized configuration for widget layout and styling
struct WidgetConfig {

    // MARK: - Font Sizes

    struct FontSize {
        /// Title/header font size
        let title: CGFloat
        /// Content text font size (station name in nearby view, destination in departures view)
        let content: CGFloat
        /// Minutes display font size
        let minutes: CGFloat
        /// Secondary text (time, platform) font size
        let secondary: CGFloat
        /// Icon size
        let icon: CGFloat
    }

    // MARK: - Spacing

    struct Spacing {
        /// Vertical spacing between rows
        let rowSpacing: CGFloat
        /// Horizontal spacing between elements
        let elementSpacing: CGFloat
        /// Padding around content
        let padding: CGFloat
        /// Vertical padding for rows
        let rowVerticalPadding: CGFloat
    }

    // MARK: - Content Limits

    struct ContentLimits {
        /// Maximum number of items to show (departures or stations)
        let maxItems: Int
    }

    let fontSize: FontSize
    let spacing: Spacing
    let limits: ContentLimits

    // MARK: - Configurations for each widget size and type

    /// Small widget - Single station departures
    static let smallDepartures = WidgetConfig(
        fontSize: FontSize(
            title: smallFont,
            content: smallFont,
            minutes: smallFont,
            secondary: 10,
            icon: smallFont - 1
        ),
        spacing: Spacing(
            rowSpacing: 4,
            elementSpacing: 4,
            padding: 10,
            rowVerticalPadding: 3
        ),
        limits: ContentLimits(maxItems: 4)
    )

    /// Small widget - Nearby stations
    static let smallNearby = WidgetConfig(
        fontSize: FontSize(
            title: smallFont,
            content: smallFont,
            minutes: smallFont,
            secondary: 10,
            icon: smallFont - 1
        ),
        spacing: Spacing(
            rowSpacing: 4,
            elementSpacing: 4,
            padding: 10,
            rowVerticalPadding: 3
        ),
        limits: ContentLimits(maxItems: 4)
    )

    /// Medium widget - Single station departures
    static let mediumDepartures = WidgetConfig(
        fontSize: FontSize(
            title: largerFont,
            content: largerFont,
            minutes: largerFont,
            secondary: 10,
            icon: largerFont - 1
        ),
        spacing: Spacing(
            rowSpacing: 4,
            elementSpacing: 8,
            padding: 12,
            rowVerticalPadding: 4
        ),
        limits: ContentLimits(maxItems: 4)
    )

    /// Medium widget - Nearby stations
    static let mediumNearby = WidgetConfig(
        fontSize: FontSize(
            title: largerFont,
            content: largerFont,
            minutes: largerFont,
            secondary: 9,
            icon: largerFont - 1
        ),
        spacing: Spacing(
            rowSpacing: 0,
            elementSpacing: 8,
            padding: 12,
            rowVerticalPadding: 4
        ),
        limits: ContentLimits(maxItems: 4)
    )

    /// Large widget - Single station departures
    static let largeDepartures = WidgetConfig(
        fontSize: FontSize(
            title: largerFont,
            content: largerFont,
            minutes: largerFont,
            secondary: 11,
            icon: largerFont - 1
        ),
        spacing: Spacing(
            rowSpacing: 4,
            elementSpacing: 8,
            padding: 14,
            rowVerticalPadding: 4
        ),
        limits: ContentLimits(maxItems: 8)
    )

    /// Large widget - Nearby stations
    static let largeNearby = WidgetConfig(
        fontSize: FontSize(
            title: largerFont,
            content: largerFont,
            minutes: largerFont,
            secondary: 10,
            icon: largerFont - 1
        ),
        spacing: Spacing(
            rowSpacing: 2,
            elementSpacing: 8,
            padding: 12,
            rowVerticalPadding: 3
        ),
        limits: ContentLimits(maxItems: 9)
    )

    // MARK: - Helper to get config by widget family and view mode

    static func config(for family: WidgetFamily, viewMode: WidgetViewMode) -> WidgetConfig {
        switch (family, viewMode) {
        case (.systemSmall, .singleStation):
            return .smallDepartures
        case (.systemSmall, .nearbyStations):
            return .smallNearby
        case (.systemMedium, .singleStation):
            return .mediumDepartures
        case (.systemMedium, .nearbyStations):
            return .mediumNearby
        case (.systemLarge, .singleStation):
            return .largeDepartures
        case (.systemLarge, .nearbyStations):
            return .largeNearby
        default:
            return .mediumDepartures
        }
    }
}

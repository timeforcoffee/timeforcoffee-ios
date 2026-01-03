//
//  WidgetConfigurationIntent.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import AppIntents
import WidgetKit
import timeforcoffeeKit

/// View mode options for the widget
enum WidgetDisplayMode: String, AppEnum {
    case nearestFavorite = "nearestFavorite"
    case nearbyStation = "nearbyStation"
    case nearbyStations = "nearbyStations"
    case specificStation = "specificStation"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Display Mode"
    }

    static var caseDisplayRepresentations: [WidgetDisplayMode: DisplayRepresentation] {
        [
            .nearestFavorite: DisplayRepresentation(
                title: "Nearest Favorite",
                subtitle: "Prefer nearby favorite stations"
            ),
            .nearbyStation: DisplayRepresentation(
                title: "Nearest Station",
                subtitle: "Show departures from the nearest station"
            ),
            .nearbyStations: DisplayRepresentation(
                title: "Nearby Stations",
                subtitle: "Show multiple nearby stations"
            ),
            .specificStation: DisplayRepresentation(
                title: "Specific Station",
                subtitle: "Choose a favorite station"
            )
        ]
    }
}

/// App Entity representing a station for widget configuration
struct StationAppEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Station"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = StationEntityQuery()
}

/// Query to provide station options
struct StationEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StationAppEntity] {
        let allStations = await fetchAvailableStations()
        return allStations.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [StationAppEntity] {
        await fetchAvailableStations()
    }

    private func fetchAvailableStations() async -> [StationAppEntity] {
        var stations: [StationAppEntity] = []

        // Get favorites from shared UserDefaults
        guard let defaults = UserDefaults(suiteName: "group.ch.opendata.timeforcoffee") else {
            return stations
        }

        // Get favorite station IDs
        if let favoriteIds = defaults.array(forKey: "favorites3") as? [String] {
            for stationId in favoriteIds {
                // Try to get station info from cache
                if let station = TFCStation.initWithCacheId(stationId) {
                    stations.append(StationAppEntity(id: station.st_id, name: station.name))
                }
            }
        }

        return stations
    }
}

/// The configuration intent for the widget
struct DepartureWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Widget"
    static var description = IntentDescription("Choose what the widget displays")

    @Parameter(title: "Display Mode", default: .nearestFavorite)
    var displayMode: WidgetDisplayMode

    @Parameter(title: "Station")
    var station: StationAppEntity?

    static var parameterSummary: some ParameterSummary {
        When(\DepartureWidgetConfigurationIntent.$displayMode, .equalTo, .specificStation) {
            Summary {
                \DepartureWidgetConfigurationIntent.$displayMode
                \DepartureWidgetConfigurationIntent.$station
            }
        } otherwise: {
            Summary {
                \DepartureWidgetConfigurationIntent.$displayMode
            }
        }
    }
}

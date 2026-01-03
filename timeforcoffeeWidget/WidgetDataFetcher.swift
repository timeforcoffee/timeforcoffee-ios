//
//  WidgetDataFetcher.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import Foundation
import CoreLocation
import timeforcoffeeKit

/// Fetches departure data for the widget from the TFC API
struct WidgetDataFetcher {
    private static let nearbyURL = "https://transport.opendata.ch/v1/locations"
    private static let appGroupId = "group.ch.opendata.timeforcoffee"

    /// Formats station name with city in parentheses: "Zürich, Limmatplatz" -> "Limmatplatz (Zürich)"
    private static func formatStationName(_ name: String) -> String {
        // Match pattern "City, Station" and convert to "Station (City)"
        if let commaRange = name.range(of: ", ") {
            let city = String(name[..<commaRange.lowerBound])
            let station = String(name[commaRange.upperBound...])
            return "\(station) (\(city))"
        }
        return name
    }

    /// Shared UserDefaults for accessing cached data
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    /// Fetches departures for a station using TFCStation from timeforcoffeeKit
    /// When applyFilters is true, only shows favorite departures when available
    static func fetchDepartures(stationId: String, stationName: String, applyFilters: Bool = true) async -> DepartureEntry {
        // Synchronize UserDefaults to ensure we have the latest filter settings from the main app
        TFCDataStore.sharedInstance.getUserDefaults()?.synchronize()

        guard let station = TFCStation.initWithCacheId(stationId, name: stationName) else {
            return DepartureEntry.empty(message: "Invalid station")
        }

        let url = station.getDeparturesURL()
        guard let requestUrl = URL(string: url) else {
            return DepartureEntry.empty(message: "Invalid URL")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: requestUrl)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return loadCachedEntry(stationId: stationId, stationName: stationName)
                    ?? DepartureEntry.empty(message: "Network error")
            }

            var departures = parseDepartures(from: data, stationId: stationId)

            // Reload filters from storage to get fresh data
            station.reloadFilters()

            // Apply favorite/filter settings if the station has them
            if applyFilters && station.hasFilters() {
                departures = filterDepartures(departures, for: station)
            }

            // Limit to max 10 departures for display
            departures = Array(departures.prefix(10))

            let entry = DepartureEntry(
                date: Date(),
                stationName: formatStationName(stationName),
                stationId: stationId,
                departures: departures
            )

            // Cache the result
            cacheEntry(entry)

            return entry
        } catch {
            // Try to return cached data on error
            return loadCachedEntry(stationId: stationId, stationName: stationName)
                ?? DepartureEntry.empty(message: "Connection failed")
        }
    }

    /// Filter departures based on station's favorite/filter settings
    private static func filterDepartures(_ departures: [WidgetDeparture], for station: TFCStation) -> [WidgetDeparture] {
        var filtered = departures.filter { departure in
            // Try exact match first
            if let shouldShow = station.shouldShowDeparture(line: departure.line, destination: departure.destination) {
                return shouldShow
            }
            // Try matching without city prefix (e.g., "Zürich, Strassenverkehrsamt" -> "Strassenverkehrsamt")
            let normalizedDestination = normalizeDestination(departure.destination)
            if normalizedDestination != departure.destination {
                if let shouldShow = station.shouldShowDeparture(line: departure.line, destination: normalizedDestination) {
                    return shouldShow
                }
            }
            // No filters set, show all
            return true
        }

        // If filtering resulted in empty list, fall back to showing all
        if filtered.isEmpty {
            return departures
        }

        return filtered
    }

    /// Normalize destination by removing city prefix: "Zürich, Strassenverkehrsamt" -> "Strassenverkehrsamt"
    private static func normalizeDestination(_ destination: String) -> String {
        if let commaRange = destination.range(of: ", ") {
            return String(destination[commaRange.upperBound...])
        }
        return destination
    }

    /// Parses the API response JSON into WidgetDeparture objects
    private static func parseDepartures(from data: Data, stationId: String) -> [WidgetDeparture] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var departures: [WidgetDeparture] = []

        // Handle TFC API format
        if let departuresArray = json["departures"] as? [[String: Any]] {
            for (index, departure) in departuresArray.enumerated() {
                if let widgetDeparture = parseWidgetDeparture(from: departure, index: index) {
                    departures.append(widgetDeparture)
                }
            }
        }
        // Handle transport.opendata.ch format (stationboard)
        else if let stationboard = json["stationboard"] as? [[String: Any]] {
            for (index, departure) in stationboard.enumerated() {
                if let widgetDeparture = parseTransportDeparture(from: departure, index: index) {
                    departures.append(widgetDeparture)
                }
            }
        }

        return departures
    }

    /// Parse a departure from TFC API format
    private static func parseWidgetDeparture(from dict: [String: Any], index: Int) -> WidgetDeparture? {
        guard let name = dict["name"] as? String,
              let to = dict["to"] as? String else {
            return nil
        }

        // Parse departure time
        let departureInfo = dict["departure"] as? [String: Any] ?? dict
        var departureTime: Date?
        var isRealtime = false

        if let realtimeStr = departureInfo["realtime"] as? String {
            departureTime = parseDate(realtimeStr)
            isRealtime = true
        }
        if departureTime == nil, let scheduledStr = departureInfo["scheduled"] as? String {
            departureTime = parseDate(scheduledStr)
        }

        guard let finalTime = departureTime else {
            return nil
        }

        // Parse colors
        let colors = dict["colors"] as? [String: String] ?? [:]
        let colorFg = colors["fg"] ?? dict["colorFg"] as? String ?? "#000000"
        let colorBg = colors["bg"] ?? dict["colorBg"] as? String ?? "#FFFFFF"

        let platform = (departureInfo["platform"] ?? dict["platform"]) as? String

        return WidgetDeparture(
            id: "\(index)-\(name)-\(to)",
            line: name,
            destination: to,  // Keep original for filtering, format in view
            departureTime: finalTime,
            isRealtime: isRealtime,
            colorFg: colorFg,
            colorBg: colorBg,
            platform: platform
        )
    }

    /// Parse a departure from transport.opendata.ch format
    private static func parseTransportDeparture(from dict: [String: Any], index: Int) -> WidgetDeparture? {
        guard let stop = dict["stop"] as? [String: Any],
              let to = dict["to"] as? String else {
            return nil
        }

        // Get line name based on category
        let categoryCode = dict["categoryCode"] as? Int ?? 0
        let name: String
        if categoryCode < 5 {
            name = dict["category"] as? String ?? ""
        } else if categoryCode == 5 {
            name = dict["name"] as? String ?? ""
        } else {
            name = dict["number"] as? String ?? ""
        }

        // Parse departure time
        var departureTime: Date?
        var isRealtime = false

        if let prognosis = stop["prognosis"] as? [String: Any],
           let realtimeStr = prognosis["departure"] as? String {
            departureTime = parseDate(realtimeStr)
            isRealtime = true
        }
        if departureTime == nil, let scheduledStr = stop["departure"] as? String {
            departureTime = parseDate(scheduledStr)
        }

        guard let finalTime = departureTime else {
            return nil
        }

        // Get platform (prognosis takes precedence)
        var platform: String? = nil
        if let prognosis = stop["prognosis"] as? [String: Any] {
            platform = prognosis["platform"] as? String
        }
        if platform == nil {
            platform = stop["platform"] as? String
        }

        return WidgetDeparture(
            id: "\(index)-\(name)-\(to)",
            line: name,
            destination: to,  // Keep original for filtering, format in view
            departureTime: finalTime,
            isRealtime: isRealtime,
            colorFg: "#000000",
            colorBg: "#FFFFFF",
            platform: platform
        )
    }

    /// Parse ISO 8601 date string
    private static func parseDate(_ string: String) -> Date? {
        // Try ISO8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }

        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: string) {
            return date
        }

        // Try various DateFormatter patterns
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mmZ",
            "yyyy-MM-dd'T'HH:mm"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    // MARK: - Caching

    private static let cacheKey = "widgetDepartureCache"
    private static let nearbyCacheKey = "widgetNearbyStationsCache"
    private static let nearbyCacheMaxAge: TimeInterval = 1800  // 30 minutes
    private static let nearbyCacheMaxDistance: Double = 100   // 100 meters

    /// Cache an entry for offline fallback
    private static func cacheEntry(_ entry: DepartureEntry) {
        guard let defaults = sharedDefaults else { return }

        let cacheData: [String: Any] = [
            "stationId": entry.stationId,
            "stationName": entry.stationName,
            "timestamp": Date().timeIntervalSince1970,
            "departures": entry.departures.map { departure in
                [
                    "id": departure.id,
                    "line": departure.line,
                    "destination": departure.destination,
                    "departureTime": departure.departureTime.timeIntervalSince1970,
                    "isRealtime": departure.isRealtime,
                    "colorFg": departure.colorFg,
                    "colorBg": departure.colorBg,
                    "platform": departure.platform ?? ""
                ]
            }
        ]

        defaults.set(cacheData, forKey: "\(cacheKey)_\(entry.stationId)")
    }

    /// Load a cached entry if available and not too old (max 5 minutes)
    private static func loadCachedEntry(stationId: String, stationName: String) -> DepartureEntry? {
        guard let defaults = sharedDefaults,
              let cacheData = defaults.dictionary(forKey: "\(cacheKey)_\(stationId)") else {
            return nil
        }

        guard let timestamp = cacheData["timestamp"] as? TimeInterval,
              Date().timeIntervalSince1970 - timestamp < 300 else { // 5 minutes max
            return nil
        }

        guard let departuresData = cacheData["departures"] as? [[String: Any]] else {
            return nil
        }

        let departures: [WidgetDeparture] = departuresData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let line = dict["line"] as? String,
                  let destination = dict["destination"] as? String,
                  let departureTimeInterval = dict["departureTime"] as? TimeInterval,
                  let isRealtime = dict["isRealtime"] as? Bool,
                  let colorFg = dict["colorFg"] as? String,
                  let colorBg = dict["colorBg"] as? String else {
                return nil
            }

            return WidgetDeparture(
                id: id,
                line: line,
                destination: destination,
                departureTime: Date(timeIntervalSince1970: departureTimeInterval),
                isRealtime: isRealtime,
                colorFg: colorFg,
                colorBg: colorBg,
                platform: dict["platform"] as? String
            )
        }

        return DepartureEntry(
            date: Date(),
            stationName: formatStationName(stationName),
            stationId: stationId,
            departures: departures
        )
    }

    // MARK: - Nearby Stations Cache

    /// Cache nearby stations with location
    private static func cacheNearbyStations(_ stations: [NearbyStation], latitude: Double, longitude: Double) {
        guard let defaults = sharedDefaults else { return }

        let cacheData: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "timestamp": Date().timeIntervalSince1970,
            "stations": stations.map { station in
                var stationDict: [String: Any] = [
                    "id": station.id,
                    "name": station.name,
                    "isFavorite": station.isFavorite
                ]
                if let departure = station.firstDeparture {
                    stationDict["departure"] = [
                        "id": departure.id,
                        "line": departure.line,
                        "destination": departure.destination,
                        "departureTime": departure.departureTime.timeIntervalSince1970,
                        "isRealtime": departure.isRealtime,
                        "colorFg": departure.colorFg,
                        "colorBg": departure.colorBg,
                        "platform": departure.platform ?? ""
                    ]
                }
                return stationDict
            }
        ]

        defaults.set(cacheData, forKey: nearbyCacheKey)
    }

    /// Load cached nearby stations if valid (within 100m and 5 minutes)
    private static func loadCachedNearbyStations(latitude: Double, longitude: Double) -> [NearbyStation]? {
        guard let defaults = sharedDefaults,
              let cacheData = defaults.dictionary(forKey: nearbyCacheKey) else {
            return nil
        }

        // Check timestamp (5 minutes max)
        guard let timestamp = cacheData["timestamp"] as? TimeInterval,
              Date().timeIntervalSince1970 - timestamp < nearbyCacheMaxAge else {
            return nil
        }

        // Check distance (100m max)
        guard let cachedLat = cacheData["latitude"] as? Double,
              let cachedLon = cacheData["longitude"] as? Double else {
            return nil
        }

        let cachedLocation = CLLocation(latitude: cachedLat, longitude: cachedLon)
        let currentLocation = CLLocation(latitude: latitude, longitude: longitude)
        let distance = currentLocation.distance(from: cachedLocation)

        guard distance < nearbyCacheMaxDistance else {
            return nil
        }

        // Parse cached stations
        guard let stationsData = cacheData["stations"] as? [[String: Any]] else {
            return nil
        }

        let stations: [NearbyStation] = stationsData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let isFavorite = dict["isFavorite"] as? Bool else {
                return nil
            }

            var firstDeparture: WidgetDeparture? = nil
            if let departureDict = dict["departure"] as? [String: Any],
               let depId = departureDict["id"] as? String,
               let line = departureDict["line"] as? String,
               let destination = departureDict["destination"] as? String,
               let departureTime = departureDict["departureTime"] as? TimeInterval,
               let isRealtime = departureDict["isRealtime"] as? Bool,
               let colorFg = departureDict["colorFg"] as? String,
               let colorBg = departureDict["colorBg"] as? String {
                firstDeparture = WidgetDeparture(
                    id: depId,
                    line: line,
                    destination: destination,
                    departureTime: Date(timeIntervalSince1970: departureTime),
                    isRealtime: isRealtime,
                    colorFg: colorFg,
                    colorBg: colorBg,
                    platform: departureDict["platform"] as? String
                )
            }

            return NearbyStation(id: id, name: name, isFavorite: isFavorite, firstDeparture: firstDeparture)
        }

        return stations.isEmpty ? nil : stations
    }

    // MARK: - Station Data Access

    /// Get the last used station from shared UserDefaults using TFCStation
    static func getLastUsedStation() -> TFCStation? {
        guard let defaults = sharedDefaults,
              let stationDict = defaults.dictionary(forKey: "lastUsedStation") as? [String: String] else {
            return nil
        }
        return TFCStation.initWithCache(stationDict)
    }

    /// Get favorite station IDs
    static func getFavoriteStationIds() -> [String] {
        guard let defaults = sharedDefaults,
              let favorites = defaults.array(forKey: "favorites3") as? [String] else {
            return []
        }
        return favorites
    }

    // MARK: - Nearby Stations

    /// Find the nearest station to a location
    static func findNearestStation(latitude: Double, longitude: Double) async -> (id: String, name: String)? {
        let urlString = "\(nearbyURL)?type=station&x=\(latitude)&y=\(longitude)"
        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stations = json["stations"] as? [[String: Any]] else {
                return nil
            }

            // Find first station with a valid ID (skip addresses with null ID)
            for station in stations {
                if let stationId = station["id"] as? String,
                   let stationName = station["name"] as? String {
                    return (stationId, stationName)
                }
            }

            return nil
        } catch {
            return nil
        }
    }

    /// Fetch departures for the nearest station to a location
    static func fetchDeparturesForNearestStation(latitude: Double, longitude: Double) async -> DepartureEntry {
        guard let station = await findNearestStation(latitude: latitude, longitude: longitude) else {
            return DepartureEntry.empty(message: "No nearby station found")
        }

        return await fetchDepartures(stationId: station.id, stationName: station.name)
    }

    /// Find nearby stations with their first departure
    static func findNearbyStations(latitude: Double, longitude: Double, limit: Int = 10) async -> [NearbyStation] {
        // Synchronize UserDefaults to ensure we have the latest filter settings from the main app
        TFCDataStore.sharedInstance.getUserDefaults()?.synchronize()

        // Check cache first (reuse if <100m moved and <5 minutes old)
        if let cachedStations = loadCachedNearbyStations(latitude: latitude, longitude: longitude) {
            return Array(cachedStations.prefix(limit))
        }

        let urlString = "\(nearbyURL)?type=station&x=\(latitude)&y=\(longitude)"
        guard let url = URL(string: urlString) else {
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stations = json["stations"] as? [[String: Any]] else {
                return []
            }

            let favoriteIds = Set(getFavoriteStationIds())

            // Parse stations (skip entries with null ID like addresses)
            var nearbyStations: [NearbyStation] = []
            for station in stations {
                // Stop once we have enough stations
                if nearbyStations.count >= limit {
                    break
                }

                guard let stationId = station["id"] as? String,
                      let stationName = station["name"] as? String else {
                    continue
                }

                let isFavorite = favoriteIds.contains(stationId)

                // Fetch first departure for this station
                let firstDeparture = await fetchFirstDeparture(stationId: stationId)

                nearbyStations.append(NearbyStation(
                    id: stationId,
                    name: formatStationName(stationName),
                    isFavorite: isFavorite,
                    firstDeparture: firstDeparture
                ))
            }

            // Sort: favorites first, then by original order
            nearbyStations.sort { $0.isFavorite && !$1.isFavorite }

            // Cache the result
            cacheNearbyStations(nearbyStations, latitude: latitude, longitude: longitude)

            return nearbyStations
        } catch {
            return []
        }
    }

    /// Fetch just the first departure for a station (applies filters if available)
    private static func fetchFirstDeparture(stationId: String) async -> WidgetDeparture? {
        guard let station = TFCStation.initWithCacheId(stationId),
              let url = URL(string: station.getDeparturesURL()) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            var departures = parseDepartures(from: data, stationId: stationId)

            // Reload filters from storage to get fresh data
            station.reloadFilters()

            // Apply favorite/filter settings if the station has them
            if station.hasFilters() {
                departures = filterDepartures(departures, for: station)
            }

            return departures.first
        } catch {
            return nil
        }
    }

    /// Fetch nearby stations entry
    static func fetchNearbyStationsEntry(latitude: Double, longitude: Double) async -> DepartureEntry {
        let stations = await findNearbyStations(latitude: latitude, longitude: longitude)

        if stations.isEmpty {
            return DepartureEntry.empty(message: "No nearby stations found")
        }

        return DepartureEntry(
            date: Date(),
            viewMode: .nearbyStations,
            stationName: NSLocalizedString("Nearby Stations", comment: ""),
            stationId: "",
            departures: [],
            nearbyStations: stations
        )
    }

    // MARK: - Nearest Favorite Station

    /// Default search radius for favorite stations (in meters)
    private static let favoriteSearchRadius: Double = 1000

    /// Find the nearest favorite station within the search radius
    static func findNearestFavoriteStation(latitude: Double, longitude: Double) -> TFCStation? {
        let currentLocation = CLLocation(latitude: latitude, longitude: longitude)
        let favoriteIds = Set(getFavoriteStationIds())

        guard !favoriteIds.isEmpty else { return nil }

        var nearestStation: TFCStation?
        var nearestDistance: Double = favoriteSearchRadius

        for stationId in favoriteIds {
            guard let station = TFCStation.initWithCacheId(stationId),
                  let coord = station.coord else {
                continue
            }

            let distance = currentLocation.distance(from: coord)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestStation = station
            }
        }

        return nearestStation
    }

    /// Fetch departures for the nearest favorite station, or fallback to nearest station
    static func fetchDeparturesForNearestFavorite(latitude: Double, longitude: Double) async -> DepartureEntry {
        // Synchronize UserDefaults to ensure we have the latest favorites from the main app
        TFCDataStore.sharedInstance.getUserDefaults()?.synchronize()

        // First, try to find a nearby favorite station
        if let favoriteStation = findNearestFavoriteStation(latitude: latitude, longitude: longitude) {
            return await fetchDepartures(stationId: favoriteStation.st_id, stationName: favoriteStation.name)
        }

        // Fallback to nearest station
        return await fetchDeparturesForNearestStation(latitude: latitude, longitude: longitude)
    }

    // MARK: - View Mode

    /// Get the last used view mode from UserDefaults
    static func getLastUsedViewMode() -> WidgetViewMode {
        guard let defaults = sharedDefaults,
              let viewString = defaults.string(forKey: "lastUsedView") else {
            return .singleStation
        }
        return viewString == "nearbyStations" ? .nearbyStations : .singleStation
    }

    /// Get the last used view update timestamp
    static func getLastUsedViewUpdateInterval() -> TimeInterval? {
        guard let defaults = sharedDefaults,
              let timestamp = defaults.object(forKey: "lastUsedViewUpdate") as? Date else {
            return nil
        }
        return timestamp.timeIntervalSinceNow
    }

    /// Get the last used station distance
    static func getLastUsedStationDistance() -> Double? {
        return sharedDefaults?.double(forKey: "lastUsedStationDistance")
    }
}

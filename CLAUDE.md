# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Time for Coffee! is a Swiss public transport departure times app for iOS and watchOS. It displays real-time departure information from Swiss public transport stations using the Swiss Transport Open Data API.

## Build Requirements

- **Xcode 26+** (or compatible version)
- **iOS Deployment Target**: 15.0
- **watchOS Deployment Target**: 7.0
- **Swift**: 5.0
- **CocoaPods**: 1.16+

## Build Commands

```bash
# Install dependencies (requires CocoaPods)
LANG=en_US.UTF-8 pod install

# Build and run via Xcode
open timeforcoffee.xcworkspace

# Build from command line
xcodebuild -workspace timeforcoffee.xcworkspace -scheme timeforcoffee -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

Always use `timeforcoffee.xcworkspace` (not `.xcodeproj`) to ensure CocoaPods dependencies are included.

The `LANG=en_US.UTF-8` prefix may be needed if CocoaPods reports encoding errors.

## Architecture

### Multi-Target Structure
The project has multiple targets sharing code through frameworks:
- **timeforcoffee** - Main iOS app
- **timeforcoffeeKit** - Shared framework for iOS (stations, departures, API, data storage)
- **timeforcoffeeKitWatch** - Shared framework for watchOS (subset of Kit with watch-specific implementations)
- **Time for Coffee! WatchOS 2 App Extension** - watchOS app
- **timeforcoffee Widget** - Today widget extension
- **NextDeparturesIntent/UI/Watch** - Siri shortcuts and intents

### Core Data Models
- **TFCStation** / **TFCStationBase** - Station with coordinates, departures, favorites, filtering
- **TFCDeparture** - Single departure with line, destination, scheduled/realtime times, colors
- **TFCPass** - Passlist (intermediate stops) for a departure
- **TFCStationModel** - CoreData entity for persistent station storage

### Key Singletons
- `TFCDataStore.sharedInstance` - iCloud key-value storage, WatchConnectivity, CoreData context
- `TFCFavorites.sharedInstance` - Favorite stations management and geofencing
- `TFCLocationManager` - Location services wrapper (different implementations for iOS/watchOS)
- `TFCCache.objects` - PINCache instances for stations and API calls

### API Layer
- **APIController** - Fetches data from transport.opendata.ch and tfc.chregu.tv APIs
- Implements `APIControllerProtocol` for async callback pattern
- Uses PINCache for response caching

### Data Flow
1. Station search/nearby uses `TFCStationsUpdate` with location
2. APIController fetches from transport.opendata.ch (search) or tfc.chregu.tv (departures)
3. Results parsed via SwiftyJSON into TFCStation/TFCDeparture objects
4. Stations cached in PINCache with keys like `dept_{st_id}` for departures
5. Favorites synced via iCloud NSUbiquitousKeyValueStore
6. WatchConnectivity syncs favorites and complications between iOS/watchOS

### Platform-Specific Code
- iOS-only code uses `#if os(iOS)` guards
- watchOS-only code uses `#if os(watchOS)` guards
- TFCStation extends TFCStationBase with iOS-specific features (walking distance via MKDirections, CoreSpotlight indexing)
- timeforcoffeeKitWatch has simplified implementations (TFCLocationManager, TFCDataStore)

## Key External Dependencies (CocoaPods)
- MGSwipeTableCell - Swipeable table cells for favorite/filter actions
- SwipeView - Horizontal paging for stations list

## API Endpoints
- Departures: `https://tfc.chregu.tv/api/ch/stationboard/{st_id}`
- Station search (CH): `https://tfc.chregu.tv/api/zvv/stations/{query}*`
- Station search (outside CH): `https://transport.opendata.ch/v1/locations?type=station&query={query}*`
- Passlist: `https://tfc.chregu.tv/api/ch/connections/{st_id}/{dest}/{date}`

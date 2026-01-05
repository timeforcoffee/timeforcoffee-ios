# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Time for Coffee! is a Swiss public transport departure times app for iOS and watchOS. It displays real-time departure information from Swiss public transport stations using the Swiss Transport Open Data API.

## Build Requirements

- **Xcode 16+** (or compatible version)
- **iOS Deployment Target**: 17.0
- **watchOS Deployment Target**: 9.0
- **Swift**: 5.0
- **CocoaPods**: 1.16+

## Build Commands

```bash
# Install dependencies (requires CocoaPods)
LANG=en_US.UTF-8 pod install

# Build and run via Xcode
open timeforcoffee.xcworkspace

# Build from command line (use simulator ID for reliability)
xcodebuild -workspace timeforcoffee.xcworkspace -scheme timeforcoffee -destination 'platform=iOS Simulator,id=4D520846-3E4C-4865-83AC-9211F02B5071'

# Alternative: build for any iOS simulator (useful when specific device unavailable)
xcodebuild -workspace timeforcoffee.xcworkspace -scheme timeforcoffee -destination 'generic/platform=iOS Simulator'
```

**Note:** Use simulator IDs rather than names for more reliable builds. The ID `4D520846-3E4C-4865-83AC-9211F02B5071` corresponds to iPhone 15 Pro (iOS 17.5). Run `xcrun simctl list devices` to see available simulators and their IDs.

Always use `timeforcoffee.xcworkspace` (not `.xcodeproj`) to ensure CocoaPods dependencies are included.

The `LANG=en_US.UTF-8` prefix may be needed if CocoaPods reports encoding errors.

## Architecture

### Multi-Target Structure

The project has multiple targets sharing code through frameworks:

- **timeforcoffee** - Main iOS app
- **timeforcoffeeKit** - Shared framework for iOS (stations, departures, API, data storage)
- **timeforcoffeeKitWatch** - Shared framework for watchOS (subset of Kit with watch-specific implementations)
- **Time for Coffee! WatchOS 2 App Extension** - watchOS app
- **timeforcoffeeWidget** - WidgetKit home screen widget extension
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

### WidgetKit Widget (timeforcoffeeWidget)

The widget uses WidgetKit with AppIntentConfiguration and supports both home screen and lock screen widgets:

**Supported Widget Families:**

- Home screen: `systemSmall`, `systemMedium`, `systemLarge`
- Lock screen: `accessoryCircular`, `accessoryRectangular`, `accessoryInline`

**Display Modes:**

- Nearest Favorite - Shows departures from the closest favorite station
- Nearest Station - Shows departures from the closest station
- Nearby Stations - Shows a list of nearby stations with next departures
- Specific Station - Choose a specific favorite station to display

**Key Files:**

- `timeforcoffeeWidget.swift` - Widget entry point and configuration
- `DepartureTimelineProvider.swift` - AppIntentTimelineProvider for widget updates
- `DepartureEntry.swift` - TimelineEntry model with departures and nearby stations
- `WidgetDataFetcher.swift` - API calls and data fetching for widget
- `WidgetLocationManager.swift` - Location services for widget
- `Views/` - SwiftUI views for small, medium, and large widget sizes
- `Views/LockScreenViews.swift` - Lock screen widget views (circular, rectangular, inline)

**Data Sharing:**

- Uses App Group `group.ch.opendata.timeforcoffee` for shared UserDefaults
- Accesses TFCDataStore for favorites and filter settings
- Calls `synchronize()` on UserDefaults to ensure cross-process data consistency

## Key External Dependencies (CocoaPods)

- MGSwipeTableCell - Swipeable table cells for favorite/filter actions
- SwipeView - Horizontal paging for stations list

## API Endpoints

- Departures: `https://tfc.chregu.tv/api/ch/stationboard/{st_id}`
- Station search (CH): `https://tfc.chregu.tv/api/zvv/stations/{query}*`
- Station search (outside CH): `https://transport.opendata.ch/v1/locations?type=station&query={query}*`
- Passlist: `https://tfc.chregu.tv/api/ch/connections/{st_id}/{dest}/{date}`

## Deep Linking

The app uses `timeforcoffee://` URL scheme:

- `timeforcoffee://station?id={stationId}&name={stationName}` - Open a specific station
- `timeforcoffee://nearby` - Open nearby stations view

## Debugging

Use the `DLog()` function in `timeforcoffeeKit/Logging.swift` for debug output:

```swift
DLog("message")                    // Console output (debug builds only)
DLog("message", toFile: true)      // Also writes to file for watchOS debugging
```

## Cache Keys

The app uses PINCache with these key patterns:

- `dept_{st_id}` - Cached departures for a station
- `stations/{query}` - Cached station search results
- `stationsinfo/{id}` - Cached station metadata

## Async Patterns

API calls use a delegate callback pattern:

```swift
class MyController: APIControllerProtocol {
    lazy var api: APIController = APIController(delegate: self)

    func didReceiveResults(_ results: JSONValue, context: Any?,
                          urlHash: String, status: APIStatus) {
        // Handle results
    }
}
```

## TestFlight Deployment

Use `scripts/upload-testflight.sh` to archive, export, and upload to TestFlight from the command line.

### Setup

Copy `.env.example` to `.env` and fill in your credentials:

```bash
cp .env.example .env
# Edit .env with your values
./scripts/upload-testflight.sh
```

### Option 1: Apple ID + App-Specific Password

Get app-specific password from <https://appleid.apple.com> → Sign-In and Security → App-Specific Passwords

```bash
APPLE_ID=your@email.com APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx ./scripts/upload-testflight.sh
```

### Option 2: App Store Connect API Key (Recommended)

No 2FA prompts, better for CI/CD:

1. Create API key at <https://appstoreconnect.apple.com/access/api>
2. Download the `.p8` key file
3. Run:

```bash
ASC_KEY_ID=XXXXXXXXXX \
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
ASC_KEY_PATH=~/.keys/AuthKey_XXXXXXXXXX.p8 \
./scripts/upload-testflight.sh
```

### Manual Steps

```bash
# 1. Archive
xcodebuild archive \
  -workspace timeforcoffee.xcworkspace \
  -scheme timeforcoffee \
  -archivePath build/timeforcoffee.xcarchive \
  -destination 'generic/platform=iOS'

# 2. Export IPA
xcodebuild -exportArchive \
  -archivePath build/timeforcoffee.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

# 3. Upload
xcrun altool --upload-app -f build/export/timeforcoffee.ipa -t ios \
  -u "your@email.com" -p "xxxx-xxxx-xxxx-xxxx"
```

### Troubleshooting: Codesign Hangs

If the export step hangs during codesign (common with watchOS frameworks), kill these processes:

```bash
sudo killall -9 codesign
sudo killall -9 trustd
sudo killall -9 securityd
```

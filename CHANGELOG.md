# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.31] - unreleased

### Added

- New WidgetKit home screen widget with configurable display modes:
  - Nearest Favorite: Shows departures from the closest favorite station
  - Nearest Station: Shows departures from the closest station
  - Nearby Stations: Shows a list of nearby stations with next departures
  - Specific Station: Choose a specific favorite station to display
- Widget supports small, medium, and large sizes
- Deep linking from widget to open stations in the main app
- Automatic widget refresh when favorites change
- Lock screen widgets: circular (departure countdown gauge), rectangular (station + departures), and inline (single departure text)
- Apple Watch app icons for larger watch sizes (Series 7+, Ultra)

### Changed

- Minimum iOS version updated to 17.0
- Minimum watchOS version updated to 9.0
- About page now uses modern WKWebView instead of deprecated UIWebView
- Increased font sizes and improved text styling for better readability
- Modernized codebase to remove deprecated iOS/watchOS APIs:
  - Updated archiving APIs for secure coding compliance
  - Replaced WKExtension with WKApplication for watchOS 9+
  - Replaced Info.plist complication families with programmatic API
  - Removed deprecated network activity indicator (no longer visible in iOS 13+)

### Fixed

- watchOS 10+: Fixed display bug showing localization keys (e.g., "IVN-0O-4Oc.text") instead of actual text
- watchOS: Station departure data now correctly updates when switching between stations
- watchOS: Removed deprecated Force Touch menu code (not supported since watchOS 7)
- App Store validation errors: removed framework embedding from widget extension
- Search bar not visible when opening station search
- Dark mode support improved for navigation bar and passlist views
- Widget departure times now update correctly at minute boundaries
- Consistent time color coding (red/orange) in nearby stations widget view
- Passlist cell layout spacing for time labels

### Removed

- Legacy Today View Widget (replaced by WidgetKit widget)

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.30]

### Added

- New WidgetKit home screen widget with configurable display modes:
  - Nearest Favorite: Shows departures from the closest favorite station
  - Nearest Station: Shows departures from the closest station
  - Nearby Stations: Shows a list of nearby stations with next departures
  - Specific Station: Choose a specific favorite station to display
- Widget supports small, medium, and large sizes
- Deep linking from widget to open stations in the main app
- Automatic widget refresh when favorites change

### Changed

- Minimum iOS version updated to 17.0
- Minimum watchOS version updated to 9.0
- About page now uses modern WKWebView instead of deprecated UIWebView

### Fixed

- Search bar not visible when opening station search

### Removed

- Legacy Today View Widget (replaced by WidgetKit widget)

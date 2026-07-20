# Ticks

<p align="center">
  <img src="https://img.shields.io/badge/SwiftUI-app-orange?logo=swift">
  <img src="https://img.shields.io/badge/Platform-iOS%20%2B%20iPadOS-blue">
</p>

## Overview
Tick is a playful, lightweight SwiftUI timekeeping app for recording how long spaces actually take.

Current MVP foundation:
- create spaces
- start and stop one active Tick session
- add missed time manually
- review and edit session title, notes, and space
- archive and restore spaces without deleting their recorded time
- create, edit, and delete opt-in Auto Tick location rules for automatic arrival/departure actions
- use Home Screen and Lock Screen widgets to glance at, start, or stop the current Tick
- view today's recorded time and sessions
- review simple daily, weekly, and monthly summaries
- persist local data between launches
- sync Tick data between iPhone and iPad with iCloud Key-Value Store

## Requirements
- macOS with Xcode installed
- Xcode with an iOS Simulator
- SwiftUI
- iCloud capability for device-to-device sync builds

## Getting Started
1. Open `Tick.xcodeproj`
2. Select an iPhone or iPad Simulator
3. Build and Run

For command-line validation:

```sh
SIMULATOR_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')"
xcodebuild \
  -project Tick.xcodeproj \
  -scheme Tick \
  -destination "id=${SIMULATOR_ID}" \
  CODE_SIGNING_ALLOWED=NO \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  clean test
```

CI creates and boots an available iPhone simulator dynamically before running tests, so local simulator names do not need to match GitHub Actions exactly.

## Release Checklist
- Build and launch a signed Debug or Release build on Don iPhone.
- Create an Auto Tick rule from current location, allow When In Use and Always access when prompted, and verify arrival/departure behavior on device.
- Start and stop a Tick from the Home Screen widget and, where supported, a Lock Screen widget.
- Record, play, rename, delete, and relaunch-check a voice memo for an active Space.
- Verify iCloud Key-Value Store sync between iPhone and iPad on the same Apple ID for spaces, sessions, Auto Tick rules, and widget-started sessions.
- Before submission, manually check VoiceOver reading order, large Dynamic Type layout, and light/dark contrast for material-backed timer and session rows.

## Project Structure
```text
Tick/
├── Tick/
│   ├── Models/
│   ├── Services/
│   ├── Utilities/
│   ├── ViewModels/
│   └── Views/
├── TickWidgetExtension/
├── TickTests/
└── TickUITests/
```

## Roadmap
- [x] Define app goals and core flows
- [x] Add real UI and data model
- [x] Add tests for key behaviors
- [x] Add timer-session editing for title and notes
- [x] Add Auto Ticks foundation
- [x] Add Home Screen and Lock Screen widget foundation
- [x] Add iCloud Key-Value Store sync foundation
- [x] Add space archiving UI
- [ ] Add map/search support for Auto Tick locations
- [x] Add daily, weekly, and monthly charts
- [ ] Add export after the local foundation is stable

## Credits
Built with care by **Don Noel** and Codex collaboration.

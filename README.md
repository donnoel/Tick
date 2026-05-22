# Ticks

<p align="center">
  <img src="https://img.shields.io/badge/SwiftUI-app-orange?logo=swift">
  <img src="https://img.shields.io/badge/Platform-multiplatform-blue">
</p>

## Overview
Tick is a playful, lightweight SwiftUI timekeeping app for tracking how long projects actually take.

Current MVP foundation:
- create projects
- start and stop one active Tick session
- add missed time manually
- review and edit session title, notes, and project
- create, edit, and delete opt-in Auto Tick location rules for automatic arrival/departure tracking
- use a small/medium widget to start or stop the current Tick
- view today's tracked time and sessions
- review simple daily, weekly, and monthly summaries
- persist local data between launches

## Requirements
- macOS with Xcode installed
- Xcode with an iOS Simulator
- SwiftUI

## Getting Started
1. Open `Tick.xcodeproj`
2. Select an iPhone or iPad Simulator
3. Build and Run

For command-line validation:

```sh
xcodebuild \
  -project Tick.xcodeproj \
  -scheme Tick \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  clean test
```

## Project Structure
```text
Tick/
├── Tick/
│   ├── Models/
│   ├── Services/
│   ├── Utilities/
│   ├── ViewModels/
│   └── Views/
├── TickTests/
└── TickUITests/
```

## Roadmap
- [x] Define app goals and core flows
- [x] Add real UI and data model
- [x] Add tests for key behaviors
- [x] Add timer-session editing for title and notes
- [x] Add Auto Ticks foundation
- [x] Add first widget foundation
- [ ] Add project archiving UI
- [ ] Add map/search support for Auto Tick locations
- [ ] Add charts and export after the local foundation is stable

## Credits
Built with care by **Don Noel** and AI collaboration.

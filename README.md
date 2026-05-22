# Tick

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
- [ ] Add project archiving UI
- [ ] Add charts and export after the local foundation is stable

## Credits
Created with **ProjectPilot**.

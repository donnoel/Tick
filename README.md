# **Ticks**

### *See where your time goes.*

<p align="center">
  <img src="https://img.shields.io/badge/SwiftUI-app-orange?logo=swift" alt="SwiftUI: app">
  <img src="https://img.shields.io/badge/Platform-iOS%20%2B%20iPadOS%20%2B%20watchOS-blue" alt="Platform: iOS + iPadOS + watchOS">
</p>

---

## 🧭 Overview

<a id="overview"></a>

Tick is a playful, lightweight SwiftUI timekeeping app for recording how long spaces actually take.

### Current status — October 18, 2026

Don confirmed the current Tick work is complete, with nothing outstanding from his perspective. This closes the prior acceptance and delete-confirmation follow-ups for the current scope on owner confirmation; it does not claim new tests, device observations, or an application release. New requests or reported regressions are follow-up work.

## 💎 Core Features

| Feature | What it does |
| --- | --- |
| **Timekeeping** | Create Spaces and record, edit, or add missed time. |
| **Reports** | Review daily through lifetime summaries and share dated work reports. |
| **Auto Tick** | Configure opt-in location rules for arrival and departure actions. |
| **Connected surfaces** | Use widgets, Apple Watch, and the ProjectPilot Mac client with shared sync. |

<details>
<summary>Feature details and controls</summary>

Implemented scope:
- create spaces
- start and stop one active Tick session
- add missed time manually
- review and edit session title, notes, and space
- archive and restore spaces without deleting their recorded time
- create, edit, and delete opt-in Auto Tick location rules for automatic arrival/departure actions
- use Home Screen and Lock Screen widgets to glance at, start, or stop the current Tick
- view today's recorded time and sessions
- review daily, weekly, monthly, yearly, and lifetime summaries
- tap a space in Summaries for a dated work report with description totals and daily sessions; adjust dates, optionally omit notes, and share the text through Mail or another app
- persist local data between launches
- sync Tick data between iPhone, iPad, Apple Watch, and the ProjectPilot Mac client with CloudKit
- select a Space and Start/Pause/Resume/Stop from Apple Watch

<a id="apple-watch"></a>

### Apple Watch

Select the `TickWatch` scheme to build for watchOS 26 or later. The Watch uses the
same iCloud container and timer records as the other clients, without a repeating
background timer. See [Watch architecture and validation](docs/WATCH_APP.md).

</details>

---

## 🚀 Getting Started

<a id="requirements"></a>

### Requirements

- macOS with Xcode installed
- Xcode with the iOS 26 SDK or newer and an installed iPhone or iPad Simulator
- SwiftUI
- iCloud capability for device-to-device sync builds

<a id="getting-started"></a>

1. Open `Tick.xcodeproj`
2. Select an iPhone or iPad Simulator
3. Build and Run

For the release validation gate, select an installed iOS 26.5 simulator UDID
from `xcrun simctl list devices available`, then run:

```sh
export DEVELOPER_DIR=/Applications/Xcode-26.6.app/Contents/Developer
SIMULATOR_ID="<iOS-26.5-simulator-UDID>"
bash Scripts/ci.sh all "$SIMULATOR_ID"
swift test -Xswiftc -warnings-as-errors
```

Use focused tests while developing small changes. CI creates and boots an
available iPhone simulator dynamically; local simulator names need not match.

## 🧠 How It Works

<a id="project-structure"></a>

### Project Structure

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

<a id="shared-timer-support"></a>

### Shared timer support

`Package.swift` exposes the first-party `TickCore` library used by the sibling
ProjectPilot Mac app. The iPhone app and widget compile the same portable source
files directly. Run `swift test -Xswiftc -warnings-as-errors` for the shared model,
Start/Stop, merge and wire-format tests. No third-party packages are used.

The current default timer sync uses CloudKit; KVS is a legacy import path.
Commit `4e84aa9` recorded an unresolved physical widget Stop-propagation checkpoint at that time. Don's October 18 owner confirmation closes the current follow-up; no new independent device verification is claimed.

## 🔒 Data and Privacy

Read the [Ticks Privacy Policy](docs/PRIVACY_POLICY.md), also available offline
from the Privacy Policy button in the Spaces toolbar. App, widget, and Watch
privacy manifests and their source evidence are documented in
[Privacy configuration](docs/PRIVACY_CONFIGURATION.md).

The current shared-data path uses CloudKit, with the earlier iCloud key-value
store retained for legacy import. The app persists local records and exposes
location-based Auto Tick rules only when the user opts in. The historical physical
widget Stop-propagation checkpoint was closed on owner confirmation; that does
not claim new independent device verification.

## 📚 Documentation

<a id="release-checklist"></a>

### Future release rechecks

These are reference procedures for a future release, not outstanding tasks for the owner-confirmed current closeout.

- Build and launch a signed Debug or Release build on Don iPhone.
- Create an Auto Tick rule from current location, allow When In Use and Always access when prompted, and verify arrival/departure behavior on device.
- Start and stop a Tick from the Home Screen widget and, where supported, a Lock Screen widget.
- Record, play, rename, delete, and relaunch-check a voice memo for an active Space.
- Verify CloudKit sync between iPhone and iPad on the same Apple ID for spaces, sessions, Auto Tick rules, and widget-started sessions.
- Before submission, manually check VoiceOver reading order, large Dynamic Type layout, and light/dark contrast for material-backed timer and session rows.

- [Repository guidance](AGENTS.md)
- [Project guide](AGENTS.project.md)

## 🗺️ Roadmap

<a id="roadmap"></a>

- [x] Define app goals and core flows
- [x] Add real UI and data model
- [x] Add tests for key behaviors
- [x] Add timer-session editing for title and notes
- [x] Add Auto Ticks foundation
- [x] Add Home Screen and Lock Screen widget foundation
- [x] Add CloudKit synchronization with legacy Key-Value Store import
- [x] Add space archiving UI
- [x] Add daily, weekly, monthly, yearly, and lifetime charts
- [x] Share dated text work reports for a Space and selected period

There are no outstanding tasks in the current scope. Map/search for Auto Tick locations and additional file-export formats are optional future ideas, not committed closeout work.

---

## 🤝 Credits

<a id="credits"></a>

Built with care by **Don Noel** and Codex collaboration.

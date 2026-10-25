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

### Current status — October 25, 2026

Ticks is in active development and has not been submitted to the App Store. Development build `2.0 (37)` was installed and launched on Don's iPhone and iPad; Don confirmed that dragging the Today timers to reorder them works. This is device feedback on that feature, not a full release qualification.

## 💎 Core Features

| Feature | What it does |
| --- | --- |
| **Timekeeping** | Run up to two independent Ticks in different Spaces, edit recorded sessions, and add missed time. |
| **Reports** | Review daily through lifetime summaries and share dated work reports. |
| **Auto Tick** | Configure opt-in location rules for arrival and departure actions. |
| **Connected surfaces** | Use widgets, Apple Watch, and the ProjectPilot Mac client with CloudKit sync. |

<details>
<summary>Feature details and controls</summary>

Implemented scope:
- create, archive, and restore Spaces without losing recorded time
- run up to two Ticks at once, one per Space, with independent Start, Pause, Resume, and Stop controls; a paused Tick still occupies one of the two slots
- press and drag the Today timer cards to swap their order; the order persists locally after reopening the app, and an unused lower card can collapse on iPhone
- see today's total across all Spaces and review today's Ticks; swipe left on a completed Tick to delete it with confirmation
- add missed time manually; edit a session's title, notes, or Space, and correct a stopped Tick's date, start, end, duration, or entry source
- record, play, rename, and delete voice memos in a Space
- create, edit, and delete opt-in Auto Tick location rules for automatic arrival/departure actions
- use Home Screen and Lock Screen widgets to glance at a Tick and start or stop when the action is unambiguous; when two Ticks are active, the Home Screen widget shows the other Space, and tapping the widget opens Ticks to choose which one to control
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
- Xcode 26.6 and an installed iOS 26.5 iPhone or iPad Simulator for local CI reproduction
- SwiftUI
- iCloud capability for device-to-device sync builds

<a id="getting-started"></a>

1. Open `Tick.xcodeproj`
2. Select an iPhone or iPad Simulator
3. Build and Run

For a deliberate full CI reproduction, select an installed iOS 26.5 simulator UDID
from `xcrun simctl list devices available`, then run:

```sh
SIMULATOR_ID="<iOS-26.5-simulator-UDID>"
bash Scripts/local-check.sh bash Scripts/ci.sh all "$SIMULATOR_ID"
bash Scripts/local-check.sh swift test -Xswiftc -warnings-as-errors
```

Use focused tests while developing small changes through
`bash Scripts/local-check.sh <command> [args...]`. The launcher selects an
already-installed CI Xcode for that command, respects `DEVELOPER_DIR`, and never
installs tools or changes global defaults. CI creates and boots an
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
├── TickWatch/
├── TickWidgetExtension/
├── TickTests/
├── TickUITests/
├── TickCoreTests/
├── Scripts/
└── docs/
```

<a id="shared-timer-support"></a>

### Shared timer support

`Package.swift` exposes the first-party `TickCore` library used by the sibling
ProjectPilot Mac app. The iPhone app and widget compile the same portable source
files directly. Run `swift test -Xswiftc -warnings-as-errors` for the shared model,
Start/Stop, merge and wire-format tests. No third-party packages are used.

The current timer sync uses CloudKit; iCloud key-value storage is a legacy import path. The shared merge preserves offline edits and limits active Ticks to two different Spaces. Today timer-card order is a local display preference on each device; moving a card does not change its recorded time or CloudKit data. When two Ticks are active, widgets do not stop either one ambiguously: choose the Tick in the app.

## 🔒 Data and Privacy

Read the [Ticks Privacy Policy](docs/PRIVACY_POLICY.md), also available offline
from the Privacy Policy button in the Spaces toolbar. App, widget, and Watch
privacy manifests and their source evidence are documented in
[Privacy configuration](docs/PRIVACY_CONFIGURATION.md).

The app stores Space and Tick records locally and syncs them through private CloudKit data, with
the earlier iCloud key-value store retained for legacy import. Location-based
Auto Ticks require opt-in permission; voice memo recording uses the microphone
only when started by the user.

## 📚 Documentation

<a id="release-checklist"></a>

### Future release rechecks

Repeat these checks when preparing a future release; feature acceptance does not substitute for release validation.

- Build and launch a signed Debug or Release build on Don iPhone.
- Confirm two independent Ticks and timer-card drag ordering on iPhone and iPad.
- Create an Auto Tick rule from current location, allow When In Use and Always access when prompted, and verify arrival/departure behavior on device.
- With one active Tick, verify widget Start/Stop on Home Screen and, where supported, Lock Screen; with two active Ticks, verify tapping opens the app without stopping either one.
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
- [x] Run two independent Ticks in different Spaces and reorder their Today cards
- [x] Edit stopped Tick timing and session details; add missed time manually
- [x] Record and manage Space voice memos
- [x] Add Auto Ticks foundation
- [x] Add Home Screen and Lock Screen widgets and Apple Watch controls
- [x] Add CloudKit synchronization with legacy Key-Value Store import
- [x] Add space archiving UI
- [x] Add daily, weekly, monthly, yearly, and lifetime charts
- [x] Share dated text work reports for a Space and selected period

App Store submission remains a separate release step. Map/search for Auto Tick locations and additional file-export formats are optional future ideas, not committed work.

---

## 🤝 Credits

<a id="credits"></a>

Built with care by **Don Noel** and Codex collaboration.

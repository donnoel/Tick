# AGENTS.project.md

# Tick Project Guide for Agents

## Product intent
Tick is a lightweight project timekeeping app for people who want a quick record of how long future projects actually take.

The first product goal is effortless capture: starting and stopping time should be immediate, while titles, notes, and missed time can be added later through lightweight manual entry.

Success for the current phase means the app can create projects, track one active timer session, add manual time, summarize tracked time, and preserve local data between launches.

## Current product phase
Tick is in MVP foundation.

Current scope:
- local-only project and time-session tracking
- Today, Projects, and Summaries tabs
- duration-only manual time entry
- session detail review and title/notes/project editing
- Auto Ticks foundation with opt-in Core Location permission, current-location rule creation, rule edit/delete, and region-monitoring service boundary
- WidgetKit foundation with Home Screen and Lock Screen widgets plus App Intent-powered Start/Stop actions where supported
- daily, weekly, and monthly text summaries
- JSON persistence in the Tick App Group container

Explicitly out of scope for this phase:
- iCloud sync, networking, authentication, Live Activities, Apple Watch, billing, exports, charts, map search, route tracking, location history, voice memos, and transcription

## Architecture snapshot
App entry and navigation:
- `TickApp` opens `ContentView`.
- `ContentView` owns a root `TickViewModel` and presents a `TabView` with Today, Projects, and Summaries.

Core models:
- `TickProject`: project identity, name, creation date, archive flag.
- `TimeSession`: project link, optional timer dates, optional manual duration, title, notes, source, and creation date.
- `AutoTickRule`: project link, location coordinate, radius, enabled state, and arrival/departure behavior.
- `SessionEntrySource`: distinguishes timer-created, manual, and Auto Tick sessions.

State and operations:
- `TickViewModel` is main-actor isolated because it owns SwiftUI-observed state.
- Project/session mutations live on the view model, not inside SwiftUI view bodies.
- Auto Tick rule mutations and arrival/departure decisions live on the view model.
- Auto Tick rule updates/deletes must persist through `TickDataStore` and refresh monitored regions.
- `TickSummaryCalculator` handles daily, weekly, and monthly duration aggregation.
- Widget App Intents use `TickWidgetActionStore` for small shared-data mutations.

Persistence:
- `TickDataStore` is an actor-backed JSON store.
- The store reads/writes off the main actor and uses atomic writes.
- Saved file path: App Group `group.dn.tick` / Tick / tick-data.json, with one-time migration from the old Application Support path.
- Widget snapshots are stored separately as `tick-widget-snapshot.json` in the same App Group container.
- Keep widget shared storage small. Widgets should render from `TickWidgetSnapshot`, not from broad SwiftUI view-model state.

Location architecture:
- `AutoTickLocationService` is the only type that owns `CLLocationManager`.
- SwiftUI views must not talk to `CLLocationManager` directly.
- Auto Ticks uses current location only to create a rule and region monitoring for enabled saved rules where permission allows.
- Do not add continuous GPS polling unless a future feature explicitly requires it and documents the battery/privacy tradeoff.

## Concurrency rules
- Keep UI-observed state on `TickViewModel`.
- Keep file IO inside `TickDataStore`.
- Keep Core Location delegate work inside `AutoTickLocationService`.
- Keep pure value models and summary helpers `nonisolated` so Codable and calculations can run outside the main actor.
- Do not add broad `@MainActor` annotations to persistence or model types to silence warnings.

## Auto Ticks privacy rules
- Auto Ticks is opt-in.
- Do not request location permission before the user opens Auto Ticks or tries to use current location.
- Do not monitor locations until at least one rule exists and is enabled.
- Explain location use in plain language before permission prompts.
- Denied or restricted location permission must leave the app usable and must not crash.
- Do not store route history, visit history, or raw location samples beyond saved rule coordinates.

## Accessibility requirements
Accessibility is part of every user-facing change.

Current implementation includes:
- semantic buttons, pickers, forms, lists, and tab labels
- accessibility labels/hints for timer actions, project selection, manual entry, project creation, active elapsed time, session rows, session editing, and Auto Tick rule creation
- visible "Manual" and "Auto" badges with spoken source descriptions
- Dynamic Type-friendly SwiftUI text styles for major labels and timer readouts

Still verify manually before submission:
- VoiceOver reading order across all three tabs
- large Dynamic Type behavior in Today cards and manual-entry form
- light/dark contrast for material-backed timer and session rows

## Behavior invariants
- Starting a timer must not require a form.
- Only one active timer session may exist at a time.
- A manual session uses `manualDuration` as its source of truth.
- A timer session duration is derived from `startedAt` and `endedAt`.
- A running session uses `Date.now - startedAt` only for display; elapsed time is not stored continuously.
- Local data should survive app relaunches.
- Widget Start must not create a duplicate active session.
- Widget Stop must stop only the current active timer/Auto Tick session.
- Widget snapshots store dates and totals, not constantly changing elapsed time.
- Lock Screen widgets use the same snapshot as Home Screen widgets and derive compact elapsed text from `activeStartedAt`.
- Lock Screen accessory rectangular may show Start/Stop buttons where WidgetKit supports App Intent buttons; compact families should still be readable as tap-to-open widgets when direct actions are unavailable.
- Auto Tick arrival must not create a duplicate active session.
- Auto Tick departure must stop only the active Auto Tick session associated with that rule.
- Auto Tick departure must not stop timer-created or manual sessions.
- Deleting an Auto Tick rule must remove its monitored geofence without deleting existing sessions.

## UX rules
- Use plain, playful Tick language: Start Tick, Stop Tick, Add Time, Today's Ticks.
- Keep capture lightweight before adding detail-heavy flows.
- Prefer Apple-native controls over custom controls.
- Do not require archived-project support in the UI until the product asks for it, but preserve `isArchived` in the model.

## Coding conventions
- Stay Apple-native. Do not add third-party dependencies.
- Keep SwiftUI views declarative and small.
- Keep business rules in view models, services, or pure helpers.
- Add tests for non-trivial duration, summary, or persistence behavior.

## Build/run notes
- Project: `Tick.xcodeproj`
- Scheme: `Tick`
- Target platform: iOS Simulator
- CI runs `xcodebuild ... clean test`
- Build warnings should be treated as failures.

## Near-term priorities
- Add project archiving UI.
- Add richer validation around manual duration entry.
- Add more UI tests once flows stabilize.

## Output expectations per patch
Provide:
- Summary of change
- Files modified
- Any migration considerations
- Commit message suggestion
- Accessibility notes for user-facing work: added, verified, missing, or not applicable

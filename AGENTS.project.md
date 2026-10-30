# AGENTS.project.md

# Tick Project Guide for Agents

## Product intent
Tick is a lightweight timekeeping app for people who want a quick record of how long spaces actually take.

The first product goal is effortless capture: starting and stopping time should be immediate, while titles, notes, and missed time can be added later through lightweight manual entry.

Success for the current phase means the app can create spaces, capture up to two active timer sessions in different Spaces, add manual time, summarize recorded time, and preserve local data between launches.

For product language only, the app is space-centric: users measure time for a Space. The internal model type is still `TickProject`.

## Current product phase
As of October 27, 2026, Don confirms the Watch screen-clearance sprint is complete after accepting build 41 on his Watch. Prior acceptance and delete-confirmation follow-ups remain closed on owner confirmation. Do not infer additional tests, battery measurements, accessibility observations, or a release from that confirmation; new requests and reported regressions are follow-up work.

Current scope:
- space capture with local JSON persistence plus CloudKit synchronization
- Today, Spaces, Auto Ticks, and Summaries tabs
- duration-only manual time entry
- session detail review and title/notes/space editing, plus date/start/end/duration/source corrections for stopped Ticks
- space detail review with space-scoped session lists, session deletion, archive/restore actions, and voice memos
- Auto Ticks foundation with opt-in Core Location permission, current-location rule creation, rule edit/delete, and region-monitoring service boundary
- WidgetKit foundation with Home Screen and Lock Screen widgets plus App Intent-powered Start/Stop actions where supported
- Apple Watch capture: select an existing Space, Start/Pause/Resume/Stop with the shared CloudKit snapshot
- daily, weekly, monthly, yearly, and lifetime summaries
- space report drill-down from Summaries, adjustable inclusive dates, recorded-description totals, daily sessions, and native text sharing with optional notes
- JSON persistence in the Tick App Group container with CloudKit sync between the iPhone/iPad app and widget actions

Explicitly out of scope for this phase:
- custom authentication, Live Activities, billing, file exports, map search, route capture, location history, and transcription

## Architecture snapshot
App entry and navigation:
- `TickApp` opens `ContentView`.
- `ContentView` owns a root `TickViewModel` and presents a `TabView` with Today, Spaces, Auto Ticks, and Summaries.

Core models:
- `TickProject`: project identity, name, creation date, archive flag.
- `TimeSession`: project link, optional timer dates, optional manual duration, title, notes, source, and creation date.
- `AutoTickRule`: project link, location coordinate, radius, enabled state, and arrival/departure behavior.
- `VoiceMemo`: space link, audio file name, duration, title, and created/updated dates.
- `SessionEntrySource`: distinguishes timer-created, manual, and Auto Tick sessions.

State and operations:
- `TickViewModel` is main-actor isolated because it owns SwiftUI-observed state.
- Project/session mutations live on the view model, not inside SwiftUI view bodies.
- Auto Tick rule mutations and arrival/departure decisions live on the view model.
- Auto Tick rule updates/deletes must persist through `TickDataStore` and refresh monitored regions.
- `TickSummaryCalculator` handles daily, weekly, monthly, yearly, and lifetime duration aggregation.
- `TickSpaceReport` builds read-only space reports and share text. Reports count full session durations by recorded date, matching summary attribution; they do not split overnight sessions. Date ranges include both selected calendar dates.
- Widget App Intents use `TickWidgetActionStore` for small shared-data mutations.
- Voice memo recording, playback, metadata, and audio-file persistence are coordinated through the view model and voice memo stores.

Persistence:
- `TickDataStore` is an actor-backed JSON store.
- The store reads/writes off the main actor and uses atomic writes.
- Saved file path: App Group `group.dn.tick` / Tick / tick-data.json, with one-time migration from the old Application Support path.
- `TickCloudSyncStore` synchronizes the full snapshot with the private CloudKit
  `TickSnapshotV1` / `snapshot-v1` record in `iCloud.dn.tick`.
- The snapshot and its server acknowledgment form an atomic durable outbox.
  `TickCloudMerge` performs a three-way merge, preserves deletion tombstones,
  makes Stop terminal and resolves simultaneous starts to at most two active sessions in different Spaces.
- Legacy iCloud KVS snapshots are imported one way when binding the account.
  `TickICloudSyncStore` remains for compatibility/testing; the default app no longer
  publishes timer snapshots to KVS. Do not restore the old timestamp-only policy.
- Widget actions use the same CloudKit store and local App Group cache.
- The Watch uses `TickCloudClientStore` from TickCore, with a separate atomic
  Application Support cache and acknowledgment per CloudKit environment. It
  shares the same transport, merge rules, and timer mutations with other clients.
- WatchConnectivity carries replaceable refresh hints only; CloudKit remains
  authoritative. Never execute timer commands on both transport paths.
- Watch elapsed time uses native date-based Text rendering. Do not add repeating
  background work, workouts, extended runtime sessions, or continuous polling.
  Sync on foreground entry, actions, and system-delivered change notifications;
  only pending edits get three bounded retries while the app is active.
- Widget snapshots are stored separately as `tick-widget-snapshot.json` in the same App Group container.
- Keep widget shared storage small. Widgets should render from `TickWidgetSnapshot`, not from broad SwiftUI view-model state.
- Voice memo metadata is stored separately from the main Tick snapshot, with audio files in the App Group container and iCloud document storage when available.

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
- accessibility labels/hints for timer actions, space selection, manual entry, space creation, active elapsed time, session rows, session editing, and Auto Tick rule creation
- visible "Manual" and "Auto" badges with spoken source descriptions
- Dynamic Type-friendly SwiftUI text styles for major labels and timer readouts

Reference checks for a future submission (not outstanding current closeout tasks):
- VoiceOver reading order across all four tabs
- large Dynamic Type behavior in Today cards and manual-entry form
- light/dark contrast for material-backed timer and session rows

## Behavior invariants
- Starting a timer must not require a form.
- At most two active timer sessions may exist at a time, one per Space. Paused sessions occupy a slot.
- A manual session uses `manualDuration` as its source of truth.
- Timing corrections are drafts until Save; active or paused Ticks must be stopped first. End/duration edits preserve recorded pause time, source conversions stay completed, and stale timing edits are rejected.
- A timer session duration is derived from `startedAt` and `endedAt`.
- A running session uses `Date.now - startedAt` only for display; elapsed time is not stored continuously.
- Local data should survive app relaunches.
- iCloud sync must preserve the same space/session/Auto Tick snapshot across iPhone and iPad when both devices use the same Apple ID and have iCloud enabled.
- CloudKit uses `TickCloudMerge` and optimistic record-version saves. Preserve offline edits, deletion tombstones, terminal Stop, and account separation.
- Widget Start must not create a duplicate active session in a Space or exceed two active sessions.
- Widget Stop must target the Tick shown in its snapshot; with two active Ticks, widgets open Today to choose rather than stopping ambiguously.
- Widget snapshots store dates and totals, not constantly changing elapsed time.
- Lock Screen widgets use the same snapshot as Home Screen widgets and derive compact elapsed text from `activeStartedAt`.
- Lock Screen accessory rectangular may show Start/Stop buttons where WidgetKit supports App Intent buttons; compact families should still be readable as tap-to-open widgets when direct actions are unavailable.
- Auto Tick arrival must not create a duplicate active session.
- Auto Tick departure must stop only the active Auto Tick session associated with that rule.
- Auto Tick departure must not stop timer-created or manual sessions.
- Deleting an Auto Tick rule must remove its monitored geofence without deleting existing sessions.
- Deleting a session must not delete its project or Auto Tick rules; active sessions must be stopped before they can be deleted.
- Deleting a Tick from a Space requires confirmation. Cancel leaves the Tick and its recorded time unchanged.
- Archiving a space removes it from active capture lists without deleting its sessions, Auto Tick rules, or voice memos.
- Voice memo recording is space-scoped and unavailable for archived spaces.

## UX rules
- Use plain, playful Tick language: Start Tick, Stop Tick, Add Time, Today's Ticks.
- Keep capture lightweight before adding detail-heavy flows.
- Prefer Apple-native controls over custom controls.
- Keep archived spaces visible enough to restore or review their history, while keeping active capture focused on unarchived spaces.

## Coding conventions
- Stay Apple-native. Do not add third-party dependencies.
- Keep SwiftUI views declarative and small.
- Keep business rules in view models, services, or pure helpers.
- Add tests for non-trivial duration, summary, or persistence behavior.

## Version display convention

- Show a read-only Version row in system Settings under Apps > Ticks, formatted `version (build)`.
- The build generates `Settings.bundle/Root.plist` from the processed app Info.plist; no first launch or UserDefaults value is required.
- Keep app, widget, and Watch versions aligned in `Tick.xcodeproj/project.pbxproj`, and increment the build number for each changed build delivered to devices. Install the same artifact on iPhone and iPad.
- Verify the built app, widget, and Settings row agree before delivery.

## Build/run notes
- Project: `Tick.xcodeproj`
- Scheme: `Tick`
- Target platform: iOS Simulator
- Watch scheme: `TickWatch`, watchOS 26 or later; see `docs/WATCH_APP.md`
- CI uses Xcode 26.6 and an explicitly selected iOS Simulator 26.5 runtime. Build, unit, UI smoke, and full UI phases use the same `Scripts/ci.sh` command locally and on GitHub.
- Build warnings should be treated as failures.

## Future release validation reference

The current scope is owner-confirmed complete. Use these procedures when a future release is requested; they are not a remaining acceptance queue.

- Run a signed build on Don iPhone before release checks that depend on system services.
- Verify Auto Tick permission prompts, current-location rule creation, and region arrival/departure behavior on device.
- Verify Home Screen and Lock Screen widget Start/Stop actions against the shared App Group store.
- Verify voice memo record/play/rename/delete with relaunch persistence.
- Verify CloudKit sync between iPhone and iPad for spaces, sessions, Auto Tick rules, and widget-started sessions.
- Re-check VoiceOver reading order, large Dynamic Type, and light/dark contrast before submission.

## Current closeout

- The Watch screen-clearance sprint is closed at Don's request on October 27, 2026; build 41 is installed and visually accepted on his Watch.
- The signed Watch build passed without warnings on Xcode 26.6, and both Watch UI tests passed on Xcode 27/watchOS 27. Full local or hosted CI success is not claimed. See `docs/WATCH_APP.md` for the dated evidence and validation limits.
- Additional validation or UI coverage belongs to separately requested future work.

## Output expectations per patch
Provide:
- Summary of change
- Files modified
- Any migration considerations
- Commit message suggestion
- Accessibility notes for user-facing work: added, verified, missing, or not applicable

## ProjectPilot integration

`Package.swift` exports selected `Tick/WidgetSupport` sources as `TickCore` for
ProjectPilot's Mac client. The iOS targets still compile the same files directly.
Keep the portable sources free of UIKit and app-global UI state. `TickTimerMutation`
provides Mac/widget Start/Stop and the app's paused Stop date calculation. Its
`TickCoreTests` run with `swift test -Xswiftc -warnings-as-errors`.

The Mac controls use the existing container and wire format. They preserve fields
outside their editing scope, including Auto Tick rules. Review paired changes in
both repositories. No data reset or KVS rollback is part of this integration.
Physical widget Stop propagation was unresolved at historical checkpoint `4e84aa9`.
Don's October 18 confirmation closes the current follow-up; builds and unit tests
alone must still not be presented as independent physical-device proof.

## CI reliability and local validation

- For ordinary changes, start with the narrowest relevant build, unit test or UI check. Expand for shared behavior, persistence, startup or release risk. Documentation and local tool-selection helper changes need scoped structural/contract checks; they do not require an application rebuild solely to repeat CI.
- Use `bash Scripts/local-check.sh <command> [args...]` for local checks. It selects already-installed Xcode 26.6 for that command without changing global defaults, and preserves an explicit `DEVELOPER_DIR`. If unavailable, focused commands can use the existing compiler with the difference reported; the strict CI driver still rejects a mismatch.
- GitHub keeps Xcode 26.6 and Simulator 26.5. For deliberate complete reproduction use `bash Scripts/local-check.sh bash Scripts/ci.sh all <fresh-iOS-26.5-simulator-UDID>`. Fresh simulators are for isolated/full reproduction; preserve existing simulator data. Upgrade pinned baselines in a separate validated change.
- Run the complete affected suites when changing build/test workflow behavior, test harnesses or shared fixtures, or when reproducing a hosted failure. Full local CI is not a blanket prerequisite for every edit. Keep GitHub CI enabled and all existing suites/assertions; a focused pass is not a full-suite pass.
- Check installed tools and equivalent capabilities before proposing a download. Do not install or switch global tools merely to obtain exact CI parity for an unrelated change. Report local compiler/runtime/browser/OS differences and checks not run; only observed GitHub results establish hosted CI success.
- Keep clean build-for-testing, unit tests, UI smoke tests, and the full UI suite visible as distinct phases. The same built artifacts are used for test phases; preserve warnings as errors and test assertions.
- Pushes to `main` and pull requests run one fast gate: build, unit tests, TickCore tests, and the representative UI smoke suite. The full UI suite runs only on manual dispatch so ordinary changes do not build and test the same app twice.
- Named UI fixtures may establish preconditions for one behavior under test. They must be DEBUG-only, deterministic, validated by unit tests, and require both reset and cloud-isolation launch arguments. Keep at least one true UI path for each core creation/persistence journey; do not replace the behavior under test with fixture data.
- Changes to UI/harness/CI build/test behavior require the full relevant suite, including deletion confirmation and cancel behavior. A focused test or unit-only pass does not establish full CI success.
- Date fixtures must use an explicit calendar/timezone consistently. UI helpers must replace text deterministically and verify the value, wait for observable readiness, and isolate cloud/Keychain dependencies when those services are not the subject of the test.
- Treat zero-step account/payment/spending-limit failures as unavailable execution evidence. Diagnose the job annotation before changing application code. Keep deployment failures separate from build/test failures.
- Prose-only pushes skip expensive CI; optional pull-request checks still run. New pushes cancel superseded runs of this workflow on the same ref. Never disable CI or weaken assertions to make a run green.

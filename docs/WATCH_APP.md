# Ticks on Apple Watch

The Watch app provides only an existing Space picker and Start, Pause, Resume,
and Stop. Space management, session editing, summaries, voice memos, and Auto
Tick configuration remain on the other clients. An active Tick locks its Space.

## Integration and persistence

`TickWatchViewModel` owns observed UI state. `TickCloudClientStore` is an actor
that atomically saves the local snapshot together with its CloudKit acknowledgment.
The cache is in Application Support `Tick/<environment>/state.json`, separate
from the phone's App Group and the Mac's cache. There is no data migration.

The Watch uses the existing private `iCloud.dn.tick` container,
`TickSnapshotV1` / `snapshot-v1`, `TickCloudMerge`, and `TickTimerMutation`.
It preserves fields outside the Watch controls, including rules and tombstones.
The same Apple ID and CloudKit environment are required across devices. Debug
builds use Development; Release builds use Production. Never reset cloud data
to resolve a device or account issue.

A new install must acknowledge the existing cloud snapshot before recording.
After that, temporary network failures allow durable local actions. A changed
account, unreadable cache, or missing previously acknowledged cloud record
blocks writes and preserves local data. Every action captures the displayed
session ID before refresh, so a stale Stop cannot stop a replacement Tick.

WatchConnectivity exchanges only replaceable change hints. Both clients refresh
CloudKit rather than replaying actions. The new iPhone build enables these hints;
older clients continue to share records through CloudKit.

## Energy behavior

The Watch screen uses a static ice-blue background, blue-gray text, and native
Liquid Glass controls. Reduce Transparency replaces glass with opaque blue
surfaces; increased contrast adds clearer control edges. The wrist-down state
uses a subdued background and opaque controls. These appearance changes add no
animation loop or background work; measured energy use remains a device check.

Elapsed time is derived from stored dates. SwiftUI's native timer Text lets
watchOS manage display updates and Always On rendering. Paused time is static.
There is no repeating Timer, TimelineView, workout, extended runtime session,
location use, or scheduled background refresh.

System-delivered WatchConnectivity tasks complete after pending messages arrive
and one cloud refresh finishes; no additional snapshot is requested.

Sync runs on foreground entry and actions, with brief event-driven refreshes for
CloudKit pushes or phone hints. Pending edits receive at most three foreground
retries after 60, 120, and 240 seconds; going inactive cancels them. Synced state
has no retry loop. System notification delivery can be delayed; opening the app
refreshes it. Source inspection does not establish measured battery drain.

## Build and validation

- Shared model, sync failure, merge, and persistence tests:
  `swift test -Xswiftc -warnings-as-errors`.
- `TickWatchUITests` exercises Space selection, Start/Pause/Resume/Stop, locked
  active Space, and relaunch while paused against an isolated simulator fixture.
- Use `-watchPreviewFixture` only in a Debug Watch simulator to show sample
  Spaces. Fixture cloud data is local and separate from real iCloud.
- Build with `GCC_TREAT_WARNINGS_AS_ERRORS=YES`,
  `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, and `SWIFT_SUPPRESS_WARNINGS=NO`.
- Signed device builds require `dn.tick.watchkitapp` on the existing team with
  CloudKit container `iCloud.dn.tick`, push notifications, and the Watch registered
  for development provisioning. Preserve mandatory pairing and Developer Mode
  confirmations.

Semantic controls expose Space selection and the active Space, timer text,
Pause/Resume/Stop labels, and state hints. Text scales with Dynamic Type and the
layout scrolls. No custom animation or material is required. Physical VoiceOver,
large text layout, live cross-device round trips, push delivery, and measured
energy use remain manual validation checkpoints until observed on devices.

## Physical delivery checkpoint — September 30, 2026

Ticks 2.0 (13) was built without warnings, passed strict code-signature
verification, and was installed and launched on Don's Apple Watch. The Watch
loaded the existing iCloud snapshot: 16 Spaces and 393 sessions, including the
running Tick. Its cloud checkpoint was confirmed at 19:12 UTC with no pending
local edits. No live timer action or recorded session was changed during this
verification. iPhone and iPad were not reinstalled; live Watch action round trips
and measured battery drain remain unverified.

The Watch implementation sprint is closed at the user's request. Hands-on
testing is now user-owned; any reported issues will be follow-up work. Live
cross-device action propagation, push delivery, measured energy use, VoiceOver,
and large text checks remain acceptance checkpoints rather than verified results.

## Watch visual update — October 3, 2026

Ticks 2.0 (17) was built without warnings, passed strict signature verification,
and was installed and launched on Don's Apple Watch. It uses the pale-blue
presentation, keeps Pause and Stop side by side at standard text sizes, reserves
space below the controls, and removes the navigation title beneath the clock.
The centered Space name remains tappable in the ready state, with no chevron
and a minimum 44-point hit target. Accessibility text sizes retain a scrollable
vertical control layout.

The focused simulator timer-flow test passed with checks for aligned, hittable
controls and bottom clearance at the largest standard text size. The user's
on-watch photo of build 15 confirmed both controls were visible above the lower
edge. Build 16's empty navigation title and control spacing were visually
verified in the simulator and a physical Watch screenshot. Build 17's Space
picker without a chevron was confirmed in the user's on-watch photo; the user
approved the on-watch appearance.
The physical build 14 cloud checkpoint was fresh with no pending edits before
these spacing updates. Verification did not perform any live timer action.
The update introduces no data migration or additional background work; measured
energy use and physical accessibility checks remain unverified.

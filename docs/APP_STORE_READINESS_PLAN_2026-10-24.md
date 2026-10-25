# Tick App Store readiness plan

Prepared October 24, 2026 from twelve read-only `APP-xxx` reviews run against Tick. `APP-App Store Submission` was deliberately excluded. The reviewed commit is `d4beec4676bff59c789279ce9446205f9418e42c`; the privacy-policy and manifest changes were present as uncommitted working-tree work. Findings below count shared root causes once.

**Decision: hold submission.** The initial review found reproduced data-loss and account-isolation paths and an incomplete privacy-policy contact and URL. The engineering fixes below have since been implemented, but signed-device and account-separation checks remain before a release can be treated as ready.

**Implementation update, October 24:** The local engineering changes for coordinated app/widget saves, corrupt-file preservation, voice-memo account binding and durable deletion, failed-save reporting, stale edit protection, widget action timing, and the listed accessibility fixes are implemented. The policy includes `donnoel@icloud.com`, and its [public GitHub URL](https://github.com/donnoel/Tick/blob/main/docs/PRIVACY_POLICY.md) returned HTTP 200 after publication. TickCore's 15 tests, focused app safety and cloud-sync tests, and the privacy, timing-editor, and manual-entry UI checks passed with warnings treated as errors. The full local suite was intentionally not repeated. Physical interaction on iPhone/iPad/Watch, two-account iCloud, location, and App Store Connect verification remain release gates; no submission was attempted.

Build 2.0 (29) signed without warnings, with app/widget/Watch manifests packaged. The same iOS artifact installed and launched on Don's iPhone and iPad. The paired Watch still reported build 22 before an attempted update; its installation failed when the device connection closed, and a subsequent query timed out. Watch build 29 is therefore unverified on device. Launch is not a hands-on test of capture, sync, recording, location, accessibility, or battery behavior.

## 1. Protect recorded data and account boundaries

These changes come first because they can lose time records or move a recording into the wrong iCloud account.

1. **Make app and widget saves one coordinated transaction.** The current read/merge/write sequence and whole-array session replacement can drop a widget-created Tick or revive a widget-stopped Tick after an app edit. Merge by record ID within one coordinated storage operation and keep Stop terminal. Cover competing app/widget Start, Stop, metadata edit, and an edit made during CloudKit upload. The existing [merge and persistence path](../Tick/ViewModels/TickViewModel.swift) is the implementation boundary. This failure was reproduced in isolated harnesses using the actual stores and extracted merge logic.
2. **Bind voice memo data to the current iCloud account.** The current memo merge/upload path can copy account A's cached metadata and audio into account B's iCloud directory after an account switch. Gate local memo reuse and all cloud uploads on established account ownership; retain files safely when ownership is uncertain. Test a simulated account switch, offline reconnection, rename, and deletion. See [TickVoiceMemoStore](../Tick/Services/TickVoiceMemoStore.swift). The cross-account copy was reproduced with simulated account directories, not real iCloud accounts.
3. **Make memo deletion durable before removing audio.** A failed metadata save can leave a durable memo reference while the audio is deleted. Save the deletion record first, propagate failure, and keep a recoverable UI state. Apply the same rule to Space deletion. See [memo mutation callers](../Tick/ViewModels/TickViewModel.swift). An injected metadata failure reproduced this path.
4. **Report failed local saves as failures.** `persist()` currently catches local write errors while mutation callers can still return success and dismiss editors. Return a durable-local-save result distinct from pending cloud sync; retain a retryable draft when saving fails. Test Add Time, session edits, and Space changes with injected write errors and relaunch. See [TickViewModel](../Tick/ViewModels/TickViewModel.swift).
5. **Reject malformed storage envelopes safely.** An invalid envelope field can fall through legacy decoding and appear as empty history; a later save can overwrite the original data. Detect document shape before legacy fallback, preserve the invalid file, and surface recovery guidance. Test a damaged envelope containing intact nested history. See [TickDataStore](../Tick/Services/TickDataStore.swift) and [TickStorageSnapshot](../Tick/Models/TickStorageSnapshot.swift).

Acceptance for this phase: each reproduced failure has a focused regression test, the fixes pass under Xcode 26.6 with warnings treated as errors, and existing records remain recoverable across failure and relaunch. Validate account separation with real iCloud accounts before release; synthetic tests alone do not establish it.

## 2. Close the remaining capture and editing gaps

1. **Protect drafts from concurrent changes.** Apply only edited metadata fields or detect conflicts so a stale editor cannot restore older notes. Revalidate the selected Space when Add Time is saved so a deleted Space cannot produce an orphaned session. Both scenarios were reproduced in isolated state tests. See [SessionDetailView](../Tick/Views/SessionDetailView.swift) and [ManualTimeEntryView](../Tick/Views/ManualTimeEntryView.swift).
2. **Make Auto Tick failures visible.** Monitoring errors currently disappear from the Auto Ticks screen after Always location permission is granted. Show monitoring state independently of authorization and test that an authorized but failed rule does not appear ready. See [AutoTicksView](../Tick/Views/AutoTicksView.swift).
3. **Prevent overlapping voice memo starts.** Reserve recording-start state before awaiting permission and file preparation; reject a second start in the audio controller. Verify record, cancel, stop, and failed-permission recovery on device. See [voice memo startup](../Tick/ViewModels/TickViewModel.swift).
4. **Preserve the tap time for widget actions.** Capture the invocation timestamp before awaiting cloud refresh. Keep account and single-active-session safeguards. Measure Watch and widget response under slow sync before changing wait policy. See [TickWidgetIntents](../TickWidgetExtension/TickWidgetIntents.swift).
5. **Check stale reloads.** A cancelled reload may still apply an older snapshot. Reproduce overlapping foreground/cloud refresh with a timer action before adding a generation or serialization guard.

Acceptance: focused tests cover each state transition; iPhone, iPad, widget, Watch, and location behavior are checked on the intended signed build where applicable.

## 3. Complete privacy and accessibility readiness

The in-app policy and app/widget/Watch manifests are drafted and packaged in clean unsigned builds. Their new UI test was compiled but has not been run.

1. Add the owner's privacy contact to both [policy copies](PRIVACY_POLICY.md) and publish the matching text at a stable public HTTPS URL. The selected contact is `donnoel@icloud.com`, and the selected URL is the policy document in the public Tick GitHub repository. Verify the policy and support URLs and App Privacy answers in App Store Connect. The current [privacy configuration](PRIVACY_CONFIGURATION.md) documents this unfinished gate.
2. Run the focused privacy-sheet UI check, then verify the text and permission explanations on iPhone and iPad. Keep the policy aligned with private iCloud synchronization, optional location and microphone use, sharing, and deletion behavior.
3. Restore the actual spoken Auto Tick instructions and errors; expose the Lock Screen widget's Start/Stop action to VoiceOver; include elapsed values in widget labels; make summary chart entries individually navigable. See [AutoTicksView](../Tick/Views/AutoTicksView.swift), [TickWidget](../TickWidgetExtension/TickWidget.swift), and [SummariesView](../Tick/Views/SummariesView.swift).
4. Check common tasks on iPhone and iPad with VoiceOver, maximum text sizes, contrast, and keyboard access. Include widget and Watch actions before declaring an accessibility feature in App Store Connect. Current source evidence does not support a VoiceOver claim.

The public policy/contact decision can happen while engineering fixes are underway. Publication and App Store Connect verification are required before submission.

## 4. Strengthen focused validation and the release pipeline

1. Add direct tests for the app/widget [`TickCloudSyncStore`](../Tick/WidgetSupport/TickCloudSyncStore.swift) coordinator: account binding, conflict retry, migration, upload-time local edit, and acknowledgment. Existing portable-client and legacy KVS tests do not cover this exact production path.
2. Add the existing TickCore package tests to CI, with warnings treated as errors. The current [workflow](../.github/workflows/ci.yml) runs the Tick scheme but omits the separate package target. Keep Watch UI checks in their appropriate scheme.
3. After the fixes, run targeted tests during development, then one complete release validation run through the documented CI path. Avoid repeating the full local and GitHub suites after each small edit.
4. Build one signed candidate and check actual iPhone/iPad/Watch capture, app/widget synchronization, iCloud account separation, memo record/play/delete, Auto Tick arrival/departure, reports, and permission denial/recovery. Verify the intended Production CloudKit schema and environment. Clean unsigned builds and synthetic reproductions do not prove these behaviors.
5. Finish App Store Connect screenshots, metadata, age rating, support contact, privacy answers, and reviewer notes. Submit only after the release gates above pass; the `APP-App Store Submission` task was not run in this review.

## 5. Improve performance and documentation after the safety fixes

- Resolve the voice memo iCloud container off the main startup path and reuse it; move coordinated widget snapshot writes off the main actor and coalesce redundant refreshes. Profile on devices with realistic history and slow sync before claiming a latency or battery benefit.
- Update the [README](../README.md) to use the pinned Xcode 26.6 / iOS 26.5 CI command, correct the [website source](../index.md) that still describes timer synchronization through KVS, and update the four-tab references in [AGENTS.project.md](../AGENTS.project.md).
- Defer unused chart builders, unused convenience methods, and repeated initializer cleanup until after submission readiness. Retain the legacy KVS import path; it is still used for migration.

## Evidence and limits

The twelve Tick reviews covered accessibility, pre-submission readiness, post-change regressions, persistence, concurrency, core flow, state architecture, documentation, performance, dead-code drift, regression coverage, and quality rollup. Multiple audits independently reproduced app/widget merge loss; isolated probes also reproduced account mixing, deletion ordering, malformed-envelope fallback, and false save success. These are test/source findings, not reports of observed customer data loss.

Xcode 26.6 produced warning-free unsigned Release and simulator build-for-testing artifacts. The app, widget, Watch, and Settings row agreed on version 2.0 (28), and bundled privacy manifests matched source. Focused tests passed; the full suite, new privacy UI test, signed physical-device checks, live Production CloudKit, and App Store Connect state were not established by this review. All twelve reviews were read-only and left the existing privacy work uncommitted.

# Testing Architecture

Tick uses a conventional test pyramid: broad, fast model and service coverage;
a small UI smoke gate for essential journeys; and a complete UI regression suite
for cross-screen behavior. The goal is not fewer assertions. It is to put each
assertion at the cheapest reliable layer.

## Test layers

### Unit and integration tests

`TickTests` owns model, view-model, persistence, merge, sync, and UI-state
contracts that do not require rendered controls. `TickCoreTests` owns the
portable package contracts used by ProjectPilot and shared timer clients.

Both suites run on every code push and pull request. New edge cases should start
here unless the contract specifically depends on navigation, accessibility, or
system UI.

### UI smoke tests

The smoke suite runs on pushes to `main` and pull requests, and exercises five representative
customer journeys:

- create a Space, start and stop a Tick, and observe the session
- create data and prove it survives relaunch
- cancel and confirm deletion from Space detail
- control two Space timers independently
- open and share a detailed Space report

Run it with:

```sh
bash Scripts/ci.sh ui-smoke <simulator-UDID>
```

Smoke tests are a fast integration signal, not a substitute for the full suite.

### Full UI regression

Every UI assertion remains in `TickUITests`. The complete suite runs:

- nightly on the default branch
- on demand through the **UI Regression** GitHub Actions workflow

Run the same phase locally with:

```sh
bash Scripts/ci.sh ui <simulator-UDID>
```

The full suite covers secondary navigation, privacy, editing, timing correction,
both deletion surfaces, timer-card ordering, totals, Auto Tick guidance, and
visual/accessibility control availability.

## Deterministic UI fixtures

Named fixtures in `Tick/Testing/TickUITestFixtures.swift` establish data-heavy
preconditions without spending UI time repeatedly typing the same setup. They
are compiled only in the app's Debug configuration through the dedicated
`UITEST_FIXTURES` compilation condition and are installed only when all three arguments are
present:

```text
-resetDataForUITests
-disableCloudSyncForUITests
-uiTestFixture <name>
```

Fixture snapshots use stable identifiers, are written atomically through the
production envelope format, and have a unit test for referential integrity and
Codable round trips. An invalid or non-isolated fixture request fails the test
launch. Fixtures must not bypass the behavior being asserted; core creation and
persistence journeys continue to create their data through the UI.

## CI policy

The push and pull-request workflow uses one build-for-testing artifact for unit and smoke phases.
The full regression workflow separately builds once and runs the complete UI
suite. Both use Xcode 26.6, iOS Simulator 26.5, warnings as errors, no retries,
and failure artifacts. Superseded runs on the same ref are cancelled.

Use focused local checks while developing. Run a complete affected suite for
shared fixtures, harness changes, CI behavior, persistence/startup changes, or
release validation. Do not repeat a full local and hosted suite after every
small edit; choose the evidence appropriate to the changed contract.

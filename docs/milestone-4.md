# Milestone 4 delivery policy

The independent review found correctness defects after this initial implementation. [Milestone 4 targeted hardening](milestone-4-hardening.md) supersedes the authorization, contention, freshness and startup details below and records the follow-up verification.

The approved timing and ranking rules remain unchanged. A valid adapter arrival is fresh within 30 seconds, with five seconds future tolerance. Only an authorized qualifying arrival is accepted; navigation is not an arrival. Source never participates in matching.

| Outcome | Durable state/timestamps | Arrival and cooldown | Next attempt |
| --- | --- | --- | --- |
| Reservation | reserved attempt; global last-attempt = reservation UTC | Event and visit consumed; 15-minute global cooldown starts | New visit after cooldown; no simultaneous outstanding delivery |
| Submission succeeds | submitted; bookmark last-submitted = confirmation UTC | Same consumed visit; one-hour item cooldown | New visit after both cooldowns |
| Definite failure | failed; item unchanged | Visit consumed; global cooldown remains | New visit after global cooldown |
| Unknown outcome | unknown; item unchanged | Visit consumed; global cooldown remains | New visit after global cooldown; never replay the attempt |
| Crash after reservation | reserved until five-minute reservation lease expires, then unknown | Global cooldown remains; no replay | New visit after global cooldown |
| Duplicate during delivery | no new attempt | Event/visit deduplication and pending reservation suppress it | New visit after cooldown |
| Restart | read durable control/attempt state; expire stale reservations | Neither cooldown nor identity resets | Same rules as above |

A five-minute reservation lease bounds abandoned/hung delivery. Late results after expiry cannot change unknown outcomes. The adapter must honor the lease and must not submit after it expires; a future OS adapter must support this contract. This milestone wires no real context adapter or delivery presenter into the application. Success means submission accepted, never visibility/readership.

All valid arrivals, including suppressed arrivals, are consumed. Retain event/visit records for 24 hours measured from receipt; older events also fail freshness checks. Pending attempts suppress new reservations globally until resolved/expired. At least 15 minutes between attempts applies even to failed/unknown attempts. Expired snooze is computed as active eligibility without a timer or automatic notification; the next valid arrival is required. Completed items remain completed. Reopening completed items is not in the approved product specification.

Persistence uses the existing SQLite connection and an explicit v1-to-v2 migration. Custom SQL tables hold reminder control and consumed arrivals/attempts; no bookmark column or previous record is rewritten. Only opaque event/visit IDs, receipt times, bookmark IDs and outcomes are retained, never browser URLs/history. Snooze choices are one hour and 24 hours. Settings support enabled and paused-until as domain/persistence controls; no disconnected automation toggle is added to the UI.

## Implementation and limits

The evaluator takes bookmark snapshots, a parsed arrival, reminder state and an explicit time. It has no Flutter, database, network or system-clock dependency. It chooses high before medium before low, never-reminded before previously reminded, then earliest submission, oldest creation, and ascending ID. Library sorting remains independent. Every nonselected item has an exclusion/ranking reason when evaluation reaches item selection.

The coordinator reserves under SQLite's write lock before calling the injected delivery interface. It rechecks the bookmark, trigger, settings and lease before submission. Completion, deletion or a newly applied snooze suppresses submission at this check. Future adapters must resolve races after this check and honor the expiry contract. A Future timeout cannot cancel a native operation; real OS cancellation/deadline behavior is a Milestone 5 gate, not a proven feature here. Database failures propagate; failed acknowledgement persistence leaves a recoverable reservation rather than fabricated success.

All lifecycle times are UTC. The UI displays snooze time locally. Snoozed status is retained as recorded history after expiry; the evaluator computes eligibility, without scheduling a timer or notification. Completion clears snooze. No completed-item reopening action was required. Existing Open/edit/delete behavior is preserved.

Two schema-v2 tables are created for fresh databases and by the v1 migration: `reminder_control` (one settings/cooldown row) and `reminder_arrivals` (unique event and visit IDs, reservation/outcome fields). Custom SQL avoids adding generated model classes for these internal records; this is a small implementation choice within Drift, not a second persistence framework. Migrations, reservation, finalization and recovery are exercised against real SQLite. The migration fixture builds the unchanged v1 bookmark schema with populated rows and no reminder tables, sets its version to 1, then verifies every bookmark column after upgrading. No user database is reset.

## Verification evidence — 2026-11-05

The initial full test run passed 46 tests. Analysis reported ten brace-style findings in the new files; `dart fix --apply --code=curly_braces_in_flow_control_structures` corrected them. Subsequent tests add late acknowledgement rejection, successful-submission restart cooldowns, UI read-only-database failure/retry and interrupted-migration recovery. The final unit/widget run passed **50 tests**, retaining all 34 existing regressions. Analysis reported no issues. `dart run build_runner build` passed; SHA-256 comparison confirmed `lib/data/bookmark_store.g.dart` remained unchanged.

Inspection of the installed Drift implementation showed custom migration statements were not implicitly atomic. Both creation and upgrade now explicitly transact schema statements and `user_version` together. A regression injects failure after creating the reminder tables, closes the failed connection, then verifies a clean retry preserves the bookmark and reaches schema 2. A format check caught the newly added test before formatting; after `dart format`, the strict check passed with 20 files and zero changes. No assertion was weakened.

New deterministic tests cover malformed/unauthorized/navigation/unsupported events; source/trigger independence; priority and ties; completed, snoozed and cooldown exclusions; exact freshness/snooze/cooldown/lease boundaries; enabled/pause controls; event/visit deduplication; 100 concurrent reservations; pending delivery; submitted/failed/unknown outcomes; exception handling; late results; rollback; v1 migration; close/reopen recovery; retained settings; successful cooldown persistence; 24-hour metadata expiry; real snooze/completion UI and snooze failure/retry. Controlled delivery and arrivals exist only in tests. No live browser/notification claim follows from these results.

The native workflow additionally snoozes, closes/reopens file-backed SQLite, checks the displayed persisted deadline, completes and verifies the snooze is cleared, then runs the existing delete checks.

Commands use the existing README toolchain recipe: temporary `subst S: 'D:\Codex Projects'`, `Set-Location S:\Revisit`, `. ./tool/use-local-toolchain.ps1`, and `S:\Revisit\.tools\flutter\bin` first on the process PATH. Android uses process-only `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false` to accommodate plugin sources on a different drive. No dependencies, permissions or SDK installations were added.

```text
dart format lib test integration_test
dart fix --apply --code=curly_braces_in_flow_control_structures
flutter --suppress-analytics analyze --no-pub
flutter --suppress-analytics test --no-pub --reporter expanded
dart run build_runner build
Get-FileHash lib/data/bookmark_store.g.dart
flutter --suppress-analytics build windows --release --no-pub
flutter --suppress-analytics test --no-pub --reporter expanded integration_test/bookmark_workflow_test.dart -d windows
```

Windows release build and Android release build (54.4 MB development-signed APK) passed. The native workflow passed on Windows and Android 16/API 36 emulator after the final atomic-migration correction. These are actual Flutter UI executions with real SQLite, not mock platform builds. File close/reopen is verified in this milestone; the earlier full process-restart evidence remains recorded under Milestone 3. Ignored `build/m4-*.log` files retain command output locally.

Additional verification commands:

```text
flutter --suppress-analytics test --reporter expanded integration_test/bookmark_workflow_test.dart -d emulator-5580
flutter --suppress-analytics build apk --release --android-project-arg=kotlin.incremental=false
dart format --output=none --set-exit-if-changed lib test integration_test
flutter --suppress-analytics devices
git diff --check
adb -s emulator-5580 install -r build/app/outputs/flutter-apk/app-release.apk
adb -s emulator-5580 shell am start -W -n com.revisit.revisit/.MainActivity
adb -s emulator-5580 shell uiautomator dump /sdcard/revisit-m4.xml
adb -s emulator-5580 pull /sdcard/revisit-m4.xml build/m4-release-ui.xml
```

The final APK installation succeeded and Activity Manager reported a successful cold launch. Its actual accessibility hierarchy showed Revisit's library, New bookmark button and real empty state. This checks release launch; snooze/completion interactions were verified by native automated workflows rather than a separate manual accessibility audit. `flutter devices` found Windows, Android emulator-5580, Chrome and Edge; no physical Android device. Final format check: 20 files, zero changes.

The first sandboxed `adb devices` probe could not start its daemon. The authorized elevated emulator check succeeded; it used the existing `Revisit_M2` read-only, headless AVD on port 5580. No physical Android device was available. `git diff --check` passed with existing line-ending notices. Much of the implementation was already untracked at task entry, so Git's tracked diff alone does not describe this milestone. Existing work was preserved; no commit was made.

## Review and next gate

Review the pure evaluator, SQL migration/reservation/finalization, delivery lease contract and native lifecycle tests together. Manual checks still recommended: snooze both durations, close/relaunch, inspect the deadline, edit while snoozed, complete and confirm snooze is unavailable; verify keyboard/screen-reader behavior on actual target devices. Do not wait an hour to test the engine; deterministic tests cover the expiry boundaries.

The next smallest task is an independent Milestone 4 review. After approval, Milestone 5 must prove the real Chrome → host → app path and actual toast submission/activation, including permission denial, focus/refresh semantics, reconnect, minimized operation and expiry/cancellation races. The persisted preference APIs still need genuine integration controls at that point. No Android background monitoring is implemented or claimed.

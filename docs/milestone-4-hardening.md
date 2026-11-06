# Milestone 4 correctness hardening

The independent review failed Milestone 4. This task addresses its lifecycle, schema-version, contention and startup findings. Milestone 5 remains separately gated.

## Submission ordering

Reservation remains durable before any delivery. Final authorization acquires SQLite's write lock, reads the current bookmark/settings/attempt, and checks freshness with the injected clock. Lifecycle writes invalidate `reserved` attempts in the same transaction as the bookmark change. Authorization conditionally claims a still-reserved attempt as `unknown`, then invokes the adapter's immediate handoff while that short transaction still owns the write lock. The returned delivery Future is wrapped and awaited only after the transaction ends.

The handoff invocation is the ordering point. A lifecycle change committed before it prevents submission. Other connections cannot commit a lifecycle write between the protected check and this invocation. The adapter must immediately initiate its request and return a Future without doing slow synchronous work or asynchronous preparation before initiating the request. It must not call back into the repository during handoff. Real native adapters must demonstrate this contract in Milestone 5.

After handoff, delivery is in flight. Completion/snooze/deletion can commit while the acknowledgement is pending, and their bookmark changes remain authoritative. The request may already reach the OS, so cancellation is not promised. A successful acknowledgement records submission without reversing a lifecycle change. An exception, missing acknowledgement, process loss or expired lease leaves `unknown`. Such attempts are never automatically replayed. Exactly-once presentation and proof of visibility remain unavailable across the OS boundary.

An in-memory, single-use authorization capability permits recording the result for this specific event and reservation time. It cannot be reconstructed after restart. SQLite holds the durable pessimistic `unknown` result from authorization, so losing that capability is safe. No schema change is required. A failed authorization commit after invoking handoff is never retried, preventing repeated external calls; its previously committed reservation still provides cooldown/recovery protection.

## Ownership and contention

The application normally owns one store. The Windows runner currently permits multiple processes, while the proof receiver has a first-pipe-instance guard. Receiver exclusivity does not establish database exclusivity. Supported storage operations therefore use bounded retry of whole SQLite write transactions on BUSY/LOCKED only. Non-contention errors propagate. Exhaustion raises a typed busy error; coordinator admission reports `storageBusy` and does not claim the event was consumed. Existing UI error/retry states handle lifecycle/startup failures. Retry refreshes time and eligibility, with no external side effect inside a retryable attempt.

## Timing and retention

Freshness applies at admission, after reading the selection snapshot, and immediately before final handoff. The existing inclusive 30-second past/five-second future window remains. An event that ages out before selection is rejected without consuming its identity. If it ages out after reservation, the attempt fails and keeps the global attempt cooldown. Tests inject time rather than waiting through these windows.

Valid wrong-context or otherwise suppressed arrivals may store deduplication IDs. They do not change bookmark rows or start a cooldown. This preserves the original consume-valid-arrivals policy and clarifies the review's “no side effects” wording.

Startup runs recovery before exposing the library. Recovery also runs during reminder processing. Rows older than 24 hours are removed, reserved attempts at least five minutes old become unknown, and fresh reservations remain reserved. Bookmark data and current cooldown timestamps survive cleanup. Cleanup resumes at startup after the app has been closed; no background scheduler is added. UTC protects against timezone changes. Wall-clock adjustments can affect wall-clock deadlines and are not a trusted elapsed-time guarantee.

## Schema handling

The supported schema stays at version 2. Fresh creation and v1-to-v2 migration remain atomic. An unsupported newer version is rejected before the migration callback makes changes, preserving its version and data.

## Regression evidence

Seven new regressions were run before production edits. All seven failed, reproducing completion/snooze/deletion after the final bookmark read, newer-schema downgrade, 40-event independent-connection contention, missing startup retention, and stale handoff after a processing delay. The original adversarial review fixtures were available for comparison, but permanent focused tests were added to `test/reminder_hardening_test.dart`.

The existing migration/restart test had expected a reservation to remain pending after snooze. Its assertions now require a durable failed reservation, as required by atomic invalidation. Bookmark-column preservation, persisted snooze/settings/cooldown checks and retention assertions remain. Separate file-backed tests retain coverage for an unsubmitted reservation across restart, stale recovery, and an authorized unknown attempt across restart.

Additional tests cover immediate handoff ordering against another connection, lifecycle completion while each acknowledgement outcome is pending, transaction rollback for each lifecycle change, no repeated handoff after an injected post-handoff commit failure, bounded BUSY exhaustion and successful retry afterward, fresh time after contention, invalidation after the last read, final-handoff freshness at 30 versus 31 seconds, wrong-context metadata, and old/fresh/unknown/reserved cleanup. Native workflows retain the existing capture/edit/snooze/reopen/complete/delete checks.

The initial corrected full run passed 65 tests. Expanded concurrency/recovery checks then passed 70. The final suite, including lifecycle rollback injection, passed **71 tests** (the existing 50 plus 21 new tests). Analysis found brace-style issues and an unnecessary non-null assertion during implementation; these were corrected and the checks rerun. No checks were disabled.

## Verification commands

All Flutter commands use the existing README environment recipe: `subst S: 'D:\Codex Projects'`, working directory `S:\Revisit`, `. ./tool/use-local-toolchain.ps1`, and `S:\Revisit\.tools\flutter\bin` first on process PATH. Android uses process-only `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false`. Existing SDKs and cached dependencies are reused.

```text
git status --short
git log -3 --oneline
flutter --suppress-analytics test --no-pub --reporter expanded test/reminder_hardening_test.dart
dart format lib test integration_test
flutter --suppress-analytics analyze --no-pub
flutter --suppress-analytics test --no-pub --reporter expanded
dart run build_runner build
Get-FileHash lib/data/bookmark_store.g.dart
dart format --output=none --set-exit-if-changed lib test integration_test
flutter --suppress-analytics build windows --release --no-pub
flutter --suppress-analytics test --no-pub --reporter expanded integration_test/bookmark_workflow_test.dart -d windows
flutter --suppress-analytics test --reporter expanded integration_test/bookmark_workflow_test.dart -d emulator-5582
flutter --suppress-analytics build apk --release --android-project-arg=kotlin.incremental=false
node --test companion/chrome/test/*.test.js
flutter --suppress-analytics devices
git diff --check
```

Git still has only the starter commit and substantial pre-existing untracked source. File comparison with the independent review's 97-file hash inventory is used to check scope, rather than claiming a reliable milestone diff from Git alone. No commit is authorized.

| Check | Observed result |
| --- | --- |
| Original seven regressions before production edits | All seven failed, reproducing the reported defects and freshness gap |
| Final Flutter unit/widget suite | 71 passed |
| Final static analysis | No issues |
| Strict formatting | 22 files, zero changes |
| Drift generation and generated-file hash | Passed; generated bookmark source identical |
| Windows release build | Passed |
| Windows native integration | Passed capture/edit/snooze/reopen/complete/delete workflow |
| Android release build | Passed; 54.4 MB development-signed APK |
| Android native integration | Passed on Android 16/API 36 emulator-5582 |
| Chrome companion contract tests | 10 passed, synthetic events only |
| Git whitespace check | Passed, with existing line-ending notices |

No toolchain installation or system-setting change was required. The Android test target used the existing `Revisit_M2` AVD in read-only/headless mode on port 5582, with cold boot verified using `adb shell getprop sys.boot_completed`. `flutter devices` reported Android emulator-5582, Windows, Chrome and Edge. Logs are retained locally in ignored `build/m4-hardening-*.log` files. Both native workflows executed the Flutter application with disposable SQLite databases. A separate manual release UI walkthrough was not performed in this task.

Verdict: targeted hardening PASS, ready for independent re-review. Milestone 5 remains unauthorized. The task emulator and temporary drive alias are removed after verification, preserving unrelated user work.

## Files and review scope

New files: `lib/data/sqlite_write_policy.dart`, `test/reminder_hardening_test.dart`, and this report.

Modified application files: `lib/application/reminder_coordinator.dart`, `lib/data/bookmark_store.dart`, `lib/data/reminder_store.dart`, `lib/domain/reminders.dart` (explicit busy decision), and `lib/ui/revisit_app.dart` (startup recovery and injected startup clock). Modified existing test: `test/reminders_test.dart` (required snooze invalidation outcome). Product, architecture, milestone-4, plan and quality documentation record the resulting policies and evidence.

Public reminder decisions still describe selection/suppression. Callers must use persisted outcomes to assess submission. `storageBusy` is an explicit failure to complete processing, including outcome recording; a durable reservation/unknown attempt may exist if admission succeeded earlier. Retrying an event cannot bypass its persisted deduplication and cooldowns.

## Remaining integration gates

Independent re-review should inspect the protected handoff ordering, its adapter contract, bounded retry and callback-zone boundary. Real Chrome arrivals and actual Windows notification submission/activation/cancellation are Milestone 5 gates. Physical Android hardware and hosted CI remain unverified. A native adapter that performs asynchronous preparation before initiating submission violates the handoff contract; preparation must finish before requesting final authorization. Wall-clock manipulation is outside the elapsed-time guarantees. Application operations must use the repository lifecycle methods so invalidation and mutation commit together.

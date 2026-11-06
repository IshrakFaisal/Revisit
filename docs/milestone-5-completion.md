# Milestone 5 production completion — checkpoint

The completion brief supersedes the earlier Gate A–F implementation ordering. Milestone 6 is not authorized.

## Current checkpoint — 2026-11-06, production release relaunched

**Milestone 5 is not complete.** The earlier sections below are historical checkpoints. Their pending approvals, activation failure and 87-test counts have been superseded by the results here.

### Root causes and corrections

1. Host installation was declared before Flutter initialized its bundle prefix. Moved the rule after initialization and added a package checker. Two genuinely fresh builds passed; the first bundle launched and rendered the existing library.
2. A temporary status widget owned the receiver. `WindowsSession` now owns one adapter/coordinator for the store session. UI replacement only observes it; shutdown waits for native pipe release before store closure.
3. Arrivals were never dispatched to the existing coordinator. The session now invokes it, reads durable results, and reports suppression/failure/uncertainty without implying visibility.
4. Activation lacked application navigation. The session re-reads the current bookmark and opens the existing watching detail view. Native COM activation validates the app identity and positive numeric bookmark ID. It does not accept URLs or alter lifecycle state.
5. Notification identity setup was incomplete. The user explicitly approved both the shortcut and the additional HKCU identity. Both were installed, and a read-only helper check confirmed matching ownership. No machine registry, notification preferences, LocalServer32, autostart or closed-app launcher was added.
6. The native adapter queried `ToastNotifier.Setting` before sending its first toast. On this machine the query returned “Element not found” despite matching registration. Microsoft's compatibility implementation documents the first-toast prerequisite. A permanent native regression fails with the old behavior; the corrected helper allows only ERROR_NOT_FOUND to proceed to the real Show call. Known disabled settings still block; other errors propagate. No synthetic initialization toast is sent.

### Current measured evidence

| Check | Actual result |
| --- | --- |
| Full Flutter suite | 93 passed (`final-tests.log`), including 12 session tests |
| Dart formatting and analysis | 28 files, zero changes; no analysis issues (`final-analyze.log`) |
| First-use notification regression before correction | Four native tests passed; new notification test failed with an unhandled Windows error (`settings-before.log`) |
| Native tests after correction | Five passed: framing, bounded worker, notification settings, activation boundary, peer identity (`settings-after.log`) |
| Chrome contracts plus forged production caller | 11 passed: ten Chrome cases and rejection of Node caller using the correct claimed extension origin |
| Real Windows platform integration | Final rerun passed both tests after the COM/settings changes. The native Debug runner built in 36.4 seconds (`native-handoff-final.log`) |
| Final fresh Windows source copy | `clean-final` had no build directory; locked offline dependencies resolved; first release build passed in 84.3 seconds (`clean-final-build.log`) |
| Final clean bundle | Package checker passed: app, host, setup helper, DLLs/assets present, no Program Files installation rule |
| Updated production build and launch | Initial LNK1104 while the previous executable was running. After normal close, rebuild passed in 50.5 seconds (`notification-fixed-build-retry.log`). The release app launched with an initialized library, a listening receiver and detected notification setup |
| Android regression release | Passed in 156.3 seconds, 54.4 MB development-signed APK; SDK XML-version warning retained (`android-build.log`) |
| Approved notification setup | `--register-identity` exit 0; final rebuilt helper `--check` exit 0 confirmed matching shortcut and registered identity, truthfully reporting Windows settings not initialized. No test toast was sent |
| Actual production arrival | Earlier genuine arrival selected bookmark ID 1 and persisted `failed`. After the rebuild, foreground navigation from example.org to GitHub in the isolated Chrome profile selected bookmark ID 4 and persisted `submitted` at 08:43:21 on November 6 (Dhaka time) |
| Requested M5 fixture | Saved through the release app's form and confirmed in SQLite as active item 4, with source X, GitHub trigger and High priority |
| Windows notification receipt | The Revisit-specific Windows history API returned one real entry, tag `4`, expiring at 08:48:21 Dhaka time. This matches the bookmark ID and submission lease. After the submission, `--check` returned Windows notification setting `0` (enabled) |
| Visible banner / actual click | NOT VERIFIED. The earlier user attempt produced no visible result. The post-fix history entry verifies Windows receipt. User observation and click verification are pending |

The native test's initial compile failed for a missing Windows header; that harness include was corrected before recording the failing behavior. The subsequent pre-fix test failure and post-fix pass used the same assertions. A limited sandbox process query incorrectly appeared empty; an elevated read-only process query confirmed PID 28860 still held the production executable, explaining the linker failure.

Automatic approval review initially stopped the final Windows channel rerun because of its usage limit. On resumption the old temporary drive mapping was absent. Restoring it with `subst S: 'D:\Codex Projects'` allowed the approved test command to run successfully.

### Commands at this checkpoint

From `S:\Revisit`, with `. ./tool/use-local-toolchain.ps1`:

```text
dart format lib test integration_test
flutter --suppress-analytics analyze --no-pub
flutter --suppress-analytics test --no-pub --reporter expanded
flutter --suppress-analytics build windows --release --no-pub
flutter --suppress-analytics build apk --release --android-project-arg=kotlin.incremental=false
flutter --suppress-analytics test --no-pub --reporter expanded integration_test/windows_handoff_test.dart -d windows
node --test companion/chrome/test/*.test.js companion/windows_host/test/desktop_host.test.mjs
./tool/build-proof.ps1 -VsTools D:\RevisitTools\BuildTools\VC\Auxiliary\Build\vcvars64.bat
./tool/check-windows-package.ps1 -BuildDirectory build/windows/x64
```

Fresh-build preparation enumerated `git ls-files --cached --others --exclude-standard`, copied those source files to a new `build/m5-completion/clean-final`, checked that its build directory was absent, and ran `flutter --suppress-analytics pub get --offline --enforce-lockfile`, the Windows release build and package checker there. Ignored SDKs, caches and previous builds were not copied.

Approved permanent-path commands (no further approval needed to verify them):

```powershell
& 'D:\Codex Projects\Revisit\build\windows\x64\runner\Release\revisit_notification_setup.exe' --install
& 'D:\Codex Projects\Revisit\build\windows\x64\runner\Release\revisit_notification_setup.exe' --register-identity
& 'D:\Codex Projects\Revisit\build\windows\x64\runner\Release\revisit_notification_setup.exe' --check
```

### Live acceptance matrix

| Scenario | Observed action / result | Verdict |
| --- | --- | --- |
| X source, GitHub trigger, visible toast and click | Saved fixture through UI. Real isolated Chrome return selected its ID 4, persisted `submitted`, and created Windows history entry with the same tag | PASS through OS receipt. Visible banner and click NOT VERIFIED |
| GitHub source, X trigger | No completed production presentation trial | NOT VERIFIED |
| Wrong context, background, refresh, rapid switching | Synthetic Chrome rules pass; earlier proof observations do not establish full production behavior | NOT VERIFIED live |
| Snoozed/completed suppression | Domain/store and session tests pass; live sequence not completed | NOT VERIFIED live |
| Minimized app | Production process was minimized during investigation; this alone proves neither toast nor click | NOT VERIFIED |
| Host reconnect / app restart | Native pipe reattach test passes; genuine browser recovery matrix pending | NOT VERIFIED live |
| Missing notification setup | Helper initially returned not configured; native integration exercised failure without a test toast | PASS at API/check level |
| Stale activation after deletion | Session test re-reads missing row and refuses stale detail; native validates input | PASS automated; NOT VERIFIED live |

The isolated Chrome profile was relaunched at `https://example.org/` with the existing narrow site grants and then navigated to GitHub. Read-only inspection checked the exact fixture and recent outcomes in SQLite. Windows PowerShell queried `ToastNotificationManager.History.GetHistory('Revisit.Desktop')` for the one app identity. The next step is to click the Windows entry while Revisit runs and confirm the current bookmark details. Expand the live matrix after that gate. Milestone 6 remains pending.

### Additional files changed since the initial checkpoint

- companion/windows_host/CMakeLists.txt
- companion/windows_host/test/activation_test.cpp
- companion/windows_host/test/desktop_host.test.mjs
- companion/windows_host/test/notification_settings_test.cpp
- companion/windows_host/test/peer_test.cpp
- windows/runner/notification_settings.h
- windows/runner/toast_activation.h

Together with the original changed-file list below, these are the 27 source/document files differing from `source-before.json`. No bookmark schema, dependency, lockfile or Milestone 6 work changed. Existing untracked project work is preserved; no commit was made.

Source for first-use behavior: [Microsoft Toolkit notifier compatibility implementation](https://github.com/CommunityToolkit/WindowsCommunityToolkit/blob/main/Microsoft.Toolkit.Uwp.Notifications/Toasts/Compat/ToastNotifierCompat.cs). Its settings getter initializes an identity-less app through a first notification; Revisit instead waits for its first genuine eligible request.

## Historical checkpoint before notification approvals

## Completed and observed

- Added permanent regressions for missing dispatch, missing activation and receiver teardown. All three failed against the original implementation before production edits (`build/m5-completion/before.log`).
- Moved native-host installation after Flutter's bundle-prefix initialization. A genuinely new source copy at `build/m5-completion/clean-project` had no build directory before verification. Its first release build passed in 72.5 seconds. The bundle check found the host, Flutter/native DLLs and assets, and no Program Files install destination. The exact executable launched and its live accessibility tree showed the existing library. No records were changed.
- Added a session owner tied to the library store lifetime. Temporary status widgets only observe the owner. Shutdown cancels subscriptions, stops native observation, settles pending handoffs and closes the store afterward. Native stop acknowledgement occurs after pipe closure; repeated native start reports current status.
- Production arrivals now invoke the existing coordinator/store, with bounded admission and truthful evaluation/submission/failure/unknown status. No new engine, schema or dependency was introduced. The extension reports queue acceptance without claiming evaluation.
- Six focused session tests pass: persisted selected ID and failed outcome, teardown, resize/status replacement, wrong-context and duplicate handling, storage-busy and generic storage-failure reporting.
- Prepared and compiled a per-user notification shortcut helper. `--check` correctly reports not configured (exit 1). No shortcut or notification registration was installed. The supported shortcut ID and exact executable target replace the old registry-key-existence probe. Process application identity is set without persistent changes.

## Approval gate

Explicit approval was requested to run:

```powershell
& 'D:\Codex Projects\Revisit\build\windows\x64\runner\Release\revisit_notification_setup.exe' --install
```

This creates only `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Revisit.lnk`, with `Revisit.Desktop` identity and the permanent production executable target. It refuses an unrelated existing shortcut. The same helper supports `--check` and ownership-checked `--uninstall`. No administrator privilege is required. Do not install from a temporary drive alias. A configured shortcut is not proof of visible notification delivery.

The user brief explicitly requires stopping at this setup gate until approval. Activation implementation and real browser/toast verification remain pending. The existing production Native Messaging registration from the earlier approved task is retained.

## Commands and measured results

All application checks use the README's process-only SDK setup from `S:\Revisit`.

- `flutter --suppress-analytics test --no-pub --reporter expanded test/windows_session_test.dart` before edits: three failing regressions.
- `flutter --suppress-analytics pub get --offline --enforce-lockfile` in the fresh source copy: passed.
- `flutter --suppress-analytics build windows --release --no-pub` in the fresh source copy: passed, 72.5 seconds; actual launch observed separately.
- `./tool/check-windows-package.ps1 -BuildDirectory build/windows/x64`: passed for the clean bundle (before helper addition) and updated production bundle (including helper).
- `flutter --suppress-analytics test --no-pub --reporter expanded test/windows_session_test.dart --name session`: six passed. Intermediate test-helper declaration/timing failures were corrected without disabling assertions; asynchronous stream cancellation is explicitly awaited by the harness.
- `flutter --suppress-analytics analyze --no-pub`: final run no issues; intermediate brace lint findings corrected.
- `flutter --suppress-analytics test --no-pub --reporter expanded`: 87 passed, one failed (activation still unimplemented at this gate). No tests skipped or weakened to hide it.
- `flutter --suppress-analytics build windows --release --no-pub` after helper/session changes: passed, 47.6 seconds.
- `revisit_notification_setup.exe --check`: exit 1, correctly reports no configured shortcut; no mutation.
- `node --test companion/chrome/test/*.test.js`: 10 passed.
- `./tool/build-proof.ps1 -VsTools 'D:\RevisitTools\BuildTools\VC\Auxiliary\Build\vcvars64.bat'`: build and CTest 3/3 passed.
- Formatting corrected the new native integration test after a check reported it. Final strict formatting and native integration result are recorded at the next checkpoint.

An initial UI launch request was not executed because automatic approval review hit a usage limit. After the user's continue instruction, the same launch succeeded through the computer-use tool. This was a tooling interruption, not a safety rejection.

## Remaining evidence

No production authenticated Chrome arrival, visible toast, notification click, minimized reminder or live recovery matrix is claimed. Earlier eight proof-receiver events remain proof-only evidence. Android regression build and final clean packaging rerun after all native changes remain to be run. The full suite remains intentionally red on the missing activation behavior. Milestone 5 is not complete.

References: [Microsoft shortcut identity setup](https://learn.microsoft.com/en-us/windows/win32/shell/enable-desktop-toast-with-appusermodelid), [desktop toast callbacks](https://learn.microsoft.com/en-us/windows/win32/shell/quickstart-sending-desktop-toast).

Native integration result: both real Windows channel tests passed, including stop/pipe-release/reattach and repeated-start status. Strict formatting subsequently passed for 28 Dart files, zero changes. Git whitespace check passed with existing line-ending notices.

Changed files at this checkpoint:

- companion/chrome/worker.js
- docs/milestone-5-completion.md
- integration_test/windows_handoff_test.dart
- lib/application/windows_session.dart
- lib/platform/windows_reminders.dart
- lib/ui/revisit_app.dart
- lib/ui/windows_integration_status.dart
- test/windows_session_test.dart
- tool/check-windows-package.ps1
- windows/CMakeLists.txt
- windows/runner/CMakeLists.txt
- windows/runner/main.cpp
- windows/runner/notification_identity.cpp
- windows/runner/notification_identity.h
- windows/runner/notification_setup.cpp
- windows/runner/windows_reminders.cpp
- README.md
- docs/architecture.md
- docs/plan.md
- docs/quality.md

The initial final whitespace check reported extra EOF blank lines in four edited documentation files. Those were removed and the check rerun; no source behavior changed.

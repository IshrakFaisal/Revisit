# Milestone 5 — Windows integration

Authorized by the Milestone 5 brief after independent Milestone 4 re-review: conditional pass; the original four defects are fixed. Work proceeds through gates, with no Milestone 6 work or automatic commit.

## Minimal implementation plan

1. Gate A: implement a Windows platform-channel notification adapter. A bounded native worker performs OS work; the Flutter/SQLite caller only initiates a request. Check deadlines again immediately before native submission. Test outcomes, uncertainty, responsiveness and lifecycle ordering.
2. Gate B: use the existing Chrome extension to observe genuine focused arrivals and record minimal event evidence. Resolve permission or browser blockers before extending the integration.
3. Gate C: reuse framing and private named-pipe transport, authenticate the native host beyond the current-user ACL, and forward validated arrivals to Flutter. No closed-app queue or launch.
4. Gate D: connect the existing coordinator to the library's real store, retaining all priority, lifecycle and cooldown rules.
5. Gate E: observe actual Windows notifications and activation of current persisted records. Keep intention text out of toast content. Registration is explicit and reversible.
6. Gate F: expand failure/restart/live tests, run all applicable regression checks, inspect the app and document actual versus unverified behavior.

## Adapter choice

No notification package currently exists in pubspec.yaml. Source inspection of flutter_local_notifications_windows 3.1.1 showed synchronous FFI calls through `showNotification` to `ToastNotifier.Show`; initialization also writes per-user registration. Calling this directly inside final authorization would not satisfy the nonblocking contract. A small Windows SDK adapter behind a platform channel avoids both synchronous OS work on Dart and implicit registration. This is platform presentation code, not a new reminder engine.

Handoff means initiating the native request. Once initiated, completion may race an in-flight OS request; cancellation and exactly-once display are not promised. The worker checks the deadline before Show. A blocked OS call cannot be safely canceled; its outcome is unknown and must not be automatically replayed.

## Evidence

Gate A: nine new Dart adapter tests pass; the full suite passes 80 tests. They cover immediate minimal handoff, native rejection, native reported failure, synchronous/asynchronous channel exceptions, hanging acknowledgement expiry, expired requests, bounded pending requests/shutdown, and completion during pending acknowledgement. Existing Milestone 4 tests retain commit-failure, lifecycle ordering and unresolved-restart coverage. Static analysis passes with no issues; two initializing-formal lint findings were corrected. Strict formatting passes for 25 files with zero changes.

The C++ bounded-worker test and existing protocol test pass (CTest 2/2). A controlled native job blocks behind a promise while a second request is rejected and worker-owner destruction returns; the job is then released. This tests native scheduling without an OS notification claim.

The actual Windows Flutter integration test `integration_test/windows_handoff_test.dart` passes. It exercises the real platform channel's malformed/expired request rejection and an actual worker failure when notification registration is absent. The test does not register an application or show a toast. Windows release compilation passed; final regression builds are recorded below when finished.

Gate B: both computer-use entry points fail before reaching Chrome with `failed to write kernel assets: The system cannot find the path specified. (os error 3)`, including after a runtime reset. The existing current-user native-host registration still points to this checkout. A bounded proof receiver is running for a requested manual Chrome check, retaining only target/event/visit IDs and timestamps in ignored `build/m5/live-events.jsonl`. At initial observation it reports only `listening`; this does not prove a browser connection. No host or notification registry changes were made.

Synthetic tests are not live browser or toast evidence. This milestone is not complete until the required genuine event, persisted selection, visible toast and activation gates pass. Gates C–F must not be expanded before Gate B is resolved.

Commands executed so far (Flutter uses the existing temporary S: toolchain recipe):

```text
dart format lib/platform/windows_reminders.dart test/platform/windows_reminders_test.dart integration_test/windows_handoff_test.dart
flutter --suppress-analytics analyze --no-pub
flutter --suppress-analytics test --no-pub --reporter expanded test/platform/windows_reminders_test.dart
flutter --suppress-analytics test --no-pub --reporter expanded
flutter --suppress-analytics build windows --release --no-pub
flutter --suppress-analytics test --no-pub --reporter expanded integration_test/windows_handoff_test.dart -d windows
./tool/build-proof.ps1 -VsTools 'D:\RevisitTools\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
node --test companion/chrome/test/*.test.js
dart format --output=none --set-exit-if-changed lib test integration_test
git diff --check
```

Chrome contract tests: 10 passed. Existing files were hashed before edits to distinguish changes from the substantial pre-existing untracked application. No commit is made.

Final Gate A release builds passed: Windows in 16.1 seconds, Android in 19.9 seconds (54.4 MB development-signed APK). Android command: `flutter --suppress-analytics build apk --release --android-project-arg=kotlin.incremental=false`, with process-only `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false`. Dependency manifests, lockfile and generated Drift source are unchanged. Android runtime testing and the ordinary Windows CRUD native workflow have not been rerun in this task; the new actual Windows handoff test passed. The original 71 unit/widget/domain/persistence tests remain green within the 80-test suite.

References inspected: [Windows notification package FFI implementation](https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications_windows/lib/src/plugin/ffi.dart), [Windows desktop toast setup](https://learn.microsoft.com/en-us/windows/win32/shell/enable-desktop-toast-with-appusermodelid), [Chrome native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging). The native worker is application-owned Windows SDK code, not a vendored modification of the package.

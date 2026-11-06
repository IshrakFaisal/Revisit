# Revisit — quality gates

Never disable tests or weaken assertions for green results. Fake events/clocks belong only in automated tests.

## GitHub application baseline — 2026-11-06

The user authorized publishing the existing application and README to the already configured `IshrakFaisal/Revisit` repository. The baseline retains the starter history and captures the current implementation, tests, companions, CI and milestone evidence. README and AGENTS now require one verified feature per descriptive `type(scope): summary` commit; three requested features produce three feature commits. README also distinguishes implemented Android manual capture from pending sharing. No application behavior changed in this task.

The root ignore file excludes local SDKs, caches, build output, machine-specific VS Code settings and environment files. Existing Android ignore rules exclude local SDK configuration and signing keys. No browser history or bookmark database was included.

Commands ran from the existing `S:\Revisit` alias with `. ./tool/use-local-toolchain.ps1` and `S:\Revisit\.tools\flutter\bin` first on process PATH. The existing alias was retained. No SDK, dependency upgrade, registration, application launch or system-setting change was requested or performed.

| Command | Actual result |
| --- | --- |
| `flutter --suppress-analytics --version` | Flutter 3.47.9, Dart 3.13.7 |
| `flutter --suppress-analytics pub get --enforce-lockfile` | Passed; locked dependency versions retained |
| `dart run build_runner build`; generated source SHA-256 comparison | Passed; `lib/data/bookmark_store.g.dart` unchanged |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Passed; 32 files, zero changes |
| `flutter --suppress-analytics analyze --no-pub` | Passed; no issues |
| `flutter --suppress-analytics test --no-pub --reporter expanded` | All 112 passed |
| `node --test companion/chrome/test/*.test.js companion/windows_host/test/desktop_host.test.mjs` | All 24 passed |
| `./tool/build-proof.ps1 -VsTools 'D:\RevisitTools\BuildTools\VC\Auxiliary\Build\vcvars64.bat'` | Native build passed; CTest 5/5 passed |
| `node --test companion/windows_host/test/transport.test.mjs` | One synthetic transport test passed |
| `flutter --suppress-analytics build windows --release --no-pub` | Passed; 14.0 seconds |
| `./tool/check-windows-package.ps1 -BuildDirectory build/windows/x64` | Passed |
| `flutter --suppress-analytics build apk --release --no-pub --android-project-arg=kotlin.incremental=false` | Failed after 153.6 seconds: stale generated Android registrant referenced the integration-test plugin |
| `flutter --suppress-analytics build apk --release --android-project-arg=kotlin.incremental=false` | Passed with the documented dependency-resolution/plugin-regeneration workaround; 10.0 seconds, 54.4 MB development-signed APK |
| `git diff --cached --check` | Passed |

The Android build used the existing process-only `GRADLE_OPTS` property `-Dorg.gradle.project.kotlin.incremental=false`. Its first attempt retained the existing SDK XML-version warning. The retry regenerated ignored plugin metadata; no tracked application source, dependency constraint or lockfile changed.

Native integration workflows, physical Android sharing, live browser prompts, Windows notification visibility/clicks and hosted GitHub Actions were not rerun for this repository-initialization task. Prior milestone records retain their stated scope and open gates. The next smallest product task remains live verification of the updated Brave in-page prompt and Yes action without bypassing cooldowns.

## Earlier feature verification

The first live v0.5 retest reported no in-page prompt. SQLite showed bookmark 8 submitted at 11:45:35 Dhaka time, and Windows Notification Center history contained tag 8. The Brave extension details page in the inspected profile still showed version 0.3.0. The Reload control was used and the same details page verified version 0.5.0. Two Brave profiles and one Chrome profile had Revisit installed. The runner now replies `upgrade_required` to version 1 X and Facebook arrivals before they enter SQLite, while GitHub version 1 remains supported. CTest 5/5 and all 24 browser/host tests passed after this guard. The Windows release and bundle check passed, and Revisit was launched again. A genuine X visit in the updated Brave profile reached the v2 handler at 11:52:23. Revisit displayed `Browser arrival evaluated: globalCooldown`. The existing 15-minute cooldown from the old toast applies until 12:00:35. The successful in-page prompt and Yes click are still unverified on the live site.

Extension v0.5 adds in-page reminders for X and Facebook. The real SQLite session regression returns the eligible saved URL over the browser arrival channel, suppresses a wrong context and repeated arrival, and checks that the Windows toast adapter is never called. The content-script test verifies that No leaves the page unchanged and Yes opens the saved URL in the current tab. Final results: 24 Node checks, CTest 5/5, 112 Flutter tests, clean Dart formatting and analysis, and a successful Windows release build and package check. The updated release was launched and the receiver reported listening. Live Brave prompt and click verification require reloading the extension.

Commands: `node --test companion/chrome/test/*.test.js companion/windows_host/test/desktop_host.test.mjs`; `./tool/build-proof.ps1 -VsTools 'D:\RevisitTools\BuildTools\VC\Auxiliary\Build\vcvars64.bat'`; `dart format --output=none --set-exit-if-changed lib test integration_test`; `flutter --suppress-analytics analyze --no-pub`; `flutter --suppress-analytics test --no-pub --reporter expanded`; `flutter --suppress-analytics build windows --release --no-pub`; `./tool/check-windows-package.ps1 -BuildDirectory build/windows/x64`. The first analysis flagged three brace lints, corrected before the clean rerun. The release build took 41.3 seconds. Android was not rebuilt for this Windows browser integration change.

The user's follow-up reported no visible X reminder after closing and reopening the site. Read-only SQLite showed a submission for the exact X bookmark seven seconds after it was saved, with no later arrival recorded at inspection. The matching Windows history entry was verified earlier, and the one-hour item cooldown applied. Extension v0.4.1 fixes a reproduced worker regression where returning focus from the editor replayed the same visit. It also explicitly ends a visit when the active tab closes. The original behavior failed the new test, then all 23 Node tests passed using `node --test companion/chrome/test/*.test.js companion/windows_host/test/desktop_host.test.mjs`. Actual v0.4.1 behavior in Brave still requires a reload and live trial. Existing cooldowns were not changed.

On 2026-11-06 the native save prompt update passed 23 Node tests (including native host caller rejection), 5 CTest checks, 111 Flutter tests, Dart analysis, and the Windows release build and bundle check. Tests exercise the actual content script with controlled DOM fixtures. They verify the confirmed X/Facebook save → Yes/No behavior and a persisted same-site trigger default. In the live Brave test, the user confirmed that X's native Bookmark button displayed the Revisit prompt. The release app reported a closed capture draft, and a read-only SQLite query showed a newly saved High priority active bookmark, ID 7, with source X and trigger X. At 11:14:14 Dhaka time, SQLite recorded `submitted` for that same ID, and the Revisit-specific Windows notification history returned tag `7` expiring at 11:19:14. Notification click behavior and the native Facebook Save post flow still require live verification.

Commands: `node --test companion/chrome/test/*.test.js companion/windows_host/test/desktop_host.test.mjs`; `ctest --test-dir build/windows_host -C Release --output-on-failure`; `dart format --output=none --set-exit-if-changed lib test integration_test`; `flutter --suppress-analytics analyze --no-pub`; `flutter --suppress-analytics test --no-pub --reporter expanded`; `flutter --suppress-analytics build windows --release --no-pub`; `./tool/check-windows-package.ps1 -BuildDirectory build/windows/x64`. Windows build took 41.5 seconds. The first sandboxed native and Flutter test runs failed on process/socket access. Both suites passed with normal Windows subprocess access. No Android build was run for this update.

The 2026-11-06 [capture and reminder correction](capture-reminder-fix.md) adds browser Save actions and Facebook contexts. Checks pass 109 Flutter tests, 19 Chrome/host-caller tests, CTest 5/5, both Windows native channel tests and both release builds. A real extension capture persisted a source-X/trigger-Facebook item as ID 6. A real Facebook visit produced a matching Windows notification history entry while Revisit was minimized. Banner visibility and real click remain open. This entry supersedes earlier test counts for the current source.

Milestone 5 is in progress. The [production completion checkpoint](milestone-5-completion.md) records 93 passing Flutter tests, clean Dart analysis and formatting, five native tests, ten Chrome contract tests, and forged-caller rejection. A fresh Windows release build passed in 84.3 seconds, and the Android release regression build passed. After the first-notification fix, the rebuilt release app handled a genuine GitHub arrival, recorded a successful submission for the saved test bookmark, and produced a matching Windows notification history entry. Both final Windows native channel tests passed. Visible banner and click activation remain unverified.

## Application acceptance (future milestones)
| Feature | Required evidence |
| --- | --- |
| Capture | Valid HTTP(S), required trimmed title/intention, priority/source/trigger persist; invalid input creates no row |
| Independent context | External article, source X, trigger GitHub reminds only on GitHub |
| Duplicates | Repeated/concurrent equivalents produce one row; colliding edits preserve data |
| Restart | Fields, completion, snooze, settings/cooldowns reload on both targets |
| Edit/delete | Edits survive restart; confirm removes, cancel preserves |
| Priority | High before medium/low; deterministic ties |
| Wrong context | X cannot trigger GitHub-only item; reject lookalike hosts |
| Snooze | Ineligible before expiry; eligible at expiry only on a fresh matching event |
| Completion/open | Completed never resurfaces; open never completes |
| Repeat events | 100 duplicate events cause at most one attempt; restart cannot bypass cooldown |
| Controls | Disable/pause prevents submission and persists |
| Windows | 20 eligible arrivals submit within five seconds; 20 background/wrong-context trials submit nothing |
| Android | Real X/browser cold/warm shares; cancel saves nothing; ambiguous text requires selection |
| Failures | Storage/host/permission/notification/launch errors preserve data and show truthful state |
| UI | Android 360 logical pixels, Windows 640×480, 200% text, keyboard/touch/focus, no overflow |

## Milestone 1 checks
Run from repository root:
- node --test companion/chrome/test/*.test.js
- ./tool/build-proof.ps1
- node --test companion/windows_host/test/transport.test.mjs
- git diff --check

Build script initializes MSVC, configures CMake/Ninja, builds, then runs CTest. Native checks use explicit failures rather than Release-disabled assert. Synthetic transport checks are NOT evidence of live browser detection.

## Application checks
- flutter doctor -v
- flutter devices
- flutter pub get --enforce-lockfile
- dart run build_runner build
- dart format --output=none --set-exit-if-changed lib test integration_test
- flutter analyze --no-pub
- flutter test --no-pub
- flutter build windows --release --no-pub
- flutter build apk --release
- flutter run -d <device-id> --no-pub
- flutter test integration_test/bookmark_workflow_test.dart -d <device-id>

Run in app root, with SDK on process PATH. Ignored .tools/ is SDK cache, not app source to format/analyze.

Milestone 2 tests exercise startup loading, the empty and populated library, retry after a storage failure, domain constraints, and SQLite round-trip after closing and reopening the database. The GitHub Actions workflow checks the generated Drift source along with formatting, analysis and tests. A successful build and an observed native launch are recorded separately.

### Milestone 2 verification

| Command | Result |
| --- | --- |
| `flutter --suppress-analytics doctor -v` | Flutter 3.47.9 and Android SDK 36 detected. Visual Studio Community 2022 reports an incomplete installation. |
| `flutter --suppress-analytics create --platforms=android,windows --project-name revisit --org com.revisit --no-pub build/m2-scaffold` | Generated the platform runners in a scratch directory before copying the needed files into the existing repository. |
| `flutter --suppress-analytics pub get --enforce-lockfile` | Passed against the application lockfile and generated Android plugin registration. A Dart-only dependency fetch did not generate this registration. |
| `dart run build_runner build` | Generated the Drift schema source. |
| `dart format --output=none --set-exit-if-changed lib test` | Passed, 9 files checked. |
| `flutter --suppress-analytics analyze --no-pub` | Passed, no issues. |
| `flutter --suppress-analytics test --no-pub --reporter expanded` | Passed, 5 tests including real SQLite and storage error recovery. |
| `flutter --suppress-analytics build apk --release --no-pub` | Passed. Development-signed release APK, 49.3 MB. |
| `adb -s emulator-5580 install -r build/app/outputs/flutter-apk/app-release.apk` | Passed on an Android 16 (API 36) x86-64 emulator. |
| `adb -s emulator-5580 shell am start -W -n com.revisit.revisit/.MainActivity` | Cold start succeeded. Confirmed “No bookmarks saved” in the live accessibility tree and inspected the rendered screen. |
| `flutter --suppress-analytics build windows --release --no-pub` | Blocked during plugin symlink creation. Flutter doctor separately reports the incomplete Visual Studio installation. |
| Workflow YAML and Android manifest XML validation, `git diff --check` | Passed locally. The hosted workflow awaits a push or pull request. |

The checkout's path with spaces broke native asset hooks. Tests ran through a temporary `subst R:` alias for the checkout and its local Flutter SDK. Android release compilation also required a full JDK with `jlink`. The local toolchain script selects the checksum-verified Microsoft JDK 17 from the dedicated tools directory.

The first APK built after a Dart-only dependency fetch crashed because the Android JNI plugin registrant was missing. Flutter's dependency command generated the registrant and the rebuilt APK passed the cold-start check. The Android scaffold uses a 2 GB Gradle heap and two workers after the template's 8 GB heap exhausted memory on this workstation. At the original milestone 2 run, Windows launch and physical Android device testing were unverified. The later Windows result follows below.

### Windows readiness verification — 2026-11-04

The Windows release application now builds and launches. The earlier milestone table above records the original failed attempt. The following results supersede its Windows readiness status.

The initial installation registration pointed at the absent `C:\Program Files\Microsoft Visual Studio\2022\Community` directory and reported `isComplete=false`. The separate compiler files on D: lacked Visual Studio's CMake component. A direct symlink probe also failed with `EPERM` under the current non-administrator token. Flutter's actual build stopped at the same plugin-symlink step.

With explicit user approval, the existing Microsoft-signed Build Tools 2022 installer installed the C++ build workload at `D:\RevisitTools\BuildTools`. The user enabled and confirmed Developer Mode. No application code or dependencies changed for this task.

| Command or check | Actual result |
| --- | --- |
| `git status --short`, required documentation and Windows CMake inspection | Preserved the existing modified/untracked work. |
| `flutter --suppress-analytics doctor -v` before repair | Incomplete Visual Studio installation. |
| `flutter --suppress-analytics devices` | Windows desktop, Chrome and Edge available. |
| `flutter --suppress-analytics config --list` | No saved overrides. Desktop support was already enabled by default. |
| `vswhere.exe -all -products '*' -format json` before repair | Registered Community installation incomplete and not launchable. |
| Current-user directory-symlink probe in a disposable build folder | Initially `EPERM`; Flutter plugin generation succeeded after confirmed Developer Mode activation. Probe files were removed. |
| `vs_BuildTools.exe --quiet --wait --norestart --installPath D:\RevisitTools\BuildTools --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended` with user-approved administrator consent | Microsoft signature valid. Installer exit 0. Build Tools 17.14.44, installation version 17.14.37827.9, complete and launchable. No reboot required. |
| `reg.exe query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock /v AllowDevelopmentWithoutDevLicense /reg:64` | `REG_DWORD 0x1` after user confirmation. |
| `dart format --output=none --set-exit-if-changed lib test` | Passed, 9 files unchanged. |
| `flutter --suppress-analytics analyze --no-pub` | Passed, no issues. |
| `flutter --suppress-analytics test --no-pub --reporter expanded` | Passed, all 5 existing tests. |
| `flutter --suppress-analytics pub get --enforce-lockfile` | Passed, plugin symlinks created. |
| `flutter --suppress-analytics build windows --release --no-pub --verbose` under the initial `R:\` checkout-root alias | Failed because the generated CMake environment merged `PROJECT_DIR=R:\` with the next value. Failed generated cache preserved under ignored `build/windows-readiness-r-root-cache`. |
| `subst S: 'D:\Codex Projects'`, then build from `S:\Revisit` with `S:\Revisit\.tools\flutter\bin` first on process PATH | Avoided both SDK spaces and the drive-root quoting failure. No permanent PATH changes. |
| `flutter --suppress-analytics build windows --release --no-pub --verbose` from `S:\Revisit` | Exit 0, zero compiler warnings/errors. Produced `build/windows/x64/runner/Release/revisit.exe` and its DLL/data bundle. |
| `flutter --suppress-analytics run -d windows --release --no-pub` from `S:\Revisit` | Launched the actual Flutter Windows app. Inspected the rendered window and accessibility tree showing Revisit, “No bookmarks saved,” and the local-library explanation. |
| Quit the attached run with `q`, remove the temporary aliases, then launch `D:\Codex Projects\Revisit\build\windows\x64\runner\Release\revisit.exe` | Standalone launch also succeeded. Inspected the window and the same initialized-library state after both aliases were removed. |
| Final `flutter --suppress-analytics doctor -v` from the original SDK path | Exit 0, all categories passed, “No issues found.” Visual Studio Build Tools and Windows SDK 10.0.26100.0 detected. |

The verified build recipe is in README.md. The executable launches directly from the original checkout path with its adjacent DLLs and data folder present. Both temporary drive aliases were removed. Application sources, tests, pubspec and lockfile hashes match their pre-task values. Documentation changes are confined to README.md, this verification record, and the Windows status in plan.md. The old incomplete Community registration is still present; Flutter selects the complete Build Tools installation. Other architecture and integration gates remain as recorded in plan.md.

Manual gates: actual Chrome focus/navigation/background/minimized behavior, permission denial/revocation, native registration, worker suspension, restart/reconnect, toast activation/OS suppression, physical Android sharing/native dialogs. Flutter integration tests cannot prove all of these.

### Milestone 3 verification

| Check | Observed result |
| --- | --- |
| Precondition `flutter --suppress-analytics test --no-pub --reporter expanded` | All seven Milestone 2 tests passed, including Unicode persistence. |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | 15 files, no changes. |
| `flutter --suppress-analytics analyze --no-pub` | No issues. |
| `flutter --suppress-analytics test --no-pub --reporter expanded` | All 20 unit, SQLite, and widget tests passed. |
| `dart run build_runner build` and generated file hash | Code generation passed. The generated Drift file stayed identical. |
| `flutter --suppress-analytics build windows --release --no-pub` | Built the Windows release app. It launched and rendered the library and form. Tab and Enter opened the editor, and submitting the empty form displayed validation errors. |
| `flutter --suppress-analytics test --no-pub --reporter expanded integration_test/bookmark_workflow_test.dart -d windows` | Passed the create, view, edit, close/reopen, cancel-delete, and confirm-delete workflow on real file-backed SQLite. |
| Same integration command with `-d emulator-5580` | Passed on the Android 16 emulator after setting the Gradle option described in README. |
| `flutter --suppress-analytics build apk --release --android-project-arg=kotlin.incremental=false` | Built the 54.3 MB development-signed release APK. Installed and cold-launched on the emulator. |
| Android release UI and process restart | Inspected the rendered library, editor, and details at 320 px. Saved a disposable bookmark, force-stopped and relaunched Revisit, then confirmed the record and its trigger survived. Open link launched the emulator browser activity. Mark complete updated the visible status. |

On this workstation, Kotlin's incremental cache failed to relativize plugin sources on C: against the temporary S: checkout. Passing the Gradle project property through `GRADLE_OPTS` fixed the emulator build. Android release verification also needed dependency resolution enabled to refresh the generated plugin registrant after the debug integration build. These workarounds did not change Android project settings. Physical Android hardware and hosted CI were unavailable for this verification.

Inspect diffs, permissions, boundary validation and persistent state. Record actual versus planned checks; retain data after failures. No fake successful UI, dead buttons or simulated live demo.

### Milestone 3 targeted hardening — 2026-11-05

The new regressions reproduced a Medium layout defect: populated-library filter and sort dropdowns overflowed horizontally at 200% text (154 px at 360 px width and 15 px in the tested desktop split pane). Both dropdowns now expand within the available width and allow intrinsic menu-item height. No domain, database, schema, launcher, or editor behavior changed.

Fourteen new tests cover transaction rollback and draft retention, retry, rapid repeated Save input, pending-save navigation, external launch success/false/exception, unchanged stored fields after opening, Keep editing/Discard/Save, keyboard capture/focus, and populated flows at 200% text in 360x640, 640x480, and 1100x700 layouts. The write-failure double throws after a real SQLite insert inside the existing transaction; the test asserts zero persisted rows before retry and exactly one afterward. Launcher platform-channel tests verify resource preservation, external mode and unsafe-scheme rejection without launching unsafe URLs.

| Command | Actual result |
| --- | --- |
| `dart format test/ui/revisit_app_test.dart test/platform/external_links_test.dart` | Formatted the new tests. |
| `flutter --suppress-analytics test --no-pub --reporter expanded test/ui/revisit_app_test.dart test/platform/external_links_test.dart` before the UI fix | Failed three enlarged-text cases; reproduced dropdown overflows. Other new failure/navigation tests passed. |
| Same focused test command after the fix and test-harness cleanup | All 21 focused tests passed. Cleanup corrected lazy-list scrolling, snackbar timing, and semantics-handle disposal; assertions were retained. |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Passed; 16 files, no changes. |
| `flutter --suppress-analytics analyze --no-pub` | First run reported a missing brace in a new test. Corrected it; subsequent runs passed with no issues. |
| `flutter --suppress-analytics test --no-pub --reporter expanded` | All 34 tests passed, including the original 20. |
| `flutter --suppress-analytics build windows --release --no-pub` | Passed. |
| `flutter --suppress-analytics test --no-pub --reporter expanded integration_test/bookmark_workflow_test.dart -d windows` | Passed the normal file-backed CRUD/reopen workflow. |
| `flutter --suppress-analytics test --reporter expanded integration_test/bookmark_workflow_test.dart -d emulator-5580` | Passed the normal workflow on Android 16/API 36. |
| `flutter --suppress-analytics build apk --release --android-project-arg=kotlin.incremental=false` | Passed; 54.3 MB APK. |
| `Get-FileHash lib/data/bookmark_store.g.dart,pubspec.yaml,pubspec.lock` compared with pre-task hashes | Unchanged. Drift generation was not rerun because schema and generated source were unaffected. |
| `git diff --check` | Passed, with existing Git line-ending notices. |

Commands used the existing README recipe: temporary `subst S: 'D:\Codex Projects'`, working directory `S:\Revisit`, `. ./tool/use-local-toolchain.ps1`, and `S:\Revisit\.tools\flutter\bin` first on process PATH. Android builds used the process-only `GRADLE_OPTS` project property for `kotlin.incremental=false`. No SDK installs or system-setting changes were made.

The native integration harness also has explicit create/verify phases for a full process-restart check. They use the production `BookmarkStore.local()` location and the real library/editor/launcher, with one store per process. The ordinary integration command retains its disposable file-backed workflow. Use a fresh run identifier for every two-phase check; never reuse a previous fixture URL. Verification deliberately leaves the labeled test bookmark rather than deleting user data.

The first lifecycle harness run opened an unnecessary second store and emitted Drift's multiple-instance warning. That test-harness issue was corrected to share the app-owned store; no warning was disabled. It was rerun with a new fixture identifier. Windows UI automation was interrupted by active desktop input, so the lifecycle checks use native Flutter test interaction rather than injecting mouse/keyboard input over the user's work. A Windows release library was separately rendered and inspected.

Lifecycle commands and measured results:

```text
flutter --suppress-analytics test --no-pub --reporter expanded integration_test/bookmark_workflow_test.dart -d windows --dart-define=REVISIT_RESTART_PHASE=create --dart-define=REVISIT_RESTART_RUN=m3-windows-hardening-2
flutter --suppress-analytics test --no-pub --reporter expanded integration_test/bookmark_workflow_test.dart -d windows --dart-define=REVISIT_RESTART_PHASE=verify --dart-define=REVISIT_RESTART_RUN=m3-windows-hardening-2
```

Both passed: native process IDs 26392 and 2232. A `Get-CimInstance Win32_Process -Filter "Name='revisit.exe'"` check for the test executable found zero remaining native processes between phases. This verifies a saved bookmark across actual Windows process exits, using the production storage location. The first exploratory pair also passed (PIDs 996/16160) before the test-only multiple-instance warning was corrected.

The initial two-phase Android attempt failed because the second run could not find its fixture. Inspection of the installed Flutter tool's `integration_test_device.dart` and `commands/test.dart` established that integration tests uninstall the application by default at cleanup. `adb shell run-as com.revisit.revisit` confirmed that the package was absent. That sequence tested uninstall/reinstall, not restart. Use Flutter's supported `--no-uninstall` on both Android phases; the persistence assertion remains required.

```text
flutter --suppress-analytics test --reporter expanded integration_test/bookmark_workflow_test.dart -d emulator-5580 --no-uninstall --dart-define=REVISIT_RESTART_PHASE=create --dart-define=REVISIT_RESTART_RUN=m3-android-hardening-3
adb -s emulator-5580 shell am force-stop com.revisit.revisit
adb -s emulator-5580 shell pidof com.revisit.revisit
flutter --suppress-analytics test --reporter expanded integration_test/bookmark_workflow_test.dart -d emulator-5580 --no-uninstall --dart-define=REVISIT_RESTART_PHASE=verify --dart-define=REVISIT_RESTART_RUN=m3-android-hardening-3
```

Both corrected Android phases passed, with native PIDs 2463 and 2561 and no PID after the intervening force-stop. The second process read the same production app-support record and verified all capture fields. `adb -s emulator-5580 shell dumpsys activity activities` showed `org.chromium.webview_shell/.WebViewBrowserActivity` resumed after Open link. `adb shell uiautomator dump` confirmed its URL field contained `https://example.org/?revisit=m3-android-hardening-3` and the external browser rendered the destination. This is real OS handoff, separate from mocked launcher tests.

`adb -s emulator-5580 install -r build/app/outputs/flutter-apk/app-release.apk` then succeeded without deleting data. `adb -s emulator-5580 shell am start -W -n com.revisit.revisit/.MainActivity` cold-launched the release application. Its rendered library and accessibility tree showed the persisted fixture, intention, Medium priority, and GitHub trigger. Inspected screenshot: ignored `build/m3-hardening-android.png` (320x640 emulator display).

The Windows release application was subsequently launched directly from `build/windows/x64/runner/Release/revisit.exe`. Its rendered split library/details displayed both labeled fixtures. Selecting the retained hardening fixture and clicking Open link opened Brave; the browser's address field and document URL both matched `https://example.org/?revisit=m3-windows-hardening-2`, and the destination rendered. Browser observation was limited to this explicitly opened test destination; no browser history was queried. This completed the previously interrupted manual handoff check.

Outcome: targeted Milestone 3 hardening passed. No Critical or High defects found; the reproduced Medium layout issue and Low plan inconsistency were corrected. No failure-handling defect was reproduced in the previously working editor/launcher. Remaining manual gates are physical Android hardware, full screen-reader/contrast and OS text-setting checks, hosted CI, and future sharing/context/reminder integrations. The tested 200% layouts and keyboard flow are automated widget evidence, not a full accessibility audit.

The read-only emulator instance and task-launched Windows application were stopped, and the temporary drive alias removed. Existing user records were not deleted. The two clearly labeled Windows restart fixtures remain in the local library; test browser tabs may remain open. The emulator's saved state was preserved by read-only mode. No commit or Milestone 4 work was performed.

### Milestone 4 — 2026-11-05

The reminder evaluator, transactional storage/coordinator and persisted snooze controls are implemented. [Milestone 4 policy and exact verification record](milestone-4.md) contains the outcome table, migration design, commands, corrected findings and remaining integration gates.

| Check | Actual final result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Passed: 20 files, zero changes |
| `flutter --suppress-analytics analyze --no-pub` | No issues |
| `flutter --suppress-analytics test --no-pub --reporter expanded` | All 50 passed; all 34 existing regressions retained |
| `dart run build_runner build`; before/after generated-file SHA-256 | Passed; generated bookmark source unchanged |
| `flutter --suppress-analytics build windows --release --no-pub` | Passed |
| `flutter --suppress-analytics test --no-pub --reporter expanded integration_test/bookmark_workflow_test.dart -d windows` | Passed actual Windows lifecycle workflow |
| `flutter --suppress-analytics test --reporter expanded integration_test/bookmark_workflow_test.dart -d emulator-5580` | Passed actual Android emulator lifecycle workflow |
| `flutter --suppress-analytics build apk --release --android-project-arg=kotlin.incremental=false` | Passed; 54.4 MB development-signed APK |
| Release APK install and `am start -W` | Success; cold launch and actual library accessibility hierarchy observed |
| `git diff --check` | Passed with existing line-ending notices |

Migration creation/upgrade and schema version now commit atomically. Tests verify migration failure/retry, preserved bookmark rows, durable successful cooldowns, stale/unknown recovery, rollback, 100 simultaneous duplicate events, source/trigger independence, ranking and timing boundaries. UI tests exercise real snooze writes, completion, read-only SQLite failure and retry. Native workflows verify snooze across a database close/reopen, display the stored deadline and clear it on completion.

No automatic Chrome detection, OS notification, Android monitoring, hosted CI or physical-device behavior is claimed. Delivery/event doubles occur only in tests. The new five-minute adapter lease must be verified against real OS submission/cancellation in Milestone 5. Independent Milestone 4 review is the next task; implementation stops here.

### Milestone 4 targeted correctness hardening — 2026-11-05

The independent review failed the initial implementation. Seven permanent regressions first reproduced all three stale lifecycle handoffs, unsupported newer-schema relabeling, independent-connection lock failures, missing startup retention and stale-event processing. The [hardening report](milestone-4-hardening.md) records the corrected authorization contract and commands.

The expanded suite passes 71 tests, including the original 50 scenarios and 21 new tests. The previous pending-after-snooze expectation now requires failed invalidation. Separate restart tests preserve coverage for pending and unknown reservations. Further tests verify lifecycle rollback on invalidation failure, two-connection handoff ordering, bounded contention exhaustion/recovery, fresh time after retry, no external replay after a post-handoff commit failure, and completion while acknowledgement remains pending.

Final analysis reports no issues. Strict formatting passes for 22 files with zero changes. Drift generation succeeds and the generated bookmark source hash is identical. Schema remains version 2; fresh initialization, populated v1 migration, injected migration failure/retry, and rejection of version 3 with preserved metadata/data all pass. The 40-event independent-connection regression now returns decisions without unhandled lock errors and produces one reservation.

Windows release build and the real Windows native workflow pass. Android release build passes with a 54.4 MB development-signed APK. The Android 16/API 36 emulator native workflow passes capture/edit/snooze/reopen/completion/deletion. All ten Chrome companion synthetic contract tests pass. These checks do not establish actual Chrome-to-app delivery or OS notification behavior. Hosted CI, physical Android hardware and the real native handoff contract remain separate gates.

The existing toolchain was used via the temporary S: alias. No dependencies or SDK installations were added. Git retains the pre-existing untracked implementation and starter-only history. No commit was made. Independent re-review is required before requesting Milestone 5 integration.

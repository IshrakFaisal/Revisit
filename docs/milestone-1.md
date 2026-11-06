# Milestone 1 — toolchain and context proof

Date: 2026-11-03 (Asia/Dhaka). **Gate not passed yet.** No Flutter application has been scaffolded. The approved current task stops at this gate.

## Implemented

- Plain-JavaScript MV3 extension with opt-in exact HTTPS X/GitHub hosts, two-second focus dwell, startup baseline, refresh/same-site suppression, session state and disconnected status. No content scripts/history/all-URL permissions.
- C++ Native Messaging host checks exact caller origin, bounded frames, strict event schema, freshness and allowed contexts.
- Proof receiver uses a current-user-only, local-only named pipe with bounded I/O; rejects replay; emits minimal authorized events only. It exits after a selected duration. It is NOT the future persistent application/notification engine.
- Build, per-user registration/unregistration and process-only toolchain scripts. Public manifest key fixes unpacked identity. No signing private key is stored.
- Approved product/architecture/quality/seven-milestone decisions recorded in repository docs.

## Commands and actual results

| Command/action | Result |
| --- | --- |
| Read AGENTS.md and four required docs; git status; rg --files | Starter-only repository, initially clean main |
| Get-Command flutter,dart,cmake,ninja,node,adb,winget | Flutter/Dart/adb absent on initial PATH; CMake/Ninja/Node/winget found |
| Invoke-RestMethod official Flutter Windows release JSON | Sandbox DNS failure; unsandboxed endpoint returned NoSuchKey; no archive downloaded through that path |
| vcvars64.bat and where cl/rc/link | Sandbox initialization failed; unsandboxed initialization succeeded using existing D: MSVC and Windows SDK |
| git ls-remote --heads https://github.com/flutter/flutter.git stable | c197ca5199e9ee5661e865596c9c07294dfab51c |
| git clone --depth 1 --branch stable https://github.com/flutter/flutter.git .tools/flutter | Succeeded; SDK kept in ignored workspace directory |
| ./.tools/flutter/bin/flutter.bat --suppress-analytics doctor -v | Bootstrap succeeded; Flutter 3.47.9, Dart 3.13.7. Initial doctor: Android SDK absent, VS incomplete, SDK not on PATH. Exit 0 does NOT mean all doctor checks passed |
| Process-only PATH; flutter --suppress-analytics devices | Windows, Chrome, Edge; no Android device |
| Existing PyCharm jbr/bin/java.exe -version | OpenJDK/JBR 17.0.10 available, no new JDK installed |
| Download/extract official Android command-line archive | SHA256 verified: 90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a |
| sdkmanager --sdk_root=<local SDK> --version | 22.0; tool warns sdkmanager CLI is deprecated in favor of Android CLI |
| sdkmanager --sdk_root=<local SDK> "platform-tools" "platforms;android-36" "build-tools;36.0.0" | Installed successfully, exit 0; initial SDK path contained spaces and failed Flutter's Android path check |
| Copy-Item local SDK to D:\RevisitTools\android-sdk -Recurse | Created dedicated no-space SDK directory, retained original download; no existing SDK overwritten |
| sdkmanager --sdk_root=D:\RevisitTools\android-sdk --licenses | Standard SDK setup licenses accepted; exit 0 |
| Dot-source tool/use-local-toolchain.ps1; flutter --suppress-analytics doctor -v | Flutter and Android checks now pass; only Visual Studio category reports an issue. Exact local log: build/flutter-doctor.log |
| adb devices -l | Empty device list; no physical Android device detected |
| Download aka.ms/vs/17/release/vs_BuildTools.exe; Get-AuthenticodeSignature | Microsoft signature Valid; Visual Studio 2022 bootstrapper |
| vs_BuildTools.exe --quiet --wait --norestart --installPath D:\RevisitTools\BuildTools --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended | Exit 1602 (installation canceled); no BuildTools target directory created. Not retried |
| node --test companion/chrome/test/*.test.js | 10 passed, 0 failed; includes Chrome API-double worker regression |
| ./tool/build-proof.ps1 | CMake/Ninja configure and all native targets build under MSVC 19.41.34123; /W4 /WX; CTest 1/1 passed |
| node --test companion/windows_host/test/transport.test.mjs | 1 passed: synthetic framed messages, origin rejection, pipe round-trip, duplicates, stale/invalid/oversized/truncated messages and disconnect |
| ./tool/register-proof-host.ps1 | Current-user com.revisit.context_proof registered to this checkout's built host |
| Hidden receiver --seconds 1800 | Started for the authorized live test; listening only at last observation, no genuine event yet |
| Computer Use Chrome setup | Stopped by tool because current browser URL could not be determined confidently; no further UI input issued |
| PowerShell Parser.ParseFile for tool/*.ps1; node --check for extension modules | All three PowerShell scripts and three JS modules parse successfully |
| git diff --check | Passed; Git emitted only LF-to-CRLF conversion notices |

The explicit unit/regression inputs are synthetic. None establish that Chrome has delivered a real event. Ten JS tests, one native CTest executable (many validation/framing/replay assertions), and one Windows transport test passed; these are separate suites, not an application test suite.

## Live browser matrix — pending

Load companion/chrome using Chrome's Load unpacked flow. Open puzzle-piece Extensions menu → Revisit context proof → Enable X and GitHub detection. Grant narrow site access. The user must perform extension consent; computer-use privacy permission automation is prohibited by its operating guidance.

Use a receiver session dedicated to live checks, separate from automated transport tests. Do not retain raw URL history or page bodies. Record counts and latency, not unrelated browsing.

| Action | Expected | Observed |
| --- | --- | --- |
| Startup already on X/GitHub | Baseline only | Pending |
| From non-target to GitHub, focused two seconds | One github event | Pending |
| From non-target to X, focused two seconds | One x event | Pending |
| Refresh / same-site route / same-target tab switch | No new arrival | Pending |
| Target tab loads in background | No event | Pending |
| Chrome unfocused or minimized | No event | Pending |
| Leave before two seconds | No event | Pending |
| Leave and return, wait two seconds | New visit/event | Pending |
| Unrelated/lookalike host | No event | Pending |
| Deny/revoke host grants | No event; truthful status | Pending |
| Worker stop/restart on unchanged context | No replay/startup arrival | Pending |
| Receiver absent, then reconnect | Disconnected result; no replay until new arrival | Pending |

Later milestone 5 must run 20 eligible positive and 20 negative trials against the actual reminder application; this isolated receiver cannot prove notifications, persisted cooldowns or bookmark behavior.

## Limits and next action

- Visual Studio's registered C: installation is incomplete although the D: C++ tools build this isolated proof. Do not fake registry state or bypass Flutter's doctor checks. A signed side-by-side Build Tools install was attempted and canceled (1602). Flutter Windows readiness still needs actual installer repair/workload completion.
- Flutter 3.47.9 and Android SDK 36 now pass doctor when using the process-only toolchain script. Java 17 is reused from PyCharm. Android SDK is at D:\RevisitTools\android-sdk; the original ignored workspace cache remains. No emulator or NDK was installed yet; those are not claimed verified by the doctor result.
- Android physical device availability was confirmed by the user but no connected device has been detected yet.
- No Flutter app commands (pub get, application format/analyze/test/build) have run: no app exists. Flutter bootstrap's internal pub resolution is not an application check.
- Extension needs real browser validation. Its dependency-free unit tests and native transport tests are necessary but insufficient.
- No reminders, database or application UI were implemented. No store publication, system PATH change, analytics, backend or browsing-history inspection was added.

Next smallest task: complete the live Chrome matrix and remaining toolchain readiness, then report milestone-1 outcome for review before scaffolding.

## Changed-file inventory

- README.md; docs/product.md, architecture.md, quality.md, plan.md; new docs/milestone-1.md.
- .gitignore excludes build output and local SDK caches.
- companion/chrome/: manifest.json, package.json, context.js, worker.js, popup.html, popup.js; test/context.test.js and test/worker.test.js.
- companion/windows_host/: CMakeLists.txt, protocol.h/.cpp, pipe_transport.h/.cpp, host.cpp, receiver.cpp; test/protocol_test.cpp and test/transport.test.mjs.
- tool/build-proof.ps1, register-proof-host.ps1, use-local-toolchain.ps1.

Local effects outside tracked source: ignored SDK/build downloads; dedicated Android SDK directory; current-user Chrome Native Messaging registration. The bounded live receiver emits only authorized minimal events into ignored build/windows_host/live-events.jsonl during this test. Disable the extension and remove that ephemeral test log after live verification; do not turn it into a retained browsing log.

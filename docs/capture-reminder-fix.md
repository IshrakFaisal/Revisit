# Browser capture and context reminder correction

2026-11-06, Asia/Dhaka. The user authorized extending the existing Windows capture and reminder experience to X/Twitter, Facebook and GitHub.

## Findings

| Category | Confirmed finding |
| --- | --- |
| Missing capture functionality | The earlier Chrome extension sent context arrivals only. It had no Save action, context menu, capture message or application draft handler |
| Missing Facebook support | The domain enums, native validator and browser allowlist supported only X and GitHub. Facebook events were rejected |
| Existing working systems | Local storage, validation, canonical duplicates, ranking, cooldowns, snooze, completion and the existing reminder coordinator passed the 93-test baseline |
| Platform limitation | Chrome's bookmarks API describes Chrome's bookmark tree. It does not report a site's internal X bookmark, Facebook Save or GitHub star as a uniform browser event |
| Setup | Existing current-user Native Messaging and notification registrations still match the production bundle. Windows reports notification setting 0, enabled. New host grants and extension reload require manual consent |
| Live verification gap | Earlier work established genuine Chrome arrival and a Windows notification history entry. Banner visibility, real click activation and the full lifecycle matrix were still open |

Native regression tests first failed on Facebook arrival rejection, then on missing capture support. The new Dart regression first failed because a browser capture did not open an editor. Tests were retained after the correction.

## Native save capabilities and chosen workflow

| Website | Supported platform mechanism and limits | Implemented capture |
| --- | --- | --- |
| X/Twitter | X documents bookmark lookup and management APIs requiring a developer account, app and user OAuth access. The application currently has no such authorization. A native bookmark-button click is not a Chrome extension API event | Save the current page using the popup, or select a post permalink through the link context menu |
| Facebook | No supported personal Saved-items callback was verified. Meta's current User, Permissions and User-webhook references returned HTTP 429 during research. This is an unverified API capability, not a claim that a hidden or undocumented endpoint works | Explicit popup/page/link capture of the selected Facebook URL |
| GitHub | GitHub provides starred-repository REST operations and repository/organization/GitHub App star webhooks. These are account/repository integrations, with token or webhook setup, rather than a generic local browser save event for every item | Explicit popup/page/link capture of a repository, issue, gist or other supported GitHub URL |

Sources are the official [X bookmark documentation](https://docs.x.com/x-api/posts/bookmarks/introduction), [GitHub starring API](https://docs.github.com/en/rest/activity/starring), [GitHub star webhook documentation](https://docs.github.com/en/webhooks/webhook-events-and-payloads#star), [Chrome bookmarks API](https://developer.chrome.com/docs/extensions/reference/api/bookmarks), [Chrome activeTab permission](https://developer.chrome.com/docs/extensions/develop/concepts/activeTab) and [Chrome context menus API](https://developer.chrome.com/docs/extensions/reference/api/contextMenus).

The selected workflow requires an explicit Save action. It uses the chosen URL, without reading private account saves or intercepting site network requests. For a post inside a feed, the user selects its permalink. A popup Save action uses the current page address.

## Implementation

1. Extension v0.3.0 adds Save this page to Revisit and page/link context menus. activeTab provides temporary capture access. Optional individual host permissions authorize automatic monitoring separately.
2. A strict six-field capture envelope travels through the existing authenticated native host and private named pipe. It contains version, kind, URL, source, event ID and timestamp. URL serialization preserves query/fragment meaning and encodes Unicode and raw resource characters before the 3,072-character ASCII limit. Frames remain capped at 4 KiB.
3. Native and Dart boundaries reject malformed fields, stale/future timestamps, wrong hosts, credentials, unsafe links, source mismatch and excessive size. Existing executable and Chrome stdio authentication remains in place.
4. WindowsSession opens the existing editor with URL and source prefilled. Title, intention, priority and explicit reminder trigger are reviewed before saving through the existing store. Duplicate saves offer the existing record. Canceling creates no row. Busy editors and duplicate capture IDs are bounded and do not overlay unsaved work.
5. Facebook joins the existing context enum and coordinator path. Source and trigger remain independent. SQLite stays at schema version 2. Text enum names and old records are preserved, with a real file-database reopen regression.
6. Automatic arrival logic retains the focused active-tab check, two-second dwell, startup baseline, refresh/same-site suppression and persisted worker-session attempt state. The existing reminder engine controls selection and interruption limits.

Supported HTTPS hosts are x.com, www.x.com, twitter.com, www.twitter.com, mobile.twitter.com, facebook.com, www.facebook.com, m.facebook.com, mbasic.facebook.com, github.com, www.github.com and gist.github.com. This is an explicit allowlist.

## Checks executed

Commands used `S:\Revisit` after restoring the existing temporary alias with `subst S: 'D:\Codex Projects'` and loading `. ./tool/use-local-toolchain.ps1`.

| Command | Actual result |
| --- | --- |
| `flutter --suppress-analytics test --no-pub --reporter expanded` before edits | 93 passed |
| `node --test companion/chrome/test/*.test.js` before edits | 10 passed |
| `./tool/build-proof.ps1 -VsTools 'D:\RevisitTools\BuildTools\VC\Auxiliary\Build\vcvars64.bat'` before edits | CTest 5/5 passed |
| New Facebook and capture regressions before corrections | Failed on unsupported Facebook and missing capture/editor behavior |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | 32 files, zero changes |
| `flutter --suppress-analytics analyze --no-pub` | Final no issues. One intermediate brace lint was corrected |
| `flutter --suppress-analytics test --no-pub --reporter expanded` after edits | All 109 passed, retaining the original 93 |
| `node --test companion/chrome/test/*.test.js companion/windows_host/test/desktop_host.test.mjs` | 19 passed, including production host rejection of a forged local caller |
| `./tool/build-proof.ps1 -VsTools 'D:\RevisitTools\BuildTools\VC\Auxiliary\Build\vcvars64.bat'` after edits | CTest 5/5 passed, with expanded capture/Facebook validation assertions |
| `flutter --suppress-analytics build windows --release --no-pub` | Passed in 70.0 seconds |
| `./tool/check-windows-package.ps1 -BuildDirectory build/windows/x64` | Passed |
| `flutter --suppress-analytics test --no-pub --reporter expanded integration_test/windows_handoff_test.dart -d windows` | Both tests passed. Native Debug build took 81.7 seconds |
| `flutter --suppress-analytics build apk --release --no-pub --android-project-arg=kotlin.incremental=false` | Passed in 176.4 seconds, 54.4 MB development-signed APK. Existing SDK XML-version warning retained |
| `revisit_notification_setup.exe --check` | Matching owned shortcut and registry identity, Windows setting 0 |
| `dart run build_runner build` with before/after SHA-256 | Passed. Generated bookmark source identical |
| `git -c core.fsmonitor=false diff --check` | Passed with existing line-ending notices |

New automated checks cover all three sources and independent triggers, capture-required fields, explicit save/cancel, persisted fields and duplicates, source/host validation, aliases, transport size and freshness, unavailable/busy native messaging, capture restore/storage failures, concurrent/manual editor protection, shutdown, Facebook matching, snooze/completion and old-row restart compatibility. Existing activation, reminder concurrency, migration and management regressions pass.

The first expanded widget run exposed teardown timers in the new test harness after its behavior assertions. Cleanup was moved into the test callback's finally block so Drift stream cancellation settles before Flutter's invariants. Assertions were retained. This was a harness correction, without a production storage change.

## Live evidence

The user manually reloaded the extension, approved site access and replied ready. The observed popup displayed the new Save action and all-site access enabled. The earlier personal-profile installation restriction was respected by leaving profile setup and consent to the user.

| Step | Actual observation | Status |
| --- | --- | --- |
| Release launch | Rebuilt release app opened with its five existing bookmarks | PASS |
| Genuine capture | Opened the real X profile page `https://x.com/github#capture-live-20261106` and clicked Save this page to Revisit in Chrome's popup | PASS for page capture. This was a profile page, not a post permalink |
| Confirmation draft | Existing editor showed that URL and source X. Chrome stayed in front, and explicit window activation was used to inspect the draft | PASS for draft delivery. Automatic foreground focus from capture was not observed |
| Explicit persistence | Entered title Live X to Facebook, intention Read before starting my project., High priority and trigger Facebook, then saved | PASS |
| SQLite evidence | Read-only query returned new ID 6 with all the selected fields, active state, and six total bookmarks | PASS |
| Minimized delivery setup | Revisit was minimized with the saved item in its library | PASS |
| Facebook arrival and Windows receipt | The manual visit produced a genuine arrival while Revisit was minimized. SQLite recorded ID 6 as submitted at 10:34:26 Dhaka time. The Windows history API returned one Revisit entry with tag 6 and expiration 10:39:26 | PASS through OS receipt |
| Real notification click and foreground | The item's details were observed afterward. The route could also have been opened from the library. Banner visibility, click causality and foreground ownership remain unconfirmed | NOT VERIFIED |
| Live snooze/completion suppression | Automated checks pass. Fresh live lifecycle sequence remains pending | NOT VERIFIED |

No notification, browser arrival or production activation event was fabricated for the live check. The automated native integration tests have their usual limited scope. They do not prove toast visibility or click routing.

## Files changed in this task

- `companion/chrome/capture.js`, `context.js`, `manifest.json`, `popup.html`, `popup.js`, `worker.js`
- `companion/chrome/test/capture.test.js`, `context.test.js`, `popup.test.js`, `worker.test.js`
- `companion/windows_host/protocol.h`, `protocol.cpp`, `desktop_host.cpp`, `peer_identity.h`, `peer_identity.cpp`, `test/protocol_test.cpp`, `test/peer_test.cpp`
- `windows/runner/windows_reminders.cpp`, `tool/register-desktop-host.ps1`
- `lib/domain/bookmark.dart`, `reminders.dart`, `browser_capture.dart`
- `lib/platform/windows_reminders.dart`, `lib/application/windows_session.dart`
- `lib/ui/bookmark_editor.dart`, `bookmark_details.dart`, `revisit_app.dart`
- `test/facebook_context_test.dart`, `browser_capture_test.dart`, `windows_capture_test.dart`, `windows_session_test.dart`
- `README.md`, `docs/product.md`, `docs/architecture.md`, this report and status links in the quality/plan documents

Existing unrelated modified/untracked work was preserved. No dependency, backend or new framework was introduced. No commit was made.

## Remaining acceptance and setup

The user must approve extension changes and site permissions in the chosen test profile. That consent was performed for this run. Existing per-user native host and notification registrations were verified read-only and retained.

Keep Revisit running or minimized for capture and reminders. Closing it stops reception and does not queue later events. A popup acceptance message acknowledges transport to a draft, so the user must confirm Save in the app. If another editor/detail route is open, finish it and repeat the capture action. Manual review remains available when Chrome or notifications are unavailable.

Current acceptance verdict is **incomplete**. A real Facebook arrival and Windows receipt passed. The visible notification, actual click and live lifecycle checks remain open. The earlier Computer Use audit established that Notification Center cards are absent from its target inventory, so the click needs a human observation.

## Brave follow-up

Brave is installed and its executable has a valid Authenticode signature from Brave Software, Inc. The previous native host filtered for Google's signed chrome.exe, so it could not authenticate Brave even if the extension loaded. The rebuilt host retains both pipe ownership checks and requires a matching executable and verified publisher for each browser. Native tests pass 5/5, including Brave/Chrome publisher mismatch rejection, and the forged local caller remains rejected. The release host target built successfully. The extension and app message formats are shared.

The user approved the Brave registration. `./tool/register-desktop-host.ps1 -Browser Brave -AppDirectory 'D:\Codex Projects\Revisit\build\windows\x64\runner\Release'` succeeded. A read-back verified the `com.revisit.context` host name, exact release executable, `stdio` transport, and single Revisit extension origin. The user loaded the extension in Brave and reported ready. See [Brave extension support](https://support.brave.app/hc/en-us/articles/360017909112-How-can-I-add-extensions-to-Brave) and [Bitwarden's Windows Native Messaging implementation](https://github.com/bitwarden/clients/blob/main/apps/desktop/src/main/native-messaging.main.ts#L429).

The real Brave test opened `https://x.com/github#revisit-brave-check` and clicked **Save this page to Revisit**. The popup reported **Draft sent to Revisit**. The running release app's accessibility tree showed the New bookmark editor, exact URL, source X and Save bookmark control. The draft was left for review. The popup also reported **Arrival queued for Revisit**, and SQLite recorded a new consumed arrival at 10:43:54 Dhaka time. This verifies live Brave capture and arrival transport. A Brave-triggered Windows notification and actual click remain unverified.

For a new user, the system works as follows. The extension sends the link you explicitly choose to Revisit. You enter why it matters and where you want to be reminded. SQLite keeps that record locally. A later focused visit to the selected site sends a small context event to the running app. The existing reminder engine selects an eligible saved item, applies snooze/completion and cooldown rules, and asks Windows to notify you. Clicking the notification is intended to open the current saved record for Open, Snooze and Mark complete. The final click behavior remains a live acceptance gate.

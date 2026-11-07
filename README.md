# Revisit

**Save with intention. Return with purpose.**

Revisit is a local-first Flutter app for Android and Windows. Save a link and the reason it matters, pick a priority and trigger context, then revisit it from your library. You can open, edit, snooze for one hour or 24 hours, mark complete, and delete bookmarks. The library supports priority filtering and sorting. A genuine Chrome arrival selected a saved bookmark and produced a matching Windows Notification Center entry. Banner visibility and click activation remain unverified. See the [current completion evidence](docs/milestone-5-completion.md).

To try it, choose **New bookmark**, paste a full `https://` URL, and enter a title and intention. Priority defaults to **Medium**, source context defaults to **Other**, and you must choose a trigger. Save the bookmark, select its title to see the details, and use **Edit** to update it. Close and reopen Revisit to confirm it was stored. Use **Delete** and confirm to remove it. Each device keeps its own library.

The v0.3 Chrome companion adds **Save this page to Revisit** in its popup, plus page/link context menus. Keep the rebuilt Windows app running, open a supported X, Facebook or GitHub item, then use the popup action or right-click its permalink and choose **Save link to Revisit**. Revisit opens a draft with the chosen URL and source. Confirm the link, enter title and intention, set priority and choose the reminder context before saving. In a feed, selecting the post's timestamp/permalink captures that item. Selecting the popup action captures the current page URL.

With v0.6.0, reload the extension in Brave or Chrome and refresh X or Facebook after granting site access. Use **Bookmark** on X or **Save post** on Facebook. When Revisit recognizes both the post and the site's confirmation, it asks **Add this post to Revisit?** **No** dismisses the prompt. **Yes** brings the running Revisit app forward to its draft, with the same site selected as the reminder trigger, and closes the page prompt. Enter a title and intention, choose a priority, and save. Use **Save link to Revisit** if the capture prompt does not appear.

On a later eligible visit to X or Facebook, Revisit asks **“You have saved bookmarks in Revisit. See them now?”** at the top right. **Yes** opens a scrollable chooser ordered High, Medium, then Low. It includes all active items whose trigger matches this site, including recently reminded items; completed and currently snoozed items are hidden. Use **Show more** for longer lists. Click a bookmark to open its current saved URL in this tab. **No** dismisses the prompt without loading the list. Keep the updated desktop app running, and keep the tab in front for two seconds on return. The existing reminder cooldown and eligibility rules apply. GitHub reminders continue through Windows notifications.

Automatic arrival detection supports X/Twitter, Facebook and GitHub on the exact aliases in docs/product.md. Grant site access through **Enable X, Facebook and GitHub detection** in the popup. The native save prompt supports recognized X and Facebook desktop controls only, with English labels for Facebook. It does not import existing saves or watch GitHub stars. See [earlier live evidence](docs/capture-reminder-fix.md) for the arrival and notification path.

Read AGENTS.md and docs/product.md, architecture.md, quality.md and plan.md. See [measured milestone evidence](docs/milestone-1.md).

## Development and commits

Complete and verify one feature at a time. Each feature gets its own commit containing the implementation, regression tests and related documentation. A prompt requesting three features should produce three feature commits.

Use `type(scope): summary` with a clear description of the change, for example:

```text
feat(bookmarks): add priority filtering
feat(reminders): add one-hour snooze
fix(browser): prevent duplicate arrival events
```

Use `docs`, `test`, `ci` or `chore` for changes of those kinds. Record verification results and remaining limitations in the task report. The initial application baseline captures the existing implementation; subsequent features follow this commit policy.

## Application checks

Clone the project from [GitHub](https://github.com/IshrakFaisal/Revisit):

```text
git clone https://github.com/IshrakFaisal/Revisit.git
cd Revisit
```

Use Flutter 3.47.9. Android builds require a full JDK 17 with `jlink`. On this workstation, run `. ./tool/use-local-toolchain.ps1` first to select the local SDK and JDK when available.

```text
flutter pub get --enforce-lockfile
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release
flutter build windows --release --no-pub
flutter devices
flutter run -d <device-id> --no-pub
flutter test integration_test/bookmark_workflow_test.dart -d <device-id>
```

GitHub Actions verifies the locked dependencies, generated Drift source, formatting, analysis and tests. Use an Android device or emulator for launch verification. Windows builds require a complete Visual Studio C++ installation and plugin symlink support. The Android release APK uses development signing for local verification.

Run Flutter's dependency command before Windows `--no-pub` builds so it generates platform plugin registrants. If it fails while creating desktop plugin symlinks, rerun after enabling symlink support. Keep dependency resolution enabled when switching between Android integration tests and release builds so Flutter generates the plugin registrant for the selected build mode.

On Windows, Flutter's native hook runner can split an SDK path containing spaces. Map the checkout's **parent** to an unused temporary drive so both the project and SDK have paths without spaces. Keep the project below the drive root because a root path such as `R:\` causes a CMake environment quoting error. For this checkout, with `S:` unused, the verified commands are below.

```powershell
subst S: 'D:\Codex Projects'
Set-Location S:\Revisit
. ./tool/use-local-toolchain.ps1
$env:PATH = 'S:\Revisit\.tools\flutter\bin;' + $env:PATH
flutter --suppress-analytics pub get --enforce-lockfile
flutter --suppress-analytics build windows --release --no-pub
flutter --suppress-analytics run -d windows --release --no-pub
```

After quitting Flutter with `q`, return to `D:\Codex Projects\Revisit` and run `subst S: /d` to remove the alias. Windows readiness was verified on 2026-11-04 using Build Tools 2022 at `D:\RevisitTools\BuildTools` and Windows Developer Mode. The build, launch, and prerequisite evidence is in `docs/quality.md`.

If Android builds using the temporary drive fail with a Kotlin error about different drive roots, run these in the same PowerShell session. The Gradle option applies only to that process and its children.

```powershell
$env:GRADLE_OPTS = ($env:GRADLE_OPTS + ' -Dorg.gradle.project.kotlin.incremental=false').Trim()
flutter build apk --release --android-project-arg=kotlin.incremental=false
flutter test integration_test/bookmark_workflow_test.dart -d <device-id>
```

## Milestone 1 Chrome proof
Windows x64, Node, CMake/Ninja and Visual Studio C++ tools. No npm packages.

~~~powershell
node --test companion/chrome/test/*.test.js
.\tool\build-proof.ps1
node --test companion/windows_host/test/transport.test.mjs
~~~

Use build-proof.ps1 -VsTools '<path to vcvars64.bat>' for another installed MSVC. Build output is ignored.

## Windows integration

Milestone 5 completion is in progress. The production receiver now dispatches arrivals to the existing reminder coordinator. A passing build or a queued event does not prove that a Windows notification appeared. Notification setup requires explicit approval; live presentation and activation remain acceptance gates.

1. Build with the application commands above. Run `./tool/check-windows-package.ps1 -BuildDirectory build/windows/x64` to check the local release bundle.
2. With explicit authorization, run `./tool/register-desktop-host.ps1 -AppDirectory '<absolute release bundle path>'`. This registers only current-user `com.revisit.context`, with allowed origin `chrome-extension://eafjimobboehjlbhhpmcjchagfencibd/`. It refuses to replace another installation.
3. With explicit authorization, run `<release bundle>/revisit_notification_setup.exe --install` and `--register-identity` from the permanent absolute bundle path, not a temporary drive alias. These create the current user's Start-menu `Revisit.lnk` and `HKCU\Software\Classes\AppUserModelId\Revisit.Desktop`. The key contains the display name, executable ownership path and activation identifier. They require no administrator access and do not change notification preferences or register an autostart/closed-app launcher. `--check` verifies ownership and queries available Windows settings; it does not prove visibility. Before the first notification, Windows may report that settings are uninitialized. The app allows that first genuine request to reach Windows; known disabled settings still suppress it.
4. In an isolated Chrome profile, open `chrome://extensions`, enable Developer mode and load this checkout's `companion/chrome`. Expected name: **Revisit**; ID: `eafjimobboehjlbhhpmcjchagfencibd`. Reload an installed copy and check version 0.6.0. Use **Enable X, Facebook and GitHub detection** to grant the narrowly scoped HTTPS host permissions, then refresh any open X or Facebook tab. Personal profile setup and site access are controlled by the user.
5. Launch one release Revisit instance before navigating. **Local receiver listening** means the pipe is available, not that Chrome is connected. The extension's **Arrival queued** means native transport accepted an event, not that SQLite evaluated it or Windows displayed anything.
6. Save a disposable link with an intention, High priority, source X and trigger GitHub. Leave GitHub for a non-target page, return to foreground GitHub and remain for two seconds. Revisit reports evaluation and durable submission/failure/unknown results. A submitted result still requires visually observing the toast. Notification-click navigation is not yet verified in this checkpoint.

Refresh and navigation within a target site do not create a new arrival. Startup establishes a baseline. Global attempt cooldown is 15 minutes; successful per-item cooldown is one hour. Snooze lasts one hour/24 hours. Do not bypass these settings for a demonstration. Closing Revisit stops delivery and does not queue events for replay; leave and return after reconnecting.

Troubleshooting: if the receiver is unavailable, close other Revisit instances and restart. If the extension reports a missing host, check the exact registered manifest/executable and reload the extension. Missing notification setup is reported separately. Windows notification suppression can prevent visibility even after submission. Storage errors preserve bookmarks and do not automatically replay uncertain handoffs.

Cleanup: disable/remove the extension; run `register-desktop-host.ps1 -AppDirectory '<same release bundle>' -Unregister`, then `<same release bundle>/revisit_notification_setup.exe --unregister-identity` and `--uninstall` only when removal is intended. The notification helper verifies ownership before removing the key or shortcut. Keep the bundle until uninstall is complete. These commands do not delete bookmarks.

### Brave setup

Use the same extension folder and rebuilt release bundle. With approval, register the current-user host for Brave using the browser selector. A real Brave Save action opened the expected confirmation draft in Revisit. A Brave-triggered notification and click remain live checks.

```powershell
./tool/register-desktop-host.ps1 -Browser Brave -AppDirectory '<absolute release bundle path>'
```

In the Brave profile you choose, open `brave://extensions`, enable Developer mode, then select **Load unpacked** and choose `companion/chrome`. Open the Revisit popup and grant the sites you want monitored through **Enable X, Facebook and GitHub detection**. Keep Revisit running or minimized. To remove the Brave host registration, use the same command with `-Unregister`.

### Historical proof-only receiver

`com.revisit.context_proof`, `register-proof-host.ps1`, and `revisit_receiver.exe` belong to the earlier proof exercise. The current extension uses `com.revisit.context` and will not send to the proof host. Old proof logs are not evidence of authenticated production Flutter delivery or notification display. The synthetic proof transport tests remain useful framing regressions only.

## Toolchain
Flutter lives under ignored .tools/. Android SDK uses D:\RevisitTools\android-sdk because Android NDK tooling does not support spaces in the SDK path. The workspace download is retained as a cache. Dot-source ./tool/use-local-toolchain.ps1 to set process-only PATH/SDK/Java variables; no system PATH changes. Then run flutter --suppress-analytics doctor -v and flutter --suppress-analytics devices. See the milestone report for actual readiness; downloading SDKs is not a successful app build.

Android currently supports manual capture and review. Android sharing remains a pending milestone; automatic usage detection is deferred. Data stays separate per device, with no cloud sync, account or backend.

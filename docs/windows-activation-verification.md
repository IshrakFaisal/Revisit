# Windows notification activation verification

Date 2026-11-06, Asia/Dhaka. Scope is inspection and verification. Application code was unchanged.

## Result

The real Windows Notification Center click is **NOT VERIFIED**. Desktop automation works for ordinary app windows. The open Notification Center panel is absent from both supported automation inventories, so its notification cannot be targeted through the documented interface.

## Observed evidence

1. Read the Computer Use skill, guidance, API and confirmation rules. The available implementation uses `@oai/sky` through the persistent Node REPL, with window enumeration, accessibility snapshots, screenshots, clicks and keyboard input.
2. `sky.list_windows()` and `sky.list_apps()` responded successfully. Revisit was initially closed. The real release executable was launched, returned as a targetable window, captured visually and inspected through its accessibility tree. Its library contained the persisted `M5 live GitHub check` bookmark.
3. At 09:04 Dhaka time, the Revisit-specific Windows history query returned zero entries. The earlier genuine notification had expired at 08:48. That earlier entry therefore could not be clicked for this task.
4. The user approved one replacement reminder. A separate fixture was saved through the real application form to preserve the original item's one-hour cooldown. Read-only SQLite inspection confirmed bookmark 5, title `M5 notification click check`, URL `https://x.com/github#activation-ui`, intention `Verify real Notification Center activation`, High priority, source X, trigger GitHub and active state.
5. Revisit was minimized using its observed title-bar control before the intended activation test. Its detail view had been empty before minimizing.
6. Automatic approval review rejected the command to launch the approved isolated Chrome profile with `blocked by policy`. No further reason was supplied. The subsequently opened Chrome process showed a Start-menu launch without the isolated-profile flag. The user confirmed it was the usual Chrome window. The replacement context arrival was not performed.
7. The user opened Notification Center manually and reported `center open`. Fresh `sky.list_windows()` and `sky.list_apps()` calls returned the ordinary app windows, including Chrome and Revisit, but exposed neither Notification Center nor the taskbar. There was no valid returned target on which to click the notification.

No real notification was clicked during this task. No foreground activation or bookmark navigation from a real notification was observed.

## Exact capability limits

- The documented interface accepts input only for returned app/window targets. It provides no desktop/taskbar capture or global screen click.
- The Computer Use skill prohibits Windows-key shortcuts. Opening the panel manually did not make it a returned automation target.
- The interface has no OS foreground-window query. Accessibility `focused_element` describes focus within the selected app. Successful screenshot capture also supports occluded windows, so it cannot establish OS foreground ownership.
- Input to Revisit would activate the app itself and contaminate the foreground check. Passive observation after an actual notification click would be appropriate if the notification were accessible.

The skill used was `C:\Users\USER\.codex\plugins\cache\openai-bundled\computer-use\26.1029.61003\skills\computer-use\SKILL.md`, with the adjacent `docs/guidance.md`, `docs/api.md` and `docs/confirmations.md`.

## Automated fallback executed

Commands used the existing tests unchanged.

```text
flutter --suppress-analytics test --no-pub --reporter expanded test/windows_session_test.dart --name activation
ctest --test-dir build/windows_host -C Release --output-on-failure -R activation_boundary
```

The Flutter command passed all six selected tests. These resolve saved and current records, completed/snoozed states, deleted/unknown IDs and duplicate activations. The tests use a real in-memory Drift store and inject `notificationActivated` into the test messenger. Log is `build/m5-completion/activation-fallback-final.log`.

The native command passed its one selected test. It invokes the COM callback implementation directly to verify input validation and callback dispatch.

These are simulated activation and direct callback tests. They cover application handling after activation arrives. They do not exercise the Notification Center click, Windows COM routing, automatic restoration or OS foreground ownership.

## Smallest remaining real verification

A current genuine reminder and a manual Notification Center click are required under the current automation limits. The user can directly confirm whether Revisit takes the foreground. Passive automation capture can then inspect the opened detail, and read-only SQLite lookup can compare its fields with the notified bookmark ID. A hybrid manual-click/automated-inspection result should be recorded with that distinction.

The new labeled fixture remains in the local library, and Revisit was left minimized for the test. No application fix was authorized or applied.

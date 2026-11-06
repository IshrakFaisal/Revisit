# Revisit — approved architecture

## Shared application
One Flutter/Dart project for Android and Windows. Constructor injection and Flutter built-in state primitives; no extra state framework.

Dependencies: Drift/SQLite through drift, drift_flutter, path_provider; url_launcher. Development: drift_dev and build_runner. Windows notifications use a small Windows SDK adapter behind a platform channel, with a bounded native worker. The previously proposed flutter_local_notifications dependency was not installed: its inspected Windows implementation calls the OS synchronously through FFI, which does not directly satisfy final authorization's prompt-return contract. See milestone-5.md. No dependency or lockfile change was needed for Gate A.

Milestone 2 implements the startup read and the first bookmark table. Drift opens the database in application-support storage. The startup read distinguishes loading, an empty or populated library, and an initialization error with retry. A typed insert and lookup support the persistence tests. The store enforces canonical URL uniqueness. URL validation and canonicalization for user input enter with the capture workflow. Link launching and notification dependencies enter with their features.

Milestone 3 opens one Drift store for the library session. The library and detail views watch SQLite queries so a successful write refreshes both. Retry opens a new connection to the same database. Editing keeps the ID, creation date, and lifecycle metadata. Manual completion records the completion time. Milestone 3 used SQLite schema version 1; Milestone 4 migrates it to version 2 without changing bookmark rows. The existing unique index rejects duplicate writes, and the store resolves the conflicting ID for the editor to display.

Milestone 4 implements `domain/reminders.dart`, transactional reminder storage and a small injected delivery coordinator. Two custom SQL tables on the existing Drift connection hold the control singleton and consumed arrivals/reservations. Schema creation and the explicit upgrade remain in Drift's migration lifecycle; generated bookmark tables are unchanged. See [the outcome and recovery policy](milestone-4.md). Milestone 5 production completion connects the native arrival source and notification adapter through one store-session-owned WindowsSession and the existing coordinator; live transport/display remain unverified. Snooze and completion controls write real SQLite state; enabled/pause preferences are persisted APIs awaiting the real integration UI.

The [Milestone 4 hardening contract](milestone-4-hardening.md) defines final authorization. A short SQLite write transaction orders immediate adapter handoff against lifecycle writes on every connection. It claims the attempt as unknown before invoking the adapter, then commits before awaiting acknowledgement. Lifecycle writes atomically fail reserved attempts. Edits and disabling/pausing also invalidate reservations. Once handoff occurs, later lifecycle changes preserve their state while the external request may already be in flight. A process-local, single-use handoff capability gates acknowledgement recording. Retry is disabled once handoff starts. Future adapters must initiate their request synchronously and return promptly, with no repository access or asynchronous preparation inside handoff.

SQLite BUSY/LOCKED transactions retry at most ten times, with increasing waits totaling at most 900 ms (excluding time spent in SQLite). The whole transaction is reevaluated, and the coordinator supplies a fresh clock. Other errors propagate. Exhausted contention produces `DatabaseBusyException`; event admission exposes `storageBusy` without claiming successful processing. If outcome recording is busy after handoff, the unknown record and cooldown remain. The app normally owns one store, but independent connections are tested and supported within this bounded policy. Native receivers must forward to the running coordinator rather than directly presenting.

Library initialization runs recovery before watching bookmarks. Cleanup runs on startup and reminder processing, including after reopening a previously closed application. Newer unsupported database versions are rejected before any version/table modification. Schema version 2 and the v1 migration remain supported.

Milestone 5 adds `WindowsReminders` platform-channel adapters in Dart and the Windows runner. The runner queues at most one native notification operation on a worker, validates the payload/deadline, and reports submission/failure/uncertainty independently of request acceptance. It does not write registration automatically. Toast content excludes bookmark titles, intentions and URLs. The session owner now connects genuine arrivals and current-record activation to the application; visible OS delivery and actual notification-click activation remain live acceptance gates.

| Boundary | Responsibility |
| --- | --- |
| lib/domain/ | Models, URL normalization, state transitions, pure eligibility/ranking |
| lib/application/ | Serialize events/actions; evaluate, reserve, present, record outcome |
| lib/data/ | Transactional repository, uniqueness, durable cooldown/replay metadata |
| lib/platform/ | Sharing, context transport, capabilities, notifications, link launching |
| lib/ui/ | Real list/editor/settings/reminder and loading/error states |
| android/ | Thin Kotlin cold/warm share adapter |
| windows/ | Runner and named-pipe adapter |
| companion/chrome/ | Plain JavaScript MV3 extension |
| companion/windows_host/ | C++ Native Messaging bridge and proof-only receiver |

Interfaces: BookmarkRepository (watch/CRUD/transactional reservations), ReminderEvaluator.evaluate(snapshot,event,policy,now) (decision/suppression reason, no I/O), ContextEventSource (events/capabilities), ShareInputSource, ReminderPresenter, ExternalLinkLauncher. Inject time/adapters.

## Records and behavior
- Bookmark: never-reused ID, URL, unique canonical URL, title, intention, priority, source, trigger, status, created/updated timestamps, snoozed-until, completed-at, last-reminder-submitted-at.
- Settings: enabled, paused-until, global/per-item cooldown.
- Attempt: ID, bookmark ID, visit ID, reservation time, outcome reserved/submitted/failed/unknown.
- Adapter state: connection and bounded replay metadata.

Store UTC timestamps and the database in application-support storage. Disable Android cloud backup. Never erase/recreate data after open/migration errors.

`BookmarkUrl` validates manual capture, edits, and external opens. Enter a full `http://` or `https://` URL up to 4,096 UTF-16 units after trimming. It accepts ASCII hostnames (use punycode for international hosts), dotted-decimal IPv4, and bracketed IPv6. Optional ports must be 1–65,535. Credentials, ambiguous numeric hosts, internal whitespace, control characters, backslashes, and malformed percent escapes are rejected.

The store keeps the trimmed original URL for display and opening. The launcher lowercases the scheme for OS handoff and preserves the rest of the URL. The separate duplicate key lowercases the scheme and host, normalizes decimal port spelling, removes the default port, and supplies `/` for an empty path. It preserves the spelling of the path, query, and fragment, including escapes, dot segments, and empty `?` or `#` delimiters. Redirects, host aliases, scheme differences, query reordering, and tracking variants are not merged. SQLite applies uniqueness to every record, including completed bookmarks.

The library defaults to newest first. Priority order is High, Medium, then Low. Equal priorities are ordered newest first, and records with the same creation time sort by descending ID. A filter changes the view only. The form defaults to Medium and source Other, and requires an explicit trigger. Title and intention each accept 1–200 Unicode code points after trimming. Future shared text is capped at 16 KiB and requires selection when it contains multiple links.

Save → active; snooze → snoozed; expiry → eligible on next matching arrival; complete → completed. Open leaves state unchanged. Edit preserves lifecycle state; confirmed delete removes.

Eligibility: authorized fresh matching trigger, not completed/deleted, snooze expired, enabled/unpaused, cooldowns expired. Source is irrelevant to matching. Rank high/medium/low, least recently reminded, oldest created, then ID.

Reserve transactionally before presentation. Failed presentation preserves the bookmark and records failure; unknown crash outcomes never replay automatically. Retain bounded attempt/replay data for 24 hours plus current cooldown timestamps. Milestone-1 receiver state is process-local and does NOT implement this future application persistence.

## Windows
Pipeline: Chrome active/focused site → MV3 worker → Native Messaging host → current-user named pipe → Dart coordinator → SQLite reservation → toast → in-app actions.

Permissions are nativeMessaging, storage, activeTab and contextMenus, with optional exact HTTPS origins listed in product.md for X, Facebook and GitHub. Session storage holds the current visit and last status. Capture URLs are forwarded only on an explicit Save action and are not retained by the extension. Consent changes reset the observation baseline. Incognito is disabled.

Arrival wire v1 has exactly version:1, target:x|facebook|github, eventId/visitId lowercase UUID strings, occurredAt integer UTC epoch milliseconds. Arrival messages contain no URL or title. Frames use a four-byte little-endian length then UTF-8, max 4 KiB. Freshness is at most 30 seconds old/five seconds future. Host checks the exact extension origin. Pipe has an explicit current-user DACL, rejects remote clients and uses bounded I/O. This does not protect against a compromised process under the same user.

Proof extension ID: eafjimobboehjlbhhpmcjchagfencibd. Its public key stabilizes unpacked identity; not a secret/signing credential. Historical proof host: com.revisit.context_proof. Production host: com.revisit.context. Per-user registration. Production peers authenticate executable identities and Chrome stdio ownership; a JSON origin claim is not trusted. Disconnected receiver: visible status, no queue; next genuine return required.

Windows toasts open the item in the running app; re-read current state on activation. Unpackaged notification cancellation/history is limited. No MSIX solely for toast cleanup.

## Android and UI
ACTION_SEND/text/plain/EXTRA_TEXT on cold/warm intents becomes an editable draft, not an automatic save. Usage detection deferred: queries do not reveal browser URLs or guarantee immediate background execution. No special access/foreground monitoring service.

Single column below 840 logical pixels; list/detail above. Verify Android at 360 logical pixels, Windows 640×480, 200% text, touch/keyboard and focus. Capability/connection labels reflect real state.

## Primary references
- [Chrome tabs](https://developer.chrome.com/docs/extensions/reference/api/tabs)
- [Window focus](https://developer.chrome.com/docs/extensions/reference/api/windows)
- [Native Messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)
- [Named-pipe access](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights)
- [Android sharing](https://developer.android.com/develop/ui/compose/sharing/receive)
- [UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager)
- [WorkManager timing](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work)
- [Drift](https://drift.simonbinder.eu/setup/)
- [Notification limitations](https://pub.dev/packages/flutter_local_notifications)

## Milestone 5 completion checkpoint
See [current evidence and remaining live gates](milestone-5-completion.md). WindowsSession owns the adapter/subscriptions independently of layout widgets. Native stop acknowledgement follows pipe closure. Explicitly approved notification setup installs a current-user Start-menu shortcut and AppUserModelId identity, both checked against the exact executable. A process-local COM callback validates activation IDs and dispatches current-record navigation. No LocalServer32/autostart or closed-app activation is registered. Windows may return ERROR_NOT_FOUND when querying settings before the first toast: only that error permits the genuine request to reach Show; disabled settings and other failures retain their behavior. No synthetic initialization toast is sent. Setup, tests and successful OS submission never establish visible delivery on their own.

## Explicit browser capture added 2026-11-06

The existing authenticated Native Messaging host also accepts a six-field capture message. Its fields are version:1, kind:capture, url, source:x|facebook|github, eventId and occurredAt. Host and runner validate the complete shape, freshness, URL/source allowlist and bounds before forwarding captureRequested to Dart. BrowserCapture repeats boundary validation using BookmarkUrl. A selected URL may cross this boundary only for an explicit capture request.

WindowsSession owns the capture subscription and bounds duplicate IDs and draft concurrency. Capture restores the running app and opens the existing BookmarkEditor with URL and source prefilled. Saving uses the existing repository and canonical unique index. Canceling creates no row. Editor lifetime does not hold session shutdown open. Capture does not create a reminder arrival or change cooldowns.

The schema remains version 2. Source and trigger use existing text enum columns without a SQL enum CHECK, so adding facebook preserves existing rows and their names. Automated file-database reopen tests cover both legacy contexts and the new value. The extension uses activeTab and contextMenus for explicit capture and optional exact host grants for automatic observation.

Extension v0.4 uses scripting to register an isolated content script only on granted X and Facebook origins. It checks the clicked post control and a bounded confirmation window in the visible DOM. It sends no post URL until Yes. The worker revalidates the sender, site grant and source before sending the same capture envelope with kind `siteSave`. Native and Dart accept that kind only for X or Facebook. Dart selects the same site as the default trigger, while explicit capture retains the existing trigger picker. No cookies, saved collections or internal website APIs are accessed.

Extension v0.4.1 retains an already observed visit across browser focus loss, which prevents returning from the editor from spending a reminder attempt. The current visit stores its active tab ID without storing URLs. Removal of that tab ends the visit even when a same-site replacement tab is already active when the event is processed. Background tab removals leave the visit alone.

Extension v0.5 sends version 2 arrivals only for X and Facebook, after checking that the active page can receive the in-page prompt. The authenticated host returns the eligible saved URL selected by the existing coordinator. The reply is bounded to the existing 4 KiB frame and contains no title or intention. The worker rechecks focus and the original page after receiving it. The isolated content script uses the URL only on a trusted Yes click, and the page prompt expires after 30 seconds. The URL is not written to browser extension storage. The app records submission when it prepares the reply, so a page change or transport loss can still consume a reminder attempt. GitHub version 1 arrivals retain the Windows toast path. The runner rejects version 1 X and Facebook arrivals with `upgrade_required` before evaluation, so another profile's older extension cannot spend the new flow's reminder cooldown.

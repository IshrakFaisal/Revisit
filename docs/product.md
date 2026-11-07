# Revisit — approved MVP specification

**Save with intention. Return with purpose.**

Approved 2026-11-03. Android and Windows share an application foundation. The journey below describes the MVP scope. See plan.md for milestone status.

## Journey
1. Share (Android) or paste a supported HTTP(S) link. Enter a title and intention, each required and 1–200 Unicode code points after trimming.
2. Select priority High/Medium/Low (default Medium), source X/Facebook/GitHub/Other (default Other), and explicit trigger X/Facebook/GitHub. Source is user-editable and independent of URL and trigger.
3. Persist locally. Canonical duplicates, including completed items, offer the existing item without silent overwrite.
4. On Windows, a genuine authorized Brave or Chrome arrival evaluates eligibility while Revisit runs, including minimized. X and Facebook show an in-page prompt. Yes opens the saved link in that tab and No dismisses the prompt. GitHub uses the Windows notification path.
5. Open, snooze one hour/24 hours, or complete. Open does not complete. Edit preserves lifecycle state. Delete requires confirmation.
6. State, settings and cooldown metadata survive restart.

Android delivers sharing and manual review with an explicit automatic-detection-unavailable label. No Usage Access or monitoring foreground service ships this week. Physical-device sharing is an acceptance gate.

## Context and interruptions
- Required Windows integration uses Chrome with narrowly granted HTTPS X, Facebook and GitHub origins. X includes x.com, www.x.com, twitter.com, www.twitter.com and mobile.twitter.com. Facebook includes facebook.com, www.facebook.com, m.facebook.com and mbasic.facebook.com. GitHub includes github.com, www.github.com and gist.github.com. Incognito is excluded.
- Arrival: target is the active tab in the focused, non-minimized window for two seconds. Closing the active site tab or navigating away ends the visit. Refreshing, same-site navigation and switching back from the editor to the same already observed visit do not start another one. Focus loss cancels an unfinished dwell. Startup establishes a baseline without emitting.
- This establishes active-site context, not whether a person read content.
- One reminder per visit; 15 minutes between automatic attempts globally; one hour between successful submissions for an item.
- Disable or pause one hour/24 hours. No forced foreground window or alarm presentation.
- Rank high/medium/low, least recently reminded, oldest created, then ID.
- Snooze expiry permits the next matching event; expiry alone never reminds. Completed items never remind.
- Closing Revisit stops delivery; no offline event replay. OS submission does not prove visibility/readership.
- Valid suppressed arrivals may retain minimal deduplication identities. Wrong-context arrivals leave bookmark data and cooldown timestamps unchanged.
- An arrival must be fresh at admission, selection and final handoff: at most 30 seconds old, with five seconds future tolerance. All boundaries are inclusive.
- A completion, snooze or deletion committed before final handoff prevents that reminder. Once handoff has begun, the OS request may be in flight and cancellation is not guaranteed. Later lifecycle changes still persist.
- Event metadata older than 24 hours is cleaned on startup and during reminder processing. Closing the application postpones cleanup until reopening. Snooze/cooldown deadlines are UTC wall-clock values; timezone changes do not change their instant, while system-clock adjustments can affect eligibility.

## Exclusions and fallback
Data stays separate on each device: Android saves do not create Windows items. No backend, accounts, sync, analytics, AI, payments, native X bookmarks, scraping, browser history, broad permissions, overlays, accessibility scraping, network interception, additional browsers, iOS/macOS, store publication, Windows autostart, always-on Android monitoring, automatic title fetching, redirect expansion, clipboard monitoring or bulk import/export.

If Windows fails its real-event gate, manual review is a clearly labeled bookmark/review prototype, not an automatic-context MVP. Never use fake events in the live demonstration.

## Browser capture expansion approved 2026-11-06

The extension's explicit Save this page to Revisit action and page/link context menus send the chosen supported HTTPS link to a confirmation draft in the running Windows app. The user confirms the URL, enters a title and intention, selects priority and an explicit reminder trigger, then saves through the existing SQLite flow. For a post inside a feed, the user selects its permalink through the link context menu. Importing a site's existing saved collection remains outside the implementation.

When the user clicks a recognized X Bookmark or Facebook Save post control on a granted origin, the extension waits for visible site confirmation and identifies the associated post permalink. The in-page prompt offers Yes and No. No discards the pending candidate. Yes opens the same editor, with the source site selected as the default reminder trigger. Only a separate Save in the editor writes SQLite. On a later focused visit to that site, the existing reminder rules decide which saved item appears. Unknown or ambiguous layouts fail closed and use the explicit capture fallback.

All in-page Revisit prompts appear at the top right of the viewport (16 px inset), as requested on 2026-11-07. They remain responsive to narrow windows.

Capture sends a selected URL only after a user action. Automatic context events continue to carry only site context, IDs and timing. Automatic monitoring requires optional site permissions even when capture has temporary activeTab access. Capture links are limited to 3,072 ASCII encoded URL characters within the existing 4 KiB transport. Manual capture retains its existing 4,096-character limit.

Closing the desktop app stops both delivery and capture reception. Minimized operation is the supported background workflow. Captures offered while another editor or routed detail is open receive a busy status in the app and require a fresh Save action after closing that view. No capture saves automatically.

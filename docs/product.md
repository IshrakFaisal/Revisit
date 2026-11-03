# Revisit — MVP product specification (proposed)

**Promise:** Save with intention. Return with purpose.

## Users and problem
People save pages/posts for later but forget the specific intended action. Revisit keeps a URL, a short why, a priority, and an explicit trigger, then brings it back without notification spam.

## Platforms
Android first for native share-in capture; Windows for desktop bookmark management. Cross-device synchronization is NOT included in hackathon MVP, and content is stored separately on each device.

## Main flow
1. User shares/pastes a supported X or GitHub URL into Revisit.
2. User enters a meaningful intention (required, 1–200 characters), priority (high/medium/low), and trigger target (`x.com` or `github.com`). Trigger may differ from source.
3. Save persists locally. Duplicate URLs prompt update/view existing rather than silently creating duplicates.
4. A *verified external context event* triggers eligibility evaluation. Show at most one prioritized reminder per context window.
5. User can open the original link, snooze, or mark Done. Opening is not automatically completion.
6. All states survive application restart.

## Explicit definitions (confirm in discovery)
- A qualifying context event is a supported domain activation on Windows or an authorized foreground-app event on Android, not a fabricated test button. Exact trigger adapter and constraints must be established in a proof of concept.
- Priority orders eligible reminders; it does not determine reminder timing.
- Snooze is a user-selected time interval (initial MVP: 1 hour or 1 day). A snoozed reminder is ineligible until expiration.
- Cooldown: avoid repeated prompts on refresh, rapid tab switching, and repeated same-session events; store last-display timestamp.
- Do not collect page bodies, browser history, X account data, or credentials.

## Scope gate
Required: save, list, edit, priority, intention, locally persist, due-state logic, snooze, done, user-facing error handling, and one real context event proven end-to-end on at least one target platform.

Optional if proved and time permits: an Android usage-event adapter with permission explanation; companion Windows Chrome extension for domain events; second full platform integration.

Not included: native X bookmark sync, cloud sync, AI, universal browser compatibility, background surveillance, mobile overlay, full Web Store or app store publishing.

## Judge demo
Demonstrate save from one site, choose the other as context, leave, return to the target platform/site, get one real reminder, snooze/complete, repeat the event and show no spam. Explicitly disclose what is supported and what is prototype-only.

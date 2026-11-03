# Revisit architecture — small, testable harness

## App code
Start with ONE Flutter project for Android and Windows. Prefer a few feature-based folders over a monorepo of micro-packages. Example naming below is *proposed*; adjust to actual conventions after initialization.

- `lib/domain/`: bookmark model, priority/status, trigger policy, pure reminder eligibility function.
- `lib/data/`: local repository and serialization/database adapters.
- `lib/platform/`: thin Android sharing and permitted app-usage event adapters; Windows browser-event adapter if validated.
- `lib/ui/`: adaptive bookmark list/editor/reminder UI.
- `test/`: pure domain and widget tests.
- `integration_test/`: end-to-end app flows where environment allows.

## Recommended dependencies
Flutter/Dart. Choose one maintained SQLite path confirmed on Android+Windows (Flutter's current docs describe `drift` as cross-platform); avoid dependency explosion. Use injectable clock and abstract event source so reminder eligibility can be deterministically tested.

## Contract
`ContextEvent { target: x|github, occurredAt, source: user_authorized_adapter }`
`Bookmark { id, url, title, intention, priority, triggerSite, state, createdAt, updatedAt, snoozedUntil?, lastRemindedAt? }`
`ReminderEvaluator.evaluate(bookmarks, contextEvent, now) -> eligible bookmark | none`

The pure evaluator MUST NOT know about Android APIs, Chrome extensions, Flutter widgets, or the database implementation.

## External context events
- Windows: reliable domain detection typically needs a small browser integration. Consider a Chrome extension plus registered native messaging host; validate native messages, origin, domain and permissions. Prove it in isolation before spending time on final UI.
- Android: UsageStatsManager provides app usage data only with special authorization; it does not reliably reveal specific browser pages. Immediate background delivery has restrictions. Treat native X app foreground detection as a feasibility spike, not as a promise.
- Fallback: manual or scheduled review is useful, but DOES NOT count as the advertised context-triggered demo.

## Data/security boundaries
Local-only, user-initiated saves; no tracking history or scraping; allowlist trigger domains; don't execute content from URLs; preserve data on failures; no synthetic success telemetry.

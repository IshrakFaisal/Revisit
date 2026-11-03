# Revisit — agent operating map

Before changing code, read `docs/product.md`, `docs/architecture.md`, `docs/quality.md`, and `docs/plan.md`. These docs represent proposed decisions; verify them against the actual repo and toolchain. Update docs when approved decisions change.

## Boundaries
- Target Android and Windows using a shared Flutter/Dart app; keep platform-specific integrations behind adapters.
- Do not imply that an ordinary app can observe arbitrary X or GitHub visits. Implement only verifiable triggers and label platform limitations.
- Default to local-first bookmark data. No account, AI API, cloud sync, analytics, or broad permissions for MVP.
- UI must be connected to real persistence and actual feature state; don't use fabricated successful outcomes or dead buttons.
- Do not inspect or store the user's browsing history except minimal, explicitly authorized trigger events required for the feature.
- Validate URLs, imported data, native messages, and platform events at boundaries.
- Prefer small dependencies and discover existing conventions before adding them.

## Execution
- Complete one milestone at a time; make focused diffs.
- Add regression tests for important behavior and failures. Never silence or weaken failing checks merely for green results.
- Run available format/analyze/test/build checks; distinguish actual execution from unsupported/unrun commands.
- After each task: report changed files, accepted behavior, exact commands/results, known limitations, and the next smallest task.
- Stop for approval before destructive repository actions, extensive permission requests, architecture rewrites, or external cost commitments.

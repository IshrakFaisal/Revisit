# Revisit — Codex harness starter

This is a **repository guide and prompt pack**, not a built app. Use it to scaffold the product with Codex in small verified increments.

## Proposed platforms
- Android mobile app + Windows desktop app using Flutter/Dart.
- Local-only data for the hackathon; no cross-device synchronization claim.
- Context triggers are feasibility gates: Windows requires reliable browser integration (likely a small companion Chrome extension); Android app-usage events need explicit user permission and may not support dependable immediate background notifications.

## Start
1. Install Flutter SDK, Android SDK / Android Studio, and Visual Studio with Windows **Desktop development with C++** workload. Check `flutter doctor -v` and `flutter devices`.
2. Copy the contents of this starter directory into the root of a new Git repository. Keep it under version control.
3. Open that folder in Codex. Ask it to read `AGENTS.md`, then paste `prompts/00-discovery-and-feasibility.txt`.
4. Approve the architecture and feasibility scope before allowing code generation.
5. Advance to the next prompt only after checking Codex's commands, diffs, and evidence.

This pack deliberately avoids generating an application, inventing build results, or copying OpenAI's large-scale internal infrastructure. For any instructions that disagree with a newly discovered platform constraint, ask Codex to document the conflict and propose the smallest revision.

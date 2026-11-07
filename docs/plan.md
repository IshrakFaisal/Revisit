# Revisit — approved execution plan

Approved 2026-11-03. Complete one milestone at a time. The milestone 2 brief authorizes the application foundation and engineering harness. Live Chrome detection remains a separate open gate.

| Milestone | Target | Exit gate | Status |
| --- | --- | --- | --- |
| 1. Toolchain/genuine-event proof | Day 1 | Verify Flutter/Android/Windows; real focused X/GitHub arrival reaches receiver; background/wrong hosts/refresh do not | In progress; see milestone-1.md |
| 2. Application foundation | Day 2 morning | Android and Windows scaffold, adaptive shell, local SQLite, tests and CI. Launch on one available target and verify builds where toolchains support them | Acceptance met on Android emulator. Windows release build and actual Flutter launch verified 2026-11-04; see quality.md. |
| 3. Persistent vertical slice | Day 2 afternoon–3 | CRUD/open/complete, validation/duplicates, SQLite restart/failure tests | Targeted hardening passed 2026-11-05: 34 tests, both release builds/native workflows, real process restarts, and observed browser handoff on Windows and Android emulator. See quality.md for remaining manual gates. |
| 4. Reminder engine/controls | Day 4 | Pure ranking/matching, snooze/cooldowns/pause, transactional attempts and tests | Independent re-review gave CONDITIONAL PASS: original defects fixed; native adapter contract remains a Milestone 5 gate. |
| 5. Windows integration | Day 5 | Extension → host → app → data → toast/actions; minimized/reconnect/repeat/restart | Production completion in progress. Genuine Chrome arrival selected the saved X fixture and created a matching Windows notification history entry. Visible banner, click and remaining live matrix are open. See milestone-5-completion.md. |
| 6. Android sharing/usability | Day 6 | Real-device X/browser cold/warm shares; drafts and adaptive keyboard/touch UI | Not started |
| 7. Verification/demo | Day 7 | Full checks, regressions, reproducible setup, real screenshots and cross-context demo | Not started |

The original day-1 plan made the live Windows proof a prerequisite for further work. Later user instructions separately authorized Milestone 2 and Milestone 3 application work while that browser gate remained open. Toolchain readiness and the shared foundation are verified; the live Chrome matrix and end-to-end context-triggered reminders remain unverified and must pass before automatic-reminder acceptance. Tool installation can cause slippage; never silently remove tests or claim automatic-reminder completion.

Toast work remains in the Windows integration milestone. Milestone 4 was separately authorized; review its engine and recovery evidence before starting Milestone 5 on separate user direction.

The user separately authorized browser capture and Facebook support on 2026-11-06. [The focused correction report](capture-reminder-fix.md) records the explicit extension capture path, three-site contexts, 109 passing Flutter tests and live acceptance progress. This expansion continues the Windows experience. Android sharing remains its own pending milestone.

After each milestone report changed files, exact commands/results, accepted behavior, unsupported/unrun checks, limitations and next task. Never mark a live gate complete from synthetic events.

The 2026-11-07 follow-up confirms the previous in-page reminder fix worked for the user and authorizes a direct capture handoff, top-right placement, and a priority-ordered current-site chooser after Yes. These changes remain in Milestone 5. Full live matrix and physical Android sharing remain separate gates.

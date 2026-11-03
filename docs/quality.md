# Revisit quality gate — Definition of Done

For each milestone require:
1. **Behavior:** the exact acceptance scenario operates end-to-end, not just a rendered widget.
2. **Safety:** invalid URLs, duplicate saves, denied permissions, storage failures, and unusable context events fail predictably.
3. **Determinism:** inject fake clock/events into domain tests, not into claimed live demo.
4. **Verification:** run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and relevant build/integration commands *if available*. If scripts/toolchain are missing, report it, don't manufacture green checks. For newly scaffolded projects, `flutter pub get` comes first.
5. **Visual inspection:** test small Windows window and Android device/emulator; check keyboard, readable focus, touch targets, empty/error/loading/saved states. Screenshots must be real.
6. **Review:** inspect diff, duplicate logic, state persistence, permissions, untrusted inputs, and whether platform integrations are actually implemented.

## Required domain tests
- Priority sorting among simultaneously eligible items.
- Source domain different from trigger domain.
- Snooze blocks until expiry and then expires.
- Done never resurfaces.
- Rapid duplicate events produce one reminder.
- Restart reloads persisted bookmarks and cooldown metadata.
- Malformed URL rejection.
- Duplicate save does not silently create multiple entries.
- Unauthorized/unknown context events ignored.

## Human hardware checks
- Android share intent opens Revisit and pre-fills the real link.
- Windows executable starts and retains a save after app restart.
- One authorized, genuine context event reaches the app and causes the correct reminder.
- Denying permissions does not crash or misrepresent functionality.

Unit tests are not proof that app-level permissions/OS background behavior work. Flutter `integration_test` can't directly operate all native permission dialogs; perform manual device checks as needed.

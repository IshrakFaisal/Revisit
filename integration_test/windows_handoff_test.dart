import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/domain/reminders.dart';
import 'package:revisit/platform/windows_reminders.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Windows channel rejects invalid and expired requests', (
    tester,
  ) async {
    const channel = MethodChannel('revisit/windows');
    final adapter = WindowsReminders();
    addTearDown(adapter.dispose);
    final registration = await adapter.registrationAvailable();
    expect(registration, isA<bool>());
    for (final payload in <Object?>[
      null,
      {'request': 1, 'bookmarkId': 1, 'context': 'github', 'expiresAt': 0},
      {
        'request': 2,
        'bookmarkId': 1,
        'context': 'evil',
        'expiresAt': DateTime.now()
            .add(reservationLease)
            .millisecondsSinceEpoch,
      },
    ]) {
      expect(
        await channel.invokeMethod<bool>('submitNotification', payload),
        isFalse,
      );
    }
    // Before explicit setup this exercises the actual worker and its native
    // error return without displaying a test notification or changing settings.
    if (!registration) {
      final now = DateTime.now();
      final bookmark = Bookmark(
        id: 1,
        url: 'https://example.org/',
        canonicalUrl: 'https://example.org/',
        title: 'Native contract test',
        intention: Intention('Not sent to the OS'),
        source: SourceContext.x,
        trigger: TriggerContext.github,
        createdAt: now,
        updatedAt: now,
      );
      expect(
        await adapter.submit(bookmark, expiresAt: now.add(reservationLease)),
        DeliveryOutcome.failed,
      );
    }
  }, skip: !Platform.isWindows);

  testWidgets(
    'receiver stops, releases its pipe and reports status after reattach',
    (tester) async {
      const channel = MethodChannel('revisit/windows');
      for (var iteration = 0; iteration < 2; iteration++) {
        final adapter = WindowsReminders();
        final status = adapter.receiverStatus.first.timeout(
          const Duration(seconds: 5),
        );
        await adapter.startReceiver();
        expect(await status, 'listening');
        final repeated = adapter.receiverStatus.first.timeout(
          const Duration(seconds: 5),
        );
        await channel.invokeMethod<void>('startReceiver');
        expect(await repeated, 'listening');
        await adapter.dispose();
      }
    },
    skip: !Platform.isWindows,
  );
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/application/reminder_coordinator.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/data/reminder_store.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/domain/reminders.dart';
import 'package:revisit/platform/windows_reminders.dart';
import 'package:drift/native.dart';

import '../reminders_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('revisit/windows');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late WindowsReminders adapter;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall) native;
  setUp(() {
    calls = [];
    native = (_) async => true;
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return native(call);
    });
    adapter = WindowsReminders(clock: () => fixture.epoch);
  });
  tearDown(() async {
    await adapter.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });
  Future<void> result(String outcome, {int request = 1}) async {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('notificationResult', {
          'request': request,
          'outcome': outcome,
        }),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }

  final bookmark = fixture.sample(id: 1);
  final expiry = fixture.epoch.add(reservationLease);

  test(
    'only validated fresh native arrivals enter the application stream',
    () async {
      final received = <ContextArrival>[];
      final subscription = adapter.arrivals.listen(received.add);
      addTearDown(subscription.cancel);
      final valid = <String, Object>{
        'version': 1,
        'target': 'github',
        'eventId': '00000000-0000-0000-0000-000000000001',
        'visitId': '10000000-0000-0000-0000-000000000001',
        'occurredAt': fixture.epoch.millisecondsSinceEpoch,
      };
      for (final payload in [
        valid,
        {...valid, 'target': 'evil'},
        {...valid, 'occurredAt': 0},
        {...valid, 'url': 'https://github.com/'},
        {...valid, 'eventId': 'bad'},
      ]) {
        final done = Completer<void>();
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('contextArrival', payload),
          ),
          (_) => done.complete(),
        );
        await done.future;
      }
      expect(received, hasLength(1));
      expect(received.single.context, TriggerContext.github);
    },
  );

  test(
    'handoff is immediate, minimal, and awaits native outcome separately',
    () async {
      final task = adapter.submit(bookmark, expiresAt: expiry);
      await Future<void>.value();
      expect(calls.single.method, 'submitNotification');
      expect(calls.single.arguments, {
        'request': 1,
        'bookmarkId': 1,
        'context': 'github',
        'expiresAt': expiry.millisecondsSinceEpoch,
      });
      var finished = false;
      unawaited(task.then((_) => finished = true));
      await Future<void>.value();
      expect(finished, isFalse);
      await result('submitted');
      expect(await task, DeliveryOutcome.submitted);
    },
  );
  test('native rejection is a definite failure', () async {
    native = (_) async => false;
    expect(
      await adapter.submit(bookmark, expiresAt: expiry),
      DeliveryOutcome.failed,
    );
  });
  test('native reported error preserves failed semantics', () async {
    final task = adapter.submit(bookmark, expiresAt: expiry);
    await result('failed');
    expect(await task, DeliveryOutcome.failed);
  });
  for (final synchronous in [true, false]) {
    test('channel exception synchronous=$synchronous is unknown', () async {
      native = synchronous
          ? (_) => throw PlatformException(code: 'lost')
          : (_) async => throw PlatformException(code: 'lost');
      expect(
        await adapter.submit(bookmark, expiresAt: expiry),
        DeliveryOutcome.unknown,
      );
      expect(calls, hasLength(1));
    });
  }
  testWidgets('hanging acknowledgement expires without retry or late success', (
    tester,
  ) async {
    native = (_) => Completer<Object?>().future;
    final task = adapter.submit(bookmark, expiresAt: expiry);
    await tester.pump(reservationLease);
    expect(await task, DeliveryOutcome.unknown);
    await result('submitted');
    expect(calls, hasLength(1));
  });
  test('expired requests never cross the channel', () async {
    expect(
      await adapter.submit(bookmark, expiresAt: fixture.epoch),
      DeliveryOutcome.failed,
    );
    expect(calls, isEmpty);
  });
  test(
    'one pending request bounds queue and shutdown preserves uncertainty',
    () async {
      final first = adapter.submit(bookmark, expiresAt: expiry);
      expect(
        await adapter.submit(bookmark, expiresAt: expiry),
        DeliveryOutcome.failed,
      );
      await adapter.dispose();
      expect(await first, DeliveryOutcome.unknown);
      expect(calls, hasLength(1));
    },
  );
  test('completion commits while native acknowledgement is pending', () async {
    final db = BookmarkStore(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.createBookmark(fixture.sample());
    final started = Completer<void>();
    native = (_) async {
      started.complete();
      return true;
    };
    final task = ReminderCoordinator(
      db,
      adapter,
      () => fixture.epoch,
    ).handle(fixture.event(fixture.epoch));
    await started.future;
    expect(await db.completeBookmark(id, fixture.epoch), isTrue);
    expect(
      await db.reminderOutcome(fixture.event(fixture.epoch).eventId),
      'unknown',
    );
    await result('submitted');
    await task;
    expect((await db.readBookmark(id))!.status, BookmarkStatus.completed);
    expect(calls, hasLength(1));
  });
}

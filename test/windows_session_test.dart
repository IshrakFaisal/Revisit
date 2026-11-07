import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/data/reminder_store.dart';
import 'package:revisit/platform/windows_reminders.dart';
import 'package:revisit/ui/revisit_app.dart';
import 'package:revisit/application/windows_session.dart';
import 'package:revisit/data/sqlite_write_policy.dart';
import 'package:revisit/ui/windows_integration_status.dart';
import 'package:revisit/ui/bookmark_editor.dart';

import 'reminders_test.dart' as f;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('revisit/windows');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  final payloads = <Map>[];
  Future<void> inbound(String method, Object data) async {
    final gate = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, data)),
      (_) => gate.complete(),
    );
    await gate.future;
  }

  Future<void> finishSession(
    WidgetTester tester,
    WindowsSession session,
  ) async {
    var finished = false;
    unawaited(session.close().then((_) => finished = true));
    for (var i = 0; i < 100 && !finished; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(
      finished,
      isTrue,
      reason: 'Receiver and session work must finish shutdown',
    );
  }

  setUp(() {
    calls.clear();
    payloads.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'stopReceiver') {
        await inbound('receiverStatus', {'status': 'stopped'});
      }
      if (call.method == 'submitNotification') {
        payloads.add(call.arguments as Map);
        return false;
      }
      return true;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'browser chooser channel reads SQLite and opens only the requested context',
    () async {
      final db = BookmarkStore(NativeDatabase.memory());
      final id = await db.createBookmark(f.sample(trigger: TriggerContext.x));
      final now = DateTime.now();
      final session = WindowsSession(
        db,
        WindowsReminders(clock: () => now),
        () => now,
      );
      await session.start();
      addTearDown(() async {
        await session.close();
        await db.close();
      });
      Future<Map> query(String kind, String target, String cursor) async {
        final result = Completer<Object?>();
        const codec = StandardMethodCodec();
        messenger.handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(
            MethodCall('browserQuery', {
              'version': 1,
              'kind': kind,
              'target': target,
              'cursor': cursor,
              'eventId': '01234567-89ab-cdef-0123-456789abcdef',
              'occurredAt': now.millisecondsSinceEpoch,
            }),
          ),
          (data) => result.complete(codec.decodeEnvelope(data!)),
        );
        return jsonDecode((await result.future) as String) as Map;
      }

      expect((await query('list', 'x', ''))['items'], [
        {
          'id': id,
          'title': f.sample().title,
          'priority': f.sample().priority.name,
        },
      ]);
      expect((await query('list', 'facebook', ''))['items'], isEmpty);
      expect(await query('open', 'facebook', '$id'), {'status': 'unavailable'});
      expect(await query('open', 'x', '$id'), {
        'status': 'open',
        'url': f.sample().url,
      });
      expect((await db.readReminderState()).lastAttemptAt, isNull);
      expect(calls, isNot(contains('submitNotification')));
    },
  );
  test(
    'browser arrival offers the saved link without a Windows notification',
    () async {
      final db = BookmarkStore(NativeDatabase.memory());
      final now = DateTime.now();
      final bookmark = f.sample(trigger: TriggerContext.x);
      await db.createBookmark(bookmark);
      final session = WindowsSession(
        db,
        WindowsReminders(clock: () => now),
        () => now,
      );
      await session.start();
      addTearDown(() async {
        await session.close();
        await db.close();
      });
      Future<Map<String, dynamic>> send(String target, int n) async {
        final event = f.event(now, n: n, target: target);
        final result = Completer<Object?>();
        const codec = StandardMethodCodec();
        messenger.handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(
            MethodCall('browserArrival', {
              'version': 2,
              'target': target,
              'eventId': event.eventId,
              'visitId': event.visitId,
              'occurredAt': now.millisecondsSinceEpoch,
            }),
          ),
          (data) => result.complete(codec.decodeEnvelope(data!)),
        );
        return jsonDecode((await result.future) as String)
            as Map<String, dynamic>;
      }

      expect(await send('facebook', 1), {'status': 'no_reminder'});
      expect(await send('x', 2), {'status': 'reminder', 'url': bookmark.url});
      expect(await send('x', 2), {'status': 'no_reminder'});
      expect(await send('x', 3), {'status': 'no_reminder'});
      expect(calls, isNot(contains('submitNotification')));
    },
  );
  testWidgets('browser capture opens a draft without saving a bookmark', (
    tester,
  ) async {
    final db = BookmarkStore(NativeDatabase.memory());
    await tester.pumpWidget(
      RevisitApp(
        openStore: () => db,
        openLink: (_) async => true,
        enableWindowsIntegration: true,
      ),
    );
    await tester.pumpAndSettle();
    final owner = tester
        .widget<WindowsIntegrationStatus>(find.byType(WindowsIntegrationStatus))
        .session;
    await inbound('captureRequested', {
      'version': 1,
      'kind': 'capture',
      'url': 'https://x.com/revisit/status/1',
      'source': 'x',
      'eventId': '11111111-1111-4111-8111-111111111111',
      'occurredAt': DateTime.now().millisecondsSinceEpoch,
    });
    await tester.pumpAndSettle();
    expect(find.byType(BookmarkEditor), findsOneWidget);
    expect(await db.countBookmarks(), 0);
    await tester.pumpWidget(const SizedBox());
    await finishSession(tester, owner);
    await tester.pumpAndSettle();
  });
  testWidgets(
    'session qualifying native event must create a persistent reminder attempt',
    (tester) async {
      final db = BookmarkStore(NativeDatabase.memory());
      final id = await db.createBookmark(f.sample());
      await tester.pumpWidget(
        RevisitApp(
          openStore: () => db,
          openLink: (_) async => true,
          enableWindowsIntegration: true,
        ),
      );
      await tester.pumpAndSettle();
      final event = f.event(DateTime.now());
      await inbound('contextArrival', {
        'version': 1,
        'target': 'github',
        'eventId': event.eventId,
        'visitId': event.visitId,
        'occurredAt': event.occurredAt.millisecondsSinceEpoch,
      });
      await tester.pumpAndSettle();
      final outcome = await db.reminderOutcome(event.eventId);
      final count = await db.countBookmarks();
      final owned =
          find
              .byType(WindowsIntegrationStatus, skipOffstage: false)
              .evaluate()
              .isEmpty
          ? null
          : tester
                .widget<WindowsIntegrationStatus>(
                  find.byType(WindowsIntegrationStatus, skipOffstage: false),
                )
                .session;
      await tester.pumpWidget(const SizedBox());
      if (owned != null) await finishSession(tester, owned);
      await tester.pumpAndSettle();
      expect(count, 1);
      expect(payloads.single['bookmarkId'], id);
      expect(outcome, 'failed');
      expect(
        outcome,
        isNotNull,
        reason: 'The existing eligible SQLite record must be evaluated and reserved.',
      );
    },
  );
  testWidgets('REVIEW notification activation must resolve a saved bookmark', (
    tester,
  ) async {
    final db = BookmarkStore(NativeDatabase.memory());
    final id = await db.createBookmark(f.sample());
    await tester.pumpWidget(
      RevisitApp(
        openStore: () => db,
        openLink: (_) async => true,
        enableWindowsIntegration: true,
      ),
    );
    await tester.pumpAndSettle();
    await inbound('notificationActivated', {'bookmarkId': id});
    await tester.pumpAndSettle();
    final opened =
        find.text('Bookmark details').evaluate().isNotEmpty ||
        find.text('Saved intention').evaluate().isNotEmpty;
    final owned =
        find
            .byType(WindowsIntegrationStatus, skipOffstage: false)
            .evaluate()
            .isEmpty
        ? null
        : tester
              .widget<WindowsIntegrationStatus>(
                find.byType(WindowsIntegrationStatus, skipOffstage: false),
              )
              .session;
    await tester.pumpWidget(const SizedBox());
    if (owned != null) await finishSession(tester, owned);
    await tester.pumpAndSettle();
    expect(
      opened,
      isTrue,
      reason: 'Activation should open current persisted details.',
    );
  });
  test(
    'session disposing the receiver owner must stop native observation',
    () async {
      final adapter = WindowsReminders();
      await adapter.startReceiver();
      await adapter.dispose();
      expect(
        calls,
        contains('stopReceiver'),
        reason: 'Native observation must not outlive its only Dart subscriber.',
      );
    },
  );

  testWidgets('session survives resize and status widget replacement', (
    tester,
  ) async {
    final db = BookmarkStore(NativeDatabase.memory());
    await db.createBookmark(f.sample());
    await tester.pumpWidget(
      RevisitApp(
        openStore: () => db,
        openLink: (_) async => true,
        enableWindowsIntegration: true,
      ),
    );
    await tester.pumpAndSettle();
    await inbound('receiverStatus', {'status': 'listening'});
    await tester.pumpAndSettle();
    expect(find.textContaining('Local receiver listening'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    await tester.pumpAndSettle();
    expect(find.textContaining('Local receiver listening'), findsOneWidget);
    expect(calls.where((c) => c == 'startReceiver'), hasLength(1));
    expect(calls, isNot(contains('stopReceiver')));
    final owned =
        find
            .byType(WindowsIntegrationStatus, skipOffstage: false)
            .evaluate()
            .isEmpty
        ? null
        : tester
              .widget<WindowsIntegrationStatus>(
                find.byType(WindowsIntegrationStatus, skipOffstage: false),
              )
              .session;
    await tester.pumpWidget(const SizedBox());
    if (owned != null) await finishSession(tester, owned);
    await tester.pumpAndSettle();
    expect(calls.where((c) => c == 'stopReceiver'), hasLength(1));
    await tester.binding.setSurfaceSize(null);
  });

  for (final state in [
    'active',
    'completed',
    'snoozed',
    'deleted',
    'unknown',
  ]) {
    testWidgets(
      'activation resolves current $state record and duplicate clicks safely',
      (tester) async {
        final db = BookmarkStore(NativeDatabase.memory());
        final id = await db.createBookmark(f.sample());
        await tester.pumpWidget(
          RevisitApp(
            openStore: () => db,
            openLink: (_) async => true,
            enableWindowsIntegration: true,
          ),
        );
        await tester.pumpAndSettle();
        final owner = tester
            .widget<WindowsIntegrationStatus>(
              find.byType(WindowsIntegrationStatus),
            )
            .session;
        if (state == 'completed') await db.completeBookmark(id, f.epoch);
        if (state == 'snoozed') {
          await db.snoozeBookmark(id, const Duration(hours: 1), f.epoch);
        }
        if (state == 'deleted') await db.deleteBookmark(id);
        final clicked = state == 'unknown' ? id + 100 : id;
        await inbound('notificationActivated', {'bookmarkId': clicked});
        await tester.pumpAndSettle();
        if (state == 'deleted' || state == 'unknown') {
          expect(
            find.textContaining('no longer in your library'),
            findsOneWidget,
          );
          expect(find.text('Bookmark details'), findsNothing);
        } else {
          expect(find.text('Bookmark details'), findsOneWidget);
          expect(find.text('Read before login work'), findsOneWidget);
          final after = await db.readBookmark(id);
          expect(after!.status.name, state);
          await inbound('notificationActivated', {'bookmarkId': clicked});
          await tester.pumpAndSettle();
          expect(calls.where((c) => c == 'showWindow'), hasLength(1));
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.text('Bookmark details'), findsNothing);
        }
        expect(await db.countBookmarks(), state == 'deleted' ? 0 : 1);
        await tester.pumpWidget(const SizedBox());
        await finishSession(tester, owner);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      },
    );
  }

  testWidgets(
    'session dispatch consumes wrong context and deduplicates failed delivery',
    (tester) async {
      final db = BookmarkStore(NativeDatabase.memory());
      final id = await db.createBookmark(f.sample());
      final session = WindowsSession(
        db,
        WindowsReminders(clock: () => f.epoch),
        () => f.epoch,
      );
      unawaited(session.start());
      await tester.pumpWidget(
        MaterialApp(home: WindowsIntegrationStatus(session: session)),
      );
      Future<void> send(int n, String target) async {
        final event = f.event(f.epoch, n: n, target: target);
        await inbound('contextArrival', {
          'version': 1,
          'target': target,
          'eventId': event.eventId,
          'visitId': event.visitId,
          'occurredAt': f.epoch.millisecondsSinceEpoch,
        });
        await tester.pumpAndSettle();
      }

      await send(1, 'x');
      expect(await db.reminderOutcome(f.event(f.epoch).eventId), 'consumed');
      expect((await db.readReminderState()).lastAttemptAt, isNull);
      expect(payloads, isEmpty);
      await send(2, 'github');
      await send(2, 'github');
      expect(payloads, hasLength(1));
      expect(payloads.single['bookmarkId'], id);
      expect(
        await db.reminderOutcome(f.event(f.epoch, n: 2).eventId),
        'failed',
      );
      final owned =
          find
              .byType(WindowsIntegrationStatus, skipOffstage: false)
              .evaluate()
              .isEmpty
          ? null
          : tester
                .widget<WindowsIntegrationStatus>(
                  find.byType(WindowsIntegrationStatus, skipOffstage: false),
                )
                .session;
      await tester.pumpWidget(const SizedBox());
      if (owned != null) await finishSession(tester, owned);
      await finishSession(tester, session);
      await db.close();
    },
  );

  for (final busy in [true, false]) {
    testWidgets(
      'session reports storage failure busy=$busy without unhandled errors',
      (tester) async {
        final db = _UnavailableStore(busy);
        await db.createBookmark(f.sample());
        final session = WindowsSession(
          db,
          WindowsReminders(clock: () => f.epoch),
          () => f.epoch,
        );
        unawaited(session.start());
        db.fail = true;
        await tester.pumpWidget(
          MaterialApp(home: WindowsIntegrationStatus(session: session)),
        );
        final event = f.event(f.epoch);
        await inbound('contextArrival', {
          'version': 1,
          'target': 'github',
          'eventId': event.eventId,
          'visitId': event.visitId,
          'occurredAt': f.epoch.millisecondsSinceEpoch,
        });
        await tester.pumpAndSettle();
        expect(
          session.processing,
          contains(busy ? 'Storage busy' : 'processing failed'),
        );
        expect(payloads, isEmpty);
        expect(tester.takeException(), isNull);
        final owned =
            find
                .byType(WindowsIntegrationStatus, skipOffstage: false)
                .evaluate()
                .isEmpty
            ? null
            : tester
                  .widget<WindowsIntegrationStatus>(
                    find.byType(WindowsIntegrationStatus, skipOffstage: false),
                  )
                  .session;
        await tester.pumpWidget(const SizedBox());
        if (owned != null) await finishSession(tester, owned);
        await finishSession(tester, session);
        await db.close();
      },
    );
  }
}

class _UnavailableStore extends BookmarkStore {
  _UnavailableStore(this.busy) : super(NativeDatabase.memory());
  final bool busy;
  bool fail = false;
  @override
  Future<T> writeTransaction<T>(
    Future<T> Function() action, {
    bool Function()? mayRetry,
  }) {
    if (fail) {
      return Future.error(
        busy
            ? const DatabaseBusyException('test contention')
            : StateError('test storage failure'),
      );
    }
    return super.writeTransaction(action, mayRetry: mayRetry);
  }
}

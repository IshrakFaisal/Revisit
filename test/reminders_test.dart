import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/domain/reminders.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/data/reminder_store.dart';
import 'package:revisit/application/reminder_coordinator.dart';

final epoch = DateTime.utc(2026, 11, 5);
ContextArrival event(DateTime now, {int n = 1, String target = 'github'}) =>
    ContextArrival.parse(
      {
        'version': 1,
        'target': target,
        'eventId': '00000000-0000-0000-0000-${n.toString().padLeft(12, '0')}',
        'visitId': '10000000-0000-0000-0000-${n.toString().padLeft(12, '0')}',
        'occurredAt': now.millisecondsSinceEpoch,
      },
      authorized: true,
      qualifyingArrival: true,
    )!;
Bookmark sample({
  int? id,
  Priority priority = Priority.medium,
  BookmarkStatus status = BookmarkStatus.active,
  DateTime? snooze,
  DateTime? last,
  TriggerContext trigger = TriggerContext.github,
  DateTime? created,
}) => Bookmark(
  id: id,
  url: 'https://example.org/$id',
  canonicalUrl: 'https://example.org/$id',
  title: 'Read authentication',
  intention: Intention('Read before login work'),
  source: SourceContext.x,
  trigger: trigger,
  priority: priority,
  status: status,
  createdAt: created ?? epoch,
  updatedAt: epoch,
  snoozedUntil: snooze,
  lastReminderSubmittedAt: last,
);
void main() {
  test('wire rejects malformed, unauthorized and navigation inputs', () {
    for (final input in [
      null,
      {},
      {'version': 1, 'target': 'github.evil'},
    ]) {
      expect(
        ContextArrival.parse(input, authorized: true, qualifyingArrival: true),
        isNull,
      );
    }
    final wire = {
      'version': 1,
      'target': 'github',
      'eventId': event(epoch).eventId,
      'visitId': event(epoch).visitId,
      'occurredAt': epoch.millisecondsSinceEpoch,
    };
    expect(
      ContextArrival.parse(wire, authorized: false, qualifyingArrival: true),
      isNull,
    );
    expect(
      ContextArrival.parse(wire, authorized: true, qualifyingArrival: false),
      isNull,
    );
    expect(
      ContextArrival.parse(
        {...wire, 'extra': true},
        authorized: true,
        qualifyingArrival: true,
      ),
      isNull,
    );
    expect(
      ContextArrival.parse(
        {...wire, 'target': 'other'},
        authorized: true,
        qualifyingArrival: true,
      ),
      isNull,
    );
  });
  test(
    'source is independent; exclusions and exact snooze/item boundaries',
    () {
      final items = [
        sample(id: 1),
        sample(id: 2, status: BookmarkStatus.completed),
        sample(id: 3, trigger: TriggerContext.x),
        sample(
          id: 4,
          status: BookmarkStatus.snoozed,
          snooze: epoch.add(const Duration(hours: 1)),
        ),
        sample(id: 5, last: epoch),
      ];
      final d = evaluateReminder(
        items,
        event(epoch),
        const ReminderState(),
        epoch,
      );
      expect(d.bookmark!.id, 1);
      expect(d.reasons[2], ReminderReason.completed);
      expect(d.reasons[3], ReminderReason.wrongContext);
      expect(d.reasons[4], ReminderReason.snoozed);
      expect(d.reasons[5], ReminderReason.itemCooldown);
      final boundary = epoch.add(const Duration(hours: 1));
      expect(
        evaluateReminder(
          [items[3]],
          event(boundary),
          const ReminderState(),
          boundary,
        ).bookmark!.id,
        4,
      );
      expect(
        evaluateReminder(
          [items[4]],
          event(boundary),
          const ReminderState(),
          boundary,
        ).bookmark!.id,
        5,
      );
      expect(
        evaluateReminder(
          [items[0]],
          event(epoch, target: 'x'),
          const ReminderState(),
          epoch,
        ).bookmark,
        isNull,
      );
    },
  );
  test('priority, least recently reminded, oldest creation and ID ties', () {
    final items = [
      sample(id: 5, priority: Priority.low),
      sample(id: 4),
      sample(
        id: 3,
        priority: Priority.high,
        last: epoch.subtract(const Duration(hours: 2)),
      ),
      sample(id: 2, priority: Priority.high),
      sample(id: 1, priority: Priority.high),
    ];
    for (final list in [items, items.reversed.toList()]) {
      final d = evaluateReminder(
        list,
        event(epoch),
        const ReminderState(),
        epoch,
      );
      expect(d.bookmark!.id, 1);
      expect(d.reasons[2], ReminderReason.lowerPriority);
    }
    expect(
      evaluateReminder(
        [
          sample(id: 1, created: epoch),
          sample(id: 2, created: epoch.subtract(const Duration(days: 1))),
        ],
        event(epoch),
        const ReminderState(),
        epoch,
      ).bookmark!.id,
      2,
    );
  });
  test('freshness, empty, disable, pause, dedup and global boundary', () {
    final b = [sample(id: 1)];
    expect(
      evaluateReminder([], event(epoch), const ReminderState(), epoch).reason,
      ReminderReason.empty,
    );
    expect(
      evaluateReminder(b, null, const ReminderState(), epoch).reason,
      ReminderReason.invalidEvent,
    );
    for (final seconds in [-31, 6]) {
      expect(
        evaluateReminder(
          b,
          event(epoch.add(Duration(seconds: seconds))),
          const ReminderState(),
          epoch,
        ).reason,
        ReminderReason.staleEvent,
      );
    }
    for (final seconds in [-30, 5]) {
      expect(
        evaluateReminder(
          b,
          event(epoch.add(Duration(seconds: seconds))),
          const ReminderState(),
          epoch,
        ).bookmark,
        isNotNull,
      );
    }
    expect(
      evaluateReminder(
        b,
        event(epoch),
        const ReminderState(enabled: false),
        epoch,
      ).reason,
      ReminderReason.disabled,
    );
    expect(
      evaluateReminder(
        b,
        event(epoch),
        ReminderState(pausedUntil: epoch.add(const Duration(seconds: 1))),
        epoch,
      ).reason,
      ReminderReason.paused,
    );
    expect(
      evaluateReminder(
        b,
        event(epoch),
        ReminderState(eventIds: {event(epoch).eventId}),
        epoch,
      ).reason,
      ReminderReason.duplicateEvent,
    );
    expect(
      evaluateReminder(
        b,
        event(epoch),
        ReminderState(visitIds: {event(epoch).visitId}),
        epoch,
      ).reason,
      ReminderReason.duplicateEvent,
    );
    expect(
      evaluateReminder(
        b,
        event(epoch),
        ReminderState(
          lastAttemptAt: epoch.subtract(const Duration(minutes: 15)),
        ),
        epoch,
      ).bookmark,
      isNotNull,
    );
    expect(
      evaluateReminder(
        b,
        event(epoch),
        ReminderState(
          lastAttemptAt: epoch.subtract(const Duration(minutes: 14)),
        ),
        epoch,
      ).reason,
      ReminderReason.globalCooldown,
    );
  });
  for (final outcome in DeliveryOutcome.values) {
    test('persists delivery ${outcome.name} and consumes arrival', () async {
      final db = BookmarkStore(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.createBookmark(sample());
      final coordinator = ReminderCoordinator(
        db,
        _Delivery(outcome),
        () => epoch,
      );
      await coordinator.handle(event(epoch));
      expect(await db.reminderOutcome(event(epoch).eventId), outcome.name);
      expect(
        (await db.readBookmark(id))!.lastReminderSubmittedAt,
        outcome == DeliveryOutcome.submitted ? epoch : null,
      );
      expect(
        (await coordinator.handle(event(epoch))).reason,
        ReminderReason.duplicateEvent,
      );
      expect(
        (await coordinator.handle(event(epoch, n: 2))).reason,
        ReminderReason.globalCooldown,
      );
    });
  }
  test('100 simultaneous events produce one reservation; pending and crash recovery', () async {
    final db = BookmarkStore(NativeDatabase.memory());
    addTearDown(db.close);
    await db.createBookmark(sample());
    final results = await Future.wait(
      List.generate(100, (_) => db.reserveReminder(event(epoch), epoch)),
    );
    expect(results.where((r) => r.decision.bookmark != null), hasLength(1));
    expect(
      (await db.reserveReminder(event(epoch, n: 2), epoch)).decision.reason,
      ReminderReason.pendingDelivery,
    );
    final later = epoch.add(const Duration(minutes: 15));
    final next = await db.reserveReminder(event(later, n: 3), later);
    expect(next.decision.bookmark, isNotNull);
    expect(await db.reminderOutcome(event(epoch).eventId), 'unknown');
    expect(
      await db.finishReminder(
        results.firstWhere((r) => r.decision.bookmark != null),
        DeliveryOutcome.submitted,
        later,
      ),
      isFalse,
    );
    expect((await db.readBookmarks()).single.lastReminderSubmittedAt, isNull);
  });
  test(
    'delivery exception is unknown; concurrent duplicate while adapter pending',
    () async {
      final db = BookmarkStore(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createBookmark(sample());
      final gate = Completer<DeliveryOutcome>();
      final delivery = _Pending(gate);
      final c = ReminderCoordinator(db, delivery, () => epoch);
      final first = c.handle(event(epoch));
      await delivery.started.future;
      expect(
        (await c.handle(event(epoch))).reason,
        ReminderReason.duplicateEvent,
      );
      gate.completeError(StateError('Lost delivery acknowledgement'));
      await first;
      expect(await db.reminderOutcome(event(epoch).eventId), 'unknown');
    },
  );
  test(
    'late adapter acknowledgement cannot turn an expired lease into success',
    () async {
      final db = BookmarkStore(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.createBookmark(sample());
      var now = epoch;
      final gate = Completer<DeliveryOutcome>();
      final delivery = _Pending(gate);
      final pending = ReminderCoordinator(
        db,
        delivery,
        () => now,
      ).handle(event(now));
      await delivery.started.future;
      now = epoch.add(reservationLease);
      gate.complete(DeliveryOutcome.submitted);
      await pending;
      expect(await db.reminderOutcome(event(epoch).eventId), 'unknown');
      expect((await db.readBookmark(id))!.lastReminderSubmittedAt, isNull);
    },
  );
  test(
    'successful submission and both cooldowns survive database reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('revisit_m4_success_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      final first = BookmarkStore(NativeDatabase(file));
      final id = await first.createBookmark(sample());
      await ReminderCoordinator(
        first,
        _Delivery(DeliveryOutcome.submitted),
        () => epoch,
      ).handle(event(epoch));
      await first.close();
      final second = BookmarkStore(NativeDatabase(file));
      addTearDown(second.close);
      expect((await second.readBookmark(id))!.lastReminderSubmittedAt, epoch);
      expect(
        (await second.reserveReminder(
          event(epoch, n: 2),
          epoch,
        )).decision.reason,
        ReminderReason.globalCooldown,
      );
      final later = epoch.add(const Duration(minutes: 15));
      final decision = (await second.reserveReminder(
        event(later, n: 3),
        later,
      )).decision;
      expect(decision.bookmark, isNull);
      expect(decision.reasons[id], ReminderReason.itemCooldown);
      final hour = epoch.add(const Duration(hours: 1));
      expect(
        (await second.reserveReminder(
          event(hour, n: 4),
          hour,
        )).decision.bookmark!.id,
        id,
      );
    },
  );
  test(
    'failed schema upgrade rolls back and can retry without losing bookmarks',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'revisit_m4_migration_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      final original = BookmarkStore(NativeDatabase(file));
      final id = await original.createBookmark(sample());
      await original.customStatement('DROP TABLE reminder_arrivals');
      await original.customStatement('DROP TABLE reminder_control');
      await original.customStatement('PRAGMA user_version=1');
      await original.close();
      final failing = _FailMigration(file);
      await expectLater(failing.readBookmarks(), throwsStateError);
      await failing.close();
      final retried = BookmarkStore(NativeDatabase(file));
      addTearDown(retried.close);
      expect((await retried.readBookmark(id))!.title, sample().title);
      expect((await retried.readReminderState()).eventIds, isEmpty);
      expect(
        (await retried.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        2,
      );
    },
  );
  test('failed reservation rolls back arrival and global cooldown', () async {
    final db = _FailStore();
    addTearDown(db.close);
    await db.createBookmark(sample());
    db.fail = true;
    await expectLater(
      db.reserveReminder(event(epoch), epoch),
      throwsStateError,
    );
    expect((await db.readReminderState()).eventIds, isEmpty);
    expect((await db.readReminderState()).lastAttemptAt, isNull);
    db.fail = false;
    expect(
      (await db.reserveReminder(event(epoch), epoch)).decision.bookmark,
      isNotNull,
    );
  });
  test('v1 migration preserves all bookmark data and restart retains lifecycle state', () async {
    final dir = await Directory.systemTemp.createTemp('revisit_m4_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final old = BookmarkStore(NativeDatabase(file));
    final id = await old.createBookmark(sample());
    final before = (await old.select(old.bookmarks).getSingle()).toJson();
    // v1 has the identical bookmarks schema and no reminder tables.
    await old.customStatement('DROP TABLE reminder_arrivals');
    await old.customStatement('DROP TABLE reminder_control');
    await old.customStatement('PRAGMA user_version=1');
    await old.close();
    final migrated = BookmarkStore(NativeDatabase(file));
    expect(
      (await migrated.select(migrated.bookmarks).getSingle()).toJson(),
      before,
    );
    await migrated.reserveReminder(event(epoch), epoch);
    await migrated.snoozeBookmark(id, const Duration(hours: 24), epoch);
    await migrated.setReminderPreferences(
      enabled: false,
      pausedUntil: epoch.add(const Duration(hours: 1)),
    );
    await migrated.close();
    final reopened = BookmarkStore(NativeDatabase(file));
    addTearDown(reopened.close);
    expect(
      (await reopened.readBookmark(id))!.snoozedUntil,
      epoch.add(const Duration(hours: 24)),
    );
    final state = await reopened.readReminderState();
    expect(state.enabled, isFalse);
    expect(state.lastAttemptAt, epoch);
    // Snooze now atomically invalidates the pre-handoff reservation.
    expect(state.pending, isFalse);
    expect(await reopened.reminderOutcome(event(epoch).eventId), 'failed');
    expect(state.pausedUntil, epoch.add(const Duration(hours: 1)));
    await reopened.recoverReminders(epoch.add(reservationLease));
    expect(await reopened.reminderOutcome(event(epoch).eventId), 'failed');
    await reopened.completeBookmark(id, epoch);
    expect(
      await reopened.snoozeBookmark(id, const Duration(hours: 1), epoch),
      isFalse,
    );
    await reopened.recoverReminders(epoch.add(const Duration(hours: 25)));
    expect((await reopened.readReminderState()).eventIds, isEmpty);
    expect((await reopened.readReminderState()).lastAttemptAt, epoch);
  });
}

class _FailMigration extends BookmarkStore {
  _FailMigration(File file) : super(NativeDatabase(file));
  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) async {
    await super.customStatement(statement, args);
    if (statement.startsWith('CREATE TABLE reminder_arrivals')) {
      throw StateError('Injected interrupted migration');
    }
  }
}

class _Delivery implements ReminderDelivery {
  _Delivery(this.outcome);
  final DeliveryOutcome outcome;
  @override
  Future<DeliveryOutcome> submit(
    Bookmark bookmark, {
    required DateTime expiresAt,
  }) async => outcome;
}

class _Pending implements ReminderDelivery {
  _Pending(this.gate);
  final Completer<DeliveryOutcome> gate;
  final started = Completer<void>();
  @override
  Future<DeliveryOutcome> submit(
    Bookmark bookmark, {
    required DateTime expiresAt,
  }) {
    started.complete();
    return gate.future;
  }
}

class _FailStore extends BookmarkStore {
  _FailStore() : super(NativeDatabase.memory());
  bool fail = false;
  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) async {
    await super.customStatement(statement, args);
    if (fail && statement.startsWith('INSERT INTO reminder_arrivals')) {
      throw StateError('Injected reservation failure');
    }
  }
}

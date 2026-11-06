import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/application/reminder_coordinator.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/data/reminder_store.dart';
import 'package:revisit/data/sqlite_write_policy.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/domain/reminders.dart';
import 'package:revisit/ui/revisit_app.dart';

import 'reminders_test.dart' as fixture;

void main() {
  test(
    'failed reservation invalidation rolls back each lifecycle mutation',
    () async {
      final db = BookmarkStore(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.createBookmark(fixture.sample());
      final event = fixture.event(fixture.epoch);
      await db.reserveReminder(event, fixture.epoch);
      final before = (await db.select(db.bookmarks).getSingle()).toJson();
      await db.customStatement(
        "CREATE TRIGGER fail_invalidation BEFORE UPDATE OF outcome ON reminder_arrivals WHEN NEW.outcome='failed' BEGIN SELECT RAISE(ABORT, 'Injected invalidation failure'); END",
      );
      for (final change in <Future<bool> Function()>[
        () => db.completeBookmark(id, fixture.epoch),
        () => db.snoozeBookmark(id, const Duration(hours: 1), fixture.epoch),
        () => db.deleteBookmark(id),
      ]) {
        await expectLater(change(), throwsA(isA<SqliteException>()));
        expect((await db.select(db.bookmarks).getSingle()).toJson(), before);
        expect(await db.reminderOutcome(event.eventId), 'reserved');
      }
      await db.customStatement('DROP TRIGGER fail_invalidation');
      expect(await db.completeBookmark(id, fixture.epoch), isTrue);
      expect(await db.reminderOutcome(event.eventId), 'failed');
    },
  );
  test('another connection cannot commit completion between authorization read and handoff', () async {
    final dir = await Directory.systemTemp.createTemp('revisit_handoff_order_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final owner = _GatedReadStore(NativeDatabase.createInBackground(file));
    final contended = Completer<void>();
    final retry = Completer<void>();
    final other = _OtherStore(
      NativeDatabase.createInBackground(file),
      writePolicy: SqliteWritePolicy(
        attempts: 2,
        wait: (_) async {
          contended.complete();
          await retry.future;
        },
      ),
    );
    addTearDown(owner.close);
    addTearDown(other.close);
    final id = await owner.createBookmark(fixture.sample());
    await other.countBookmarks();
    final delivery = _Delivery()..wait = true;
    final task = ReminderCoordinator(
      owner,
      delivery,
      () => fixture.epoch,
    ).handle(fixture.event(fixture.epoch));
    await owner.readReached.future;
    var completionCommitted = false;
    final completed = other.completeBookmark(id, fixture.epoch).then((value) {
      completionCommitted = true;
      return value;
    });
    await contended.future;
    expect(completionCommitted, isFalse);
    owner.releaseRead.complete();
    await delivery.started.future;
    // A queued read on the owner proves the short authorization transaction ended.
    expect(
      await owner.reminderOutcome(fixture.event(fixture.epoch).eventId),
      'unknown',
    );
    expect(completionCommitted, isFalse);
    retry.complete();
    expect(await completed, isTrue);
    expect((await other.readBookmark(id))!.status, BookmarkStatus.completed);
    delivery.gate.complete(DeliveryOutcome.submitted);
    await task;
    expect((await other.readBookmark(id))!.status, BookmarkStatus.completed);
    expect(delivery.calls, 1);
  });
  test(
    'failure after immediate handoff never retries the external operation',
    () async {
      final db = _FailCommitStore();
      addTearDown(db.close);
      await db.createBookmark(fixture.sample());
      final delivery = _Delivery()
        ..onHandoff = () {
          db.failCommit = true;
        };
      await expectLater(
        ReminderCoordinator(
          db,
          delivery,
          () => fixture.epoch,
        ).handle(fixture.event(fixture.epoch)),
        throwsA(isA<SqliteException>()),
      );
      expect(delivery.calls, 1);
      db.failCommit = false;
      expect(
        await db.reminderOutcome(fixture.event(fixture.epoch).eventId),
        'reserved',
      );
      expect((await db.readBookmarks()).single.lastReminderSubmittedAt, isNull);
      await db.recoverReminders(fixture.epoch.add(reservationLease));
      expect(
        await db.reminderOutcome(fixture.event(fixture.epoch).eventId),
        'unknown',
      );
      expect((await db.readReminderState()).lastAttemptAt, fixture.epoch);
    },
  );

  test(
    'restart preserves unknown handoff and cannot reuse its reservation',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'revisit_handoff_restart_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      final first = BookmarkStore(NativeDatabase(file));
      await first.createBookmark(fixture.sample());
      final event = fixture.event(fixture.epoch);
      final reservation = await first.reserveReminder(event, fixture.epoch);
      final gate = Completer<DeliveryOutcome>();
      final handoff = await first.authorizeReminder(
        reservation,
        event,
        () => fixture.epoch,
        (_, _) => gate.future,
      );
      expect(handoff, isNotNull);
      expect(await first.reminderOutcome(event.eventId), 'unknown');
      await first.close();
      final second = BookmarkStore(NativeDatabase(file));
      addTearDown(second.close);
      await second.recoverReminders(fixture.epoch.add(reservationLease));
      expect(await second.reminderOutcome(event.eventId), 'unknown');
      var calls = 0;
      expect(
        await second.authorizeReminder(
          reservation,
          event,
          () => fixture.epoch,
          (_, _) async {
            calls++;
            return DeliveryOutcome.submitted;
          },
        ),
        isNull,
      );
      expect(calls, 0);
      expect((await second.readReminderState()).lastAttemptAt, fixture.epoch);
      final later = fixture.epoch.add(const Duration(minutes: 15));
      expect(
        (await second.reserveReminder(
          fixture.event(later, n: 2),
          later,
        )).decision.bookmark,
        isNotNull,
      );
      gate.complete(DeliveryOutcome.unknown);
    },
  );

  test(
    'unsubmitted reservation survives restart then expires idempotently',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'revisit_reserved_restart_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      final first = BookmarkStore(NativeDatabase(file));
      await first.createBookmark(fixture.sample());
      await first.reserveReminder(fixture.event(fixture.epoch), fixture.epoch);
      await first.close();
      final second = BookmarkStore(NativeDatabase(file));
      addTearDown(second.close);
      expect((await second.readReminderState()).pending, isTrue);
      await second.recoverReminders(fixture.epoch.add(reservationLease));
      await second.recoverReminders(fixture.epoch.add(reservationLease));
      expect(
        await second.reminderOutcome(fixture.event(fixture.epoch).eventId),
        'unknown',
      );
      expect((await second.readReminderState()).pending, isFalse);
      expect(
        (await second.readBookmarks()).single.lastReminderSubmittedAt,
        isNull,
      );
    },
  );

  test('lock retry reevaluates freshness after contention', () async {
    final dir = await Directory.systemTemp.createTemp('revisit_retry_clock_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final owner = BookmarkStore(NativeDatabase.createInBackground(file));
    addTearDown(owner.close);
    await owner.createBookmark(fixture.sample());
    var now = fixture.epoch;
    final release = Completer<void>();
    final locked = Completer<void>();
    late Future<void> holding;
    final contender = _OtherStore(
      NativeDatabase.createInBackground(file),
      writePolicy: SqliteWritePolicy(
        attempts: 2,
        wait: (_) async {
          now = now.add(const Duration(seconds: 31));
          release.complete();
          await holding;
        },
      ),
    );
    addTearDown(contender.close);
    await contender.countBookmarks();
    holding = owner.transaction(() async {
      await owner.customStatement('UPDATE reminder_control SET id=id');
      locked.complete();
      await release.future;
    });
    await locked.future;
    final delivery = _Delivery();
    final result = await ReminderCoordinator(
      contender,
      delivery,
      () => now,
    ).handle(fixture.event(fixture.epoch));
    expect(result.reason, ReminderReason.staleEvent);
    expect(delivery.calls, 0);
    expect((await contender.readReminderState()).eventIds, isEmpty);
    expect((await contender.readReminderState()).lastAttemptAt, isNull);
  });
  for (final outcome in DeliveryOutcome.values) {
    test(
      'in-flight ${outcome.name} releases SQLite and preserves completion',
      () async {
        final db = BookmarkStore(NativeDatabase.memory());
        addTearDown(db.close);
        final id = await db.createBookmark(fixture.sample());
        final delivery = _Delivery()..wait = true;
        final task = ReminderCoordinator(
          db,
          delivery,
          () => fixture.epoch,
        ).handle(fixture.event(fixture.epoch));
        await delivery.started.future;
        expect(await db.completeBookmark(id, fixture.epoch), isTrue);
        expect(
          await db.reminderOutcome(fixture.event(fixture.epoch).eventId),
          'unknown',
        );
        delivery.gate.complete(outcome);
        await task;
        final saved = (await db.readBookmark(id))!;
        expect(saved.status, BookmarkStatus.completed);
        expect(saved.completedAt, fixture.epoch);
        expect(
          saved.lastReminderSubmittedAt,
          outcome == DeliveryOutcome.submitted ? fixture.epoch : null,
        );
        expect(
          await db.reminderOutcome(fixture.event(fixture.epoch).eventId),
          outcome.name,
        );
        expect(delivery.calls, 1);
      },
    );
  }

  test(
    'bounded lock timeout reports busy, preserves state, then recovers',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'revisit_lock_timeout_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      final owner = BookmarkStore(NativeDatabase.createInBackground(file));
      var waits = 0;
      final contender = _OtherStore(
        NativeDatabase.createInBackground(file),
        writePolicy: SqliteWritePolicy(
          attempts: 3,
          wait: (_) async {
            waits++;
          },
        ),
      );
      addTearDown(owner.close);
      addTearDown(contender.close);
      await owner.createBookmark(fixture.sample());
      await contender.countBookmarks();
      final locked = Completer<void>();
      final release = Completer<void>();
      final holding = owner.transaction(() async {
        await owner.customStatement('UPDATE reminder_control SET id=id');
        locked.complete();
        await release.future;
      });
      await locked.future;
      final delivery = _Delivery();
      try {
        final result = await ReminderCoordinator(
          contender,
          delivery,
          () => fixture.epoch,
        ).handle(fixture.event(fixture.epoch));
        expect(result.reason, ReminderReason.storageBusy);
        expect(waits, 2);
        expect(delivery.calls, 0);
      } finally {
        release.complete();
        await holding;
      }
      expect((await contender.readReminderState()).eventIds, isEmpty);
      expect((await contender.readReminderState()).lastAttemptAt, isNull);
      await ReminderCoordinator(
        contender,
        delivery,
        () => fixture.epoch,
      ).handle(fixture.event(fixture.epoch));
      expect(delivery.calls, 1);
      expect(
        await contender.reminderOutcome(fixture.event(fixture.epoch).eventId),
        'submitted',
      );
    },
  );

  test(
    'cleanup retains fresh reserved and unknown records and cooldowns',
    () async {
      final db = BookmarkStore(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.createBookmark(fixture.sample());
      final now = fixture.epoch;
      for (var i = 1; i <= 4; i++) {
        final age = switch (i) {
          1 => const Duration(hours: 25),
          2 => const Duration(minutes: 5),
          _ => const Duration(minutes: 1),
        };
        final event = fixture.event(now.subtract(age), n: i);
        await db.customStatement(
          'INSERT INTO reminder_arrivals(event_id,visit_id,received_at,bookmark_id,outcome) VALUES(?,?,?,?,?)',
          [
            event.eventId,
            event.visitId,
            now.subtract(age).microsecondsSinceEpoch,
            id,
            i == 4 ? 'unknown' : 'reserved',
          ],
        );
      }
      await db.customStatement('UPDATE reminder_control SET last_attempt=?', [
        now.microsecondsSinceEpoch,
      ]);
      await db.recoverReminders(now);
      await db.recoverReminders(now);
      expect(
        await db.reminderOutcome(fixture.event(now, n: 1).eventId),
        isNull,
      );
      expect(
        await db.reminderOutcome(fixture.event(now, n: 2).eventId),
        'unknown',
      );
      expect(
        await db.reminderOutcome(fixture.event(now, n: 3).eventId),
        'reserved',
      );
      expect(
        await db.reminderOutcome(fixture.event(now, n: 4).eventId),
        'unknown',
      );
      expect((await db.readReminderState()).lastAttemptAt, now);
      expect((await db.readBookmark(id))!.title, fixture.sample().title);
    },
  );

  test(
    'wrong context consumes only identity and freshness uses inclusive bounds',
    () async {
      final db = BookmarkStore(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createBookmark(fixture.sample());
      final before = (await db.select(db.bookmarks).getSingle()).toJson();
      final wrong = fixture.event(fixture.epoch, target: 'x');
      await db.reserveReminder(wrong, fixture.epoch);
      expect(await db.reminderOutcome(wrong.eventId), 'consumed');
      expect((await db.readReminderState()).lastAttemptAt, isNull);
      expect((await db.select(db.bookmarks).getSingle()).toJson(), before);
      for (final offset in [-31, -30, 5, 6]) {
        final time = fixture.epoch.add(Duration(seconds: offset));
        final arrival = fixture.event(time, n: offset + 100);
        final decision = evaluateReminder(
          await db.readBookmarks(),
          arrival,
          const ReminderState(),
          fixture.epoch,
        );
        expect(decision.bookmark != null, offset == -30 || offset == 5);
      }
    },
  );

  for (final age in [30, 31]) {
    test('final authorization at age $age seconds', () async {
      final db = _RacingStore();
      addTearDown(db.close);
      await db.createBookmark(fixture.sample());
      var now = fixture.epoch;
      db.afterRead = () async {
        now = now.add(Duration(seconds: age));
      };
      final delivery = _Delivery();
      await ReminderCoordinator(
        db,
        delivery,
        () => now,
      ).handle(fixture.event(fixture.epoch));
      expect(delivery.calls, age == 30 ? 1 : 0);
      expect(
        await db.reminderOutcome(fixture.event(fixture.epoch).eventId),
        age == 30 ? 'submitted' : 'failed',
      );
    });
  }
  for (final action in ['complete', 'snooze', 'delete']) {
    test('$action committed after bookmark read prevents handoff', () async {
      final db = _RacingStore();
      addTearDown(db.close);
      final id = await db.createBookmark(fixture.sample());
      db.afterRead = () async {
        switch (action) {
          case 'complete':
            await db.completeBookmark(id, fixture.epoch);
          case 'snooze':
            await db.snoozeBookmark(
              id,
              const Duration(hours: 1),
              fixture.epoch,
            );
          case 'delete':
            await db.deleteBookmark(id);
        }
      };
      final delivery = _Delivery();
      await ReminderCoordinator(
        db,
        delivery,
        () => fixture.epoch,
      ).handle(fixture.event(fixture.epoch));
      expect(delivery.calls, 0);
      expect(
        await db.reminderOutcome(fixture.event(fixture.epoch).eventId),
        'failed',
      );
      expect((await db.readReminderState()).lastAttemptAt, fixture.epoch);
      final saved = await db.readBookmark(id);
      if (action == 'delete') {
        expect(saved, isNull);
      } else {
        expect(
          saved!.status,
          action == 'complete'
              ? BookmarkStatus.completed
              : BookmarkStatus.snoozed,
        );
        expect(saved.lastReminderSubmittedAt, isNull);
      }
    });
  }

  test('newer schema is rejected without changing data or metadata', () async {
    final dir = await Directory.systemTemp.createTemp('revisit_version_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final original = BookmarkStore(NativeDatabase(file));
    await original.createBookmark(fixture.sample());
    final before = (await original.select(original.bookmarks).getSingle())
        .toJson();
    await original.customStatement('PRAGMA user_version=3');
    await original.close();
    final unsupported = BookmarkStore(NativeDatabase(file));
    await expectLater(unsupported.readBookmarks(), throwsA(isA<StateError>()));
    await unsupported.close();
    final inspection = _Version3Store(NativeDatabase(file));
    addTearDown(inspection.close);
    expect(
      (await inspection.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      3,
    );
    expect(
      (await inspection.select(inspection.bookmarks).getSingle()).toJson(),
      before,
    );
  });

  test(
    '40 arrivals across two connections produce decisions without lock errors',
    () async {
      final dir = await Directory.systemTemp.createTemp('revisit_contention_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      final first = BookmarkStore(NativeDatabase.createInBackground(file));
      final second = _OtherStore(NativeDatabase.createInBackground(file));
      addTearDown(first.close);
      addTearDown(second.close);
      await first.createBookmark(fixture.sample());
      await second.countBookmarks();
      final results = await Future.wait(
        List.generate(
          40,
          (i) => (i.isEven ? first : second).reserveReminder(
            fixture.event(fixture.epoch, n: i + 1),
            fixture.epoch,
          ),
        ),
      );
      expect(results.where((r) => r.decision.bookmark != null), hasLength(1));
      expect((await first.readReminderState()).eventIds, hasLength(40));
    },
  );

  testWidgets('library startup removes old attempts and preserves bookmarks', (
    tester,
  ) async {
    final db = BookmarkStore(NativeDatabase.memory());
    final id = await db.createBookmark(fixture.sample());
    final old = fixture.epoch.subtract(const Duration(hours: 48));
    await db.reserveReminder(fixture.event(old), old);
    await tester.pumpWidget(
      RevisitApp(
        openStore: () => db,
        openLink: (_) async => true,
        clock: () => fixture.epoch,
      ),
    );
    await tester.pumpAndSettle();
    expect((await db.readReminderState()).eventIds, isEmpty);
    expect(
      (await db.readBookmark(id))!.intention.text,
      fixture.sample().intention.text,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test('arrival aging during selection cannot reach handoff', () async {
    final db = _RacingStore();
    addTearDown(db.close);
    await db.createBookmark(fixture.sample());
    var now = fixture.epoch;
    db.duringSelection = () => now = now.add(const Duration(seconds: 31));
    final delivery = _Delivery();
    await ReminderCoordinator(
      db,
      delivery,
      () => now,
    ).handle(fixture.event(fixture.epoch));
    expect(delivery.calls, 0);
    expect((await db.readBookmarks()).single.lastReminderSubmittedAt, isNull);
  });
}

class _RacingStore extends BookmarkStore {
  _RacingStore() : super(NativeDatabase.memory());
  Future<void> Function()? afterRead;
  void Function()? duringSelection;
  @override
  Future<Bookmark?> readBookmark(int id) async {
    final value = await super.readBookmark(id);
    final action = afterRead;
    afterRead = null;
    if (action != null) await action();
    return value;
  }

  @override
  Future<List<Bookmark>> readBookmarks() async {
    final rows = await super.readBookmarks();
    final action = duringSelection;
    duringSelection = null;
    action?.call();
    return rows;
  }
}

class _OtherStore extends BookmarkStore {
  _OtherStore(super.executor, {super.writePolicy});
}

class _GatedReadStore extends BookmarkStore {
  _GatedReadStore(super.executor);
  final readReached = Completer<void>();
  final releaseRead = Completer<void>();
  @override
  Future<Bookmark?> readBookmark(int id) async {
    final value = await super.readBookmark(id);
    if (!readReached.isCompleted) {
      readReached.complete();
      await releaseRead.future;
    }
    return value;
  }
}

class _Version3Store extends BookmarkStore {
  _Version3Store(super.executor);
  @override
  int get schemaVersion => 3;
}

class _Delivery implements ReminderDelivery {
  int calls = 0;
  final gate = Completer<DeliveryOutcome>();
  final started = Completer<void>();
  bool wait = false;
  void Function()? onHandoff;
  @override
  Future<DeliveryOutcome> submit(
    Bookmark bookmark, {
    required DateTime expiresAt,
  }) {
    calls++;
    onHandoff?.call();
    if (!started.isCompleted) started.complete();
    return wait ? gate.future : Future.value(DeliveryOutcome.submitted);
  }
}

class _FailCommitStore extends BookmarkStore {
  _FailCommitStore() : super(NativeDatabase.memory());
  bool failCommit = false;
  @override
  Future<T> writeTransaction<T>(
    Future<T> Function() action, {
    bool Function()? mayRetry,
  }) => super.writeTransaction(() async {
    final result = await action();
    if (failCommit) {
      throw SqliteException(
        extendedResultCode: 5,
        message: 'Injected failure before authorization commit',
      );
    }
    return result;
  }, mayRetry: mayRetry);
}

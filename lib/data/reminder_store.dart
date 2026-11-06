import 'dart:async';

import 'package:drift/drift.dart';

import '../domain/bookmark.dart';
import '../domain/reminders.dart';
import 'bookmark_store.dart';

// Custom tables remain in the same Drift database/transactions. This schema is
// created explicitly on fresh databases and in the version-1 migration.
Future<void> createReminderSchema(BookmarkStore db) async {
  await db.customStatement(
    'CREATE TABLE reminder_control (id INTEGER PRIMARY KEY CHECK(id=1), enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)), paused_until INTEGER, last_attempt INTEGER)',
  );
  await db.customStatement('INSERT INTO reminder_control(id) VALUES(1)');
  await db.customStatement(
    "CREATE TABLE reminder_arrivals (event_id TEXT PRIMARY KEY, visit_id TEXT NOT NULL UNIQUE, received_at INTEGER NOT NULL, bookmark_id INTEGER, outcome TEXT NOT NULL CHECK(outcome IN ('consumed','reserved','submitted','failed','unknown')))",
  );
}

final class ReminderReservation {
  ReminderReservation(this.decision, this.eventId, this.reservedAt);
  final ReminderDecision decision;
  final String eventId;
  final DateTime reservedAt;
}

/// A process-local capability for one handoff, never reconstructed on restart.
final class ReminderHandoff {
  ReminderHandoff._(this.reservation, this.result);
  final ReminderReservation reservation;
  final Future<DeliveryOutcome> result;
  bool _finished = false;
}

extension ReminderStorage on BookmarkStore {
  Future<void> setReminderPreferences({
    required bool enabled,
    DateTime? pausedUntil,
  }) => writeTransaction(() async {
    await customStatement(
      'UPDATE reminder_control SET enabled=?, paused_until=? WHERE id=1',
      [enabled ? 1 : 0, pausedUntil?.toUtc().microsecondsSinceEpoch],
    );
    if (!enabled || pausedUntil != null) {
      await customStatement(
        "UPDATE reminder_arrivals SET outcome='failed' WHERE outcome='reserved'",
      );
    }
  });

  /// Caller includes this in the same transaction as the lifecycle write.
  Future<void> invalidateReminderReservations(int bookmarkId) =>
      customStatement(
        "UPDATE reminder_arrivals SET outcome='failed' WHERE bookmark_id=? AND outcome='reserved'",
        [bookmarkId],
      );

  Future<ReminderState> readReminderState() async {
    final control = await customSelect(
      'SELECT * FROM reminder_control WHERE id=1',
    ).getSingle();
    final arrivals = await customSelect('SELECT * FROM reminder_arrivals')
        .get();
    DateTime? utc(int? value) => value == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
    return ReminderState(
      enabled: control.read<int>('enabled') == 1,
      pausedUntil: utc(control.readNullable<int>('paused_until')),
      lastAttemptAt: utc(control.readNullable<int>('last_attempt')),
      pending: arrivals.any((r) => r.read<String>('outcome') == 'reserved'),
      eventIds: arrivals.map((r) => r.read<String>('event_id')).toSet(),
      visitIds: arrivals.map((r) => r.read<String>('visit_id')).toSet(),
    );
  }

  Future<void> recoverReminders(DateTime now) =>
      writeTransaction(() => _recoverReminders(now));

  Future<void> _recoverReminders(DateTime now) async {
    await customStatement(
      "UPDATE reminder_arrivals SET outcome='unknown' WHERE outcome='reserved' AND received_at<=?",
      [now.subtract(reservationLease).microsecondsSinceEpoch],
    );
    await customStatement('DELETE FROM reminder_arrivals WHERE received_at<?', [
      now.subtract(const Duration(hours: 24)).microsecondsSinceEpoch,
    ]);
  }

  Future<ReminderReservation> reserveReminder(
    ContextArrival? event,
    DateTime now, {
    ReminderClock? clock,
  }) => writeTransaction(() async {
    // Acquire SQLite's write lock before reading eligibility, including when
    // separate database connections receive near-simultaneous arrivals.
    await customStatement('UPDATE reminder_control SET id=id WHERE id=1');
    await _recoverReminders(clock?.call() ?? now);
    final bookmarks = await readBookmarks();
    final state = await readReminderState();
    final selectedAt = clock?.call() ?? now;
    final decision = evaluateReminder(bookmarks, event, state, selectedAt);
    if (event != null &&
        event.fresh(selectedAt) &&
        decision.reason != ReminderReason.duplicateEvent) {
      await customStatement(
        'INSERT INTO reminder_arrivals(event_id,visit_id,received_at,bookmark_id,outcome) VALUES(?,?,?,?,?)',
        [
          event.eventId,
          event.visitId,
          selectedAt.microsecondsSinceEpoch,
          decision.bookmark?.id,
          decision.bookmark == null ? 'consumed' : 'reserved',
        ],
      );
      if (decision.bookmark != null) {
        await customStatement(
          'UPDATE reminder_control SET last_attempt=? WHERE id=1',
          [selectedAt.microsecondsSinceEpoch],
        );
      }
    }
    return ReminderReservation(
      decision,
      event?.eventId ?? '',
      selectedAt.toUtc(),
    );
  });

  Future<ReminderHandoff?> authorizeReminder(
    ReminderReservation reservation,
    ContextArrival event,
    ReminderClock clock,
    Future<DeliveryOutcome> Function(Bookmark, DateTime) handoff,
  ) {
    final callerZone = Zone.current;
    var invoked = false;
    return writeTransaction(() async {
      await customStatement('UPDATE reminder_control SET id=id WHERE id=1');
      await _recoverReminders(clock());
      final id = reservation.decision.bookmark?.id;
      if (id == null) return null;
      final current = await readBookmark(id);
      final settings = await readReminderState();
      final now = clock();
      final expiresAt = reservation.reservedAt.add(reservationLease);
      final valid =
          current != null &&
          current.trigger == event.context &&
          current.status != BookmarkStatus.completed &&
          !(current.status == BookmarkStatus.snoozed &&
              (current.snoozedUntil == null ||
                  current.snoozedUntil!.isAfter(now))) &&
          settings.enabled &&
          !(settings.pausedUntil?.isAfter(now) ?? false) &&
          event.fresh(now) &&
          now.isBefore(expiresAt);
      final claimed = await customUpdate(
        "UPDATE reminder_arrivals SET outcome=? WHERE event_id=? AND received_at=? AND bookmark_id=? AND outcome='reserved'",
        variables: [
          Variable(valid ? 'unknown' : 'failed'),
          Variable(reservation.eventId),
          Variable(reservation.reservedAt.microsecondsSinceEpoch),
          Variable(id),
        ],
      );
      if (!valid || claimed == 0) return null;
      // No await between this last clock check and immediate external handoff.
      final handoffAt = clock();
      if (!event.fresh(handoffAt) || !handoffAt.isBefore(expiresAt)) {
        await customStatement(
          "UPDATE reminder_arrivals SET outcome='failed' WHERE event_id=?",
          [reservation.eventId],
        );
        return null;
      }
      invoked = true;
      Future<DeliveryOutcome> result;
      try {
        // The adapter's async continuation must not inherit Drift's transaction.
        result = callerZone.run(
          () => handoff(current, expiresAt).then(
            (outcome) => outcome,
            onError: (Object _, StackTrace _) => DeliveryOutcome.unknown,
          ),
        );
      } catch (_) {
        result = Future.value(DeliveryOutcome.unknown);
      }
      // Wrap the Future so Drift commits without awaiting OS acknowledgement.
      return ReminderHandoff._(reservation, result);
    }, mayRetry: () => !invoked);
  }

  Future<bool> finishHandoff(
    ReminderHandoff handoff,
    DeliveryOutcome outcome,
    DateTime now,
  ) async {
    if (handoff._finished) return false;
    handoff._finished = true;
    try {
      return await _finishReminder(
        handoff.reservation,
        outcome,
        now,
        'unknown',
      );
    } catch (_) {
      handoff._finished = false;
      rethrow;
    }
  }

  Future<bool> finishReminder(
    ReminderReservation reservation,
    DeliveryOutcome outcome,
    DateTime now,
  ) => _finishReminder(reservation, outcome, now, 'reserved');

  Future<bool> _finishReminder(
    ReminderReservation reservation,
    DeliveryOutcome outcome,
    DateTime now,
    String expected,
  ) => writeTransaction(() async {
    await customStatement('UPDATE reminder_control SET id=id WHERE id=1');
    await _recoverReminders(now);
    if (!now.isBefore(reservation.reservedAt.add(reservationLease))) {
      return false;
    }
    final changed = await customUpdate(
      'UPDATE reminder_arrivals SET outcome=? WHERE event_id=? AND received_at=? AND outcome=?',
      variables: [
        Variable(outcome.name),
        Variable(reservation.eventId),
        Variable(reservation.reservedAt.microsecondsSinceEpoch),
        Variable(expected),
      ],
    );
    if (changed == 0) return false;
    if (outcome == DeliveryOutcome.submitted) {
      final row = await customSelect(
        'SELECT bookmark_id FROM reminder_arrivals WHERE event_id=?',
        variables: [Variable(reservation.eventId)],
      ).getSingle();
      await (update(
        bookmarks,
      )..where((b) => b.id.equals(row.read<int>('bookmark_id')))).write(
        BookmarksCompanion(
          lastReminderSubmittedAt: Value(now.toUtc().microsecondsSinceEpoch),
        ),
      );
    }
    return true;
  });

  Future<String?> reminderOutcome(String eventId) async => (await customSelect(
    'SELECT outcome FROM reminder_arrivals WHERE event_id=?',
    variables: [Variable(eventId)],
  ).getSingleOrNull())?.read<String>('outcome');

  Future<bool> snoozeBookmark(int id, Duration duration, DateTime now) async {
    if (duration != const Duration(hours: 1) &&
        duration != const Duration(hours: 24)) {
      throw ArgumentError('Unsupported snooze duration');
    }
    return writeTransaction(() async {
      final changed =
          await (update(bookmarks)..where(
                (b) =>
                    b.id.equals(id) &
                    b.status.equalsValue(BookmarkStatus.completed).not(),
              ))
              .write(
                BookmarksCompanion(
                  status: const Value(BookmarkStatus.snoozed),
                  snoozedUntil: Value(
                    now.toUtc().add(duration).microsecondsSinceEpoch,
                  ),
                  updatedAt: Value(now.toUtc().microsecondsSinceEpoch),
                ),
              );
      if (changed != 0) await invalidateReminderReservations(id);
      return changed != 0;
    });
  }
}

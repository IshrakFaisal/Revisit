import '../data/bookmark_store.dart';
import '../data/reminder_store.dart';
import '../data/sqlite_write_policy.dart';
import '../domain/bookmark.dart';
import '../domain/reminders.dart';

abstract interface class ReminderDelivery {
  // Initiate handoff synchronously and return promptly. Do not await preparation
  // before initiating, or access the repository here. The caller holds SQLite's
  // write lock only until this method returns its Future, not until it resolves.
  // Honor expiresAt. Exceptions are unknown; success means submission only.
  Future<DeliveryOutcome> submit(
    Bookmark bookmark, {
    required DateTime expiresAt,
  });
}

final class ReminderCoordinator {
  ReminderCoordinator(this.store, this.delivery, this.clock);
  final BookmarkStore store;
  final ReminderDelivery delivery;
  final ReminderClock clock;
  Future<ReminderDecision> handle(ContextArrival? event) async {
    final admittedAt = clock();
    if (event == null) return ReminderDecision(ReminderReason.invalidEvent);
    if (!event.fresh(admittedAt)) {
      return ReminderDecision(ReminderReason.staleEvent);
    }
    try {
      final reservation = await store.reserveReminder(
        event,
        admittedAt,
        clock: clock,
      );
      if (reservation.decision.bookmark == null) return reservation.decision;
      final handoff = await store.authorizeReminder(
        reservation,
        event,
        clock,
        (bookmark, expiresAt) =>
            delivery.submit(bookmark, expiresAt: expiresAt),
      );
      if (handoff == null) return reservation.decision;
      final remaining = reservation.reservedAt
          .add(reservationLease)
          .difference(clock());
      final outcome = await handoff.result.timeout(
        remaining.isNegative ? Duration.zero : remaining,
        onTimeout: () => DeliveryOutcome.unknown,
      );
      await store.finishHandoff(handoff, outcome, clock());
      return reservation.decision;
    } on DatabaseBusyException {
      return ReminderDecision(ReminderReason.storageBusy);
    }
  }
}

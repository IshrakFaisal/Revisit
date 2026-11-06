import 'dart:convert';

import 'bookmark.dart';

typedef ReminderClock = DateTime Function();
const reservationLease = Duration(minutes: 5);

enum ReminderReason {
  eligible,
  invalidEvent,
  staleEvent,
  duplicateEvent,
  disabled,
  paused,
  pendingDelivery,
  globalCooldown,
  wrongContext,
  completed,
  snoozed,
  itemCooldown,
  lowerPriority,
  empty,
  storageBusy,
}

enum DeliveryOutcome { submitted, failed, unknown }

final class ContextArrival {
  ContextArrival._(this.context, this.eventId, this.visitId, this.occurredAt);
  final TriggerContext context;
  final String eventId, visitId;
  final DateTime occurredAt;
  // Authorization and dwell qualification come from the trusted adapter, never
  // from fields claimed by the message itself.
  static ContextArrival? parse(
    Object? value, {
    required bool authorized,
    required bool qualifyingArrival,
  }) {
    if (!authorized || !qualifyingArrival || value is! Map<String, dynamic>) {
      return null;
    }
    try {
      if (utf8.encode(jsonEncode(value)).length > 4096 ||
          value.length != 5 ||
          (value['version'] != 1 && value['version'] != 2)) {
        return null;
      }
      final target = value['target'];
      if (value['version'] == 2 && target == 'github') return null;
      final id = value['eventId'];
      final visit = value['visitId'];
      final time = value['occurredAt'];
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      );
      final context = TriggerContext.values.where(
        (value) => value.name == target,
      );
      if (context.length != 1 ||
          id is! String ||
          visit is! String ||
          !uuid.hasMatch(id) ||
          !uuid.hasMatch(visit) ||
          time is! int) {
        return null;
      }
      return ContextArrival._(
        context.single,
        id,
        visit,
        DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
      );
    } catch (_) {
      return null;
    }
  }

  bool fresh(DateTime now) =>
      !occurredAt.isBefore(now.subtract(const Duration(seconds: 30))) &&
      !occurredAt.isAfter(now.add(const Duration(seconds: 5)));
}

final class ReminderState {
  const ReminderState({
    this.enabled = true,
    this.pausedUntil,
    this.lastAttemptAt,
    this.pending = false,
    this.eventIds = const {},
    this.visitIds = const {},
  });
  final bool enabled, pending;
  final DateTime? pausedUntil, lastAttemptAt;
  final Set<String> eventIds, visitIds;
}

final class ReminderDecision {
  ReminderDecision(
    this.reason, {
    this.bookmark,
    Map<int, ReminderReason> reasons = const {},
  }) : reasons = Map.unmodifiable(reasons);
  final ReminderReason reason;
  final Bookmark? bookmark;
  final Map<int, ReminderReason> reasons;
}

ReminderDecision evaluateReminder(
  List<Bookmark> bookmarks,
  ContextArrival? event,
  ReminderState state,
  DateTime now,
) {
  if (event == null) return ReminderDecision(ReminderReason.invalidEvent);
  if (!event.fresh(now)) return ReminderDecision(ReminderReason.staleEvent);
  if (state.eventIds.contains(event.eventId) ||
      state.visitIds.contains(event.visitId)) {
    return ReminderDecision(ReminderReason.duplicateEvent);
  }
  if (!state.enabled) return ReminderDecision(ReminderReason.disabled);
  if (state.pausedUntil?.isAfter(now) ?? false) {
    return ReminderDecision(ReminderReason.paused);
  }
  if (state.pending) return ReminderDecision(ReminderReason.pendingDelivery);
  if (state.lastAttemptAt != null &&
      now.isBefore(state.lastAttemptAt!.add(const Duration(minutes: 15)))) {
    return ReminderDecision(ReminderReason.globalCooldown);
  }
  final reasons = <int, ReminderReason>{};
  final candidates = <Bookmark>[];
  for (final b in bookmarks) {
    if (b.id == null) continue;
    final reason = b.status == BookmarkStatus.completed
        ? ReminderReason.completed
        : b.trigger != event.context
        ? ReminderReason.wrongContext
        : b.status == BookmarkStatus.snoozed &&
              (b.snoozedUntil == null || b.snoozedUntil!.isAfter(now))
        ? ReminderReason.snoozed
        : b.lastReminderSubmittedAt != null &&
              now.isBefore(
                b.lastReminderSubmittedAt!.add(const Duration(hours: 1)),
              )
        ? ReminderReason.itemCooldown
        : ReminderReason.eligible;
    reasons[b.id!] = reason;
    if (reason == ReminderReason.eligible) candidates.add(b);
  }
  candidates.sort((a, b) {
    var order = b.priority.index.compareTo(a.priority.index);
    if (order != 0) return order;
    final aTime = a.lastReminderSubmittedAt, bTime = b.lastReminderSubmittedAt;
    order = aTime == null
        ? (bTime == null ? 0 : -1)
        : (bTime == null ? 1 : aTime.compareTo(bTime));
    if (order != 0) return order;
    order = a.createdAt.compareTo(b.createdAt);
    return order != 0 ? order : a.id!.compareTo(b.id!);
  });
  for (final b in candidates.skip(1)) {
    reasons[b.id!] = ReminderReason.lowerPriority;
  }
  return ReminderDecision(
    candidates.isEmpty ? ReminderReason.empty : ReminderReason.eligible,
    bookmark: candidates.firstOrNull,
    reasons: reasons,
  );
}

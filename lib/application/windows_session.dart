import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/bookmark_store.dart';
import '../data/reminder_store.dart';
import '../domain/reminders.dart';
import '../domain/browser_capture.dart';
import '../domain/bookmark.dart';
import '../domain/bookmark_url.dart';
import '../platform/windows_reminders.dart';
import 'reminder_coordinator.dart';

/// One owner for the library store session, independent of screen layout.
final class WindowsSession extends ChangeNotifier {
  WindowsSession(
    this.store,
    this.adapter,
    this.clock, {
    this.openBookmark,
    this.openCapture,
  }) : coordinator = ReminderCoordinator(store, adapter, clock);
  final BookmarkStore store;
  final WindowsReminders adapter;
  final ReminderClock clock;
  final ReminderCoordinator coordinator;
  final Future<void> Function(int id)? openBookmark;
  final Future<void> Function(BrowserCapture capture)? openCapture;
  final _captureIds = <String, DateTime>{};
  bool _capturing = false;
  final _activating = <int>{};
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _work = <Future<void>>{};
  Future<void>? _startup;
  Future<void>? _shutdown;
  bool _closed = false;
  String receiver = 'Starting local receiver…';
  String notification = 'Checking notification setup…';
  String processing = 'No Chrome arrival observed this session.';

  Future<void> start() => _startup ??= _start();
  Future<void> _start() async {
    adapter.onBrowserArrival = _browserArrival;
    _subscriptions.add(
      adapter.receiverStatus.listen((status) {
        receiver = status == 'listening'
            ? 'Local receiver listening; this does not confirm Chrome connectivity.'
            : 'Local receiver unavailable. Close other Revisit instances and reopen.';
        _changed();
      }),
    );
    _subscriptions.add(
      adapter.arrivals.listen(
        _dispatch,
        onError: (Object _) {
          processing = 'Context delivery failed. No event will be replayed.';
          _changed();
        },
      ),
    );
    _subscriptions.add(adapter.captures.listen(_captureRequested));
    _subscriptions.add(
      adapter.activations.listen((id) {
        if (_closed || _activating.contains(id) || _activating.length >= 32) {
          return;
        }
        _activating.add(id);
        final task = _activate(id);
        _work.add(task);
        unawaited(task.whenComplete(() => _work.remove(task)));
      }),
    );
    try {
      await adapter.startReceiver();
      if (_closed) return;
      notification = await adapter.registrationAvailable()
          ? 'Notification setup detected; visible delivery is not confirmed.'
          : 'Windows notifications are not configured. See README → Windows integration.';
    } catch (_) {
      notification = 'Windows integration could not initialize. See README → Windows integration.';
    }
    _changed();
  }

  void _dispatch(ContextArrival event) {
    if (_closed) return;
    // Bound admission without queuing behind a potentially slow OS ack.
    if (_work.length >= 32) {
      processing = 'Context processing busy; arrival dropped without replay.';
      _changed();
      return;
    }
    final task = _handle(event);
    _work.add(task);
    unawaited(task.whenComplete(() => _work.remove(task)));
  }

  void _captureRequested(BrowserCapture capture) {
    if (_closed || !capture.fresh(clock())) return;
    final now = clock().toUtc();
    _captureIds.removeWhere(
      (_, receivedAt) =>
          now.difference(receivedAt) > const Duration(minutes: 1),
    );
    if (_captureIds.containsKey(capture.eventId)) return;
    if (_captureIds.length >= 256) _captureIds.remove(_captureIds.keys.first);
    _captureIds[capture.eventId] = now;
    if (_capturing || _work.length >= 32) {
      processing = 'Capture busy. Finish the current draft and try again.';
      _changed();
      return;
    }
    _capturing = true;
    final task = _openCapture(capture);
    _work.add(task);
    unawaited(task.whenComplete(() => _work.remove(task)));
  }

  Future<void> _openCapture(BrowserCapture capture) async {
    try {
      await adapter.showWindow().timeout(const Duration(seconds: 5));
      if (_closed) {
        _capturing = false;
        return;
      }
      final open = openCapture;
      if (open == null) throw StateError('Capture editor unavailable');
      // The route owns its lifetime. A draft must not hold shutdown or storage.
      unawaited(
        open(capture).then(
          (_) {
            _capturing = false;
            processing =
                'Capture draft closed. Saved items are in your library.';
            _changed();
          },
          onError: (Object _) {
            _capturing = false;
            processing = 'Capture draft could not open. Finish the current editor and try again.';
            _changed();
          },
        ),
      );
      processing = 'Review the captured link, intention, priority and trigger before saving.';
    } catch (_) {
      _capturing = false;
      processing = 'Capture draft could not open. Try again from Chrome.';
    }
    _changed();
  }

  Future<void> _activate(int id) async {
    try {
      final bookmark = await store.readBookmark(id);
      if (_closed) return;
      await adapter.showWindow();
      if (_closed) return;
      if (bookmark == null) {
        processing = 'This bookmark is no longer in your library.';
        _activating.remove(id);
      } else if (openBookmark != null) {
        // The view watches the current record, including completion/snooze/delete.
        // Route lifetime must not hold shutdown or the database open.
        unawaited(
          openBookmark!(id).then(
            (_) {
              _activating.remove(id);
            },
            onError: (Object _) {
              _activating.remove(id);
              processing = 'This bookmark could not be opened.';
              _changed();
            },
          ),
        );
      } else {
        _activating.remove(id);
      }
    } catch (_) {
      _activating.remove(id);
      processing =
          'This bookmark could not be opened. Saved items are unchanged.';
    }
    _changed();
  }

  Future<void> _handle(ContextArrival event) async {
    processing =
        'Received ${event.context.name} arrival; evaluating saved items.';
    _changed();
    try {
      final decision = await coordinator.handle(event);
      if (_closed) return;
      if (decision.reason == ReminderReason.storageBusy) {
        processing =
            'Storage busy; processing did not finish. No automatic replay.';
      } else if (decision.bookmark == null) {
        processing =
            'Arrival evaluated: ${decision.reason.name}. No notification requested.';
      } else {
        final outcome = await store.reminderOutcome(event.eventId);
        processing = switch (outcome) {
          'submitted' =>
            'Reminder submitted to Windows for saved item ${decision.bookmark!.id}; visibility is not confirmed.',
          'failed' =>
            'Reminder request failed or was invalidated; saved item retained.',
          _ => 'Reminder outcome uncertain; no automatic replay.',
        };
      }
    } catch (_) {
      processing = 'Reminder processing failed; saved items retained. No automatic replay.';
    }
    _changed();
  }

  Future<String> _browserArrival(ContextArrival event) {
    if (_closed || _work.length >= 32) return Future.value('{"status":"busy"}');
    final response = _offerInBrowser(event);
    final work = response.then<void>((_) {});
    _work.add(work);
    unawaited(work.whenComplete(() => _work.remove(work)));
    return response;
  }

  Future<String> _offerInBrowser(ContextArrival event) async {
    final delivery = _BrowserPromptDelivery(clock);
    try {
      final decision = await ReminderCoordinator(
        store,
        delivery,
        clock,
      ).handle(event);
      if (_closed) return '{"status":"busy"}';
      processing = delivery.offer == null
          ? 'Browser arrival evaluated: ${decision.reason.name}.'
          : 'Saved item offered to the browser.';
      _changed();
      if (decision.reason == ReminderReason.storageBusy) {
        return '{"status":"busy"}';
      }
      return delivery.offer ?? '{"status":"no_reminder"}';
    } catch (_) {
      return '{"status":"busy"}';
    }
  }

  void _changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> close() => _shutdown ??= _close();
  Future<void> _close() async {
    _closed = true;
    adapter.onBrowserArrival = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await adapter.dispose();
    await Future.wait(_work.toList());
    await _startup;
    super.dispose();
  }
}

final class _BrowserPromptDelivery implements ReminderDelivery {
  _BrowserPromptDelivery(this.clock)
    : deadline = clock().add(const Duration(milliseconds: 2500));
  final ReminderClock clock;
  final DateTime deadline;
  String? offer;

  @override
  Future<DeliveryOutcome> submit(
    Bookmark bookmark, {
    required DateTime expiresAt,
  }) {
    try {
      if (!clock().isBefore(deadline) || !clock().isBefore(expiresAt)) {
        return Future.value(DeliveryOutcome.failed);
      }
      final url = BookmarkUrl.parse(bookmark.url).originalText;
      final value = jsonEncode({'status': 'reminder', 'url': url});
      if (utf8.encode(value).length > 4096) {
        return Future.value(DeliveryOutcome.failed);
      }
      offer = value;
      return Future.value(DeliveryOutcome.submitted);
    } on FormatException {
      return Future.value(DeliveryOutcome.failed);
    }
  }
}

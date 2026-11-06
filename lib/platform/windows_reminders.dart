import 'dart:async';

import 'package:flutter/services.dart';

import '../application/reminder_coordinator.dart';
import '../domain/bookmark.dart';
import '../domain/browser_capture.dart';
import '../domain/reminders.dart';

/// Sends a bounded request immediately. Native Windows work runs on a worker;
/// neither this adapter nor that worker accesses the bookmark repository.
final class WindowsReminders implements ReminderDelivery {
  WindowsReminders({
    this.channel = const MethodChannel('revisit/windows'),
    this.clock = DateTime.now,
  }) {
    channel.setMethodCallHandler(_receive);
  }

  final MethodChannel channel;
  final ReminderClock clock;
  final _activations = StreamController<int>.broadcast();
  final _arrivals = StreamController<ContextArrival>.broadcast();
  final _captures = StreamController<BrowserCapture>.broadcast();
  final _receiverStatus = StreamController<String>.broadcast();
  final _pending = <int, Completer<DeliveryOutcome>>{};
  int _sequence = 0;
  bool _closed = false;
  bool _receiverRequested = false;
  Future<void>? _receiverStart;
  Future<void>? _disposal;
  String? currentReceiverStatus;
  Future<String> Function(ContextArrival)? onBrowserArrival;
  Completer<void>? _receiverStopped;

  Stream<int> get activations => _activations.stream;
  Stream<ContextArrival> get arrivals => _arrivals.stream;
  Stream<BrowserCapture> get captures => _captures.stream;
  Stream<String> get receiverStatus => _receiverStatus.stream;
  Future<void> startReceiver() {
    if (_closed) return Future.error(StateError('Adapter closed'));
    _receiverRequested = true;
    return _receiverStart ??= channel.invokeMethod<void>('startReceiver');
  }

  Future<void> showWindow() => channel.invokeMethod<void>('showWindow');

  Future<bool> registrationAvailable() async =>
      await channel.invokeMethod<bool>('notificationRegistration') ?? false;

  @override
  Future<DeliveryOutcome> submit(
    Bookmark bookmark, {
    required DateTime expiresAt,
  }) {
    final remaining = expiresAt.difference(clock());
    if (_closed || bookmark.id == null || remaining <= Duration.zero) {
      return Future.value(DeliveryOutcome.failed);
    }
    if (_pending.isNotEmpty) return Future.value(DeliveryOutcome.failed);
    final request = ++_sequence;
    final result = Completer<DeliveryOutcome>();
    _pending[request] = result;
    // Fixed, bounded payload. No title, URL or intention crosses this boundary.
    // invokeMethod sends immediately; no OS acknowledgement is awaited here.
    try {
      unawaited(
        channel
            .invokeMethod<bool>('submitNotification', {
              'request': request,
              'bookmarkId': bookmark.id,
              'context': bookmark.trigger.name,
              'expiresAt': expiresAt.toUtc().millisecondsSinceEpoch,
            })
            .then(
              (accepted) {
                if (accepted != true) _finish(request, DeliveryOutcome.failed);
              },
              onError: (Object _, StackTrace _) {
                // Channel loss cannot establish whether native handoff occurred.
                _finish(request, DeliveryOutcome.unknown);
              },
            ),
      );
    } catch (_) {
      _finish(request, DeliveryOutcome.unknown);
    }
    final timer = Timer(
      remaining,
      () => _finish(request, DeliveryOutcome.unknown),
    );
    return result.future.whenComplete(timer.cancel);
  }

  Future<Object?> _receive(MethodCall call) async {
    if (call.method == 'receiverStatus' &&
        call.arguments is Map &&
        call.arguments['status'] == 'stopped') {
      if (_receiverStopped case final stopped? when !stopped.isCompleted) {
        stopped.complete();
      }
    }
    if (_closed) return null;
    final data = call.arguments;
    if (data is! Map) return null;
    if (call.method == 'captureRequested') {
      final capture = BrowserCapture.parse(data, clock());
      if (capture != null) _captures.add(capture);
    } else if (call.method == 'contextArrival' ||
        call.method == 'browserArrival') {
      final browser = call.method == 'browserArrival';
      if (data['version'] != (browser ? 2 : 1) ||
          data.keys.any((key) => key is! String)) {
        return null;
      }
      final event = ContextArrival.parse(
        Map<String, dynamic>.from(data),
        authorized: true,
        qualifyingArrival: true,
      );
      if (event != null && event.fresh(clock())) {
        if (browser) return onBrowserArrival?.call(event);
        _arrivals.add(event);
      }
    } else if (call.method == 'receiverStatus') {
      if (['listening', 'unavailable'].contains(data['status'])) {
        currentReceiverStatus = data['status'] as String;
        _receiverStatus.add(data['status'] as String);
      }
    } else if (call.method == 'notificationResult') {
      final request = data['request'];
      final outcome = data['outcome'];
      if (request is! int || outcome is! String) return null;
      final parsed = DeliveryOutcome.values.where((v) => v.name == outcome);
      if (parsed.isNotEmpty) _finish(request, parsed.single);
    } else if (call.method == 'notificationActivated') {
      final id = data['bookmarkId'];
      if (id is int && id > 0) _activations.add(id);
    }
    return null;
  }

  void _finish(int request, DeliveryOutcome outcome) {
    _pending.remove(request)?.complete(outcome);
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _closed = true;
    for (final request in _pending.keys.toList()) {
      _finish(request, DeliveryOutcome.unknown);
    }
    if (_receiverRequested) {
      try {
        _receiverStopped = Completer<void>();
        await channel
            .invokeMethod<void>('stopReceiver')
            .timeout(const Duration(seconds: 5));
        await _receiverStopped!.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        // Process teardown is the final cleanup boundary if native is lost.
      }
    }
    channel.setMethodCallHandler(null);
    await _activations.close();
    await _arrivals.close();
    await _captures.close();
    await _receiverStatus.close();
  }
}

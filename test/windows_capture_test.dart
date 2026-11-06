import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/application/windows_session.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/ui/bookmark_editor.dart';
import 'package:revisit/ui/revisit_app.dart';
import 'package:revisit/ui/windows_integration_status.dart';

const _channel = MethodChannel('revisit/windows');
WindowsSession? _mountedSession;

Future<void> _finishClose(WidgetTester tester, WindowsSession session) async {
  var closed = false;
  unawaited(session.close().then((_) => closed = true));
  for (var i = 0; i < 100 && !closed; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(closed, isTrue);
}

void _captureWidgets(String name, WidgetTesterCallback action) {
  testWidgets(name, (tester) async {
    try {
      await action(tester);
    } finally {
      final session = _mountedSession;
      _mountedSession = null;
      await tester.pumpWidget(const SizedBox());
      if (session != null) await _finishClose(tester, session);
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(null);
    }
  });
}

Future<void> _inbound(String method, Object data) async {
  final completed = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, data)),
        (_) => completed.complete(),
      );
  await completed.future;
}

Map<String, Object> _capture(String source, String url, {int sequence = 1}) => {
  'version': 1,
  'kind': 'capture',
  'url': url,
  'source': source,
  'eventId': '11111111-1111-4111-8111-${sequence.toString().padLeft(12, '0')}',
  'occurredAt': DateTime.now().millisecondsSinceEpoch,
};

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), value);
  await tester.pumpAndSettle();
}

Future<WindowsSession> _mount(WidgetTester tester, BookmarkStore store) async {
  await tester.binding.setSurfaceSize(const Size(1100, 1000));
  await tester.pumpWidget(
    RevisitApp(
      openStore: () => store,
      openLink: (_) async => true,
      enableWindowsIntegration: true,
    ),
  );
  await tester.pumpAndSettle();
  final session = tester
      .widget<WindowsIntegrationStatus>(find.byType(WindowsIntegrationStatus))
      .session;
  _mountedSession = session;
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  var failRestore = false;
  setUp(() {
    calls.clear();
    failRestore = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);
          if (call.method == 'stopReceiver') {
            await _inbound('receiverStatus', {'status': 'stopped'});
          }
          if (call.method == 'showWindow' && failRestore) {
            throw PlatformException(code: 'restore_failed');
          }
          return true;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  for (final item in [
    (
      SourceContext.x,
      'https://x.com/example/status/123',
      TriggerContext.github,
      'GitHub',
    ),
    (
      SourceContext.github,
      'https://github.com/example/project',
      TriggerContext.facebook,
      'Facebook',
    ),
    (
      SourceContext.facebook,
      'https://www.facebook.com/example/posts/123',
      TriggerContext.x,
      'X',
    ),
  ]) {
    _captureWidgets(
      '${item.$1.name} capture requires review and saves independent trigger',
      (tester) async {
        final store = BookmarkStore(NativeDatabase.memory());
        await _mount(tester, store);
        await _inbound('captureRequested', _capture(item.$1.name, item.$2));
        await tester.pumpAndSettle();
        expect(find.byType(BookmarkEditor), findsOneWidget);
        expect(
          tester.widget<TextFormField>(_field('URL')).controller!.text,
          item.$2,
        );
        expect(
          tester.widget<TextFormField>(_field('Title')).controller!.text,
          isEmpty,
        );
        expect(
          tester.widget<TextFormField>(_field('Intention')).controller!.text,
          isEmpty,
        );
        expect(
          tester
              .widget<DropdownButtonFormField<SourceContext>>(
                find.byType(DropdownButtonFormField<SourceContext>),
              )
              .initialValue,
          item.$1,
        );
        expect(
          tester
              .widget<DropdownButtonFormField<TriggerContext>>(
                find.byType(DropdownButtonFormField<TriggerContext>),
              )
              .initialValue,
          isNull,
        );
        expect(await store.countBookmarks(), 0);
        await _tap(tester, find.text('Save bookmark'));
        expect(find.text('Enter a title.'), findsOneWidget);
        expect(find.text('Enter an intention.'), findsOneWidget);
        expect(find.text('Choose a trigger context.'), findsOneWidget);
        expect(await store.countBookmarks(), 0);
        await _enter(tester, 'Title', 'Captured ${item.$1.name}');
        await _enter(
          tester,
          'Intention',
          'Read before returning to the chosen context',
        );
        await _tap(tester, find.byType(DropdownButtonFormField<Priority>));
        await _tap(tester, find.text('High').last);
        await _tap(
          tester,
          find.byType(DropdownButtonFormField<TriggerContext>),
        );
        await _tap(tester, find.text(item.$4).last);
        await _tap(tester, find.text('Save bookmark'));
        final saved = (await store.readBookmarks()).single;
        expect(saved.url, item.$2);
        expect(saved.source, item.$1);
        expect(saved.trigger, item.$3);
        expect(saved.priority, Priority.high);
        expect(
          saved.intention.text,
          'Read before returning to the chosen context',
        );
        expect(find.byType(BookmarkEditor), findsNothing);
        // Another explicit capture uses the normal uniqueness path and preserves
        // the original intention instead of silently overwriting it.
        await _inbound(
          'captureRequested',
          _capture(item.$1.name, item.$2, sequence: 2),
        );
        await tester.pumpAndSettle();
        await _enter(tester, 'Title', 'Duplicate title');
        await _enter(tester, 'Intention', 'Duplicate intention');
        await _tap(
          tester,
          find.byType(DropdownButtonFormField<TriggerContext>),
        );
        await _tap(tester, find.text(item.$4).last);
        await _tap(tester, find.text('Save bookmark'));
        expect(find.text('This link is already saved.'), findsOneWidget);
        expect(await store.countBookmarks(), 1);
        expect(
          (await store.readBookmark(saved.id!))!.intention.text,
          saved.intention.text,
        );
      },
    );
  }

  _captureWidgets('native save persists the same-site reminder by default', (
    tester,
  ) async {
    final store = BookmarkStore(NativeDatabase.memory());
    await _mount(tester, store);
    await _inbound('captureRequested', {
      ..._capture('facebook', 'https://www.facebook.com/example/posts/123'),
      'kind': 'siteSave',
    });
    await tester.pumpAndSettle();
    expect(await store.countBookmarks(), 0);
    expect(
      tester
          .widget<DropdownButtonFormField<TriggerContext>>(
            find.byType(DropdownButtonFormField<TriggerContext>),
          )
          .initialValue,
      TriggerContext.facebook,
    );
    await _enter(tester, 'Title', 'Facebook post');
    await _enter(tester, 'Intention', 'Read when I return');
    await _tap(tester, find.byType(DropdownButtonFormField<Priority>));
    await _tap(tester, find.text('High').last);
    await _tap(tester, find.text('Save bookmark'));
    final bookmark = (await store.readBookmarks()).single;
    expect(bookmark.source, SourceContext.facebook);
    expect(bookmark.trigger, TriggerContext.facebook);
    expect(bookmark.priority, Priority.high);
  });

  _captureWidgets(
    'capture deduplicates events and never overlays an existing draft',
    (tester) async {
      final store = BookmarkStore(NativeDatabase.memory());
      final session = await _mount(tester, store);
      final first = _capture('x', 'https://x.com/first');
      await _inbound('captureRequested', first);
      await tester.pumpAndSettle();
      await _enter(tester, 'Intention', 'Keep this unsaved intention');
      await _inbound('captureRequested', first);
      await _inbound(
        'captureRequested',
        _capture('facebook', 'https://facebook.com/second', sequence: 2),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkEditor), findsOneWidget);
      expect(
        tester.widget<TextFormField>(_field('URL')).controller!.text,
        'https://x.com/first',
      );
      expect(
        tester.widget<TextFormField>(_field('Intention')).controller!.text,
        'Keep this unsaved intention',
      );
      expect(calls.where((method) => method == 'showWindow'), hasLength(1));
      expect(session.processing, contains('Capture busy'));
      expect(await store.countBookmarks(), 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Discard changes'));
      expect(await store.countBookmarks(), 0);
      await _inbound('captureRequested', first);
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkEditor), findsNothing);
    },
  );

  _captureWidgets(
    'manual editor prevents a capture from hiding unsaved changes',
    (tester) async {
      final store = BookmarkStore(NativeDatabase.memory());
      final session = await _mount(tester, store);
      await _tap(tester, find.text('New bookmark'));
      await _enter(tester, 'Intention', 'Keep manual draft');
      await _inbound(
        'captureRequested',
        _capture('github', 'https://github.com/example'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkEditor), findsOneWidget);
      expect(
        tester.widget<TextFormField>(_field('URL')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextFormField>(_field('Intention')).controller!.text,
        'Keep manual draft',
      );
      expect(session.processing, contains('could not open'));
      expect(await store.countBookmarks(), 0);
    },
  );

  _captureWidgets(
    'malformed and stale captures do not restore, open or write',
    (tester) async {
      final store = BookmarkStore(NativeDatabase.memory());
      await _mount(tester, store);
      for (final input in [
        {..._capture('x', 'https://x.com/example'), 'unexpected': 'field'},
        _capture('x', 'https://facebook.com/example'),
        _capture('facebook', 'https://facebook.com.evil.test/example'),
        {
          ..._capture('github', 'https://github.com/example'),
          'occurredAt': DateTime.now()
              .subtract(const Duration(minutes: 1))
              .millisecondsSinceEpoch,
        },
      ]) {
        await _inbound('captureRequested', input);
      }
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkEditor), findsNothing);
      expect(calls, isNot(contains('showWindow')));
      expect(await store.countBookmarks(), 0);
    },
  );

  _captureWidgets(
    'restore and storage failures retain an unsaved capture safely',
    (tester) async {
      final store = _FailingCaptureStore();
      final session = await _mount(tester, store);
      failRestore = true;
      await _inbound(
        'captureRequested',
        _capture('x', 'https://x.com/example'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkEditor), findsNothing);
      expect(session.processing, contains('could not open'));
      expect(await store.countBookmarks(), 0);
      failRestore = false;
      await _inbound(
        'captureRequested',
        _capture('x', 'https://x.com/example', sequence: 2),
      );
      await tester.pumpAndSettle();
      await _enter(tester, 'Title', 'Preserve capture title');
      await _enter(tester, 'Intention', 'Preserve capture intention');
      await _tap(tester, find.byType(DropdownButtonFormField<TriggerContext>));
      await _tap(tester, find.text('Facebook').last);
      await _tap(tester, find.text('Save bookmark'));
      expect(
        find.text('Your bookmark could not be saved. Try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(_field('Intention')).controller!.text,
        'Preserve capture intention',
      );
      expect(await store.countBookmarks(), 0);
    },
  );

  _captureWidgets(
    'capture completion after session closure cannot open or write',
    (tester) async {
      final store = BookmarkStore(NativeDatabase.memory());
      final session = await _mount(tester, store);
      final restored = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method == 'showWindow') await restored.future;
            if (call.method == 'stopReceiver') {
              await _inbound('receiverStatus', {'status': 'stopped'});
            }
            return true;
          });
      await _inbound(
        'captureRequested',
        _capture('github', 'https://github.com/example'),
      );
      await tester.pump();
      unawaited(session.close());
      restored.complete();
      await _finishClose(tester, session);
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkEditor), findsNothing);
      expect(await store.countBookmarks(), 0);
    },
  );
}

class _FailingCaptureStore extends BookmarkStore {
  _FailingCaptureStore() : super(NativeDatabase.memory());
  @override
  Future<int> createBookmark(Bookmark bookmark) =>
      Future.error(StateError('Storage unavailable'));
}

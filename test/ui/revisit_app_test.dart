import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/domain/bookmark_url.dart';
import 'package:revisit/ui/revisit_app.dart';

void main() {
  _testLibraryWidgets('opens the library before showing the real empty state', (
    tester,
  ) async {
    final result = Completer<List<Bookmark>>();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      RevisitApp(
        openStore: () => _WatchStore(() => Stream.fromFuture(result.future)),
        openLink: (_) async => true,
      ),
    );
    expect(find.text('Opening your library'), findsOneWidget);
    expect(find.text('No bookmarks saved'), findsNothing);

    result.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Revisit'), findsOneWidget);
    expect(find.text('No bookmarks saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  _testLibraryWidgets(
    'failed storage open shows an error and retry reads again',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        RevisitApp(
          openStore: () => _WatchStore(() {
            if (++attempts == 1) {
              return Stream.error(StateError('Storage open failed'));
            }
            return Stream.value([
              _bookmark('First', id: 1),
              _bookmark('Second', id: 2),
            ]);
          }),
          openLink: (_) async => true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your library could not be opened'), findsOneWidget);
      expect(find.text('No bookmarks saved'), findsNothing);

      await _tap(tester, find.text('Try again'));
      expect(attempts, 2);
      expect(find.text('2 saved bookmarks'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    },
  );

  _testLibraryWidgets('validates the form and saves a real bookmark', (
    tester,
  ) async {
    final store = BookmarkStore(NativeDatabase.memory());
    final opened = <String>[];
    await _mount(
      tester,
      store,
      openLink: (url) async {
        opened.add(url);
        return true;
      },
    );
    expect(find.text('No bookmarks saved'), findsOneWidget);
    await _tap(tester, find.text('New bookmark').first);
    await _tap(tester, find.text('Save bookmark'));
    expect(find.text('Enter a URL.'), findsOneWidget);
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(find.text('Enter an intention.'), findsOneWidget);
    expect(find.text('Choose a trigger context.'), findsOneWidget);
    expect(await store.countBookmarks(), 0);

    const url = 'https://x.com/example/status/12345';
    await _enter(tester, 'URL', url);
    await _enter(tester, 'Title', 'Authentication architecture');
    await _enter(tester, 'Intention', 'Review before working on login code');
    await _tap(tester, find.byType(DropdownButtonFormField<SourceContext>));
    await _tap(tester, find.text('X').last);
    await _tap(tester, find.byType(DropdownButtonFormField<TriggerContext>));
    await _tap(tester, find.text('GitHub').last);
    await _tap(tester, find.text('Save bookmark'));

    expect(find.text('Bookmark saved.'), findsOneWidget);
    expect(find.text('Authentication architecture'), findsOneWidget);
    expect(find.text('Review before working on login code'), findsOneWidget);
    final saved = (await store.readBookmarks()).single;
    expect(saved.url, url);
    expect(saved.priority, Priority.medium);
    expect(saved.source, SourceContext.x);
    expect(saved.trigger, TriggerContext.github);

    await _tap(tester, find.text('Authentication architecture'));
    await _tap(tester, find.text('Open link'));
    expect(opened, [url]);
  });

  _testLibraryWidgets('edits persisted fields on the original record', (
    tester,
  ) async {
    final store = BookmarkStore(NativeDatabase.memory());
    final original = _bookmark('Old title', priority: Priority.high);
    final id = await store.createBookmark(original);
    await _mount(tester, store);

    await _tap(tester, find.text('Old title'));
    await _tap(tester, find.text('Edit'));
    expect(
      tester.widget<TextFormField>(_field('Title')).controller!.text,
      'Old title',
    );
    expect(
      tester.widget<TextFormField>(_field('Intention')).controller!.text,
      original.intention.text,
    );
    await _enter(tester, 'Title', 'Updated title');
    await _enter(tester, 'Intention', 'Revisit after the design review');
    await _tap(tester, find.byType(DropdownButtonFormField<Priority>));
    await _tap(tester, find.text('Low').last);
    await _tap(tester, find.text('Save changes'));

    expect(find.text('Bookmark updated.'), findsOneWidget);
    expect(find.text('Updated title'), findsWidgets);
    final saved = (await store.readBookmark(id))!;
    expect(saved.id, id);
    expect(saved.title, 'Updated title');
    expect(saved.intention.text, 'Revisit after the design review');
    expect(saved.priority, Priority.low);
    expect(saved.createdAt, original.createdAt);
    expect(saved.updatedAt.isAfter(original.updatedAt), isTrue);
  });

  _testLibraryWidgets('sorts and filters real bookmarks by priority', (
    tester,
  ) async {
    final store = BookmarkStore(NativeDatabase.memory());
    await store.createBookmark(
      _bookmark('Older high', priority: Priority.high),
    );
    await store.createBookmark(
      _bookmark(
        'Newer low',
        priority: Priority.low,
        createdAt: DateTime.utc(2026, 11, 4),
      ),
    );
    await _mount(tester, store);

    final high = find.text('Older high');
    final low = find.text('Newer low');
    expect(tester.getTopLeft(low).dy, lessThan(tester.getTopLeft(high).dy));
    await _tap(tester, find.text('Newest first'));
    await _tap(tester, find.text('Priority first').last);
    expect(tester.getTopLeft(high).dy, lessThan(tester.getTopLeft(low).dy));

    await _tap(tester, find.text('All priorities'));
    await _tap(tester, find.text('High').last);
    expect(high, findsOneWidget);
    expect(low, findsNothing);
    expect(await store.countBookmarks(), 2);
  });

  _testLibraryWidgets('cancels or confirms deletion explicitly', (
    tester,
  ) async {
    final store = BookmarkStore(NativeDatabase.memory());
    final id = await store.createBookmark(_bookmark('Keep until confirmed'));
    await _mount(tester, store);

    await _tap(tester, find.text('Keep until confirmed'));
    await _tap(tester, find.text('Delete'));
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    await _tap(
      tester,
      find.descendant(of: dialog, matching: find.text('Cancel')),
    );
    expect(await store.readBookmark(id), isNotNull);

    await _tap(tester, find.text('Delete'));
    await _tap(
      tester,
      find.descendant(of: dialog, matching: find.text('Delete')),
    );
    expect(await store.readBookmark(id), isNull);
    expect(find.text('No bookmarks saved'), findsOneWidget);
    expect(find.text('Bookmark deleted.'), findsOneWidget);
  });

  _testLibraryWidgets(
    'duplicate save opens the existing bookmark without overwrite',
    (tester) async {
      final store = BookmarkStore(NativeDatabase.memory());
      final original = _bookmark(
        'Original title',
        rawUrl: 'https://example.org/',
      );
      final id = await store.createBookmark(original);
      await _mount(tester, store);

      await _tap(tester, find.text('New bookmark').first);
      await _enter(tester, 'URL', 'HTTPS://EXAMPLE.ORG:443');
      await _enter(tester, 'Title', 'My new draft');
      await _enter(tester, 'Intention', 'Keep this draft');
      await _tap(tester, find.byType(DropdownButtonFormField<TriggerContext>));
      await _tap(tester, find.text('GitHub').last);
      await _tap(tester, find.text('Save bookmark'));

      expect(find.text('This link is already saved.'), findsOneWidget);
      expect(await store.countBookmarks(), 1);
      expect((await store.readBookmark(id))!.title, original.title);
      await _tap(tester, find.text('View existing bookmark'));
      expect(find.text('Original title'), findsWidgets);
      expect(find.text('Edit'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(_field('Title')).controller!.text,
        'My new draft',
      );
    },
  );
  _testLibraryWidgets(
    'failed transaction retains the whole draft and retry saves once',
    (tester) async {
      final gate = Completer<void>();
      final store = _ControlledWriteStore(gate: gate, failNext: true);
      await _mount(tester, store);
      await _tap(tester, find.text('New bookmark'));
      await _enter(tester, 'URL', 'https://example.org/hardening?x=1#notes');
      await _enter(tester, 'Title', 'Read about authentication');
      await _enter(tester, 'Intention', 'Review before changing login 😀');
      await _tap(tester, find.byType(DropdownButtonFormField<Priority>));
      await _tap(tester, find.text('High').last);
      await _tap(tester, find.byType(DropdownButtonFormField<SourceContext>));
      await _tap(tester, find.text('X').last);
      await _tap(tester, find.byType(DropdownButtonFormField<TriggerContext>));
      await _tap(tester, find.text('GitHub').last);

      // Several taps before a rebuild exercise the busy guard as well as the
      // disabled button. The write stays pending until the test releases it.
      final save = find.widgetWithText(FilledButton, 'Save bookmark');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump();
      expect(store.insertCalls, 1);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Discard changes?'), findsNothing);
      expect(_field('Intention'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Your bookmark could not be saved. Try again.'),
        findsOneWidget,
      );
      expect(await store.readBookmarks(), isEmpty);
      expect(
        tester.widget<TextFormField>(_field('URL')).controller!.text,
        'https://example.org/hardening?x=1#notes',
      );
      expect(
        tester.widget<TextFormField>(_field('Title')).controller!.text,
        'Read about authentication',
      );
      expect(
        tester.widget<TextFormField>(_field('Intention')).controller!.text,
        'Review before changing login 😀',
      );
      expect(
        tester
            .widget<DropdownButtonFormField<Priority>>(
              find.byType(DropdownButtonFormField<Priority>),
            )
            .initialValue,
        Priority.high,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<SourceContext>>(
              find.byType(DropdownButtonFormField<SourceContext>),
            )
            .initialValue,
        SourceContext.x,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<TriggerContext>>(
              find.byType(DropdownButtonFormField<TriggerContext>),
            )
            .initialValue,
        TriggerContext.github,
      );

      await _tap(tester, find.text('Save bookmark'));
      expect(find.text('Bookmark saved.'), findsOneWidget);
      expect(store.insertCalls, 2);
      final saved = (await store.readBookmarks()).single;
      expect(saved.title, 'Read about authentication');
      expect(saved.intention.text, 'Review before changing login 😀');
      expect(saved.url, 'https://example.org/hardening?x=1#notes');
      expect(saved.priority, Priority.high);
      expect(saved.source, SourceContext.x);
      expect(saved.trigger, TriggerContext.github);
    },
  );

  for (final outcome in ['success', 'false', 'exception']) {
    _testLibraryWidgets('external open $outcome preserves every stored field', (
      tester,
    ) async {
      final store = BookmarkStore(NativeDatabase.memory());
      final id = await store.createBookmark(_bookmark('External link'));
      final before = (await store.select(store.bookmarks).getSingle()).toJson();
      final targets = <String>[];
      await _mount(
        tester,
        store,
        openLink: (url) async {
          targets.add(url);
          if (outcome == 'exception') {
            throw PlatformException(code: 'no_handler');
          }
          return outcome == 'success';
        },
      );
      await _tap(tester, find.text('External link'));
      await _tap(tester, find.text('Open link'));
      expect(targets, [(await store.readBookmark(id))!.url]);
      expect(
        find.text('Could not open this link. Try again.'),
        outcome == 'success' ? findsNothing : findsOneWidget,
      );
      expect(
        (await store.select(store.bookmarks).getSingle()).toJson(),
        before,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Open link'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  _testLibraryWidgets(
    'keep editing, discard and save protect the existing intention',
    (tester) async {
      final store = BookmarkStore(NativeDatabase.memory());
      final id = await store.createBookmark(_bookmark('Protected draft'));
      final original = (await store.readBookmark(id))!;
      await _mount(tester, store);
      await _tap(tester, find.text('Protected draft'));
      await _tap(tester, find.text('Edit'));
      await _enter(tester, 'Intention', 'Unsaved intention');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await _tap(tester, find.text('Keep editing'));
      expect(
        tester.widget<TextFormField>(_field('Intention')).controller!.text,
        'Unsaved intention',
      );
      expect(
        (await store.readBookmark(id))!.intention.text,
        original.intention.text,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Discard changes'));
      expect(find.text('Edit bookmark'), findsNothing);
      expect(
        (await store.readBookmark(id))!.intention.text,
        original.intention.text,
      );
      await _tap(tester, find.text('Edit'));
      await _enter(tester, 'Intention', 'Saved intention');
      await _tap(tester, find.text('Save changes'));
      expect(find.text('Bookmark updated.'), findsOneWidget);
      expect((await store.readBookmark(id))!.intention.text, 'Saved intention');
    },
  );

  _testLibraryWidgets(
    'back navigation during an edit write waits for the saved result',
    (tester) async {
      final gate = Completer<void>();
      final store = _ControlledWriteStore(updateGate: gate);
      final id = await store.createBookmark(_bookmark('Pending edit'));
      await _mount(tester, store);
      await _tap(tester, find.text('Pending edit'));
      await _tap(tester, find.text('Edit'));
      await _enter(tester, 'Intention', 'Finish writing before leaving');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Edit bookmark'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      expect(store.updateCalls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Bookmark updated.'), findsOneWidget);
      expect(
        (await store.readBookmark(id))!.intention.text,
        'Finish writing before leaving',
      );
      expect(await store.countBookmarks(), 1);
    },
  );

  for (final size in [
    const Size(360, 640),
    const Size(640, 480),
    const Size(1100, 700),
  ]) {
    _testLibraryWidgets(
      'populated flows stay usable at 200 percent text in $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        try {
          final store = BookmarkStore(NativeDatabase.memory());
          final id = await store.createBookmark(
            _bookmark('Accessible bookmark', priority: Priority.high),
          );
          await _mount(tester, store, openLink: (_) async => false);
          await tester.scrollUntilVisible(
            find.text('Accessible bookmark'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await _tap(tester, find.text('Accessible bookmark'));
          await _tap(tester, find.text('Open link'));
          expect(
            find.text('Could not open this link. Try again.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          // Allow the temporary error snackbar to leave before interacting with
          // the controls beneath it on a short desktop window.
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          await _tap(tester, find.text('Delete'));
          expect(find.text('Delete bookmark?'), findsOneWidget);
          await _tap(tester, find.text('Cancel'));
          expect(await store.readBookmark(id), isNotNull);
          await _tap(tester, find.text('Edit'));
          await _enter(tester, 'URL', 'javascript:alert(1)');
          await _tap(tester, find.text('Save changes'));
          expect(
            find.text('Enter a full URL starting with http:// or https://.'),
            findsOneWidget,
          );
          expect(tester.getSemantics(_field('URL')).label, contains('URL'));
          await _enter(tester, 'URL', 'https://example.org/accessible');
          await _enter(tester, 'Intention', 'An accessible edited intention');
          await tester.pageBack();
          await tester.pumpAndSettle();
          await _tap(tester, find.text('Keep editing'));
          await _tap(tester, find.text('Save changes'));
          expect(
            (await store.readBookmark(id))!.intention.text,
            'An accessible edited intention',
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  _testLibraryWidgets('keyboard Tab and Enter open capture and focus URL', (
    tester,
  ) async {
    final store = BookmarkStore(NativeDatabase.memory());
    await _mount(tester, store);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('New bookmark'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // The first focus stop is the editor's Back button; the next is URL.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: _field('URL'),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
  });
  _testLibraryWidgets(
    'snooze write failure preserves state and supports retry',
    (tester) async {
      final store = BookmarkStore(NativeDatabase.memory());
      final id = await store.createBookmark(_bookmark('Retry snooze'));
      await _mount(tester, store);
      await _tap(tester, find.text('Retry snooze'));
      await store.customStatement('PRAGMA query_only=ON');
      await _tap(tester, find.text('Snooze'));
      await _tap(tester, find.text('Snooze 24 hours'));
      expect(
        find.text('Could not snooze the bookmark. Try again.'),
        findsOneWidget,
      );
      expect((await store.readBookmark(id))!.status, BookmarkStatus.active);
      expect((await store.readBookmark(id))!.snoozedUntil, isNull);
      await store.customStatement('PRAGMA query_only=OFF');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Snooze'));
      await _tap(tester, find.text('Snooze 24 hours'));
      final saved = (await store.readBookmark(id))!;
      expect(
        saved.snoozedUntil!.difference(saved.updatedAt),
        const Duration(hours: 24),
      );
      expect(find.textContaining('Snoozed until'), findsOneWidget);
    },
  );
  _testLibraryWidgets('snooze and completion update stored lifecycle', (
    tester,
  ) async {
    final store = BookmarkStore(NativeDatabase.memory());
    final id = await store.createBookmark(_bookmark('Snooze test'));
    await _mount(tester, store);
    await _tap(tester, find.text('Snooze test'));
    await _tap(tester, find.text('Snooze'));
    await _tap(tester, find.text('Snooze 1 hour'));
    final saved = (await store.readBookmark(id))!;
    expect(saved.status, BookmarkStatus.snoozed);
    expect(
      saved.snoozedUntil!.difference(saved.updatedAt),
      const Duration(hours: 1),
    );
    expect(find.textContaining('Snoozed until'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Mark complete'));
    expect((await store.readBookmark(id))!.status, BookmarkStatus.completed);
    expect((await store.readBookmark(id))!.snoozedUntil, isNull);
    expect(find.text('Snooze'), findsNothing);
  });
}

void _testLibraryWidgets(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      // Dispose the app and drain Drift's query stream cleanup before Flutter
      // checks for pending timers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

class _WatchStore extends BookmarkStore {
  _WatchStore(this._watch) : super(NativeDatabase.memory());

  final Stream<List<Bookmark>> Function() _watch;

  @override
  Stream<List<Bookmark>> watchBookmarks() => _watch();
}

Bookmark _bookmark(
  String title, {
  int? id,
  String? rawUrl,
  Priority priority = Priority.medium,
  DateTime? createdAt,
}) {
  final link = BookmarkUrl.parse(
    rawUrl ?? 'https://example.org/${Uri.encodeComponent(title)}',
  );
  final time = createdAt ?? DateTime.utc(2026, 11, 3);
  return Bookmark(
    id: id,
    url: link.originalText,
    canonicalUrl: link.canonicalKey,
    title: title,
    intention: Intention('Read again when the work comes up'),
    source: SourceContext.other,
    trigger: TriggerContext.github,
    createdAt: time,
    updatedAt: time,
    priority: priority,
  );
}

Future<void> _mount(
  WidgetTester tester,
  BookmarkStore store, {
  Future<bool> Function(String)? openLink,
}) async {
  await tester.pumpWidget(
    RevisitApp(openStore: () => store, openLink: openLink ?? (_) async => true),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _enter(WidgetTester tester, String label, String text) async {
  final field = _field(label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// Fail after the insert inside createBookmark's transaction, so SQLite must
// roll back a real write. Gates also make repeated input/navigation deterministic.
class _ControlledWriteStore extends BookmarkStore {
  _ControlledWriteStore({this.gate, this.updateGate, this.failNext = false})
    : super(NativeDatabase.memory());
  final Completer<void>? gate;
  final Completer<void>? updateGate;
  bool failNext;
  int insertCalls = 0;
  int updateCalls = 0;

  @override
  Future<int> insertBookmark(Bookmark bookmark) async {
    insertCalls++;
    if (gate != null) await gate!.future;
    final id = await super.insertBookmark(bookmark);
    if (failNext) {
      failNext = false;
      throw StateError('Injected failure inside the SQLite transaction');
    }
    return id;
  }

  @override
  Future<bool> updateBookmark(Bookmark bookmark) async {
    updateCalls++;
    if (updateGate != null) await updateGate!.future;
    return super.updateBookmark(bookmark);
  }
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/platform/external_links.dart';
import 'package:revisit/ui/revisit_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The normal workflow below is self-contained. These explicit phases allow
  // a host to run two native processes against production app-support storage.
  const phase = String.fromEnvironment('REVISIT_RESTART_PHASE');
  const run = String.fromEnvironment('REVISIT_RESTART_RUN');
  if (phase.isNotEmpty) {
    testWidgets('production process restart: $phase', (tester) async {
      expect(['create', 'verify'], contains(phase));
      expect(run, matches(RegExp(r'^[a-z0-9-]{1,60}$')));
      debugPrint('Revisit lifecycle phase=$phase pid=$pid run=$run');
      final title = 'Restart check $run';
      final url = 'https://example.org/?revisit=$run';
      final store = _WorkflowStore.local();
      await tester.pumpWidget(
        RevisitApp(openStore: () => store, openLink: openExternalLink),
      );
      await tester.pumpAndSettle();
      if (phase == 'create') {
        await _tap(tester, find.text('New bookmark').first);
        await _enter(tester, 'URL', url);
        await _enter(tester, 'Title', title);
        await _enter(
          tester,
          'Intention',
          'Verify persistence after process restart',
        );
        await _tap(
          tester,
          find.byType(DropdownButtonFormField<TriggerContext>),
        );
        await _tap(tester, find.text('GitHub').last);
        await _tap(tester, find.text('Save bookmark'));
        expect(find.text('Bookmark saved.'), findsOneWidget);
      }
      try {
        final persisted = await store.readByCanonicalUrl(url);
        expect(
          persisted,
          isNotNull,
          reason: 'The saved fixture must survive process exit.',
        );
        final record = persisted!;
        expect(record.title, title);
        expect(
          record.intention.text,
          'Verify persistence after process restart',
        );
        expect(record.priority, Priority.medium);
        expect(record.source, SourceContext.other);
        expect(record.trigger, TriggerContext.github);
        expect(record.status, BookmarkStatus.active);
        if (phase == 'verify') {
          await tester.scrollUntilVisible(
            find.text(title),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await _tap(tester, find.text(title));
          expect(find.text('Saved intention'), findsOneWidget);
          await _tap(tester, find.text('Open link'));
          expect(
            find.text('Could not open this link. Try again.'),
            findsNothing,
          );
          // The host separately observes the actual browser process/activity.
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await store.close();
      }
    });
    return;
  }

  testWidgets('creates, edits, reopens, and deletes a bookmark on disk', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'revisit_workflow_',
    );
    final database = File(
      '${directory.path}${Platform.pathSeparator}library.sqlite',
    );
    final stores = <_WorkflowStore>[];
    RevisitApp app() => RevisitApp(
      openStore: () {
        final store = _WorkflowStore(database);
        stores.add(store);
        return store;
      },
      openLink: openExternalLink,
    );

    addTearDown(() async {
      for (final store in stores) {
        await store.close();
      }
      await directory.delete(recursive: true);
    });

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('No bookmarks saved'), findsOneWidget);
    await _tap(tester, find.text('New bookmark').first);
    await _enter(tester, 'URL', 'https://x.com/example/status/12345');
    await _enter(tester, 'Title', 'Review authentication');
    await _enter(tester, 'Intention', 'Read before working on login.');
    await _tap(tester, find.byType(DropdownButtonFormField<SourceContext>));
    await _tap(tester, find.text('X').last);
    await _tap(tester, find.byType(DropdownButtonFormField<TriggerContext>));
    await _tap(tester, find.text('GitHub').last);
    await _tap(tester, find.text('Save bookmark'));
    expect(find.text('Bookmark saved.'), findsOneWidget);
    final created = (await stores.single.readBookmarks()).single;
    expect(created.source, SourceContext.x);
    expect(created.trigger, TriggerContext.github);

    await _tap(tester, find.text('Review authentication').first);
    expect(find.text('Saved intention'), findsOneWidget);
    await _tap(tester, find.text('Edit'));
    await _enter(tester, 'Title', 'Review authentication before release');
    await _enter(tester, 'Intention', 'Check login and session expiry.');
    await _tap(tester, find.text('Save changes'));
    expect(find.text('Bookmark updated.'), findsOneWidget);
    expect(find.text('Check login and session expiry.'), findsWidgets);

    await _tap(tester, find.text('Snooze'));
    await _tap(tester, find.text('Snooze 1 hour'));
    final snoozed = (await stores.single.readBookmarks()).single;
    expect(snoozed.status, BookmarkStatus.snoozed);
    expect(
      snoozed.snoozedUntil!.difference(snoozed.updatedAt),
      const Duration(hours: 1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await stores.single.close();
    expect(await database.exists(), isTrue);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final persisted = (await stores.last.readBookmarks()).single;
    expect(persisted.id, created.id);
    expect(persisted.createdAt, created.createdAt);
    expect(persisted.title, 'Review authentication before release');
    expect(persisted.intention.text, 'Check login and session expiry.');
    expect(persisted.status, BookmarkStatus.snoozed);
    expect(persisted.snoozedUntil, snoozed.snoozedUntil);
    await _tap(tester, find.text(persisted.title).first);
    expect(find.textContaining('Snoozed until'), findsOneWidget);
    await _tap(tester, find.text('Mark complete'));
    expect(
      (await stores.last.readBookmark(created.id!))!.status,
      BookmarkStatus.completed,
    );
    expect((await stores.last.readBookmark(created.id!))!.snoozedUntil, isNull);
    await _tap(tester, find.text('Delete'));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    expect(await stores.last.readBookmark(persisted.id!), isNotNull);
    await _tap(tester, find.text('Delete'));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    expect(find.text('No bookmarks saved'), findsOneWidget);
    expect(await stores.last.readBookmarks(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _WorkflowStore extends BookmarkStore {
  _WorkflowStore(File file) : super(NativeDatabase.createInBackground(file));
  _WorkflowStore.local() : super.local();

  Future<void>? _closing;

  @override
  Future<void> close() => _closing ??= super.close();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

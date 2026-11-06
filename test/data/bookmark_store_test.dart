import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/domain/bookmark.dart';

void main() {
  test(
    'SQLite round-trips Unicode titles and intentions at the limit',
    () async {
      final store = BookmarkStore(NativeDatabase.memory());
      addTearDown(store.close);
      final title = 'é' * 199 + '😀';
      final intention = '😀' * 199 + '界';
      const url = 'https://example.org/unicode';
      final time = DateTime.utc(2026, 11, 4);
      final bookmark = Bookmark(
        url: url,
        canonicalUrl: url,
        title: ' $title ',
        intention: Intention(' $intention '),
        source: SourceContext.other,
        trigger: TriggerContext.github,
        createdAt: time,
        updatedAt: time,
      );

      final id = await store.insertBookmark(bookmark);
      final saved = (await store.readBookmark(id))!;
      expect(saved.title, title);
      expect(saved.intention.text, intention);
    },
  );

  test(
    'SQLite retains a bookmark across connections and rejects duplicates',
    () async {
      final folder = await Directory.systemTemp.createTemp('revisit_test_');
      addTearDown(() => folder.delete(recursive: true));
      final file = File(
        '${folder.path}${Platform.pathSeparator}library.sqlite',
      );
      final time = DateTime.utc(2026, 11, 3, 12, 30, 2, 345, 678);
      final sample = Bookmark(
        url: 'https://example.org/article?topic=review#intro',
        canonicalUrl: 'https://example.org/article?topic=review#intro',
        title: 'Review checklist',
        intention: Intention('Read before reviewing'),
        source: SourceContext.x,
        trigger: TriggerContext.github,
        priority: Priority.high,
        status: BookmarkStatus.completed,
        createdAt: time,
        updatedAt: time,
        completedAt: time,
        lastReminderSubmittedAt: time,
      );

      final writer = BookmarkStore(NativeDatabase(file));
      late final int id;
      try {
        expect(await writer.countBookmarks(), 0);
        id = await writer.insertBookmark(sample);
      } finally {
        await writer.close();
      }

      final reader = BookmarkStore(NativeDatabase(file));
      addTearDown(reader.close);
      final saved = (await reader.readBookmark(id))!;
      expect(saved.id, id);
      expect(saved.url, sample.url);
      expect(saved.canonicalUrl, sample.canonicalUrl);
      expect(saved.title, sample.title);
      expect(saved.intention.text, sample.intention.text);
      expect(saved.source, sample.source);
      expect(saved.trigger, sample.trigger);
      expect(saved.priority, sample.priority);
      expect(saved.status, sample.status);
      expect(saved.createdAt, time);
      expect(saved.updatedAt, time);
      expect(saved.completedAt, time);
      expect(saved.lastReminderSubmittedAt, time);
      expect(saved.snoozedUntil, isNull);
      expect(await reader.readBookmark(id + 1), isNull);
      await expectLater(
        reader.insertBookmark(sample),
        throwsA(isA<SqliteException>()),
      );
      expect(await reader.countBookmarks(), 1);
    },
  );

  test('edits, completion and deletion survive reopening SQLite', () async {
    final folder = await Directory.systemTemp.createTemp('revisit_crud_');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}${Platform.pathSeparator}library.sqlite');
    final original = _bookmark('https://example.org/article');
    final other = _bookmark('https://example.org/other');
    final modified = original.createdAt.add(const Duration(hours: 1));
    final completedAt = modified.add(const Duration(hours: 1));
    final writer = BookmarkStore(NativeDatabase(file));
    late final int id;
    late final int otherId;
    try {
      id = await writer.createBookmark(original);
      otherId = await writer.createBookmark(other);
      expect((await writer.readBookmarks()).map((row) => row.id), [
        otherId,
        id,
      ]);

      expect(
        await writer.updateBookmark(
          Bookmark(
            id: id,
            url: 'https://GITHUB.com/example?tab=readme#notes',
            canonicalUrl: 'https://github.com/example?tab=readme#notes',
            title: 'New title',
            intention: Intention('Read before reviewing'),
            source: SourceContext.github,
            trigger: TriggerContext.x,
            priority: Priority.high,
            createdAt: modified,
            updatedAt: modified,
          ),
        ),
        isTrue,
      );
    } finally {
      await writer.close();
    }

    final reader = BookmarkStore(NativeDatabase(file));
    try {
      final saved = (await reader.readBookmark(id))!;
      expect(saved.id, id);
      expect(saved.url, 'https://GITHUB.com/example?tab=readme#notes');
      expect(saved.canonicalUrl, 'https://github.com/example?tab=readme#notes');
      expect(saved.title, 'New title');
      expect(saved.intention.text, 'Read before reviewing');
      expect(saved.source, SourceContext.github);
      expect(saved.trigger, TriggerContext.x);
      expect(saved.priority, Priority.high);
      expect(saved.createdAt, original.createdAt);
      expect(saved.updatedAt, modified);
      expect(saved.status, BookmarkStatus.snoozed);
      expect(saved.snoozedUntil, original.snoozedUntil);
      expect(saved.lastReminderSubmittedAt, original.lastReminderSubmittedAt);
      expect(await reader.readByCanonicalUrl(original.canonicalUrl), isNull);
      expect((await reader.readByCanonicalUrl(saved.canonicalUrl))!.id, id);

      expect(await reader.completeBookmark(id, completedAt), isTrue);
      expect(await reader.completeBookmark(id, completedAt), isFalse);
      expect(await reader.deleteBookmark(otherId), isTrue);
      expect(await reader.deleteBookmark(otherId), isFalse);
    } finally {
      await reader.close();
    }

    final reopened = BookmarkStore(NativeDatabase(file));
    addTearDown(reopened.close);
    final completed = (await reopened.readBookmarks()).single;
    expect(completed.id, id);
    expect(completed.status, BookmarkStatus.completed);
    expect(completed.completedAt, completedAt);
    expect(completed.updatedAt, completedAt);
    expect(completed.snoozedUntil, isNull);
    expect(completed.lastReminderSubmittedAt, original.lastReminderSubmittedAt);
    expect(await reopened.readBookmark(otherId), isNull);
    expect(await reopened.createBookmark(other), greaterThan(otherId));
  });

  test('concurrent creates preserve one record per canonical URL', () async {
    final folder = await Directory.systemTemp.createTemp('revisit_concurrent_');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}${Platform.pathSeparator}library.sqlite');
    final store = BookmarkStore(
      NativeDatabase.createBackgroundConnection(file),
    );
    addTearDown(store.close);
    const canonical = 'https://example.org/';
    final drafts = [
      _bookmark(
        'HTTPS://EXAMPLE.ORG:443',
        canonical: canonical,
        title: 'First',
      ),
      _bookmark(canonical, title: 'Second'),
    ];
    final outcomes = await Future.wait<Object>(
      drafts.map((draft) async {
        try {
          return await store.createBookmark(draft);
        } on DuplicateBookmarkException catch (error) {
          return error;
        }
      }),
    );

    final id = outcomes.whereType<int>().single;
    final duplicate = outcomes.whereType<DuplicateBookmarkException>().single;
    expect(duplicate.existingId, id);
    final saved = (await store.readBookmarks()).single;
    expect(saved.id, id);
    expect(saved.url, drafts[outcomes.indexOf(id)].url);
    expect(saved.title, drafts[outcomes.indexOf(id)].title);
  });

  test('conflicting edits leave both records intact', () async {
    final store = BookmarkStore(NativeDatabase.memory());
    addTearDown(store.close);
    final first = _bookmark('https://example.org/first', title: 'First');
    final second = _bookmark('https://example.org/second', title: 'Second');
    final firstId = await store.createBookmark(first);
    final secondId = await store.createBookmark(second);

    await expectLater(
      store.updateBookmark(
        _bookmark(second.url, id: firstId, title: 'Conflicting change'),
      ),
      throwsA(
        isA<DuplicateBookmarkException>().having(
          (error) => error.existingId,
          'existingId',
          secondId,
        ),
      ),
    );

    expect(await store.countBookmarks(), 2);
    for (final (id, original) in [(firstId, first), (secondId, second)]) {
      final saved = (await store.readBookmark(id))!;
      expect(saved.title, original.title);
      expect(saved.url, original.url);
      expect(saved.canonicalUrl, original.canonicalUrl);
    }
    expect(
      await store.updateBookmark(
        _bookmark(first.url, id: firstId, title: 'OK'),
      ),
      isTrue,
    );
    expect((await store.readBookmark(firstId))!.title, 'OK');
  });
}

Bookmark _bookmark(String url, {String? canonical, int? id, String? title}) {
  final now = DateTime.utc(2026, 11, 4);
  return Bookmark(
    id: id,
    url: url,
    canonicalUrl: canonical ?? url,
    title: title ?? 'Saved article',
    intention: Intention('Read this later'),
    source: SourceContext.other,
    trigger: TriggerContext.github,
    createdAt: now,
    updatedAt: now,
    status: BookmarkStatus.snoozed,
    snoozedUntil: now.add(const Duration(days: 1)),
    lastReminderSubmittedAt: now,
  );
}

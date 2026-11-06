import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/data/reminder_store.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/domain/reminders.dart';

import 'reminders_test.dart' as fixtures;

SourceContext get facebookSource =>
    SourceContext.values.singleWhere((value) => value.name == 'facebook');
TriggerContext get facebookTrigger =>
    TriggerContext.values.singleWhere((value) => value.name == 'facebook');

Bookmark bookmark({
  int? id,
  SourceContext? source,
  TriggerContext? trigger,
  String path = 'post',
}) => Bookmark(
  id: id,
  url: 'https://www.facebook.com/$path',
  canonicalUrl: 'https://www.facebook.com/$path',
  title: 'Saved Facebook item',
  intention: Intention('Read when the selected context returns'),
  source: source ?? facebookSource,
  trigger: trigger ?? TriggerContext.github,
  priority: Priority.high,
  createdAt: fixtures.epoch,
  updatedAt: fixtures.epoch,
);

void main() {
  test('Facebook arrival is supported only as an exact authorized context', () {
    final wire = {
      'version': 1,
      'target': 'facebook',
      'eventId': '00000000-0000-0000-0000-000000000001',
      'visitId': '10000000-0000-0000-0000-000000000001',
      'occurredAt': fixtures.epoch.millisecondsSinceEpoch,
    };
    final accepted = ContextArrival.parse(
      wire,
      authorized: true,
      qualifyingArrival: true,
    );
    expect(accepted, isNotNull);
    expect(accepted!.context.name, 'facebook');
    for (final target in ['facebook.com.evil', 'Facebook', 'fb']) {
      expect(
        ContextArrival.parse(
          {...wire, 'target': target},
          authorized: true,
          qualifyingArrival: true,
        ),
        isNull,
      );
    }
    expect(
      ContextArrival.parse(wire, authorized: false, qualifyingArrival: true),
      isNull,
    );
  });

  test('Facebook source remains independent from its reminder trigger', () {
    final saved = bookmark(id: 1);
    final github = fixtures.event(fixtures.epoch);
    final facebook = fixtures.event(fixtures.epoch, target: 'facebook');
    expect(
      evaluateReminder(
        [saved],
        github,
        const ReminderState(),
        fixtures.epoch,
      ).bookmark?.id,
      1,
    );
    final wrong = evaluateReminder(
      [saved],
      facebook,
      const ReminderState(),
      fixtures.epoch,
    );
    expect(wrong.bookmark, isNull);
    expect(wrong.reasons[1], ReminderReason.wrongContext);
    final fromX = bookmark(
      id: 2,
      source: SourceContext.x,
      trigger: facebookTrigger,
    );
    expect(
      evaluateReminder(
        [fromX],
        facebook,
        const ReminderState(),
        fixtures.epoch,
      ).bookmark?.id,
      2,
    );
  });

  test(
    'Facebook trigger obeys snooze and completion with real SQLite',
    () async {
      final db = BookmarkStore(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.createBookmark(bookmark(trigger: facebookTrigger));
      await db.snoozeBookmark(id, const Duration(hours: 1), fixtures.epoch);
      final snoozed = (await db.readBookmark(id))!;
      final before = evaluateReminder(
        [snoozed],
        fixtures.event(fixtures.epoch, target: 'facebook'),
        const ReminderState(),
        fixtures.epoch,
      );
      expect(before.bookmark, isNull);
      expect(before.reasons[id], ReminderReason.snoozed);
      final expiry = fixtures.epoch.add(const Duration(hours: 1));
      expect(
        evaluateReminder(
          [snoozed],
          fixtures.event(expiry, target: 'facebook'),
          const ReminderState(),
          expiry,
        ).bookmark?.id,
        id,
      );
      await db.completeBookmark(id, expiry);
      final completed = (await db.readBookmark(id))!;
      expect(completed.status, BookmarkStatus.completed);
      expect(
        evaluateReminder(
          [completed],
          fixtures.event(expiry, target: 'facebook'),
          const ReminderState(),
          expiry,
        ).reasons[id],
        ReminderReason.completed,
      );
    },
  );

  test(
    'Facebook and existing contexts survive restart without schema changes',
    () async {
      final supportedFacebook = facebookTrigger;
      final directory = await Directory.systemTemp.createTemp(
        'revisit_facebook_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/library.sqlite');
      final writer = BookmarkStore(NativeDatabase(file));
      final oldX = await writer.createBookmark(
        bookmark(source: SourceContext.x, path: 'old-x'),
      );
      final oldGithub = await writer.createBookmark(
        bookmark(
          source: SourceContext.github,
          trigger: TriggerContext.x,
          path: 'old-github',
        ),
      );
      final id = await writer.createBookmark(
        bookmark(trigger: supportedFacebook),
      );
      final schemaSql =
          (await writer
                  .customSelect(
                    "SELECT sql FROM sqlite_master WHERE name='bookmarks'",
                  )
                  .getSingle())
              .read<String>('sql');
      expect(schemaSql.toUpperCase(), isNot(contains('CHECK')));
      await writer.close();
      final reader = BookmarkStore(NativeDatabase(file));
      addTearDown(reader.close);
      final saved = (await reader.readBookmark(id))!;
      expect(saved.source, facebookSource);
      expect(saved.trigger, facebookTrigger);
      expect(saved.priority, Priority.high);
      expect(saved.intention.text, bookmark().intention.text);
      expect((await reader.readBookmark(oldX))!.source, SourceContext.x);
      expect(
        (await reader.readBookmark(oldGithub))!.source,
        SourceContext.github,
      );
      expect((await reader.readBookmark(oldGithub))!.trigger, TriggerContext.x);
      expect(reader.schemaVersion, 2);
      expect(
        (await reader.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        2,
      );
      await expectLater(
        reader.createBookmark(bookmark(trigger: facebookTrigger)),
        throwsA(isA<DuplicateBookmarkException>()),
      );
      expect(await reader.countBookmarks(), 3);
    },
  );
}

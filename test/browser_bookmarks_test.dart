import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/application/browser_bookmarks.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/data/reminder_store.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/domain/browser_query.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7);
  Map<String, Object> wire(String kind, String cursor, {String target = 'x'}) =>
      {
        'version': 1,
        'kind': kind,
        'target': target,
        'cursor': cursor,
        'eventId': '01234567-89ab-cdef-0123-456789abcdef',
        'occurredAt': now.millisecondsSinceEpoch,
      };
  test('browser queries reject malformed, stale and wrong-site inputs', () {
    for (final value in [
      {...wire('list', ''), 'extra': 1},
      wire('list', '3:1'),
      wire('open', ''),
      wire('list', '0:'),
      wire('list', '', target: 'github'),
      {...wire('list', ''), 'eventId': 'invalid'},
      {...wire('list', ''), 'occurredAt': now.millisecondsSinceEpoch - 30001},
      {...wire('list', ''), 'occurredAt': now.millisecondsSinceEpoch + 5001},
    ]) {
      expect(BrowserQuery.parse(value, now), isNull);
    }
    expect(BrowserQuery.parse(wire('list', '0:12'), now), isNotNull);
    expect(BrowserQuery.parse(wire('open', '12'), now), isNotNull);
  });

  test('chooser lists every matching active item by priority across bounded pages and revalidates opens', () async {
    final db = BookmarkStore(NativeDatabase.memory());
    addTearDown(db.close);
    Future<int> add(
      int n,
      Priority priority, {
      TriggerContext trigger = TriggerContext.x,
      BookmarkStatus status = BookmarkStatus.active,
      DateTime? snoozedUntil,
    }) => db.createBookmark(
      Bookmark(
        url: 'https://x.com/person/status/$n',
        canonicalUrl: 'https://x.com/person/status/$n',
        title: '${'😀' * 190} $n',
        intention: Intention('Intention stays private'),
        source: SourceContext.other,
        trigger: trigger,
        priority: priority,
        status: status,
        createdAt: now,
        updatedAt: now,
        snoozedUntil: snoozedUntil,
        lastReminderSubmittedAt:
            now, // Manual browsing must not hide recently reminded items.
      ),
    );
    final low = await add(1, Priority.low);
    final high = await add(2, Priority.high);
    final medium = await add(3, Priority.medium);
    final remaining = <int>[];
    for (var n = 4; n < 18; n++) {
      remaining.add(await add(n, Priority.medium));
    }
    final other = await add(
      50,
      Priority.high,
      trigger: TriggerContext.facebook,
    );
    await add(51, Priority.high, status: BookmarkStatus.completed);
    await add(
      52,
      Priority.high,
      status: BookmarkStatus.snoozed,
      snoozedUntil: now.add(const Duration(hours: 1)),
    );
    final expired = await add(
      53,
      Priority.low,
      status: BookmarkStatus.snoozed,
      snoozedUntil: now,
    );
    Future<Map<String, dynamic>> query(
      String kind,
      String cursor, {
      String target = 'x',
    }) async => jsonDecode(
      await browserBookmarks(
        db,
        BrowserQuery.parse(wire(kind, cursor, target: target), now)!,
        now,
      ),
    ) as Map<String, dynamic>;
    final ids = <int>[];
    String? cursor = '';
    var pages = 0;
    do {
      final response = await query('list', cursor!);
      expect(utf8.encode(jsonEncode(response)).length, lessThanOrEqualTo(4096));
      expect(jsonEncode(response), isNot(contains('Intention stays private')));
      expect(jsonEncode(response), isNot(contains('https://')));
      ids.addAll((response['items'] as List).map((i) => i['id'] as int));
      cursor = response['cursor'] as String?;
      expect(++pages, lessThan(20));
    } while (cursor != null);
    expect(pages, greaterThan(1));
    expect(ids, [high, medium, ...remaining, low, expired]);
    expect((await db.readReminderState()).lastAttemptAt, isNull);
    expect(await query('open', '$high'), {
      'status': 'open',
      'url': 'https://x.com/person/status/2',
    });
    expect(await query('open', '$other'), {'status': 'unavailable'});
    await db.completeBookmark(high, now);
    expect(await query('open', '$high'), {'status': 'unavailable'});
    await db.deleteBookmark(low);
    expect(await query('open', '$low'), {'status': 'unavailable'});
  });
}

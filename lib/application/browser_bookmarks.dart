import 'dart:convert';

import '../data/bookmark_store.dart';
import '../domain/bookmark.dart';
import '../domain/bookmark_url.dart';
import '../domain/browser_query.dart';

/// User-requested browsing never consumes an arrival or resets a cooldown.
Future<String> browserBookmarks(
  BookmarkStore store,
  BrowserQuery query,
  DateTime now,
) async {
  bool visible(Bookmark b) =>
      b.trigger == query.context &&
      b.status != BookmarkStatus.completed &&
      !(b.snoozedUntil?.isAfter(now) ?? false);
  if (query.kind == 'open') {
    final bookmark = await store.readBookmark(int.parse(query.cursor));
    if (bookmark == null || !visible(bookmark)) {
      return '{"status":"unavailable"}';
    }
    final reply = jsonEncode({
      'status': 'open',
      'url': BookmarkUrl.parse(bookmark.url).originalText,
    });
    return utf8.encode(reply).length <= 4096 ? reply : '{"status":"too_large"}';
  }
  int rank(Bookmark b) => 2 - b.priority.index;
  final after = query.cursor.isEmpty
      ? null
      : query.cursor.split(':').map(int.parse).toList();
  final bookmarks =
      (await store.readBookmarks())
          .where(visible)
          .where(
            (b) =>
                after == null ||
                rank(b) > after[0] ||
                (rank(b) == after[0] && b.id! > after[1]),
          )
          .toList()
        ..sort(
          (a, b) => rank(a) != rank(b)
              ? rank(a).compareTo(rank(b))
              : a.id!.compareTo(b.id!),
        );
  final items = <Map<String, Object>>[];
  String? cursor;
  for (final bookmark in bookmarks) {
    final item = <String, Object>{
      'id': bookmark.id!,
      'title': bookmark.title,
      'priority': bookmark.priority.name,
    };
    final candidate = jsonEncode({
      'status': 'bookmarks',
      'items': [...items, item],
      'cursor': '${rank(bookmark)}:${bookmark.id}',
    });
    if (utf8.encode(candidate).length > 3900) break;
    items.add(item);
    cursor = '${rank(bookmark)}:${bookmark.id}';
  }
  return jsonEncode({
    'status': 'bookmarks',
    'items': items,
    'cursor': items.length < bookmarks.length ? cursor : null,
  });
}

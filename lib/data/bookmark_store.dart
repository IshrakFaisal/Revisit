import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:revisit/domain/bookmark.dart';

import 'reminder_store.dart';
import 'sqlite_write_policy.dart';

part 'bookmark_store.g.dart';

@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text()();
  TextColumn get canonicalUrl => text().unique()();
  // Bookmark and Intention enforce the limit in Unicode code points.
  TextColumn get title => text()();
  TextColumn get intention => text()();
  TextColumn get source => textEnum<SourceContext>()();
  TextColumn get trigger => textEnum<TriggerContext>()();
  TextColumn get priority => textEnum<Priority>()();
  TextColumn get status => textEnum<BookmarkStatus>()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get snoozedUntil => integer().nullable()();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get lastReminderSubmittedAt => integer().nullable()();
}

final class DuplicateBookmarkException implements Exception {
  const DuplicateBookmarkException(this.existingId);

  final int existingId;
}

@DriftDatabase(tables: [Bookmarks])
class BookmarkStore extends _$BookmarkStore {
  BookmarkStore(super.executor, {this.writePolicy = const SqliteWritePolicy()});

  final SqliteWritePolicy writePolicy;

  Future<T> writeTransaction<T>(
    Future<T> Function() action, {
    bool Function()? mayRetry,
  }) => writePolicy.run(() => transaction(action), mayRetry: mayRetry);

  BookmarkStore.local()
    : this(
        driftDatabase(
          name: 'revisit',
          native: const DriftNativeOptions(
            databaseDirectory: getApplicationSupportDirectory,
          ),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => transaction(() async {
      await m.createAll();
      await createReminderSchema(this);
      await customStatement('PRAGMA user_version=2');
    }),
    onUpgrade: (m, from, to) {
      if (from > to) {
        throw StateError(
          'Database version $from is newer than supported version $to.',
        );
      }
      return transaction(() async {
        if (from < 2) await createReminderSchema(this);
        // Commit the version with the schema, including across process loss.
        await customStatement('PRAGMA user_version=2');
      });
    },
  );

  Future<int> countBookmarks() => bookmarks.count().getSingle();

  Future<int> createBookmark(Bookmark bookmark) => _withDuplicateCheck(
    bookmark.canonicalUrl,
    () => insertBookmark(bookmark),
  );

  // SQLite assigns the ID. A unique constraint rejects duplicate canonical URLs.
  Future<int> insertBookmark(Bookmark bookmark) async {
    if (bookmark.id != null) {
      throw ArgumentError('Only new bookmarks can be inserted.');
    }
    return into(bookmarks).insert(
      BookmarksCompanion.insert(
        url: bookmark.url,
        canonicalUrl: bookmark.canonicalUrl,
        title: bookmark.title,
        intention: bookmark.intention.text,
        source: bookmark.source,
        trigger: bookmark.trigger,
        priority: bookmark.priority,
        status: bookmark.status,
        createdAt: bookmark.createdAt.microsecondsSinceEpoch,
        updatedAt: bookmark.updatedAt.microsecondsSinceEpoch,
        snoozedUntil: Value(bookmark.snoozedUntil?.microsecondsSinceEpoch),
        completedAt: Value(bookmark.completedAt?.microsecondsSinceEpoch),
        lastReminderSubmittedAt: Value(
          bookmark.lastReminderSubmittedAt?.microsecondsSinceEpoch,
        ),
      ),
    );
  }

  Future<Bookmark?> readBookmark(int id) => _bookmarkById(id).getSingleOrNull();

  Stream<Bookmark?> watchBookmark(int id) =>
      _bookmarkById(id).watchSingleOrNull();

  Selectable<Bookmark> _bookmarkById(int id) =>
      (select(bookmarks)..where((row) => row.id.equals(id))).map(_toBookmark);

  Future<List<Bookmark>> readBookmarks() => _bookmarksNewestFirst().get();

  Stream<List<Bookmark>> watchBookmarks() => _bookmarksNewestFirst().watch();

  Selectable<Bookmark> _bookmarksNewestFirst() =>
      (select(bookmarks)..orderBy([
            (row) => OrderingTerm.desc(row.createdAt),
            (row) => OrderingTerm.desc(row.id),
          ]))
          .map(_toBookmark);

  Future<Bookmark?> readByCanonicalUrl(String canonicalUrl) async {
    final row = await _readRowByCanonicalUrl(canonicalUrl);
    return row == null ? null : _toBookmark(row);
  }

  Future<bool> updateBookmark(Bookmark bookmark) async {
    final id = bookmark.id;
    if (id == null) {
      throw ArgumentError('Only saved bookmarks can be updated.');
    }
    return _withDuplicateCheck(bookmark.canonicalUrl, () async {
      final changed =
          await (update(bookmarks)..where((row) => row.id.equals(id))).write(
            BookmarksCompanion(
              url: Value(bookmark.url),
              canonicalUrl: Value(bookmark.canonicalUrl),
              title: Value(bookmark.title),
              intention: Value(bookmark.intention.text),
              source: Value(bookmark.source),
              trigger: Value(bookmark.trigger),
              priority: Value(bookmark.priority),
              updatedAt: Value(bookmark.updatedAt.microsecondsSinceEpoch),
            ),
          );
      if (changed != 0) await invalidateReminderReservations(id);
      return changed != 0;
    });
  }

  Future<bool> deleteBookmark(int id) => writeTransaction(() async {
    final changed = await (delete(
      bookmarks,
    )..where((row) => row.id.equals(id))).go();
    if (changed != 0) await invalidateReminderReservations(id);
    return changed != 0;
  });

  Future<bool> completeBookmark(int id, DateTime now) =>
      writeTransaction(() async {
        final timestamp = now.microsecondsSinceEpoch;
        final changed =
            await (update(bookmarks)..where(
                  (row) =>
                      row.id.equals(id) &
                      row.status.equalsValue(BookmarkStatus.completed).not(),
                ))
                .write(
                  BookmarksCompanion(
                    status: const Value(BookmarkStatus.completed),
                    completedAt: Value(timestamp),
                    snoozedUntil: const Value(null),
                    updatedAt: Value(timestamp),
                  ),
                );
        if (changed != 0) await invalidateReminderReservations(id);
        return changed != 0;
      });

  Future<BookmarkRow?> _readRowByCanonicalUrl(String canonicalUrl) => (select(
    bookmarks,
  )..where((row) => row.canonicalUrl.equals(canonicalUrl))).getSingleOrNull();

  Future<T> _withDuplicateCheck<T>(
    String canonicalUrl,
    Future<T> Function() write,
  ) => writeTransaction(() async {
    try {
      return await write();
    } on Exception catch (error) {
      final cause = error is DriftRemoteException ? error.remoteCause : error;
      const sqliteConstraintUnique = 2067;
      if (cause is! SqliteException ||
          cause.extendedResultCode != sqliteConstraintUnique) {
        rethrow;
      }
      final existing = await _readRowByCanonicalUrl(canonicalUrl);
      if (existing == null) rethrow;
      throw DuplicateBookmarkException(existing.id);
    }
  });

  static Bookmark _toBookmark(BookmarkRow row) => Bookmark(
    id: row.id,
    url: row.url,
    canonicalUrl: row.canonicalUrl,
    title: row.title,
    intention: Intention(row.intention),
    source: row.source,
    trigger: row.trigger,
    priority: row.priority,
    status: row.status,
    createdAt: _utc(row.createdAt),
    updatedAt: _utc(row.updatedAt),
    snoozedUntil: _optionalUtc(row.snoozedUntil),
    completedAt: _optionalUtc(row.completedAt),
    lastReminderSubmittedAt: _optionalUtc(row.lastReminderSubmittedAt),
  );

  static DateTime _utc(int time) =>
      DateTime.fromMicrosecondsSinceEpoch(time, isUtc: true);

  static DateTime? _optionalUtc(int? time) => time == null ? null : _utc(time);
}

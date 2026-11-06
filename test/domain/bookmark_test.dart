import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/domain/bookmark.dart';

void main() {
  test('intention trims input and validates its character limit', () {
    expect(
      Intention('  Read before reviewing  ').text,
      'Read before reviewing',
    );
    expect(Intention('a' * 200).text.length, 200);
    expect(() => Intention('a' * 201), throwsArgumentError);
    expect(() => Intention(' \n '), throwsArgumentError);
  });

  test('title and intention reject more than 200 Unicode code points', () {
    final overLimit = '😀' * 200 + 'é';
    final date = DateTime.utc(2026, 11, 4);
    const url = 'https://example.org/unicode';

    expect(() => Intention(overLimit), throwsArgumentError);
    expect(
      () => Bookmark(
        title: overLimit,
        url: url,
        canonicalUrl: url,
        intention: Intention('Read later'),
        source: SourceContext.other,
        trigger: TriggerContext.github,
        createdAt: date,
        updatedAt: date,
      ),
      throwsArgumentError,
    );
  });

  test('a bookmark preserves distinct contexts and normalizes timestamps', () {
    final date = DateTime(2026, 11, 3, 10);
    const url = 'https://example.org/article';
    final bookmark = Bookmark(
      title: ' Article ',
      url: url,
      canonicalUrl: url,
      intention: Intention('Read before reviewing'),
      source: SourceContext.x,
      trigger: TriggerContext.github,
      createdAt: date,
      updatedAt: date,
    );

    expect(bookmark.title, 'Article');
    expect(bookmark.priority, Priority.medium);
    expect(bookmark.status, BookmarkStatus.active);
    expect(bookmark.source, SourceContext.x);
    expect(bookmark.trigger, TriggerContext.github);
    expect(bookmark.createdAt, date.toUtc());
    expect(bookmark.createdAt.isUtc, isTrue);
  });
}

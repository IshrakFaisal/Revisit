import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/domain/browser_capture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 12);
  Map<String, Object> payload({
    String url = 'https://x.com/example/status/123',
    String source = 'x',
    int? occurredAt,
  }) => {
    'version': 1,
    'kind': 'capture',
    'url': url,
    'source': source,
    'eventId': '11111111-1111-4111-8111-111111111111',
    'occurredAt': occurredAt ?? now.millisecondsSinceEpoch,
  };

  test('capture accepts only the explicit source host aliases', () {
    const sites = {
      'x': [
        'x.com',
        'www.x.com',
        'twitter.com',
        'www.twitter.com',
        'mobile.twitter.com',
      ],
      'facebook': [
        'facebook.com',
        'www.facebook.com',
        'm.facebook.com',
        'mbasic.facebook.com',
      ],
      'github': ['github.com', 'www.github.com', 'gist.github.com'],
    };
    for (final site in sites.entries) {
      for (final host in site.value) {
        final url = 'https://$host/example?ref=123#saved';
        final capture = BrowserCapture.parse(
          payload(url: url, source: site.key),
          now,
        );
        expect(capture, isNotNull, reason: host);
        expect(capture!.source.name, site.key);
        expect(capture.url, url);
      }
    }
  });

  test('confirmed native save suggests only the same social trigger', () {
    expect(BrowserCapture.parse(payload(), now)?.suggestedTrigger, isNull);
    for (final (source, url) in [
      ('x', 'https://x.com/example/status/123'),
      ('facebook', 'https://www.facebook.com/example/posts/123'),
    ]) {
      final capture = BrowserCapture.parse({
        ...payload(source: source, url: url),
        'kind': 'siteSave',
      }, now);
      expect(capture?.suggestedTrigger?.name, source);
    }
    expect(
      BrowserCapture.parse({
        ...payload(source: 'github', url: 'https://github.com/example/repo'),
        'kind': 'siteSave',
      }, now),
      isNull,
    );
  });

  test(
    'capture freshness uses inclusive 30 second and future 5 second limits',
    () {
      for (final age in [-5000, 0, 30000]) {
        final data = payload(occurredAt: now.millisecondsSinceEpoch - age);
        final capture = BrowserCapture.parse(data, now);
        expect(capture, isNotNull);
        expect(capture!.fresh(now), isTrue);
      }
      for (final age in [-5001, 30001]) {
        expect(
          BrowserCapture.parse(
            payload(occurredAt: now.millisecondsSinceEpoch - age),
            now,
          ),
          isNull,
        );
      }
    },
  );

  test(
    'capture rejects malformed, oversized, wrong-source and unsafe inputs',
    () {
      final invalid = <Object?>[
        null,
        'capture',
        {...payload(), 'version': 1.0},
        {...payload(), 'kind': 'arrival'},
        {...payload(), 'unexpected': 'value'},
        {...payload()}..remove('kind'),
        {...payload(), 'occurredAt': now.millisecondsSinceEpoch.toDouble()},
        {...payload(), 'eventId': 'arbitrary'},
        {...payload(), 'eventId': 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'},
        payload(source: 'facebook'),
        payload(source: 'other'),
        for (final url in [
          'http://x.com/example',
          'HTTPS://x.com/example',
          'https://X.COM/example',
          'https://x.com:443/example',
          'https://x.com:8443/example',
          'https://x.com.evil.test/example',
          'https://user@x.com/example',
          'https://x.com/%zz',
          'https://x.com/emoji/😀',
          'https://x.com/has space',
          'https://x.com/\nheader',
          'https://x.com\\evil.test/example',
          'https://example.org/',
          'https://x.com/${'a' * 3072}',
          'https://x.com/${'"' * 3000}',
        ])
          payload(url: url),
      ];
      for (var i = 0; i < invalid.length; i++) {
        expect(
          BrowserCapture.parse(invalid[i], now),
          isNull,
          reason: 'case $i',
        );
      }
      final boundary =
          'https://x.com/${'a' * (3072 - 'https://x.com/'.length)}';
      expect(BrowserCapture.parse(payload(url: boundary), now), isNotNull);
    },
  );
}

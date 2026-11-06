import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/domain/bookmark_url.dart';

void main() {
  test('keeps the entered URL and normalizes only address structure', () {
    const text = 'HTTPS://WWW.Example.org:0443?item=%2f&item=A#Section';
    final url = BookmarkUrl.parse('  $text\r\n');
    expect(url.originalText, text);
    expect(url.host, 'www.example.org');
    expect(
      url.canonicalKey,
      'https://www.example.org/?item=%2f&item=A#Section',
    );
    expect(
      url.canonicalKey,
      BookmarkUrl.parse('https://www.example.org/?item=%2f&item=A#Section')
          .canonicalKey,
    );
    expect(
      BookmarkUrl.parse('HTTP://Example.org:80').canonicalKey,
      'http://example.org/',
    );
  });

  test('supports a host, decimal IPv4, bracketed IPv6 and explicit ports', () {
    const supported = {
      'http://localhost:008080': 'http://localhost:8080/',
      'http://192.168.1.12/a': 'http://192.168.1.12/a',
      'https://[2001:DB8::1]:443': 'https://[2001:db8::1]/',
      'https://XN--BCHER-KVA.Example/': 'https://xn--bcher-kva.example/',
    };
    for (final MapEntry(key: input, value: expected) in supported.entries) {
      expect(BookmarkUrl.parse(input).canonicalKey, expected, reason: input);
    }
  });

  test('preserves meaningful and byte-sensitive resource distinctions', () {
    const distinct = [
      ('http://example.org/a', 'https://example.org/a'),
      ('https://example.org/a', 'https://example.org:8443/a'),
      ('https://example.org/a', 'https://www.example.org/a'),
      ('https://example.org/a', 'https://example.org./a'),
      ('https://example.org/a', 'https://example.org/A'),
      ('https://example.org/a', 'https://example.org/a/'),
      ('https://example.org/a', 'https://example.org/b/../a'),
      ('https://example.org/a', 'https://example.org/a?'),
      ('https://example.org/a', 'https://example.org/a#'),
      ('https://example.org/a#a', 'https://example.org/a#A'),
      ('https://example.org/a?x=1&x=2', 'https://example.org/a?x=2&x=1'),
      ('https://example.org/a?x=%41', 'https://example.org/a?x=A'),
      ('https://example.org/%2f', 'https://example.org/%2F'),
      ('https://example.org/a/b', 'https://example.org/a%2Fb'),
    ];
    for (final (first, second) in distinct) {
      expect(
        BookmarkUrl.parse(first).canonicalKey,
        isNot(BookmarkUrl.parse(second).canonicalKey),
        reason: '$first and $second',
      );
    }
  });

  test('rejects unsafe schemes, ambiguous hosts and malformed URLs', () {
    const invalid = [
      '',
      '  ',
      'x.com/article',
      '//example.org/a',
      'https:example.org',
      'javascript:alert(1)',
      'file:///Users/me/bookmark.html',
      'ftp://example.org/a',
      'https:///a',
      'https://user:password@example.org/a',
      'https://@example.org/a',
      'https://example.org:0/a',
      'https://example.org:65536/a',
      'https://example.org:/a',
      'https://example.org:+443/a',
      'https://example..org/a',
      'https://-example.org/a',
      'https://ex%61mple.org/a',
      'https://127.1/a',
      'https://0177.0.0.1/a',
      'https://0x7f000001/a',
      'https://256.0.0.1/a',
      'https://[:::]/a',
      'https://example.org/a b',
      'https://example.org/a\t?x=b',
      'https://example.org/\u0000',
      r'https://example.org\@evil.org/a',
      'https://example.org/?x=%z1',
      'https://example.org/%2',
    ];
    for (final input in invalid) {
      expect(
        () => BookmarkUrl.parse(input),
        throwsFormatException,
        reason: input,
      );
    }
  });

  test('applies the length limit after trimming', () {
    const prefix = 'https://example.org/';
    final boundary = prefix + 'x' * (4096 - prefix.length);
    expect(BookmarkUrl.parse(' $boundary ').originalText, boundary);
    expect(() => BookmarkUrl.parse('${boundary}x'), throwsFormatException);
  });
}

import 'dart:convert';

import 'bookmark.dart';
import 'bookmark_url.dart';

/// An explicit user-requested draft, separate from automatic context arrivals.
final class BrowserCapture {
  const BrowserCapture._({
    required this.url,
    required this.source,
    required this.eventId,
    required this.occurredAt,
    this.suggestedTrigger,
  });

  final String url;
  final SourceContext source;
  final String eventId;
  final DateTime occurredAt;
  final TriggerContext? suggestedTrigger;

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final _asciiUrl = RegExp(r'^[\x21-\x7e]+$');
  static final _address = RegExp(r'^https://([^/?#]+)(?:[/?#]|$)');
  static const _fields = {
    'version',
    'kind',
    'url',
    'source',
    'eventId',
    'occurredAt',
  };
  static const _hosts = {
    'x.com': SourceContext.x,
    'www.x.com': SourceContext.x,
    'twitter.com': SourceContext.x,
    'www.twitter.com': SourceContext.x,
    'mobile.twitter.com': SourceContext.x,
    'facebook.com': SourceContext.facebook,
    'www.facebook.com': SourceContext.facebook,
    'm.facebook.com': SourceContext.facebook,
    'mbasic.facebook.com': SourceContext.facebook,
    'github.com': SourceContext.github,
    'www.github.com': SourceContext.github,
    'gist.github.com': SourceContext.github,
  };

  bool fresh(DateTime now) {
    final age = now.toUtc().difference(occurredAt);
    return age >= const Duration(seconds: -5) &&
        age <= const Duration(seconds: 30);
  }

  static BrowserCapture? parse(Object? input, DateTime now) {
    if (input is! Map ||
        input.length != _fields.length ||
        input.keys.any((key) => !_fields.contains(key)) ||
        input['version'] is! int ||
        input['version'] != 1 ||
        (input['kind'] != 'capture' && input['kind'] != 'siteSave')) {
      return null;
    }
    final url = input['url'];
    final source = input['source'];
    final eventId = input['eventId'];
    final occurredAt = input['occurredAt'];
    if (url is! String ||
        url.isEmpty ||
        url.length > 3072 ||
        !_asciiUrl.hasMatch(url) ||
        source is! String ||
        eventId is! String ||
        !_uuid.hasMatch(eventId) ||
        occurredAt is! int) {
      return null;
    }
    final age = now.toUtc().millisecondsSinceEpoch - occurredAt;
    if (age < -5000 || age > 30000) return null;
    try {
      if (utf8.encode(jsonEncode(input)).length > 4096) return null;
      final parsed = BookmarkUrl.parse(url);
      final inferred = _hosts[_address.firstMatch(url)?.group(1)];
      if (inferred == null || inferred.name != source) {
        return null;
      }
      final TriggerContext? suggestedTrigger;
      if (input['kind'] == 'siteSave') {
        suggestedTrigger = switch (inferred) {
          SourceContext.x => TriggerContext.x,
          SourceContext.facebook => TriggerContext.facebook,
          _ => null,
        };
        if (suggestedTrigger == null) return null;
      } else {
        suggestedTrigger = null;
      }
      return BrowserCapture._(
        url: parsed.originalText,
        source: inferred,
        suggestedTrigger: suggestedTrigger,
        eventId: eventId,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(
          occurredAt,
          isUtc: true,
        ),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}

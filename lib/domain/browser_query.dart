import 'bookmark.dart';

/// Explicit browser chooser reads, separate from automatic reminder events.
final class BrowserQuery {
  BrowserQuery._(this.kind, this.context, this.cursor);
  final String kind, cursor;
  final TriggerContext context;

  static BrowserQuery? parse(Map data, DateTime now) {
    const keys = {
      'version',
      'kind',
      'target',
      'cursor',
      'eventId',
      'occurredAt',
    };
    if (data.length != keys.length ||
        !data.keys.every(keys.contains) ||
        data['version'] != 1 ||
        !['list', 'open'].contains(data['kind']) ||
        !['x', 'facebook'].contains(data['target']) ||
        data['cursor'] is! String ||
        data['eventId'] is! String ||
        data['occurredAt'] is! int) {
      return null;
    }
    if (!RegExp(r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$')
        .hasMatch(data['eventId'] as String)) {
      return null;
    }
    final age = now.millisecondsSinceEpoch - (data['occurredAt'] as int);
    if (age < -5000 || age > 30000) return null;
    final cursor = data['cursor'] as String;
    final pattern = data['kind'] == 'list'
        ? RegExp(r'^(?:[0-2]:[1-9][0-9]{0,14})?$')
        : RegExp(r'^[1-9][0-9]{0,14}$');
    if (!pattern.hasMatch(cursor)) return null;
    return BrowserQuery._(
      data['kind'] as String,
      TriggerContext.values.byName(data['target'] as String),
      cursor,
    );
  }
}

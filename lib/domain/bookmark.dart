enum Priority { low, medium, high }

enum BookmarkStatus { active, snoozed, completed }

enum SourceContext { x, github, other, facebook }

enum TriggerContext { x, github, facebook }

final class Intention {
  factory Intention(String text) {
    final value = text.trim();
    final error = validationError(value);
    if (error != null) throw ArgumentError(error);
    return Intention._(value);
  }

  const Intention._(this.text);

  final String text;

  static String? validationError(String text) {
    final value = text.trim();
    if (value.isEmpty) return 'Enter an intention.';
    if (value.runes.length > 200) return 'Use 200 characters or fewer.';
    return null;
  }
}

final class Bookmark {
  Bookmark({
    this.id,
    required this.url,
    required this.canonicalUrl,
    required String title,
    required this.intention,
    required this.source,
    required this.trigger,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.priority = Priority.medium,
    this.status = BookmarkStatus.active,
    DateTime? snoozedUntil,
    DateTime? completedAt,
    DateTime? lastReminderSubmittedAt,
  }) : title = _validateTitle(title),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       snoozedUntil = snoozedUntil?.toUtc(),
       completedAt = completedAt?.toUtc(),
       lastReminderSubmittedAt = lastReminderSubmittedAt?.toUtc();

  final int? id;
  final String url;
  final String canonicalUrl;
  final String title;
  final Intention intention;
  final SourceContext source;
  final TriggerContext trigger;
  final Priority priority;
  final BookmarkStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? snoozedUntil;
  final DateTime? completedAt;
  final DateTime? lastReminderSubmittedAt;

  static String _validateTitle(String input) {
    final title = input.trim();
    final error = titleValidationError(title);
    if (error != null) throw ArgumentError(error);
    return title;
  }

  static String? titleValidationError(String input) {
    final title = input.trim();
    if (title.isEmpty) return 'Enter a title.';
    if (title.runes.length > 200) return 'Use 200 characters or fewer.';
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/domain/browser_capture.dart';
import 'package:revisit/ui/bookmark_editor.dart';
import 'package:revisit/data/reminder_store.dart';

extension PriorityLabel on Priority {
  String get label => switch (this) {
    Priority.high => 'High',
    Priority.medium => 'Medium',
    Priority.low => 'Low',
  };
}

extension TriggerLabel on TriggerContext {
  String get label => switch (this) {
    TriggerContext.x => 'X',
    TriggerContext.github => 'GitHub',
    TriggerContext.facebook => 'Facebook',
  };
}

extension StatusLabel on BookmarkStatus {
  String get label => switch (this) {
    BookmarkStatus.active => 'Active',
    BookmarkStatus.snoozed => 'Snoozed',
    BookmarkStatus.completed => 'Completed',
  };
}

extension BookmarkDisplay on Bookmark {
  String get sourceDomain => Uri.tryParse(url)?.host ?? '';
}

Future<void> showBookmarkEditor(
  BuildContext context,
  BookmarkStore store,
  Future<bool> Function(String) openLink, {
  Bookmark? bookmark,
  BrowserCapture? capture,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => BookmarkEditor(
        store: store,
        bookmark: bookmark,
        capture: capture,
        viewExisting: (existing) =>
            showBookmarkDetails(context, store, openLink, existing.id!),
      ),
    ),
  );
  if (saved == true && messenger.mounted) {
    _showNotice(
      messenger,
      bookmark == null ? 'Bookmark saved.' : 'Bookmark updated.',
    );
  }
}

Future<void> showBookmarkDetails(
  BuildContext context,
  BookmarkStore store,
  Future<bool> Function(String) openLink,
  int id,
) async {
  final record = store.watchBookmark(id);
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Bookmark details')),
        body: SafeArea(
          child: StreamBuilder<Bookmark?>(
            stream: record,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading bookmark',
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text('This bookmark could not be opened.'),
                );
              }
              final bookmark = snapshot.data;
              if (bookmark == null) {
                return const Center(
                  child: Text('This bookmark is no longer in your library.'),
                );
              }
              return BookmarkDetails(
                bookmark: bookmark,
                store: store,
                openLink: openLink,
                closeOnDelete: true,
              );
            },
          ),
        ),
      ),
    ),
  );
}

void _notice(BuildContext context, String message) {
  _showNotice(ScaffoldMessenger.of(context), message);
}

void _showNotice(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class BookmarkDetails extends StatefulWidget {
  const BookmarkDetails({
    super.key,
    required this.bookmark,
    required this.store,
    required this.openLink,
    this.closeOnDelete = false,
  });

  final Bookmark bookmark;
  final BookmarkStore store;
  final Future<bool> Function(String) openLink;
  final bool closeOnDelete;

  @override
  State<BookmarkDetails> createState() => _BookmarkDetailsState();
}

class _BookmarkDetailsState extends State<BookmarkDetails> {
  bool _busy = false;

  Future<void> _snooze(Duration duration) async {
    setState(() => _busy = true);
    try {
      final changed = await widget.store.snoozeBookmark(
        widget.bookmark.id!,
        duration,
        DateTime.now(),
      );
      if (mounted) {
        _notice(
          context,
          changed ? 'Bookmark snoozed.' : 'This bookmark cannot be snoozed.',
        );
      }
    } catch (_) {
      if (mounted) {
        _notice(context, 'Could not snooze the bookmark. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final opened = await widget.openLink(widget.bookmark.url);
      if (!opened && mounted) {
        _notice(context, 'Could not open this link. Try again.');
      }
    } catch (_) {
      if (mounted) _notice(context, 'Could not open this link. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      final changed = await widget.store.completeBookmark(
        widget.bookmark.id!,
        DateTime.now(),
      );
      if (!mounted) return;
      if (changed) _notice(context, 'Bookmark completed.');
    } catch (_) {
      if (mounted) {
        _notice(context, 'Could not complete the bookmark. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete bookmark?'),
        content: const Text(
          'This will permanently remove the bookmark from this device.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    // The stream can remove this detail widget before the operation returns.
    final messenger = ScaffoldMessenger.of(context);
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    final popOnSuccess = widget.closeOnDelete;
    try {
      final removed = await widget.store.deleteBookmark(widget.bookmark.id!);
      if (!removed) {
        if (mounted) {
          _notice(context, 'This bookmark is no longer in your library.');
        }
        return;
      }
      if (popOnSuccess && navigator.mounted && route?.isCurrent == true) {
        navigator.pop();
      }
      if (messenger.mounted) {
        _showNotice(messenger, 'Bookmark deleted.');
      }
    } catch (_) {
      if (mounted) {
        _notice(context, 'Could not delete the bookmark. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmark = widget.bookmark;
    final theme = Theme.of(context);
    final source = switch (bookmark.source) {
      SourceContext.x => 'X',
      SourceContext.github => 'GitHub',
      SourceContext.facebook => 'Facebook',
      SourceContext.other => 'Other',
    };
    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  bookmark.title,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 6),
              Text(bookmark.sourceDomain, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              Text('Saved intention', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(bookmark.intention.text, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _DetailValue(
                    label: 'Priority',
                    value: bookmark.priority.label,
                  ),
                  _DetailValue(label: 'Source context', value: source),
                  _DetailValue(
                    label: 'Trigger context',
                    value: bookmark.trigger.label,
                  ),
                  _DetailValue(label: 'Status', value: bookmark.status.label),
                ],
              ),
              const SizedBox(height: 20),
              Text('Original link', style: theme.textTheme.titleSmall),
              if (bookmark.snoozedUntil != null &&
                  bookmark.status == BookmarkStatus.snoozed)
                Text(
                  'Snoozed until ${bookmark.snoozedUntil!.toLocal()} — eligible on the next matching arrival after this time.',
                ),
              const SizedBox(height: 6),
              SelectableText(bookmark.url),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _open,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open link'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => showBookmarkEditor(
                            context,
                            widget.store,
                            widget.openLink,
                            bookmark: bookmark,
                          ),
                    child: const Text('Edit'),
                  ),
                  if (bookmark.status != BookmarkStatus.completed)
                    PopupMenuButton<Duration>(
                      enabled: !_busy,
                      tooltip: 'Snooze bookmark',
                      onSelected: _snooze,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: Duration(hours: 1),
                          child: Text('Snooze 1 hour'),
                        ),
                        PopupMenuItem(
                          value: Duration(hours: 24),
                          child: Text('Snooze 24 hours'),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Snooze'),
                      ),
                    ),
                  if (bookmark.status != BookmarkStatus.completed)
                    OutlinedButton(
                      onPressed: _busy ? null : _complete,
                      child: const Text('Mark complete'),
                    ),
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Text(value),
    ],
  );
}

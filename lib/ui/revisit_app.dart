import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/data/reminder_store.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/ui/bookmark_details.dart';

import 'windows_integration_status.dart';
import '../application/windows_session.dart';
import '../platform/windows_reminders.dart';

class RevisitApp extends StatelessWidget {
  const RevisitApp({
    super.key,
    required this.openStore,
    required this.openLink,
    this.clock = DateTime.now,
    this.enableWindowsIntegration = false,
  });

  final BookmarkStore Function() openStore;
  final Future<bool> Function(String) openLink;
  final DateTime Function() clock;
  final bool enableWindowsIntegration;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Revisit',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: _BookmarkLibrary(
      openStore: openStore,
      openLink: openLink,
      clock: clock,
      enableWindowsIntegration: enableWindowsIntegration,
    ),
  );

  static ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF376557),
      brightness: brightness,
    ),
  );
}

class _BookmarkLibrary extends StatefulWidget {
  const _BookmarkLibrary({
    required this.openStore,
    required this.openLink,
    required this.clock,
    required this.enableWindowsIntegration,
  });

  final BookmarkStore Function() openStore;
  final Future<bool> Function(String) openLink;
  final DateTime Function() clock;
  final bool enableWindowsIntegration;

  @override
  State<_BookmarkLibrary> createState() => _BookmarkLibraryState();
}

enum _Sort { newest, priority }

class _BookmarkLibraryState extends State<_BookmarkLibrary> {
  BookmarkStore? _store;
  WindowsSession? _windows;
  late Stream<List<Bookmark>> _library;
  Priority? _priority;
  _Sort _sort = _Sort.newest;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    final store = widget.openStore();
    _store = store;
    _library = _initialize(store);
  }

  Stream<List<Bookmark>> _initialize(BookmarkStore store) async* {
    await store.recoverReminders(widget.clock());
    if (mounted &&
        identical(_store, store) &&
        widget.enableWindowsIntegration &&
        Platform.isWindows) {
      final session = WindowsSession(
        store,
        WindowsReminders(clock: widget.clock),
        widget.clock,
        openBookmark: (id) async {
          if (!mounted || !identical(store, _store)) return;
          await showBookmarkDetails(context, store, widget.openLink, id);
        },
        openCapture: (capture) async {
          if (!mounted || !identical(store, _store)) return;
          if (Navigator.of(context).canPop()) {
            throw StateError('An editor or detail view is already open');
          }
          await showBookmarkEditor(
            context,
            store,
            widget.openLink,
            capture: capture,
          );
        },
      );
      _windows = session;
      unawaited(session.start());
    }
    yield* store.watchBookmarks();
  }

  Future<void> _retry() async {
    final previous = _store;
    if (previous == null) return;
    final windows = _windows;
    _windows = null;
    setState(() => _store = null);
    await windows?.close();
    await _close(previous);
    if (mounted) setState(_connect);
  }

  Future<void> _close(BookmarkStore store) async {
    try {
      await store.close();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'Revisit'),
      );
    }
  }

  @override
  void dispose() {
    final store = _store;
    final windows = _windows;
    unawaited(() async {
      await windows?.close();
      if (store != null) await _close(store);
    }());
    super.dispose();
  }

  List<Bookmark> _visibleBookmarks(List<Bookmark> records) {
    final visible = records
        .where(
          (bookmark) => _priority == null || bookmark.priority == _priority,
        )
        .toList();
    visible.sort((a, b) {
      if (_sort == _Sort.priority) {
        final priority = b.priority.index.compareTo(a.priority.index);
        if (priority != 0) return priority;
      }
      final date = b.createdAt.compareTo(a.createdAt);
      return date == 0 ? b.id!.compareTo(a.id!) : date;
    });
    return visible;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisit')),
    body: SafeArea(
      child: StreamBuilder<List<Bookmark>>(
        stream: _library,
        builder: (context, snapshot) {
          final store = _store;
          if (store == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const _LibraryMessage(
              title: 'Opening your library',
              description: 'Loading bookmarks from this device.',
              icon: Icons.folder_open_outlined,
              action: LinearProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return _LibraryMessage(
              title: 'Your library could not be opened',
              description: 'Try opening local storage again.',
              icon: Icons.error_outline,
              action: FilledButton(
                onPressed: _retry,
                child: const Text('Try again'),
              ),
            );
          }
          final records = snapshot.requireData;
          final visible = _visibleBookmarks(records);
          final selected = visible
              .where((b) => b.id == _selectedId)
              .firstOrNull;

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 840;
              final list = _buildList(context, store, records, visible, wide);
              if (!wide || records.isEmpty) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: list,
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: list),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 6,
                    child: selected == null
                        ? const _LibraryMessage(
                            title: 'Select a bookmark',
                            description:
                                'Its details and actions will appear here.',
                            icon: Icons.bookmark_outline,
                          )
                        : BookmarkDetails(
                            key: ValueKey(selected.id),
                            bookmark: selected,
                            store: store,
                            openLink: widget.openLink,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );

  Widget _buildList(
    BuildContext context,
    BookmarkStore store,
    List<Bookmark> records,
    List<Bookmark> visible,
    bool wide,
  ) {
    final theme = Theme.of(context);
    final count = records.length;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_windows case final session?)
                  WindowsIntegrationStatus(session: session),
                Semantics(
                  header: true,
                  child: Text(
                    'Your library',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  count == 0
                      ? 'Save with intention. Return with purpose.'
                      : '$count saved ${count == 1 ? 'bookmark' : 'bookmarks'}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      showBookmarkEditor(context, store, widget.openLink),
                  icon: const Icon(Icons.add),
                  label: const Text('New bookmark'),
                ),
                if (count != 0) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 4,
                    children: [
                      Semantics(
                        label: 'Filter by priority',
                        child: DropdownButton<Priority?>(
                          isExpanded: true,
                          itemHeight: null,
                          value: _priority,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All priorities'),
                            ),
                            for (final priority in Priority.values.reversed)
                              DropdownMenuItem(
                                value: priority,
                                child: Text(priority.label),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _priority = value),
                        ),
                      ),
                      Semantics(
                        label: 'Sort bookmarks',
                        child: DropdownButton<_Sort>(
                          isExpanded: true,
                          itemHeight: null,
                          value: _sort,
                          items: const [
                            DropdownMenuItem(
                              value: _Sort.newest,
                              child: Text('Newest first'),
                            ),
                            DropdownMenuItem(
                              value: _Sort.priority,
                              child: Text('Priority first'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _sort = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: _LibraryMessage(
              title: count == 0
                  ? 'No bookmarks saved'
                  : 'No bookmarks match this priority',
              description: count == 0
                  ? 'Add a link and a note about why you want to return to it.'
                  : 'Choose All priorities to see your full library.',
              icon: Icons.bookmark_outline,
              action: count == 0
                  ? null
                  : TextButton(
                      onPressed: () => setState(() => _priority = null),
                      child: const Text('Clear filter'),
                    ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final bookmark = visible[index];
                final isSelected = wide && bookmark.id == _selectedId;
                return _BookmarkCard(
                  key: ValueKey(bookmark.id),
                  bookmark: bookmark,
                  selected: isSelected,
                  onTap: () {
                    if (wide) {
                      setState(() => _selectedId = bookmark.id);
                    } else {
                      showBookmarkDetails(
                        context,
                        store,
                        widget.openLink,
                        bookmark.id!,
                      );
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    super.key,
    required this.bookmark,
    required this.selected,
    required this.onTap,
  });

  final Bookmark bookmark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? theme.colorScheme.secondaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookmark.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  bookmark.sourceDomain,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  bookmark.intention.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                DefaultTextStyle(
                  style: theme.textTheme.labelMedium!,
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      Text('${bookmark.priority.label} priority'),
                      Text('Trigger: ${bookmark.trigger.label}'),
                      if (bookmark.status != BookmarkStatus.active)
                        Text(bookmark.status.label),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.title,
    required this.description,
    required this.icon,
    this.action,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyLarge),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

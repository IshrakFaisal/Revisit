import 'dart:async';

import 'package:flutter/material.dart';
import 'package:revisit/data/bookmark_store.dart';
import 'package:revisit/domain/bookmark.dart';
import 'package:revisit/domain/bookmark_url.dart';
import 'package:revisit/domain/browser_capture.dart';

class BookmarkEditor extends StatefulWidget {
  const BookmarkEditor({
    super.key,
    required this.store,
    this.bookmark,
    this.capture,
    required this.viewExisting,
  }) : assert(bookmark == null || capture == null);

  final BookmarkStore store;
  final Bookmark? bookmark;
  final BrowserCapture? capture;
  final Future<void> Function(Bookmark) viewExisting;

  @override
  State<BookmarkEditor> createState() => _BookmarkEditorState();
}

class _BookmarkEditorState extends State<BookmarkEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _url;
  late final TextEditingController _title;
  late final TextEditingController _intention;
  late Priority _priority;
  late SourceContext _source;
  TriggerContext? _trigger;
  bool _busy = false;
  bool _submitted = false;
  bool _confirmingDiscard = false;
  String? _error;
  int? _duplicateId;

  @override
  void initState() {
    super.initState();
    final bookmark = widget.bookmark;
    _url = TextEditingController(text: bookmark?.url ?? widget.capture?.url);
    _title = TextEditingController(text: bookmark?.title);
    _intention = TextEditingController(text: bookmark?.intention.text);
    _priority = bookmark?.priority ?? Priority.medium;
    _source = bookmark?.source ?? widget.capture?.source ?? SourceContext.other;
    _trigger = bookmark?.trigger ?? widget.capture?.suggestedTrigger;
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _intention.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final bookmark = widget.bookmark;
    final capture = widget.capture;
    return _url.text != (bookmark?.url ?? capture?.url ?? '') ||
        _title.text != (bookmark?.title ?? '') ||
        _intention.text != (bookmark?.intention.text ?? '') ||
        _priority != (bookmark?.priority ?? Priority.medium) ||
        _source !=
            (bookmark?.source ?? capture?.source ?? SourceContext.other) ||
        _trigger != (bookmark?.trigger ?? capture?.suggestedTrigger);
  }

  void _clearError() {
    _error = null;
    _duplicateId = null;
  }

  String? _validateUrl(String? value) {
    try {
      BookmarkUrl.parse(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_submitted) setState(() => _submitted = true);
    final invalidFields = _form.currentState!.validateGranularly();
    if (invalidFields.isNotEmpty) {
      unawaited(Scrollable.ensureVisible(invalidFields.first.context));
      return;
    }

    setState(() {
      _busy = true;
      _clearError();
    });
    try {
      final link = BookmarkUrl.parse(_url.text);
      final previous = widget.bookmark;
      final now = DateTime.now().toUtc();
      final bookmark = Bookmark(
        id: previous?.id,
        url: link.originalText,
        canonicalUrl: link.canonicalKey,
        title: _title.text,
        intention: Intention(_intention.text),
        source: _source,
        trigger: _trigger!,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        priority: _priority,
        status: previous?.status ?? BookmarkStatus.active,
        snoozedUntil: previous?.snoozedUntil,
        completedAt: previous?.completedAt,
        lastReminderSubmittedAt: previous?.lastReminderSubmittedAt,
      );

      if (previous == null) {
        await widget.store.createBookmark(bookmark);
      } else if (!await widget.store.updateBookmark(bookmark)) {
        if (mounted) {
          setState(() {
            _error =
                'This bookmark was removed. Copy your changes before leaving.';
          });
        }
        return;
      }

      if (mounted) Navigator.pop(context, true);
    } on DuplicateBookmarkException catch (error) {
      if (mounted) {
        setState(() {
          _duplicateId = error.existingId;
          _error = 'This link is already saved.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Your bookmark could not be saved. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openExisting() async {
    final id = _duplicateId;
    if (_busy || id == null) return;
    setState(() => _busy = true);
    try {
      final bookmark = await widget.store.readBookmark(id);
      if (!mounted) return;
      if (bookmark == null) {
        setState(() {
          _duplicateId = null;
          _error = 'That bookmark has been removed. Try saving again.';
        });
        return;
      }
      await widget.viewExisting(bookmark);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The existing bookmark could not be opened. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDiscard() async {
    if (_busy || _confirmingDiscard || !_hasChanges) return;
    _confirmingDiscard = true;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (mounted && discard == true) Navigator.pop(context);
    } finally {
      _confirmingDiscard = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.bookmark != null;
    final colors = Theme.of(context).colorScheme;
    return PopScope<bool>(
      canPop: !_busy && !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(editing ? 'Edit bookmark' : 'New bookmark')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Form(
                  key: _form,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  onChanged: () => setState(_clearError),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _url,
                        readOnly: _busy,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'URL',
                          hintText: 'https://example.org/article',
                          errorMaxLines: 3,
                        ),
                        validator: _validateUrl,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _title,
                        readOnly: _busy,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          errorMaxLines: 3,
                        ),
                        validator: (value) =>
                            Bookmark.titleValidationError(value ?? ''),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _intention,
                        readOnly: _busy,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Intention',
                          hintText: 'Why is this worth revisiting?',
                          errorMaxLines: 3,
                        ),
                        validator: (value) =>
                            Intention.validationError(value ?? ''),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Priority>(
                        initialValue: _priority,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: Priority.high,
                            child: Text('High'),
                          ),
                          DropdownMenuItem(
                            value: Priority.medium,
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(
                            value: Priority.low,
                            child: Text('Low'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _priority = value!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SourceContext>(
                        initialValue: _source,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Source context',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: SourceContext.x,
                            child: Text('X'),
                          ),
                          DropdownMenuItem(
                            value: SourceContext.github,
                            child: Text('GitHub'),
                          ),
                          DropdownMenuItem(
                            value: SourceContext.facebook,
                            child: Text('Facebook'),
                          ),
                          DropdownMenuItem(
                            value: SourceContext.other,
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _source = value!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<TriggerContext>(
                        initialValue: _trigger,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Trigger context',
                          errorMaxLines: 2,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TriggerContext.x,
                            child: Text('X'),
                          ),
                          DropdownMenuItem(
                            value: TriggerContext.github,
                            child: Text('GitHub'),
                          ),
                          DropdownMenuItem(
                            value: TriggerContext.facebook,
                            child: Text('Facebook'),
                          ),
                        ],
                        validator: (value) =>
                            value == null ? 'Choose a trigger context.' : null,
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _trigger = value),
                      ),
                      const SizedBox(height: 24),
                      if (_error case final error?) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                        if (_duplicateId != null)
                          TextButton(
                            onPressed: _busy ? null : _openExisting,
                            child: const Text('View existing bookmark'),
                          ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(editing ? 'Save changes' : 'Save bookmark'),
                      ),
                      if (_busy) const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

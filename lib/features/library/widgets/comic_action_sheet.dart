import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/comic_summary.dart';
import '../../../data/repositories/providers.dart';

/// Long-press action sheet for a catalog item: favorite, manage tags, and add to
/// collections. All edits go through the active source, so the library refreshes
/// live via the change stream.
Future<void> showComicActionSheet(BuildContext context, ComicSummary comic) {
  HapticFeedback.mediumImpact(); // confirm the long-press (mobile)
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF141414),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ComicActionSheet(comic: comic),
  );
}

class _ComicActionSheet extends ConsumerStatefulWidget {
  const _ComicActionSheet({required this.comic});
  final ComicSummary comic;

  @override
  ConsumerState<_ComicActionSheet> createState() => _ComicActionSheetState();
}

class _ComicActionSheetState extends ConsumerState<_ComicActionSheet> {
  final _tagController = TextEditingController();
  List<String> _tags = [];
  Set<String> _memberLibraries = {};
  bool _favorite = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _favorite = widget.comic.isFavorite;
    _load();
  }

  Future<void> _load() async {
    final source = ref.read(activeSourceProvider);
    final tags = await source.tagsForComic(widget.comic.id);
    final libs = await source.librariesForComic(widget.comic.id);
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _memberLibraries = libs;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    setState(() => _favorite = !_favorite);
    ref.read(activeSourceProvider).setFavorite(widget.comic.id, _favorite);
  }

  Future<void> _addTag(String raw) async {
    final name = raw.trim();
    if (name.isEmpty || _tags.contains(name)) {
      _tagController.clear();
      return;
    }
    final next = [..._tags, name];
    setState(() {
      _tags = next;
      _tagController.clear();
    });
    await ref.read(activeSourceProvider).setTagsForComic(widget.comic.id, next);
  }

  Future<void> _removeTag(String name) async {
    final next = _tags.where((t) => t != name).toList();
    setState(() => _tags = next);
    await ref.read(activeSourceProvider).setTagsForComic(widget.comic.id, next);
  }

  Future<void> _toggleLibrary(String libraryId, bool member) async {
    setState(() {
      if (member) {
        _memberLibraries = {..._memberLibraries, libraryId};
      } else {
        _memberLibraries = _memberLibraries.where((id) => id != libraryId).toSet();
      }
    });
    await ref.read(activeSourceProvider).setInLibrary(libraryId, widget.comic.id, member);
  }

  Future<void> _createCollection() async {
    final name = await _promptName(context, 'New collection');
    if (name == null || name.trim().isEmpty) return;
    final id = await ref.read(activeSourceProvider).createLibrary(name.trim());
    ref.invalidate(librariesProvider);
    if (id.isNotEmpty) await _toggleLibrary(id, true);
  }

  @override
  Widget build(BuildContext context) {
    final libraries = ref.watch(librariesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.comic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_favorite ? Icons.favorite : Icons.favorite_border,
                  color: _favorite ? const Color(0xFFEF4444) : null),
              title: Text(_favorite ? 'Favorited' : 'Add to favorites'),
              onTap: _toggleFavorite,
            ),
            const Divider(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final tag in _tags)
                    Chip(
                      label: Text(tag),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: const Color(0xFF1C1C1C),
                    ),
                ],
              ),
              TextField(
                controller: _tagController,
                decoration: const InputDecoration(
                  hintText: 'Add a tag…',
                  isDense: true,
                  prefixIcon: Icon(Icons.tag, size: 18),
                ),
                onSubmitted: _addTag,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Collections', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    onPressed: _createCollection,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              libraries.maybeWhen(
                data: (libs) => libs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No collections yet — create one above.',
                            style: TextStyle(color: Color(0xFF888888))),
                      )
                    : Column(
                        children: [
                          for (final lib in libs)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: _memberLibraries.contains(lib.id),
                              title: Text(lib.name),
                              onChanged: (v) => _toggleLibrary(lib.id, v ?? false),
                            ),
                        ],
                      ),
                orElse: () => const SizedBox(height: 8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<String?> _promptName(BuildContext context, String title) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF141414),
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create')),
      ],
    ),
  );
}

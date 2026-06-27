import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/sources/library_source.dart';
import '../../organize/widgets/collection_item_picker.dart';
import 'comic_action_sheet.dart';
import 'library_grid.dart';

/// A titled grid for an arbitrary [LibraryQuery] — reused by the tag, collection
/// and series browsers. Cards open the reader on tap and the action sheet on
/// long-press.
///
/// When [collectionId] is set (collection view), the app bar shows an "Add"
/// action that opens the library picker for adding books/comics to it.
class BrowseGridScreen extends ConsumerWidget {
  /// Creates a titled grid showing the results of [query].
  const BrowseGridScreen({
    super.key,
    required this.title,
    required this.query,
    this.collectionId,
  });

  /// App-bar title.
  final String title;

  /// Query whose results are displayed.
  final LibraryQuery query;

  /// Collection id this grid belongs to; enables the "Add items" action. Null
  /// for tag/series grids, which aren't manually curated.
  final String? collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comicsAsync = ref.watch(browseComicsProvider(query));
    final isCollection = collectionId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isCollection)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add books or comics',
              onPressed: () => showAddToCollectionSheet(
                context,
                collectionId: collectionId!,
                collectionName: title,
              ),
            ),
        ],
      ),
      body: comicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load:\n$e', textAlign: TextAlign.center)),
        data: (comics) {
          if (comics.isEmpty) {
            return Center(
              child: Text(
                isCollection ? 'Empty — tap + to add books or comics' : 'Nothing here yet',
                style: const TextStyle(color: CbColors.mutedForeground),
                textAlign: TextAlign.center,
              ),
            );
          }
          return LibraryGrid(
            comics: comics,
            onOpen: (comic) => context.push('/read/${comic.id}'),
            onLongPress: (comic) => showComicActionSheet(context, comic),
            onRefresh: () async {
              invalidateLibraryProviders(ref);
              await ref.read(browseComicsProvider(query).future);
            },
          );
        },
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/comic_summary.dart';
import '../../../data/repositories/providers.dart';

/// A comic's cover image, source-agnostic. Resolves, in order:
///  1. inline bytes already on the summary (remote pre-load / legacy),
///  2. a remote thumbnail URL (disk-cached),
///  3. for local items — whose list query skips the BLOB to stay light — the
///     cover loaded lazily by id via [localCoverProvider].
///
/// Falls back to [CoverPlaceholder]. Fills its parent (`BoxFit.cover`); the
/// caller owns clipping and sizing.
class ComicCover extends ConsumerWidget {
  /// Creates a cover for [comic].
  const ComicCover({super.key, required this.comic});

  /// The item whose cover to show.
  final ComicSummary comic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inline = comic.coverThumbnail;
    if (inline != null) {
      return Image.memory(inline, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final url = comic.coverUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        httpHeaders: comic.imageHeaders,
        fit: BoxFit.cover,
        placeholder: (_, _) => const CoverPlaceholder(),
        errorWidget: (_, _, _) => const CoverPlaceholder(),
      );
    }
    return ref.watch(localCoverProvider(comic.id)).maybeWhen(
          data: (bytes) => bytes == null
              ? const CoverPlaceholder()
              : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
          orElse: () => const CoverPlaceholder(),
        );
  }
}

/// Neutral placeholder shown while a cover loads or when there is none.
class CoverPlaceholder extends StatelessWidget {
  /// Creates a cover placeholder.
  const CoverPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: CbColors.surfaceAlt,
      child: Center(
        child: Icon(Icons.menu_book_outlined, color: CbColors.mutedForeground, size: 28),
      ),
    );
  }
}

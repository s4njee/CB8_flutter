import 'dart:typed_data';

/// Source-agnostic view of a catalog row used across the UI.
///
/// Both [LocalSource] (Drift rows) and [RemoteSource] (CB8 REST JSON) map into
/// this so screens never branch on where content came from.
class ComicSummary {
  const ComicSummary({
    required this.id,
    required this.title,
    required this.pageCount,
    required this.mediaType,
    this.coverThumbnail,
    this.coverUrl,
    this.lastPage,
    this.lastLocation,
    this.completed = false,
    this.isFavorite = false,
    this.seriesName,
    this.volumeNumber,
    this.chapterNumber,
    this.extension,
    this.sourceUri,
    this.imageHeaders,
  });

  final String id;
  final String title;
  final int pageCount;

  /// 'comic' or 'book' (see [MediaTypes]).
  final String mediaType;

  /// Inline cover bytes (local source). Mutually exclusive with [coverUrl].
  final Uint8List? coverThumbnail;

  /// Remote cover endpoint (remote source).
  final String? coverUrl;

  final int? lastPage;
  final String? lastLocation;
  final bool completed;
  final bool isFavorite;

  final String? seriesName;
  final double? volumeNumber;
  final double? chapterNumber;

  /// Lowercase file extension without the dot ('cbz' | 'pdf' | 'epub'), for the
  /// format badge on cards. May be null for remote items that don't expose it.
  final String? extension;

  /// For local items, the on-device file path the readers open. Null for remote
  /// items (those read via [coverUrl]/page URLs on the [RemoteSource]).
  final String? sourceUri;

  /// HTTP headers (e.g. session cookie) needed to fetch [coverUrl]/page images
  /// for a remote item. Null for local items.
  final Map<String, String>? imageHeaders;

  ComicSummary copyWith({String? sourceUri}) => ComicSummary(
        id: id,
        title: title,
        pageCount: pageCount,
        mediaType: mediaType,
        coverThumbnail: coverThumbnail,
        coverUrl: coverUrl,
        lastPage: lastPage,
        lastLocation: lastLocation,
        completed: completed,
        isFavorite: isFavorite,
        seriesName: seriesName,
        volumeNumber: volumeNumber,
        chapterNumber: chapterNumber,
        extension: extension,
        sourceUri: sourceUri ?? this.sourceUri,
        imageHeaders: imageHeaders,
      );

  /// Fraction read in [0,1], for the progress bar drawn on the card.
  double get progress {
    if (pageCount <= 0 || lastPage == null) return completed ? 1 : 0;
    return (lastPage! / (pageCount - 1)).clamp(0, 1);
  }

  bool get inProgress => progress > 0 && !completed;
}

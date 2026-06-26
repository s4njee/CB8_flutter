import 'dart:typed_data';

/// A tag with how many comics carry it (for the Tags browser).
class TagCount {
  const TagCount({required this.name, required this.count});
  final String name;
  final int count;
}

/// A named collection (CB8 "library") with its size and a representative cover.
class LibraryInfo {
  const LibraryInfo({required this.id, required this.name, required this.count, this.cover});
  final String id;
  final String name;
  final int count;
  final Uint8List? cover;
}

/// An auto-derived series group (by parsed `seriesName`) with a cover.
class SeriesGroup {
  const SeriesGroup({required this.name, required this.count, this.cover});
  final String name;
  final int count;
  final Uint8List? cover;
}

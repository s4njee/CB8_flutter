import 'package:flutter/widgets.dart';

import 'cbz_archive.dart';

/// Where the comic reader gets each page's image — local archive bytes or remote
/// page-image URLs — so the reader is agnostic to the active source.
abstract class ComicPageSource {
  int get pageCount;
  ImageProvider imageFor(int index);

  /// Release any held resources (e.g. an open PDF document). No-op for sources
  /// that hold nothing.
  void dispose() {}
}

/// Pages from an on-device CBZ archive.
class LocalCbzPageSource implements ComicPageSource {
  LocalCbzPageSource(this._archive);
  final CbzArchive _archive;

  @override
  int get pageCount => _archive.pageCount;

  @override
  ImageProvider imageFor(int index) => MemoryImage(_archive.pageBytes(index));

  @override
  void dispose() {}
}

/// Pages fetched from a CB8 server's `/api/comics/:id/pages/:n` endpoint.
class RemotePageSource implements ComicPageSource {
  RemotePageSource({required this.pageCount, required this.urlFor, this.headers});

  @override
  final int pageCount;
  final String Function(int index) urlFor;
  final Map<String, String>? headers;

  @override
  ImageProvider imageFor(int index) => NetworkImage(urlFor(index), headers: headers);

  @override
  void dispose() {}
}

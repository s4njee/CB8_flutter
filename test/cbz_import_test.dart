import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cb8_flutter/features/import/media_probe.dart';
import 'package:cb8_flutter/features/reader/comic/cbz_archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Builds a CBZ on disk with [pages] solid-color JPEG images, named out of order
/// to also exercise the natural sort.
String _writeCbz(Directory dir, String name, int pages) {
  final archive = Archive();
  for (var i = 1; i <= pages; i++) {
    final image = img.Image(width: 40, height: 60);
    img.fill(image, color: img.ColorRgb8(0x22, 0x44, 0xAA));
    final jpg = img.encodeJpg(image, quality: 70);
    // Non-zero-padded names so "page2" must sort before "page10".
    archive.addFile(ArchiveFile('page$i.jpg', jpg.length, jpg));
  }
  final path = p.join(dir.path, name);
  File(path).writeAsBytesSync(Uint8List.fromList(ZipEncoder().encode(archive)!));
  return path;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cb8_cbz_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('probeFile reads a CBZ: page count, cover, comic media type', () async {
    final path = _writeCbz(tmp, 'Probe Series v01.cbz', 12);
    final result = await probeFile(path);

    expect(result, isNotNull);
    expect(result!.mediaType, 'comic');
    expect(result.pageCount, 12);
    expect(result.coverJpg, isNotNull);
    expect(img.decodeImage(result.coverJpg!), isNotNull); // cover is valid JPEG
    expect(result.series.seriesName, 'Probe Series');
    expect(result.series.volumeNumber, 1);
  });

  test('CbzArchive opens and yields decodable pages in natural order', () async {
    final path = _writeCbz(tmp, 'Reader.cbz', 11);
    final archive = await CbzArchive.open(path);

    expect(archive.pageCount, 11);
    // First and last pages decode to real images.
    expect(img.decodeImage(archive.pageBytes(0)), isNotNull);
    expect(img.decodeImage(archive.pageBytes(10)), isNotNull);
  });

  test('unsupported extension returns null', () async {
    final path = p.join(tmp.path, 'notes.txt');
    File(path).writeAsStringSync('hello');
    expect(await probeFile(path), isNull);
  });
}

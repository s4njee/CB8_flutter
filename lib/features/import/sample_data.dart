import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/local_files.dart';

/// Generates a handful of synthetic CBZ comics on disk so the app can be tried
/// without sideloading real files (handy on a fresh simulator). Each generated
/// page is a solid color with its page number drawn on it.
///
/// Returns paths RELATIVE to [appStorageDir] (see that file for why). Dev/demo
/// aid only — not part of the real import path.
Future<List<String>> writeSampleComics() async {
  final dir = Directory(p.join((await appStorageDir()).path, 'samples'));
  await dir.create(recursive: true);

  final specs = <_Spec>[
    _Spec('Sample Comic v01.cbz', 8, [img.ColorRgb8(0x1E, 0x88, 0xE5), img.ColorRgb8(0xD3, 0x2F, 0x2F)]),
    _Spec('Sample Comic v02.cbz', 6, [img.ColorRgb8(0x43, 0xA0, 0x47), img.ColorRgb8(0x6D, 0x4C, 0x41)]),
    _Spec('Demo Series #003.cbz', 10, [img.ColorRgb8(0x8E, 0x24, 0xAA), img.ColorRgb8(0xF4, 0x51, 0x1E)]),
  ];

  final paths = <String>[];
  for (final spec in specs) {
    await File(p.join(dir.path, spec.name)).writeAsBytes(_buildCbz(spec));
    paths.add(p.join('samples', spec.name)); // relative to app storage
  }

  // A sample book (PDF) so the PDF reader has something to open too.
  const pdfName = 'Sample Book.pdf';
  await File(p.join(dir.path, pdfName)).writeAsBytes(await _buildPdf(5));
  paths.add(p.join('samples', pdfName));

  // A sample EPUB for the reflowable reader.
  const epubName = 'Sample Novel.epub';
  await File(p.join(dir.path, epubName)).writeAsBytes(_buildEpub(6));
  paths.add(p.join('samples', epubName));

  return paths;
}

/// Builds a minimal but valid EPUB 3 (mimetype + container + OPF + nav + N
/// chapters) so the EPUB reader has real content to page through.
Uint8List _buildEpub(int chapters) {
  ArchiveFile file(String name, String content, {bool compress = true}) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes)..compress = compress;
  }

  final archive = Archive();
  // mimetype must be first and stored (uncompressed).
  archive.addFile(file('mimetype', 'application/epub+zip', compress: false));
  archive.addFile(file('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''));

  final manifest = StringBuffer('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>');
  final spine = StringBuffer();
  final navList = StringBuffer();
  for (var i = 1; i <= chapters; i++) {
    final href = 'chapter$i.xhtml';
    archive.addFile(file('OEBPS/$href', _chapterXhtml(i)));
    manifest.write('<item id="ch$i" href="$href" media-type="application/xhtml+xml"/>');
    spine.write('<itemref idref="ch$i"/>');
    navList.write('<li><a href="$href">Chapter $i</a></li>');
  }

  archive.addFile(file('OEBPS/nav.xhtml', '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Contents</title></head>
<body><nav epub:type="toc"><ol>$navList</ol></nav></body>
</html>'''));

  archive.addFile(file('OEBPS/content.opf', '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">urn:uuid:cb8-sample-novel</dc:identifier>
    <dc:title>Sample Novel</dc:title>
    <dc:language>en</dc:language>
    <meta property="dcterms:modified">2026-01-01T00:00:00Z</meta>
  </metadata>
  <manifest>$manifest</manifest>
  <spine>$spine</spine>
</package>'''));

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _chapterXhtml(int n) {
  final para = StringBuffer();
  for (var i = 0; i < 6; i++) {
    para.write('<p>This is paragraph ${i + 1} of chapter $n. '
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod '
        'tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim '
        'veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea '
        'commodo consequat.</p>');
  }
  return '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter $n</title></head>
<body><h1>Chapter $n</h1>$para</body>
</html>''';
}

Future<Uint8List> _buildPdf(int pages) async {
  final doc = pw.Document();
  for (var i = 1; i <= pages; i++) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Text('PAGE $i', style: pw.TextStyle(fontSize: 64)),
        ),
      ),
    );
  }
  return doc.save();
}

Uint8List _buildCbz(_Spec spec) {
  final archive = Archive();
  for (var i = 0; i < spec.pages; i++) {
    final color = spec.colors[i % spec.colors.length];
    final page = img.Image(width: 1000, height: 1500);
    img.fill(page, color: color);
    img.drawString(
      page,
      'PAGE ${i + 1}',
      font: img.arial48,
      x: 410,
      y: 700,
      color: img.ColorRgb8(255, 255, 255),
    );
    final jpg = img.encodeJpg(page, quality: 80);
    final name = 'page_${(i + 1).toString().padLeft(3, '0')}.jpg';
    archive.addFile(ArchiveFile(name, jpg.length, jpg));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

class _Spec {
  _Spec(this.name, this.pages, this.colors);
  final String name;
  final int pages;
  final List<img.Color> colors;
}

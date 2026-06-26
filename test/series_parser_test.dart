import 'package:cb8_flutter/features/import/series_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ports a representative slice of CB8's `seriesParser.test.ts` so the Dart
/// parser is held to the same behaviour.
void main() {
  group('parseSeriesFromFilename', () {
    test('Title v01 -> series + volume', () {
      final r = parseSeriesFromFilename('Berserk v01.cbz');
      expect(r.seriesName, 'Berserk');
      expect(r.volumeNumber, 1);
      expect(r.chapterNumber, isNull);
    });

    test('Vol. and Ch. markers', () {
      final r = parseSeriesFromFilename('One Piece Vol. 3 Ch. 12.cbz');
      expect(r.seriesName, 'One Piece');
      expect(r.volumeNumber, 3);
      expect(r.chapterNumber, 12);
    });

    test('# issue number', () {
      final r = parseSeriesFromFilename('Saga #005.cbz');
      expect(r.seriesName, 'Saga');
      expect(r.chapterNumber, 5);
    });

    test('leading scanlation group is stripped', () {
      final r = parseSeriesFromFilename('[Group] Naruto v01.cbz');
      expect(r.seriesName, 'Naruto');
      expect(r.volumeNumber, 1);
    });

    test('leading release date is stripped, bare issue after volume', () {
      final r = parseSeriesFromFilename('199305 X-Force v1 022.cbz');
      expect(r.seriesName, 'X-Force');
      expect(r.volumeNumber, 1);
      expect(r.chapterNumber, 22);
    });

    test('numeric series name is not eaten', () {
      final r = parseSeriesFromFilename('20th Century Boys v05.cbz');
      expect(r.seriesName, '20th Century Boys');
      expect(r.volumeNumber, 5);
    });

    test('no markers -> all null (standalone)', () {
      final r = parseSeriesFromFilename('Some Standalone Graphic Novel.cbz');
      expect(r.seriesName, isNull);
      expect(r.volumeNumber, isNull);
      expect(r.chapterNumber, isNull);
    });
  });
}

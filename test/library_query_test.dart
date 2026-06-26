import 'package:cb8_flutter/data/sources/library_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LibraryQuery.copyWith', () {
    test('explicit null clears a nullable field (the "All" chip)', () {
      const q = LibraryQuery(mediaType: 'comic');
      expect(q.copyWith(mediaType: null).mediaType, isNull);
    });

    test('omitting a field leaves it unchanged', () {
      const q = LibraryQuery(mediaType: 'comic', search: 'x');
      final next = q.copyWith(favoritesOnly: true);
      expect(next.mediaType, 'comic');
      expect(next.search, 'x');
      expect(next.favoritesOnly, isTrue);
    });

    test('clearing search works', () {
      const q = LibraryQuery(search: 'naruto');
      expect(q.copyWith(search: null).search, isNull);
    });

    test('setting a field replaces it', () {
      const q = LibraryQuery(mediaType: 'comic');
      expect(q.copyWith(mediaType: 'book').mediaType, 'book');
    });
  });
}

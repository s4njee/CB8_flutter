import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Local SQLite database, mirroring CB8's schema (`src/main/db/schema/create.ts`)
/// trimmed to the single-user-on-device case. Multi-user/auth tables live on the
/// server and are reached via the remote source instead.

/// Media kind for a catalog row. CB8 stores this as the `media_type` text column.
class MediaTypes {
  static const comic = 'comic';
  static const book = 'book';
}

/// The core catalog row for every comic/book — CB8's `comics` table.
@DataClassName('ComicRow')
class Comics extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Platform-stable handle to the file. On desktop this is a path; on mobile it
  /// is a security-scoped URI (SAF / UIDocumentPicker) — see plan risks.
  TextColumn get uri => text().unique()();
  TextColumn get title => text()();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();

  /// 240x360 JPEG cover, stored inline like CB8's `cover_thumbnail` BLOB.
  BlobColumn get coverThumbnail => blob().nullable()();
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();

  /// Reading progress. `lastPage` for comics/PDF; `lastLocation` is an EPUB CFI.
  IntColumn get lastPage => integer().nullable()();
  TextColumn get lastLocation => text().nullable()();
  DateTimeColumn get lastRead => dateTime().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  TextColumn get mediaType => text().withDefault(const Constant(MediaTypes.comic))();

  // Parsed / scraped metadata.
  TextColumn get seriesName => text().nullable()();
  RealColumn get volumeNumber => real().nullable()();
  RealColumn get chapterNumber => real().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get summary => text().nullable()();
}

/// Per-book page bookmarks — CB8's `bookmarks` (user scoping dropped locally).
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get comicId => integer().references(Comics, #id, onDelete: KeyAction.cascade)();

  /// Page index for comics/PDF, or the EPUB CFI string stuffed into [location].
  IntColumn get page => integer().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Open/page-turn/complete log — CB8's `reading_history`, drives Recent shelf.
class ReadingHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get comicId => integer().references(Comics, #id, onDelete: KeyAction.cascade)();
  TextColumn get action => text()();
  IntColumn get page => integer().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

/// Favorited books — CB8's `user_favorites`.
class Favorites extends Table {
  IntColumn get comicId =>
      integer().references(Comics, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {comicId};
}

/// Named, media-typed collections — CB8's `libraries`.
class Libraries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get mediaType => text().withDefault(const Constant(MediaTypes.comic))();
  DateTimeColumn get dateCreated => dateTime().withDefault(currentDateAndTime)();
}

class LibraryComics extends Table {
  IntColumn get libraryId =>
      integer().references(Libraries, #id, onDelete: KeyAction.cascade)();
  IntColumn get comicId =>
      integer().references(Comics, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {libraryId, comicId};
}

/// Series->Volume->Chapter grouping containers — CB8's `folders`.
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get coverComicId =>
      integer().nullable().references(Comics, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get dateCreated => dateTime().withDefault(currentDateAndTime)();
}

class FolderComics extends Table {
  IntColumn get folderId =>
      integer().references(Folders, #id, onDelete: KeyAction.cascade)();
  IntColumn get comicId =>
      integer().references(Comics, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {folderId, comicId};
}

/// Free-form labels — CB8's `tags` / `comic_tags`.
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class ComicTags extends Table {
  IntColumn get comicId =>
      integer().references(Comics, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {comicId, tagId};
}

/// Saved remote servers (the hybrid model). Tokens live in the cookie jar, not
/// here — this table only remembers how to reach a CB8-compatible backend.
@DataClassName('ConnectionRow')
class Connections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text().unique()();
  TextColumn get lastUsername => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    Comics,
    Bookmarks,
    ReadingHistory,
    Favorites,
    Libraries,
    LibraryComics,
    Folders,
    FolderComics,
    Tags,
    ComicTags,
    Connections,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// Test/in-memory constructor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() =>
      driftDatabase(name: 'cb8'); // app-data dir on every platform
}

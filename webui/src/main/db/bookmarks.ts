import type { Db } from './pg';
import type { BookmarkResponse } from '../../shared/apiTypes';

/**
 * @module
 * Database Operations for Per-User Bookmarks
 *
 * Architecture overview for Junior Devs:
 * Owns the `bookmarks` table — a user saving a specific page (with an optional
 * note) in a comic. Straightforward create/list/delete, scoped per user. Free
 * functions taking the async DB handle, surfaced through `libraryDatabase.ts`.
 */

export async function createBookmark(
  db: Db,
  userId: number,
  comicId: number,
  page: number,
  note: string | null = null,
): Promise<BookmarkResponse & { userId: number; comicId: number }> {
  const row = (await db.get<{ id: number; user_id: number; comic_id: number; page: number; note: string | null; created_at: string }>(
    'INSERT INTO bookmarks (user_id, comic_id, page, note) VALUES (?, ?, ?, ?) RETURNING id, user_id, comic_id, page, note, created_at',
    [userId, comicId, page, note],
  ))!;
  return { id: row.id, userId: row.user_id, comicId: row.comic_id, page: row.page, note: row.note, createdAt: row.created_at };
}

export async function listBookmarks(
  db: Db,
  userId: number,
  comicId: number,
): Promise<BookmarkResponse[]> {
  const rows = await db.all<{ id: number; page: number; note: string | null; created_at: string }>(
    'SELECT id, page, note, created_at FROM bookmarks WHERE user_id = ? AND comic_id = ? ORDER BY page, id',
    [userId, comicId],
  );
  return rows.map((r) => ({ id: r.id, page: r.page, note: r.note, createdAt: r.created_at }));
}

export async function updateBookmark(db: Db, userId: number, bookmarkId: number, note: string | null): Promise<void> {
  await db.run('UPDATE bookmarks SET note = ? WHERE id = ? AND user_id = ?', [note, bookmarkId, userId]);
}

export async function deleteBookmark(db: Db, userId: number, bookmarkId: number): Promise<void> {
  await db.run('DELETE FROM bookmarks WHERE id = ? AND user_id = ?', [bookmarkId, userId]);
}

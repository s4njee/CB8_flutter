import type { Db } from './pg';

/**
 * @module
 * Database Operations for Per-User Favorites
 *
 * Architecture overview for Junior Devs:
 * Owns the `user_favorites` table — a simple per-(user, comic) "starred" flag.
 * Adding uses `ON CONFLICT DO NOTHING` so favoriting twice is harmless. Free
 * functions taking the async DB handle, surfaced through `libraryDatabase.ts`.
 */

export async function addFavorite(db: Db, userId: number, comicId: number): Promise<void> {
  await db.run('INSERT INTO user_favorites (user_id, comic_id) VALUES (?, ?) ON CONFLICT DO NOTHING', [userId, comicId]);
}

export async function removeFavorite(db: Db, userId: number, comicId: number): Promise<void> {
  await db.run('DELETE FROM user_favorites WHERE user_id = ? AND comic_id = ?', [userId, comicId]);
}

export async function isFavorite(db: Db, userId: number, comicId: number): Promise<boolean> {
  const row = await db.get('SELECT 1 FROM user_favorites WHERE user_id = ? AND comic_id = ?', [userId, comicId]);
  return row !== undefined;
}

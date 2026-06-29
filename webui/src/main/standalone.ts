/**
 * @module
 * Electron-Free Entry Point (Docker / VPS)
 *
 * Architecture overview for Junior Devs:
 * This is one of the app's three entry points. Unlike `index.ts` (the Electron
 * desktop/headless entry), this one has no Electron at all — no window, no IPC,
 * no menu. It connects to Postgres and starts the Fastify web server. It's what
 * runs inside the slim Docker image and on a plain server.
 *
 * Configuration comes entirely from environment variables:
 *   - DATABASE_URL : Postgres connection string, e.g. postgres://u:pw@host:5432/cb8 (required)
 *   - CB8_DATA_DIR : directory for image cache and uploads (default /var/lib/cb8)
 *   - CB8_PORT     : TCP port to listen on (default 8008)
 *   - CB8_HOST     : bind address (default 0.0.0.0)
 */

import * as path from 'node:path';
import { LibraryDatabase } from './libraryDatabase';
import { setImageCacheRoot, setUpscaleCacheRoot } from './imageResizer';
import { setUploadRoot } from './webServer/routes/upload';
import { buildServer } from './webServer/server';
import { startBoss, stopBoss } from './jobs/boss';

async function main(): Promise<void> {
  const dataDir = process.env.CB8_DATA_DIR ?? '/var/lib/cb8';
  const port = parseInt(process.env.CB8_PORT ?? '8008', 10);
  const host = process.env.CB8_HOST ?? '0.0.0.0';

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required (a Postgres connection string).');
  }

  setImageCacheRoot(path.join(dataDir, 'image-cache'));
  setUpscaleCacheRoot(process.env.CB8_UPSCALE_CACHE_DIR ?? path.join(dataDir, 'upscale-cache'));
  setUploadRoot(dataDir);

  console.log('[CB8] Standalone startup: connecting to Postgres');
  const db = new LibraryDatabase(databaseUrl);
  await db.initialize();
  console.log('[CB8] Standalone startup: database ready');

  // Producer-only pg-boss: the API only enqueues jobs (scans, backfills); the
  // separate cb8-worker process drains them. No maintenance/cron runs here.
  await startBoss(databaseUrl, { producerOnly: true });

  const fastify = await buildServer(db);
  await fastify.listen({ port, host });
  console.log(`[CB8] Web UI listening on http://${host}:${port}`);

  const shutdown = async (): Promise<void> => {
    console.log('[CB8] Shutting down…');
    try { await fastify.close(); } catch { /* ignore */ }
    try { await stopBoss(); } catch { /* ignore */ }
    try { await db.close(); } catch { /* ignore */ }
    process.exit(0);
  };
  process.on('SIGINT', () => { void shutdown(); });
  process.on('SIGTERM', () => { void shutdown(); });
}

main().catch((err) => {
  console.error('[CB8] Standalone startup failed:', err);
  process.exit(1);
});

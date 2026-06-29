# CB8 Study Guide

A guided tour of the codebase for someone who just cloned it. The goal is that
after reading this you can answer two questions for any task: **"what does this
file do?"** and **"where do I make my change?"**

- For the high-level system design, read [ARCHITECTURE.md](../ARCHITECTURE.md).
- For the terse "how do I add X" checklist, read [CONTRIBUTING.md](../CONTRIBUTING.md).
- This file sits in between: it explains the layout file-by-file and points you
  at the right edit site for common tasks.

---

## 1. The 60-second mental model

CB8 is one TypeScript codebase that ships in three shapes:

| Mode | Entry point | What runs |
| --- | --- | --- |
| Desktop app | `src/main/index.ts` | Electron window + embedded HTTP server + SQLite |
| Headless server | `src/main/index.ts --headless` | Same as desktop, no window |
| Standalone (Docker/VPS) | `src/main/standalone.ts` | HTTP server + SQLite, no Electron |

The key insight that explains the whole repo: **the UI is a web app, even on the
desktop.** The Electron window doesn't talk to the database directly — it loads
the React SPA from `http://127.0.0.1:<port>` and the SPA calls a normal HTTP API.
So the data flow is almost always:

```
React component → src/renderer/lib/api/* → fetch('/api/...') →
  src/main/webServer/routes/* → src/main/db/* → SQLite
```

Electron's native bridge (IPC) is used for **only** a handful of things a browser
can't do: file pickers, window controls, opening a file from the OS. Everything
else — listing comics, reading pages, progress, auth — is HTTP.

The three source roots:

- **`src/main/`** — Node side. Database, ingest, archive readers, HTTP server,
  Electron lifecycle. Anything that touches the filesystem or `better-sqlite3`.
- **`src/renderer/`** — the React 18 SPA (Vite + Tailwind + shadcn/ui).
- **`src/shared/`** — pure TypeScript usable from both sides (sorting, types,
  validators). **No DOM, no Node APIs** — that's the rule that keeps it shareable.

---

## 2. Suggested reading order

If you read files in this order you'll build up the mental model the way the data
flows, instead of getting lost:

1. **`src/shared/types.ts`** — the core `MediaRecord` and query types. Almost
   everything is a comic/book record; learn its shape first.
2. **`src/main/index.ts`** — how the app boots (window vs headless), and the
   `createWindow` / `startHeadless` split.
3. **`src/main/db/schema/create.ts`** — the SQL schema. This *is* the data model.
4. **`src/main/libraryDatabase.ts`** — the façade every DB read/write goes through.
5. **`src/main/webServer/server.ts`** — how an HTTP request gets routed.
6. **`src/main/webServer/routes/comics.ts`** — a representative route handler.
7. **`src/renderer/App.tsx` + `components/layout/AppShell.tsx`** — how the UI
   mounts and where routes are declared.
8. **`src/renderer/lib/api/comics.ts`** — how the UI calls the server.
9. **`src/renderer/pages/AllPage.tsx`** — a page that ties a route to data to UI.

---

## 3. Main process — `src/main/`

### 3.1 Lifecycle & entry points

| File | Responsibility | Edit it when… |
| --- | --- | --- |
| `index.ts` | Electron entry. `app.ready` → `createWindow()` (desktop) or `startHeadless()`. Owns the `open-file` handler and the `before-quit` shutdown chain. | You change app startup, window creation, or OS file-open behavior. |
| `standalone.ts` | Electron-free entry for Docker/VPS. Builds the Fastify server and listens on `CB8_HOST:CB8_PORT`, reads paths from `CB8_DATA_DIR`. | You change how the server boots *without* Electron. |
| `menu.ts` | Builds the native app menu and its destructive actions (Clear DB, Reset Admin Password, Open Recent). Talks to the app only via an injected `MenuContext`. | You add/change a native menu item. |
| `preload.ts` | The `contextBridge` that exposes `electronAPI` to the renderer. Whitelist is generated from `src/shared/ipcTypes.ts`. | Rarely — only when changing the IPC bridge mechanics. |
| `adminReset.ts` | Implements the menu's "Reset Admin Password". | Changing admin password reset flow. |
| `sevenZipPath.ts` | Finds a usable `7z`/`7zz`/`7za` binary (honors `CB8_SEVENZIP_PATH`). | 7-Zip discovery issues. |
| `logger.ts` | App-wide logging helper. | — |
| `utils/timeout.ts` | `withTimeout` helper used by ingest. | — |

### 3.2 Database — `src/main/db/`

The pattern: **`libraryDatabase.ts` is a thin façade.** It opens one
`better-sqlite3` handle and exposes one method per operation; each method
delegates to a free function in a per-domain file. So to change a query you edit
the domain file, not the façade (unless you're adding a brand-new method).

| File | Owns |
| --- | --- |
| `libraryDatabase.ts` | The façade. One method per logical DB operation; delegates to the files below. Add a method here when you expose a new DB operation to the rest of the app. |
| `schema/open.ts` | Opens the DB, sets pragmas (WAL, foreign keys), wipes-and-recreates on corruption, runs migrations + repairs. Exposes `DbStartupError`. |
| `schema/create.ts` | The `SCHEMA` string — every table definition. **This is the data model.** |
| `schema/migrations.ts` | Versioned migrations (`CURRENT_VERSION`). Add a migration here when you change `create.ts`. |
| `schema/repairs.ts` | Idempotent post-startup data fixes, gated by `app_meta` flags. |
| `comics.ts` | Comic CRUD, series metadata, paged user queries (`queryComicsForUser`), continue/recently-read lists. Query construction lives in `comicQueryHelpers.ts`; metadata update mapping lives in `comicMetadataHelpers.ts`. |
| `folders.ts` | Folder CRUD and folder membership. Series/volume/chapter rollup SQL lives in `folderHierarchyQueries.ts`, with scope/query/record helpers in sibling `folder*Helpers.ts` files. |
| `libraries.ts` | Libraries (`comic` vs `book` buckets) and their membership. |
| `tags.ts` | Tag CRUD + bulk ops. |
| `users.ts` | User table, admin counts, credential-account upserts that bridge to better-auth. |
| `progress.ts` | Per-user `user_progress` rows; powers continue/recently-read. |
| `bookmarks.ts` / `favorites.ts` / `history.ts` | Side tables, self-explanatory. |
| `appMeta.ts` | Single-row config `get`/`set` against `app_meta`. |
| `maintenance.ts` | `clearLibrary` — truncate catalog but keep users/auth. |
| `cast.ts` / `transaction.ts` / `types.ts` | Small shared helpers (row casting, transaction wrapper, DB types). |

> **Schema change recipe:** edit `create.ts` → add a numbered migration in
> `migrations.ts` (bump `CURRENT_VERSION`) → add the read/write in the relevant
> domain file → expose via `libraryDatabase.ts` → add a test like
> `db/comics.query.test.ts`.

### 3.3 Ingest pipeline (getting files into the library)

| File | Responsibility |
| --- | --- |
| `fileScanner.ts` | Stable public surface (`FileScannerImpl`) used by the upload route. Delegates to `IngestService`. |
| `ingestService.ts` | The worker: prepares inserts, runs bounded workers, extracts covers, batches inserts in one transaction, parses series info. Tune concurrency via `CB8_INGEST_CONCURRENCY`. |
| `ingestDiscovery.ts` | Recursive and incremental directory discovery. It only collects matching file paths. |
| `ingestQueue.ts` | Async producer/consumer queue used by ingest workers. |
| `ingestPathHelpers.ts` | Extension sets and series-name inference from scan-root folders. |
| `archiveLoader.ts` | Opens CBZ (yauzl) and CBR (unrar/7-Zip). Provides cover image and page reads. |
| `archiveEntryHelpers.ts` | Filters, orders, and normalizes archive entries. |
| `archivePageHelpers.ts` | Page index validation and byte-bounded in-memory page cache. |
| `archiveProcessHelpers.ts` | Generic `unrar`/`node-7z` process timeout and stream helpers. |
| `epubCoverExtractor.ts` / `pdfCoverExtractor.ts` | Format-specific cover + page-count helpers. |
| `imageDecoder.ts` | Decodes odd formats (e.g. JXL) so `sharp` can handle them. |
| `thumbnailGenerator.ts` | Encodes cover thumbnails (+ placeholder on failure). |
| `imageResizer.ts` | On-demand page resizing via `sharp`, cached on disk under `<userData>/image-cache`. |
| `metadataScraper.ts` | External metadata lookups (used by the comics route). |
| `seriesParser.ts` | Pure filename parser: `name v01 c003.cbz` → `{ seriesName, volumeNumber, chapterNumber }`. Well unit-tested. |
| `ingestErrorLog.ts` | Classifies/persists per-file failures so the upload UI can show what dropped and why. |
| `folderScheduler.ts` | Schedules folder rescans. |

### 3.4 IPC handlers — `src/main/ipc/`

The IPC surface is intentionally tiny — most features go through HTTP instead.

| File | Channels |
| --- | --- |
| `ipc/index.ts` | Composes `registerIpcHandlers` (re-exported by `ipcHandlers.ts`). |
| `ipc/libraryHandlers.ts` | Native file/dir pickers (`dialog:open-file`, `dialog:open-directory`). |
| `ipc/readingHandlers.ts` | `reading:get-comic-by-path` — turn an OS file-open into a comic id. |
| `ipc/webServerHandlers.ts` | `webserver:get-settings` / `set-settings`; server lifecycle from the renderer's view. |
| `ipc/appHandlers.ts` | Window controls + `shell:open-path`. |

> **Add an IPC channel:** declare it in `src/shared/ipcTypes.ts` (this updates the
> preload allowlist automatically) → handle it in the right `ipc/*Handlers.ts` →
> call it from `src/renderer/lib/hostBridge.ts`. Only do this for native
> capabilities a browser lacks; for product data, add an HTTP route instead.

### 3.5 Embedded web server — `src/main/webServer/`

This is where most backend work happens. A Fastify instance serves the SPA and
the entire `/api`.

| File | Responsibility | Edit it when… |
| --- | --- | --- |
| `webServer.ts` (parent dir) | Public façade: `startWebServer(db, port, host)` + `getLanIp()`. | Changing how the server is started/stopped. |
| `webServer/server.ts` | `buildServer(db)`: rate-limit hooks, CORS, mounts `/api/auth/*` (better-auth), `/api/*` (`dispatchApi`), and static SPA. | Adding a top-level mount or global hook. |
| `webServer/middleware.ts` | Cookie parsing, loopback detection, body reading with size limits, guest-access policy, initial-admin bootstrap, `sendJson`/`sendError`. | Cross-cutting request behavior. |
| `webServer/auth.ts` | better-auth setup against the existing SQLite handle; bridges to our `users` table; persists `auth_secret`. | Auth/session behavior. |
| `webServer/context.ts` | `RequestContext` and `RouteHandler` types + `requireAdmin`. | Adding shared per-request context. |
| `webServer/routes/*.ts` | **One file per resource.** Each exports `handle: RouteHandler` returning `true` when it owns the request. | **Most endpoint work happens here.** |
| `webServer/routes/validation.ts` | Reusable request helpers: `requireCurrentUser`, `requireComic`, `readJsonBody`, `parseBoundedInteger`, `readPageIndex`. | Use these in new handlers instead of hand-rolling parsing. |
| `webServer/routes/*RouteHelpers.ts` | Pure parsing, response, and policy helpers for route modules. | Put reusable route rules here with colocated tests. |
| `webServer/routes/routeResponseHelpers.ts` | Shared paged comic/book response formatting. | Use for endpoints that return `{ records, totalCount }`. |
| `webServer/archiveCache.ts` | LRU of open archive handles keyed by comic id; concurrent page fetches share one open handle (`withArchive`). | Page-read performance/caching. |
| `webServer/ingest.ts` | Bridges the upload route to `IngestService` with a streaming event interface. | Upload streaming behavior. |
| `webServer/mapping.ts` | `toWebRecord` / `overlayUserState` — internal `MediaRecord` → API shape + per-user overlay. | Changing what the API returns for a comic. |
| `webServer/rateLimit.ts` | Login + forgot-password limiters. | Rate-limit tuning. |
| `webServer/safeFetch.ts` | SSRF-safe outbound HTTP for the scraper. | Outbound request safety. |
| `webServer/emailSender.ts` | better-auth email hooks; no-ops without SMTP. | Email/verification. |

The route files: `auth.ts`, `users.ts`, `comics.ts`, `folders.ts`,
`libraries.ts`, `progress.ts`, `tags.ts`, `upload.ts`, `staticFiles.ts`.

> **Add an endpoint recipe:** pick the resource file in `routes/` → parse ids with
> a regex + `parseInt` → use the `validation.ts` helpers → return via `sendJson`/
> `sendError` → if it's a new response shape, define the type in
> `src/shared/apiTypes.ts` and import it on both sides → add/extend a route test
> (see `webServer/authRoutes.test.ts`).

---

## 4. Renderer — `src/renderer/`

A hash-routed React SPA. **Server data** lives in `@tanstack/react-query`;
**UI state that must survive navigation** lives in Zustand stores. Don't reach for
Zustand to cache server data — that's React Query's job.

### 4.1 Entry & shell

| File | Responsibility |
| --- | --- |
| `main.tsx` | React root mount. |
| `App.tsx` | Wraps app in `QueryClientProvider` + `HashRouter`; does session bootstrap. |
| `components/layout/AppShell.tsx` | The persistent layout (navbar, sidebar, mobile tab bar, reader overlay) and **the `<Routes>` declaration**. Listens to host-bridge events. Add a new route here. |
| `index.html` / `globals.css` | HTML shell and global/Tailwind styles. |

### 4.2 Pages — `src/renderer/pages/`

One file per top-level route. To add a page: create it here, then wire it into
`AppShell`'s `<Routes>`.

| File | Route(s) |
| --- | --- |
| `AllPage` / `RecentPage` / `ContinuePage` | Library-wide views. |
| `LibraryPage` | A single library by id. |
| `FolderPages.tsx` | Folder + folder series/volume/chapter drill-down. |
| `BrowsePages.tsx` | Global series/volume/chapter drill-down. |
| `TagPage` | Tag-scoped listing. |
| `ReaderPage.tsx` | Resolves the record then picks `ComicReader` / `EpubReader` / `PdfReader`. |
| `AuthPages.tsx` | Reset-password and verified pages. |

### 4.3 Components

| Folder | What's in it | Edit when… |
| --- | --- | --- |
| `components/layout/` | `Navbar`, `Sidebar`, `TabBar`, `TabPanel`, `SortSheet`, `ReaderOverlay`. | Changing chrome/navigation. |
| `components/library/` | `ComicCard`, `FolderCard`, `GroupCard`, `LibraryGrid`, `ContextMenu`(+`ContextMenuDialogs`), `ContinueShelf`, `Breadcrumb`, `FilterStrips`, `SelectionBar`. | Changing how the grid/cards/menus look or behave. |
| `components/reader/` | `ComicReader`, `EpubReader`, `PdfReader`, `ReaderToolbar`, presentational `*View` files, controls/sheets/types, and tested rule helpers such as `comicReaderRules`, `pdfReaderRules`, `epubReaderInteractions`, `epubReaderIframeEvents`, `epubReaderLinks`, and `epubRenditionTheme`. | Reader UI behavior (see `docs/READER.md`). |
| `components/admin/` | `AdminModal` + tab panels: `Login`, `Signup`, `ForgotPassword`, `ResetPassword`, `Settings`, `Upload`, `AddPath`, `Users`, `AdminMenu`. | Auth/settings/upload UI. |
| `components/ui/` | shadcn-style primitives over Radix (button, dialog, sheet, slider, select, tabs, toast…). | Reuse these before inventing new primitives. |

### 4.4 Hooks, lib, stores

| File | Responsibility |
| --- | --- |
| `hooks/useDrop.ts` | Drag-and-drop ingest path. |
| `hooks/useComicGestures.ts` / `useComicKeyboard.ts` / `useReaderViewportControls.ts` | Reader gesture, keyboard, fullscreen, and orientation-lock handling. |
| `hooks/useInfiniteComics.ts` | Infinite-scroll paging over the library. |
| `hooks/usePullToRefresh.ts` / `useWakeLock.ts` / `useToast.ts` | Mobile/UX helpers. |
| `lib/api.ts` | **Barrel only** — re-exports `./api/index`. Keep UI imports pointed at `@/lib/api`. |
| `lib/api/client.ts` | Owns `get`/`post`/`put`/`del` fetch + error handling. |
| `lib/api/stream.ts` | `postIngestStream()` for NDJSON ingest streams. |
| `lib/api/types.ts` | Renderer-facing API types. (Shared shapes go in `src/shared/apiTypes.ts`.) |
| `lib/api/{comics,folders,libraries,reading,browse,tags,admin,users,auth,settings,metadata}.ts` | Endpoint groups by domain. |
| `lib/hostBridge.ts` | Optional Electron bridge; no-ops in a plain browser so the SPA degrades gracefully. |
| `lib/queryClient.ts` | React Query setup + `invalidateLibraryQueries`. |
| `lib/dropUtils.ts` / `lib/utils.ts` / `lib/errors.ts` | `cn` helper, drop helpers, error types. |
| `store/readerStore.ts` | Reader prefs (zoom, direction, spread, EPUB font/theme), persisted to `localStorage`. |
| `store/selectionStore.ts` | Multi-select state for bulk operations. |
| `store/uiStore.ts` | Global UI state. |

> **Add a renderer API call recipe:** pick the domain module in `lib/api/` → use
> `get/post/put/del` from `client.ts` → put types in `api/types.ts` (or
> `shared/apiTypes.ts` if shared) → call it from a component through a React Query
> hook so caching/invalidation is consistent.

---

## 5. Shared — `src/shared/`

Pure modules, no DOM, no Node. Importable from both server and renderer. Most have
a colocated `.test.ts` run by Vitest.

| File | Responsibility |
| --- | --- |
| `types.ts` | Canonical `MediaRecord`, `QueryOptions`, `QueryResult`, `ScanProgress`, `NavigationState`. |
| `apiTypes.ts` | Shapes returned by the HTTP API, shared by server + renderer. |
| `ipcTypes.ts` | Source of truth for the IPC channel surface (drives the preload allowlist). |
| `mediaTypes.ts` | File-extension → `'comic' \| 'book'` mapping. |
| `naturalSort.ts` | Natural filename comparison (`page2 < page10`). |
| `coverSelection.ts` | Picks the cover entry from an archive's image list. |
| `imageFilter.ts` | `isImageFile` extension check. |
| `scaleFit.ts` | Fit-width/fit-height math for the comic reader. |
| `filterLogic.ts` | Filter-preset normalization shared by sidebar + query routes. |
| `statusFormat.ts` / `windowTitle.ts` | Small formatting helpers. |
| `lru.ts` | Byte-bounded LRU used by `archiveLoader`'s in-archive page cache. |
| `dropValidator.ts` | Drag-and-drop file-list validation. |
| `epubTheme.ts` | EPUB theme injection helpers. |

---

## 6. "I want to change X — where do I go?"

| Goal | Start here |
| --- | --- |
| Add a column / table | `db/schema/create.ts` → `db/schema/migrations.ts` → domain file → `libraryDatabase.ts` |
| Add or change an API endpoint | `webServer/routes/<resource>.ts` (+ `routes/validation.ts`, `shared/apiTypes.ts`) |
| Change what a comic record returns to the UI | `webServer/mapping.ts` |
| Add a UI page | `pages/` + register in `components/layout/AppShell.tsx` |
| Add a UI call to the server | `lib/api/<domain>.ts` (via `client.ts`) |
| Change the library grid / cards | `components/library/` |
| Change reader behavior | `components/reader/` + `store/readerStore.ts`; start with the relevant `*Rules.ts`/interaction helper before editing the component (see `docs/READER.md`) |
| Change how files are imported | `ingestService.ts`; use `ingestDiscovery.ts`, `ingestPathHelpers.ts`, `ingestQueue.ts`, `seriesParser.ts`, and `archiveLoader.ts` for their specific boundaries |
| Change page image rendering/caching | `imageResizer.ts` + `webServer/archiveCache.ts` |
| Add a native (Electron-only) capability | `shared/ipcTypes.ts` → `ipc/*Handlers.ts` → `lib/hostBridge.ts` |
| Change app startup | `main/index.ts` (desktop/headless) or `main/standalone.ts` (Docker) |
| Change auth / sessions | `webServer/auth.ts` + `webServer/routes/auth.ts` |

---

## 7. Build, run, test

| Command | What it does |
| --- | --- |
| `pnpm install --frozen-lockfile` | Install deps. |
| `pnpm start` | Run the Electron desktop app. |
| `pnpm start:headless` | Run the server with no window. |
| `pnpm dev:renderer` | Vite dev server for the SPA (proxies `/api` to the CB8 server). Run alongside `start:headless` for fast frontend work. |
| `pnpm test` | Vitest **through Electron's Node runtime** — required because `better-sqlite3` is built for Electron's ABI. |
| `pnpm typecheck` | `tsc --noEmit`. |
| `pnpm build:renderer` | Build the SPA bundle. |
| `pnpm build:standalone` | Build the Electron-free Node bundle for Docker/VPS. |

Before handing off: run `pnpm typecheck`, `pnpm test`, and `pnpm build:renderer`,
and mention any skipped check. (The renderer build emits a known chunk-size
warning — not a failure.)

### Config knobs

- **Env vars:** `CB8_HEADLESS`, `CB8_DATA_DIR`, `CB8_PORT`, `CB8_HOST`,
  `CB8_INGEST_CONCURRENCY`, `CB8_SEVENZIP_PATH`, `CB8_UNRAR_PATH`,
  `CB8_ARCHIVE_LIST_TIMEOUT_MS`, `CB8_ARCHIVE_EXTRACT_TIMEOUT_MS`,
  `BETTER_AUTH_SECRET`.
- **Persistent settings** live in the `app_meta` table.
- **On-disk artifacts:** `library.db` (+WAL/SHM), `image-cache/`, `web-uploads/`,
  ingest-error log — under the platform `userData` dir (or `CB8_DATA_DIR`).

---

## 8. Conventions worth internalizing early

- **Product data goes over HTTP, native capabilities go over IPC.** When in doubt,
  it's HTTP.
- **`src/shared/` stays pure.** If you're tempted to import `fs` or touch
  `document` there, the code belongs in `main/` or `renderer/` instead.
- **The DB façade pattern:** read/write logic lives in `db/<domain>.ts`;
  `libraryDatabase.ts` just exposes it. Don't put SQL in routes.
- **Types that cross the wire live in `src/shared/apiTypes.ts`** and are imported
  by both server and renderer, so the contract can't drift.
- **Schema changes always need a migration.** Editing `create.ts` without bumping
  `migrations.ts` breaks existing databases.

# AGENTS.md

Guidance for coding agents working in this repository.

## Project Shape

CB8 is an Electron + TypeScript comic/book reader with a shared Fastify HTTP
API and a React SPA frontend.

- `src/main/` owns Electron lifecycle, the embedded/headless/standalone web
  server, SQLite access, ingest, archive loading, IPC, and packaging-facing
  Node code.
- `src/renderer/` is the active frontend. It is a React 18 + Vite +
  shadcn/Tailwind SPA served by the embedded server and loaded by Electron from
  `http://127.0.0.1:<port>`.
- `src/shared/` contains pure shared TypeScript utilities and types.
- `src/web/` was the old vanilla SPA and is no longer present on this branch.

## Useful Commands

Run these from the repo root:

```sh
pnpm install --frozen-lockfile
pnpm run typecheck
pnpm test
pnpm build:renderer
pnpm start
pnpm run package
```

`pnpm test` intentionally runs Vitest under Electron's Node runtime through
`scripts/run-vitest-electron.mjs`, because `better-sqlite3` is rebuilt for
Electron's Node ABI. Running plain `vitest` under system Node can skip or fail
DB-backed tests.

For DB-backed perf work, the search benchmark is:

```sh
ELECTRON_RUN_AS_NODE=1 ./node_modules/.bin/electron scripts/bench-search.mjs --rows 100000 --runs 5
```

## Code Map

### Main Process / Server

| Concern | Files |
| --- | --- |
| Electron lifecycle, window, headless mode | `src/main/index.ts` |
| Standalone Node entry | `src/main/standalone.ts` |
| Application menu | `src/main/menu.ts` |
| IPC registration | `src/main/ipc/{index,libraryHandlers,readingHandlers,webServerHandlers,appHandlers}.ts` |
| IPC channel types | `src/shared/ipcTypes.ts` |
| Server bootstrap and raw-route adapter | `src/main/webServer.ts`, `src/main/webServer/server.ts` |
| Web routes | `src/main/webServer/routes/{auth,comics,folders,libraries,progress,tags,upload,users,staticFiles}.ts` |
| Middleware, auth gates, body limits, initial admin | `src/main/webServer/middleware.ts`, `src/main/webServer/context.ts` |
| Better-auth wiring | `src/main/webServer/auth.ts` |
| Rate limiting | `src/main/webServer/rateLimit.ts` |
| SSRF-safe remote fetch | `src/main/webServer/safeFetch.ts` |
| Archive handle cache | `src/main/webServer/archiveCache.ts` |
| Web record mapping | `src/main/webServer/mapping.ts` |

### Database / Catalog

| Concern | Files |
| --- | --- |
| Schema, migrations, repairs | `src/main/db/schema/{create,migrations,open,repairs,index}.ts` |
| DB facade | `src/main/libraryDatabase.ts` |
| Comics and search queries | `src/main/db/comics.ts` |
| Folder hierarchy and folder membership | `src/main/db/folders.ts` |
| Libraries, tags, users | `src/main/db/{libraries,tags,users}.ts` |
| Per-user state | `src/main/db/{progress,bookmarks,history,favorites}.ts` |
| App metadata and maintenance | `src/main/db/{appMeta,maintenance}.ts` |

### Ingest / Archive / Media

| Concern | Files |
| --- | --- |
| File scanning and ingest orchestration | `src/main/fileScanner.ts`, `src/main/ingestService.ts` |
| Archive open/page extract | `src/main/archiveLoader.ts` |
| 7-Zip binary lookup | `src/main/sevenZipPath.ts` |
| JXL/odd image decode | `src/main/imageDecoder.ts` |
| EPUB/PDF cover and page-count helpers | `src/main/{epubCoverExtractor,pdfCoverExtractor}.ts` |
| Thumbnail generation | `src/main/thumbnailGenerator.ts` |
| On-disk image resize cache | `src/main/imageResizer.ts` |
| Ingest error log | `src/main/ingestErrorLog.ts` |
| Series parser | `src/main/seriesParser.ts` |

### Renderer

| Concern | Files |
| --- | --- |
| App shell and routing | `src/renderer/App.tsx`, `src/renderer/components/layout/AppShell.tsx` |
| Pages | `src/renderer/pages/*.tsx` |
| Library cards/grid/context/selection | `src/renderer/components/library/*.tsx` |
| Readers | `src/renderer/components/reader/{ComicReader,EpubReader,PdfReader,ReaderToolbar}.tsx` |
| Admin panels | `src/renderer/components/admin/*.tsx` |
| shadcn/Radix primitives | `src/renderer/components/ui/*.tsx` |
| API client | `src/renderer/lib/api.ts` barrel + domain modules under `src/renderer/lib/api/` |
| Electron host bridge | `src/renderer/lib/hostBridge.ts` |
| React Query setup | `src/renderer/lib/queryClient.ts` |
| Zustand stores | `src/renderer/store/*.ts` |
| Global styles | `src/renderer/globals.css`, `tailwind.config.js` |

### Build / Packaging

| Concern | Files |
| --- | --- |
| Electron Forge | `forge.config.ts` |
| Main/preload Vite builds | `vite.main.config.ts`, `vite.preload.config.ts` |
| Renderer Vite build | `vite.renderer.config.ts` |
| Standalone build | `scripts/build-standalone.mjs` |
| Docker/systemd/k8s | `packaging/` |

## IPC Rules

Most product operations go through the HTTP API, not IPC. Add IPC only for
genuine shell concerns such as native dialogs, window controls, shell-open, and
web-server host settings.

When adding or changing IPC:

1. Update `src/shared/ipcTypes.ts`.
2. Register the handler in the matching `src/main/ipc/*Handlers.ts` module.
3. Expose a browser-safe helper in `src/renderer/lib/hostBridge.ts`.
4. Run `pnpm run typecheck`.

The preload bridge whitelists channels from the shared IPC type maps. Missing
channels fail at runtime.

## Testing Expectations

- Keep pure shared logic covered under `src/shared/*.test.ts`.
- DB and route tests should use deterministic temp databases and run through
  the default `pnpm test` command.
- Avoid relying on local comic collections.
- Run `pnpm run typecheck` before trusting main-process, route, IPC, or
  renderer changes.
- Run `pnpm build:renderer` after frontend changes.

## Safety Notes

- Do not delete underlying comic/book files when removing library records.
  Library removal should update the database only.
- New state-mutating web routes must be admin-gated (`requireAdmin`) or
  host-gated (`isHostConnection`) as appropriate.
- Keep remote fetching behind `safeFetchBuffer` unless there is a deliberate
  reason and equivalent SSRF protection.
- The desktop app binds locally unless LAN sharing is enabled; headless and
  standalone deployments may bind to `0.0.0.0`.
- Keep generated/build output out of commits: `node_modules/`, `dist/`,
  `.vite/`, `out/`, local libraries, archives, and scratch output should not be
  committed unless intentionally added as fixtures.

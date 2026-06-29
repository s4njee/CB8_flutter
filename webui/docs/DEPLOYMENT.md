# Deployment Guide

CB8 can run as a desktop app, a headless Electron process, or a standalone Node
server. All modes use the same SQLite database and the same React bundle built
to `dist/web`.

## Build Targets

```sh
pnpm build:renderer      # build the React SPA into dist/web
pnpm build:standalone    # build dist/standalone.mjs
pnpm package             # build an Electron desktop package for this OS
```

Run `pnpm run typecheck` and `pnpm test` before packaging a release.

## Desktop

Desktop mode starts the embedded server and opens an Electron window pointed at
`http://127.0.0.1:<port>`.

```sh
pnpm start
pnpm package
```

The packaged app serves the built `dist/web` assets.

## Headless

Headless mode still uses Electron's runtime, but opens no window:

```sh
CB8_HEADLESS=1 pnpm start
```

Useful environment variables:

- `CB8_DATA_DIR` — location for `library.db`, uploads, and image cache.
- `CB8_HOST` — bind address. Use `127.0.0.1` for local-only or `0.0.0.0` for LAN.
- `CB8_PORT` — HTTP port.

## Standalone Node

The standalone bundle skips Electron and runs `src/main/standalone.ts` through a
plain Node entry.

```sh
pnpm build:renderer
pnpm build:standalone
node dist/standalone.mjs
```

Standalone deployments need Node 20+ and a usable 7-Zip executable on `PATH`, or
`CB8_SEVENZIP_PATH` pointing at `7z`, `7zz`, or `7za`.

## Docker

Docker packaging lives under `packaging/docker/`.

The container should mount a persistent data directory for the SQLite database
and cache files. For a LAN-only home deployment, bind to `0.0.0.0` inside the
container and publish the port only on the trusted network.

## First Admin Account

On first boot, CB8 creates an `admin` user and prints the generated password to
stdout. The same password is visible in Settings until it is changed.

If you lose the initial password after it has been cleared, reset the admin
through the desktop menu if available, or recreate the database and rescan the
library.

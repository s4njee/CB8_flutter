# CB8 Documentation Index

Use this file as the map for current vs historical documentation.

## Current Sources

- `README.md` — project overview, install targets, first-run notes, and development commands.
- `ARCHITECTURE.md` — implementation architecture notes.
- `docs/STUDY_GUIDE.md` — junior-dev onboarding tour: what each file does and where to edit for common tasks.
- `typedoc.json` — TypeDoc config. Run `pnpm docs:api` to generate browsable HTML API docs from the in-source doc blocks into `docs/api/`.
- `docs/DEPLOYMENT.md` — release, Docker, standalone, and service deployment details.
- `docs/READER.md` — reader UI behavior and supported formats.
- `CONTRIBUTING.md` — new-contributor setup and "how to add X" guide.
- `docs/diagrams.md` — small Mermaid diagrams for common request flows.
- `docs/examples/` — copyable examples for adding features.

> Historical planning docs (an earlier Go/Postgres direction's `requirements.md`,
> `design.md`, `tasks.md`, and the `docs/legacy/` plan archive) were removed when
> CB8 was vendored into the Flutter monorepo under `webui/`. They remain in the
> standalone CB8 repo if needed for context.

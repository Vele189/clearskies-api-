# ClearSkies — API

The read API and the drafting assistant: burden scores on an H3 resolution 8
grid, the drill-down behind each one, and a document drafted from the statute
corpus with every citation verified.

FastAPI, asyncpg, and Postgres with PostGIS, h3 and pgvector.

## This repository is generated

It is produced from [`Vele189/ClearSkies`](https://github.com/Vele189/ClearSkies)
by `make split`, which rewrites that repository's `api/` directory into the root
of this one with `git subtree split`, keeping the commits that touched it.

**Send changes there, not here.** A commit made in this repository is not
carried back and is overwritten by the next sync. The monorepo's `docs/repos.md`
explains the arrangement and how to recover such a commit if one happens
anyway.

Some things this service depends on live only in the monorepo, and that is
deliberate rather than an oversight:

| What | Where | Why it stayed |
|---|---|---|
| The methodology | `docs/methodology.md` | The paper is the authority on what the numbers mean. The service implements it; it does not define it. |
| The scoring package | `scoring/` | Nothing here imports it. Scores are computed by the pipeline and written to the database. |
| The ingestion pipeline | `etl/` | Same: it writes, this reads. |
| The statute corpus build | `assistant/` | Builds and seals corpus versions. This service only retrieves from the sealed ones. |
| The local database image | `infra/postgres/` | One Dockerfile compiling h3-pg, in one place. The compose file here builds it from the monorepo over git. |
| `check_requirements_sync.py` | `scripts/` | Runs in the monorepo's CI, over both files at once. |

## Running it

```
python -m venv .venv && .venv/bin/pip install -e ".[dev]"
cp .env.example .env      # at least DATABASE_URL
.venv/bin/uvicorn app.main:app --reload --port 8000
```

`http://localhost:8000/docs` is the schema. `/health` answers whether the
database is reachable and which Postgres extensions are actually loaded, which
is the cheap way to tell a custom image from a stock Postgres — the single most
likely thing to be silently wrong about this stack.

A database is `docker compose up -d db` here, or `make up` in the monorepo, or a
Neon branch. Migrations are applied by hand, never at startup:

```
python -m app.migrate up        # uses DATABASE_URL_UNPOOLED when it is set
python -m app.migrate verify
```

The runner holds a session-level advisory lock so that two runners queue rather
than interleave, and PgBouncer's transaction mode does not keep that lock — so
migrations go over the direct connection string, not the pooled one.

## The container

```
docker build -t clearskies-api .
docker run --rm -p 8000:8000 -e DATABASE_URL=... clearskies-api
```

`python:3.12-slim`, `requirements.txt` installed as its own layer, uvicorn under
an unprivileged uid. `requirements.txt` and not the `pyproject.toml` extras
because it is the runtime list without the dev tools; the two are kept in step
by a check that runs in the monorepo's CI, so a dependency added to
`pyproject.toml` must be added to both.

The migration runner is in the image on purpose, so an operator can apply
migrations with the same code the service runs:

```
docker run --rm -e DATABASE_URL_UNPOOLED=... clearskies-api python -m app.migrate up
```

Nothing applies them at startup.

## What CI here does and does not do

Lint, typecheck, the tests that need no database, and a build of the image
followed by a request to `/health`. The suites that need a real PostGIS — the
neighbour query, the hex drill-down, the corpus retrieval view — and the
migration round-trip from empty run in the monorepo, against the image in
`infra/postgres`. A change is meant to be green there before it is split.

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
| `check_requirements_sync.py` | `scripts/` | Runs in the monorepo's CI, over both files at once. |

## Running it

The database is a Neon branch that already holds the schema and the data.
There is no local or self-hosted database.

With Docker:

```
cp .env.example .env      # DATABASE_URL (pooled) and DATABASE_URL_UNPOOLED (direct) from Neon
./start.sh                # builds and runs the API on :8000
./start.sh down           # stops it
```

Without Docker:

```
python -m venv .venv && .venv/bin/pip install -e ".[dev]"
cp .env.example .env
.venv/bin/uvicorn app.main:app --reload --port 8000
```

`http://localhost:8000/docs` is the schema. `/health` answers whether the
database is reachable and which Postgres extensions are loaded (PostGIS, h3,
pgvector).

Migrations are applied by hand, never at API startup or by `start.sh`, because
the Neon branch is shared:

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

## Deploying to Railway

`railway.json` tells Railway to build the Dockerfile and to wait for `/health`
before switching traffic. `/health` answers 200 while the database is down, so
a green deploy proves the process is serving; read the response body to see
whether the database and its extensions are there.

The database is Neon, not a Railway service. Create one service from this
repository, named `api`, Root Directory `/`, with these variables:

```
DATABASE_URL=<Neon pooled connection string, host contains -pooler>
DATABASE_URL_UNPOOLED=<Neon direct connection string>
CORS_ORIGINS=https://${{web.RAILWAY_PUBLIC_DOMAIN}}
LOG_FORMAT=json
PILOT_STATE=LA
OPENAI_API_KEY=            # optional; /draft answers 503 without it
```

Generate a public domain under Settings > Networking. Leave the CDN off:
`/draft` returns a document generated per request, and an edge cache in front
of it risks serving one request's output to another.

Neon is reachable from anywhere, so migrations run from any machine with
`DATABASE_URL_UNPOOLED` set: `python -m app.migrate verify`.

`${{web.RAILWAY_PUBLIC_DOMAIN}}` is empty until `web` has a public domain. If
`web` gets its domain after `api` deploys, redeploy `api`.

## What CI here does and does not do

Lint, typecheck, the tests that need no database, and a build of the image
followed by a request to `/health`. The suites that need a real PostGIS — the
neighbour query, the hex drill-down, the corpus retrieval view — and the
migration round-trip from empty run in the monorepo, against the image in
`infra/postgres`. A change is meant to be green there before it is split.

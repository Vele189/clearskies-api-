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

The quick way, with Docker:

```
./start.sh          # builds, starts the database, applies migrations, runs the API on :8000
./start.sh down     # stops both; the database volume is kept
```

Without Docker for the API:

```
python -m venv .venv && .venv/bin/pip install -e ".[dev]"
cp .env.example .env      # at least DATABASE_URL
.venv/bin/uvicorn app.main:app --reload --port 8000
```

`http://localhost:8000/docs` is the schema. `/health` answers whether the
database is reachable and which Postgres extensions are actually loaded, which
is the cheap way to tell a custom image from a stock Postgres — the single most
likely thing to be silently wrong about this stack.

A database is `docker compose --profile db up -d db` here, or a Neon branch.
`start.sh` applies migrations; otherwise they are applied by hand, never at
API startup:

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

## The database image

`db/` is Postgres 17 with PostGIS, h3 (h3-pg, built from source) and pgvector.
h3-pg is why it is a custom image: no managed Postgres offers it, and migration
0001 creates it. The first build compiles the H3 C library and takes several
minutes.

- h3-pg is fetched from `postgis/h3-pg`. The old `zachasme/h3-pg` URL is a 404,
  because the project moved and codeload does not follow the redirect.
- `PGDATA` is a subdirectory of `/var/lib/postgresql/data`. A Railway volume's
  root holds `lost+found`, and initdb refuses a data directory that is not
  empty.
- `POSTGRES_PASSWORD` is read only when the data directory is first created.
  Changing the variable later does not change the password; run `ALTER USER`,
  then update the variable to match.

## Deploying to Railway

`railway.json` tells Railway to build the Dockerfile and to wait for `/health`
before switching traffic. `/health` answers 200 while the database is down, so
a green deploy proves the process is serving; read the response body to see
whether the database and its extensions are there.

**The database cannot be Railway's stock Postgres.** Migration 0001 creates the
`h3` extension, which no managed Postgres ships. Both services come from this
repository:

1. New service from this repository, named `db`.
   - Settings > Source: Root Directory `/db`. `db/railway.json` builds its
     Dockerfile and redeploys only on changes under `db/`.
   - Attach a volume at `/var/lib/postgresql/data`. Without one, every
     redeploy starts from an empty database.
   - Variables: `POSTGRES_USER=clearskies`, `POSTGRES_DB=clearskies`,
     `POSTGRES_PASSWORD=<a long random value>`.
   - No public domain. The API reaches it at `db.railway.internal:5432`.
2. New service from this repository, named `api`, Root Directory `/`.
   Variables:

   ```
   DATABASE_URL=postgresql://clearskies:${{db.POSTGRES_PASSWORD}}@${{db.RAILWAY_PRIVATE_DOMAIN}}:5432/clearskies
   CORS_ORIGINS=https://${{web.RAILWAY_PUBLIC_DOMAIN}}
   LOG_FORMAT=json
   PILOT_STATE=LA
   OPENAI_API_KEY=            # optional; /draft answers 503 without it
   ```

   Generate a public domain under Settings > Networking. Leave the CDN off:
   `/draft` returns a document generated per request, and an edge cache in
   front of it risks serving one request's output to another.
3. Apply the migrations once the `api` deploy is up, from inside Railway's
   network where the private domain resolves:

   ```
   railway ssh --service api -- python -m app.migrate up
   railway ssh --service api -- python -m app.migrate verify
   ```

   `railway run` would run the command on this machine, where
   `db.railway.internal` does not resolve.

`${{web.RAILWAY_PUBLIC_DOMAIN}}` is empty until `web` has a public domain. If
`web` gets its domain after `api` deploys, redeploy `api`.

## What CI here does and does not do

Lint, typecheck, the tests that need no database, and a build of the image
followed by a request to `/health`. The suites that need a real PostGIS — the
neighbour query, the hex drill-down, the corpus retrieval view — and the
migration round-trip from empty run in the monorepo, against the image in
`infra/postgres`. A change is meant to be green there before it is split.

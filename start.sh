#!/usr/bin/env bash
# Start the database and the API together, locally, in containers.
#
#   ./start.sh          build, start db, apply migrations, run the API in the foreground
#   ./start.sh down     stop both (the database volume is kept)
#
# The database image is built from db/. Ports and credentials come from .env
# when one exists (see .env.example). Ctrl-C stops the API and the database.

set -euo pipefail

cd "$(dirname "$0")"

compose() {
  docker compose --profile db "$@"
}

if [[ "${1:-}" == "down" ]]; then
  compose down
  exit 0
fi

port_busy() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

# The API reaches the database over the compose network, so the host port is
# only for psql from this machine. When another Postgres already holds 5432,
# take the next free port rather than fail. An explicit POSTGRES_PORT, from the
# environment or .env, is left alone.
if [[ -z "${POSTGRES_PORT:-}" ]] && ! grep -q '^POSTGRES_PORT=' .env 2>/dev/null; then
  port=5432
  while port_busy "$port"; do port=$((port + 1)); done
  export POSTGRES_PORT="$port"
fi

echo "==> Building images"
compose build

echo "==> Starting the database (localhost:${POSTGRES_PORT:-5432})"
compose up --detach --wait db

# Migrations are idempotent: already-applied ones are skipped, and an edited
# one stops the script rather than starting an API on a schema it disagrees with.
echo "==> Applying migrations"
compose run --rm --no-deps api python -m app.migrate up

echo "==> Starting the API on http://localhost:${API_PORT:-8000}"
trap 'compose stop' EXIT
compose up api

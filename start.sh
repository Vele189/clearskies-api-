#!/usr/bin/env bash
# Run the API locally, in a container, against the Neon database.
#
#   ./start.sh          build and run the API in the foreground
#   ./start.sh down     stop it
#
# DATABASE_URL (and DATABASE_URL_UNPOOLED, for migrations) come from .env (see
# .env.example). Migrations are not applied here: the Neon branch is shared, so
# they are applied deliberately with `python -m app.migrate up`.

set -euo pipefail

cd "$(dirname "$0")"

if [[ "${1:-}" == "down" ]]; then
  docker compose down
  exit 0
fi

if [[ -z "${DATABASE_URL:-}" ]] && ! grep -q '^DATABASE_URL=.' .env 2>/dev/null; then
  echo "error: DATABASE_URL is not set. Put the Neon pooled URL in .env." >&2
  exit 1
fi

echo "==> Starting the API on http://localhost:${API_PORT:-8000}"
trap 'docker compose stop' EXIT
docker compose up --build api

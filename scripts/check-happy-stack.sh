#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

if [ -f "${ROOT_DIR}/.env" ]; then
  set -a
  . "${ROOT_DIR}/.env"
  set +a
fi

API_HOST="${HAPPY_BIND_ADDRESS:-127.0.0.1}"
API_PORT="${HAPPY_PORT:-3005}"
METRICS_HOST="${HAPPY_METRICS_BIND_ADDRESS:-127.0.0.1}"
METRICS_PORT="${HAPPY_METRICS_PORT:-9090}"

cd "${ROOT_DIR}"

echo "# docker compose ps"
docker compose ps

echo
echo "# happy-server /health"
curl --fail --silent --show-error "http://${API_HOST}:${API_PORT}/health"
echo

echo
echo "# metrics /health"
curl --fail --silent --show-error "http://${METRICS_HOST}:${METRICS_PORT}/health"
echo

echo
echo "# recent happy-server logs"
docker compose logs --tail=50 happy-server

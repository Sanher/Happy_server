#!/bin/sh
set -eu

if [ -z "${HANDY_MASTER_SECRET:-}" ] && [ -n "${SEED:-}" ]; then
  export HANDY_MASTER_SECRET="${SEED}"
fi

: "${DATABASE_URL:?DATABASE_URL is required}"
: "${REDIS_URL:?REDIS_URL is required}"
: "${HANDY_MASTER_SECRET:?HANDY_MASTER_SECRET or SEED is required}"
: "${PORT:=3005}"
: "${DATA_DIR:=/data}"
: "${METRICS_PORT:=9090}"

mkdir -p "${DATA_DIR}"

echo "[happy-entrypoint] waiting for Postgres..."
until pg_isready -d "${DATABASE_URL}" >/dev/null 2>&1; do
  sleep 2
done

echo "[happy-entrypoint] waiting for Redis..."
until [ "$(redis-cli --raw -u "${REDIS_URL}" ping 2>/dev/null || true)" = "PONG" ]; do
  sleep 2
done

echo "[happy-entrypoint] running Prisma migrations..."
./node_modules/.bin/prisma --schema packages/happy-server/prisma/schema.prisma migrate deploy

echo "[happy-entrypoint] starting happy-server on port ${PORT}..."
exec yarn --cwd packages/happy-server start

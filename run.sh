#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"
STATE_ENV="/data/happy_internal.env"
APP_DIR="/opt/happy"
APP_PORT="3005"
METRICS_PORT="9090"
PG_PORT="5432"
REDIS_PORT="6379"
PGDATA="/data/postgres"
REDIS_DIR="/data/redis"
HAPPY_DATA_DIR="/data/happy"

option_string() {
  local key="$1"
  local default_value="${2:-}"
  if [ -f "$OPTIONS_FILE" ]; then
    local value
    value="$(jq -er --arg key "$key" '.[$key] // empty | strings' "$OPTIONS_FILE" 2>/dev/null || true)"
    if [ -n "$value" ]; then
      printf '%s' "$value"
      return
    fi
  fi
  printf '%s' "$default_value"
}

log() {
  printf '[happy-addon] %s\n' "$*"
}

ensure_state_file() {
  mkdir -p /data
  if [ ! -f "$STATE_ENV" ]; then
    umask 077
    cat > "$STATE_ENV" <<STATEEOF
INTERNAL_POSTGRES_USER=happy
INTERNAL_POSTGRES_DB=happy_server
INTERNAL_POSTGRES_PASSWORD=$(openssl rand -hex 24)
INTERNAL_SEED=$(openssl rand -hex 32)
STATEEOF
  fi
  # shellcheck disable=SC1090
  . "$STATE_ENV"
}

resolve_pg_bin_dir() {
  local dir
  dir="$(find /usr/lib/postgresql -path '*/bin/postgres' 2>/dev/null | sort | tail -n 1 | xargs dirname)"
  if [ -z "$dir" ]; then
    printf '[happy-addon] No se encontro la instalacion de PostgreSQL en /usr/lib/postgresql\n' >&2
    exit 1
  fi
  printf '%s' "$dir"
}

wait_for_postgres() {
  local tries=0
  until "$PG_ISREADY" -h 127.0.0.1 -p "$PG_PORT" -U postgres >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 60 ]; then
      printf '[happy-addon] PostgreSQL no responde tras %s segundos\n' "$tries" >&2
      exit 1
    fi
    sleep 1
  done
}

wait_for_redis() {
  local tries=0
  until redis-cli -h 127.0.0.1 -p "$REDIS_PORT" ping >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 60 ]; then
      printf '[happy-addon] Redis no responde tras %s segundos\n' "$tries" >&2
      exit 1
    fi
    sleep 1
  done
}

ensure_postgres_cluster() {
  install -d -m 0700 -o postgres -g postgres "$PGDATA"

  if [ ! -s "$PGDATA/PG_VERSION" ]; then
    log "Inicializando PostgreSQL en $PGDATA"
    gosu postgres "$INITDB" -D "$PGDATA" --encoding=UTF8 --locale=C >/dev/null
    {
      printf "listen_addresses = '127.0.0.1'\n"
      printf "port = %s\n" "$PG_PORT"
      printf "unix_socket_directories = '/tmp'\n"
    } >> "$PGDATA/postgresql.conf"
    {
      printf 'host all all 127.0.0.1/32 scram-sha-256\n'
      printf 'host all all ::1/128 scram-sha-256\n'
    } >> "$PGDATA/pg_hba.conf"
    chown postgres:postgres "$PGDATA/postgresql.conf" "$PGDATA/pg_hba.conf"
  fi
}

start_postgres() {
  log "Arrancando PostgreSQL interno"
  gosu postgres "$POSTGRES_BIN" -D "$PGDATA" &
  POSTGRES_PID=$!
  wait_for_postgres
}

ensure_postgres_database() {
  log "Asegurando usuario y base de datos internos"
  gosu postgres "$PSQL" -h /tmp -p "$PG_PORT" -v ON_ERROR_STOP=1 --dbname postgres <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${INTERNAL_POSTGRES_USER}') THEN
    CREATE ROLE ${INTERNAL_POSTGRES_USER} LOGIN PASSWORD '${INTERNAL_POSTGRES_PASSWORD}';
  ELSE
    ALTER ROLE ${INTERNAL_POSTGRES_USER} WITH LOGIN PASSWORD '${INTERNAL_POSTGRES_PASSWORD}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${INTERNAL_POSTGRES_DB} OWNER ${INTERNAL_POSTGRES_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${INTERNAL_POSTGRES_DB}')\gexec
SQL
}

start_redis() {
  log "Arrancando Redis interno"
  mkdir -p "$REDIS_DIR"
  redis-server \
    --bind 127.0.0.1 \
    --port "$REDIS_PORT" \
    --dir "$REDIS_DIR" \
    --appendonly yes \
    --save 60 1 &
  REDIS_PID=$!
  wait_for_redis
}

wait_for_happy() {
  local tries=0
  until curl --fail --silent http://127.0.0.1:${APP_PORT}/health >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 90 ]; then
      printf '[happy-addon] Happy Server no responde en /health tras %s segundos\n' "$tries" >&2
      exit 1
    fi
    sleep 1
  done
}

cleanup() {
  local exit_code=$?
  trap - EXIT INT TERM

  if [ -n "${APP_PID:-}" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi

  if [ -n "${REDIS_PID:-}" ] && kill -0 "$REDIS_PID" 2>/dev/null; then
    kill "$REDIS_PID" 2>/dev/null || true
    wait "$REDIS_PID" 2>/dev/null || true
  fi

  if [ -n "${POSTGRES_PID:-}" ] && kill -0 "$POSTGRES_PID" 2>/dev/null; then
    gosu postgres "$PG_CTL" -D "$PGDATA" -m fast stop >/dev/null 2>&1 || kill "$POSTGRES_PID" 2>/dev/null || true
    wait "$POSTGRES_PID" 2>/dev/null || true
  fi

  exit "$exit_code"
}

ensure_state_file

PUBLIC_URL="$(option_string public_url "http://homeassistant.local:${APP_PORT}")"
SEED_VALUE="$(option_string seed "${INTERNAL_SEED}")"

export PG_BIN_DIR="$(resolve_pg_bin_dir)"
export POSTGRES_BIN="${PG_BIN_DIR}/postgres"
export PG_CTL="${PG_BIN_DIR}/pg_ctl"
export INITDB="${PG_BIN_DIR}/initdb"
export PSQL="${PG_BIN_DIR}/psql"
export PG_ISREADY="${PG_BIN_DIR}/pg_isready"

mkdir -p "$HAPPY_DATA_DIR"

trap cleanup EXIT INT TERM

ensure_postgres_cluster
start_postgres
ensure_postgres_database
start_redis

export DATABASE_URL="postgresql://${INTERNAL_POSTGRES_USER}:${INTERNAL_POSTGRES_PASSWORD}@127.0.0.1:${PG_PORT}/${INTERNAL_POSTGRES_DB}"
export REDIS_URL="redis://127.0.0.1:${REDIS_PORT}/0"
export HANDY_MASTER_SECRET="$SEED_VALUE"
export PUBLIC_URL="$PUBLIC_URL"
export PORT="$APP_PORT"
export METRICS_ENABLED="true"
export METRICS_PORT="$METRICS_PORT"
export DATA_DIR="$HAPPY_DATA_DIR"
export SEED="$SEED_VALUE"

log "PUBLIC_URL configurada en ${PUBLIC_URL}"
log "Ejecutando migraciones Prisma"
cd "$APP_DIR"
./node_modules/.bin/prisma migrate deploy --schema packages/happy-server/prisma/schema.prisma

log "Arrancando Happy Server en el puerto interno ${APP_PORT}"
yarn --cwd packages/happy-server start &
APP_PID=$!

wait_for_happy
log "Happy Server listo: http://127.0.0.1:${APP_PORT}/health"
log "Metricas internas: http://127.0.0.1:${METRICS_PORT}/metrics"

wait -n "$APP_PID" "$REDIS_PID" "$POSTGRES_PID"

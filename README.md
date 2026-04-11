# Happy Server self-host v1

Preparacion pragmatica para levantar `happy-server` con `docker compose`, `postgres` y `redis`, dejando el servicio listo para poner Nginx delante despues.

## Arquitectura minima

- `happy-server`: backend HTTP/WebSocket de Happy.
- `postgres`: persistencia principal de la aplicacion.
- `redis`: dependencia pedida por la documentacion y validada al arranque.
- `happy_data` en `/data`: persistencia de ficheros locales subidos por la app.
- `postgres_data`: persistencia de PostgreSQL.
- `redis_data`: persistencia de Redis AOF.

La app queda publicada solo en `127.0.0.1:3005` y `127.0.0.1:9090` por defecto. `postgres` y `redis` no exponen puertos al host.

## Discrepancias detectadas entre docs y repo

1. La guia oficial de self-host sigue apuntando a `slopus/happy-server`, pero ese repo esta archivado y remite al monorepo `slopus/happy`.
2. La guia oficial habla de `SEED`, pero el codigo actual usa `HANDY_MASTER_SECRET`. Esta plantilla acepta `SEED` y lo mapea al nombre real que espera el servidor.
3. La guia oficial y `Dockerfile.server` mezclan `3000` y `3005`, pero el codigo actual escucha en `3005` y levanta un servidor de metricas en `9090`.
4. El `Dockerfile.server` oficial arranca la app, pero no ejecuta migraciones. Esta plantilla anade una entrada de arranque que espera a Postgres/Redis y ejecuta `prisma migrate deploy` antes de iniciar el servicio.

## Archivos

- `Dockerfile.happy-server`: wrapper derivado del `Dockerfile.server` oficial.
- `docker-compose.yml`: stack con `happy-server`, `postgres` y `redis`.
- `.env.example`: variables base para la fase sin proxy.
- `scripts/bootstrap-happy-upstream.sh`: clona/actualiza el upstream oficial.
- `scripts/check-happy-stack.sh`: comprobacion rapida de estado, health y logs.

## Puesta en marcha

1. Descargar el upstream oficial:

```sh
./scripts/bootstrap-happy-upstream.sh
```

2. Crear la configuracion local:

```sh
cp .env.example .env
```

3. Editar `.env`:

- `POSTGRES_PASSWORD`
- `SEED`
- `HAPPY_PUBLIC_URL`

4. Levantar el stack:

```sh
docker compose up -d --build
```

## Comprobaciones pedidas

### 1. Puerto real de escucha

El proceso HTTP principal escucha en `3005`.

- Codigo: `packages/happy-server/sources/app/api/api.ts`
- Health HTTP: `http://127.0.0.1:3005/health`
- Metrics/health adicional: `http://127.0.0.1:9090/health`

### 2. Healthcheck

```sh
curl http://127.0.0.1:3005/health
curl http://127.0.0.1:9090/health
```

O en una sola pasada:

```sh
./scripts/check-happy-stack.sh
```

### 3. Arranque con Postgres y Redis

El contenedor `happy-server`:

- espera a que Postgres responda con `pg_isready`
- espera a que Redis responda con `PONG`
- ejecuta `prisma migrate deploy`
- arranca la app

Logs utiles:

```sh
docker compose logs -f happy-server
docker compose logs -f postgres
docker compose logs -f redis
```

### 4. Que persistir

- `happy_data` -> `/data`
- `postgres_data` -> `/var/lib/postgresql/data`
- `redis_data` -> `/data`

Si algun dia mueves uploads a S3/MinIO, `happy_data` dejaria de ser critico, pero hoy debe persistirse porque el codigo actual usa almacenamiento local si no configuras S3.

### 5. Upstream para Nginx despues

Si Nginx se monta en la misma red Docker:

```nginx
proxy_pass http://happy-server:3005;
```

Si Nginx corre en el host y no en el mismo compose:

```nginx
proxy_pass http://127.0.0.1:3005;
```

## Observabilidad y depuracion

- `happy-server` expone `/health` en `3005`.
- `happy-server` expone `/metrics` y `/health` en `9090`.
- Los tres servicios rotan logs con `max-size=10m` y `max-file=3`.
- El bind a `127.0.0.1` evita exposicion accidental mientras no exista Nginx delante.

## Validacion del warning de listeners

Si aparece un warning tipo `MaxListenersExceededWarning` sobre `AbortSignal`, el patron problemático suele ser reutilizar el mismo signal global en una tarea recurrente y anadir un listener nuevo en cada espera sin retirarlo cuando el timeout termina de forma normal.

Tras aplicar el fix, la comprobacion mas simple es operativa:

1. Reinicia el servicio con el addon actualizado.
2. Dejalo correr al menos 12-15 minutos.
3. Revisa que no vuelva a aparecer el warning en los logs del addon.

Comprobacion rapida:

```sh
ha addons logs local_happy_server | grep -i MaxListenersExceededWarning
```

Si ese grep no devuelve nada despues de varias iteraciones del job de metricas, el numero de listeners ya no esta creciendo indefinidamente.

## Fase 2 con Nginx

Cuando quieras publicarlo con HTTPS:

1. Cambiar `HAPPY_PUBLIC_URL` a la URL final `https://...`
2. Poner Nginx delante apuntando a `happy-server:3005` o `127.0.0.1:3005`
3. Configurar soporte WebSocket para la ruta `/v1/updates`
4. Mantener `9090` solo para uso interno

## Riesgos y puntos delicados

- No he podido ejecutar `docker compose` ni validar el stack en esta maquina porque `docker` no esta instalado en el entorno actual.
- El upstream esta moviendose dentro del monorepo `slopus/happy`, asi que conviene revisar cambios del `packages/happy-server` al actualizar.
- La documentacion oficial esta parcialmente desalineada con el codigo actual en repo, entorno y puertos; esta plantilla prioriza el codigo real.

# Changelog

## 0.1.7

- Reconvierte este repositorio a wrapper source consumible por tag desde el repo padre del add-on.
- Sube al hijo el `run.sh` canonico y los parches locales usados por el add-on padre.
- Anade `wrapper-source.yaml` para fijar `upstream_repo` y `upstream_ref` desde la tag del wrapper.
- Deja `patches/fix-delay-abort-listener.py` como artefacto canonico del parche para el repo padre.
- Elimina artefactos de repo final por `docker compose` que ya no deben formar parte del wrapper source.

## 0.1.6

- Alinea este repositorio con la release del addon que robustece la inyeccion del fix de `delay.ts` durante el build.
- Mantiene la serie de tags sincronizada con la version publicada en el repo padre de addons.

## 0.1.5

- Alinea este repositorio con la release del addon que corrige la inyeccion del fix de `delay.ts` durante el build.
- Mantiene la serie de tags sincronizada con la version publicada en el repo padre de addons.

## 0.1.4

- Documenta el fix del helper `delay` para evitar acumulacion de listeners `abort` sobre un `AbortSignal` reutilizado.
- Anade una comprobacion simple para validar que el warning no reaparece tras varias iteraciones.

## 0.1.3

- Alinea el versionado del repositorio con la serie publicada del addon de Home Assistant.
- Añade la base inicial del changelog para futuras releases etiquetadas.

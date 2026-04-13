# Happy Server Wrapper

Runtime wrapper source for the Happy Server Home Assistant add-on.

This repository is not the final Home Assistant add-on repository. It only
contains the wrapper artifacts consumed by the parent add-on repository.

The published Home Assistant add-on metadata, build configuration, icons, and
Supervisor-facing files must remain in the parent repository.

## What lives here

- `run.sh`: canonical runtime entrypoint for the add-on wrapper
- `patches/`: local wrapper patches applied during the parent build
- `wrapper-source.yaml`: small metadata file with the upstream repo/ref that the
  parent can consume later
- `VERSION` and `CHANGELOG.md`: semver history for wrapper tags

## What does not live here

- no `repository.yaml`
- no `build.yaml`
- no Supervisor-facing add-on metadata
- no Home Assistant publication packaging

## Wrapper responsibilities

This wrapper encapsulates the add-on-specific glue that differentiates the
runtime shipped in the parent add-on repository:

- coordinated startup of Happy Server with internal PostgreSQL and Redis
- local environment shaping for the container runtime
- local patches that must be applied during build
- persistence layout under `/data`
- health-oriented startup behavior before the server begins serving traffic

## Consumption model from the parent repository

The parent repository is expected to consume this wrapper source by tag, in the
same spirit as `Rustdesk_wrapper`.

Target flow:

- `APP_REPO=<wrapper source repository URL>`
- `APP_REF=<wrapper tag>`

The parent add-on can then:

- clone this repository at the requested tag
- copy `run.sh`
- copy `patches/`
- read `wrapper-source.yaml` if it wants to pin the third-party upstream repo
  and commit centrally from the wrapper tag

## Canonical patch artifact

The canonical patch artifact for the parent repository is:

- `patches/fix-delay-abort-listener.py`

This wrapper intentionally keeps the Python patcher as the only source of truth
for the `delay.ts` fix to avoid ambiguity when the parent consumes the wrapper
by tag.

## Versioning

This repository should publish stable semver tags compatible with the parent
add-on release flow, for example:

- `0.1.6`
- `0.1.7`
- `0.1.8`

The parent repository can then synchronize both:

- add-on `version`
- wrapper `APP_REF`

from the wrapper tag published here.

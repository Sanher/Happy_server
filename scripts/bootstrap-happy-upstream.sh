#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
UPSTREAM_DIR="${ROOT_DIR}/upstream/happy"

mkdir -p "${ROOT_DIR}/upstream"

if [ ! -d "${UPSTREAM_DIR}/.git" ]; then
  echo "[bootstrap] cloning slopus/happy into ${UPSTREAM_DIR}"
  git clone --depth 1 https://github.com/slopus/happy.git "${UPSTREAM_DIR}"
else
  echo "[bootstrap] updating existing upstream checkout"
  git -C "${UPSTREAM_DIR}" pull --ff-only
fi

echo "[bootstrap] upstream ready at ${UPSTREAM_DIR}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLING_DIR="$ROOT_DIR/.tooling"
FLUTTER_DIR="$TOOLING_DIR/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"
DART_BIN="$FLUTTER_DIR/bin/dart"
RELEASES_JSON_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[init-codex-env] Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd git
need_cmd curl
need_cmd python3
need_cmd tar

mkdir -p "$TOOLING_DIR"

if [[ ! -x "$FLUTTER_BIN" ]]; then
  echo "[init-codex-env] Flutter SDK not found, downloading stable release..."
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  curl -fsSL "$RELEASES_JSON_URL" -o "$TMP_DIR/releases.json"

  ARCHIVE_PATH="$(python3 - "$TMP_DIR/releases.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

current = data.get('current_release', {}).get('stable')
if not current:
    raise SystemExit('Could not determine stable Flutter release hash')

for rel in data.get('releases', []):
    if rel.get('hash') == current:
        archive = rel.get('archive')
        if not archive:
            raise SystemExit('Stable release is missing archive field')
        print(archive)
        break
else:
    raise SystemExit('Stable release metadata not found in releases list')
PY
)"

  ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/${ARCHIVE_PATH}"
  ARCHIVE_FILE="$TMP_DIR/flutter.tar.xz"

  echo "[init-codex-env] Downloading: $ARCHIVE_URL"
  curl -fL "$ARCHIVE_URL" -o "$ARCHIVE_FILE"

  rm -rf "$FLUTTER_DIR"
  mkdir -p "$TOOLING_DIR"
  tar -xJf "$ARCHIVE_FILE" -C "$TOOLING_DIR"

  if [[ ! -x "$FLUTTER_BIN" ]]; then
    echo "[init-codex-env] Flutter extraction failed: $FLUTTER_BIN missing" >&2
    exit 1
  fi
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Flutter tool executes git inside SDK checkout; in containerized environments
# archive ownership metadata can trigger "dubious ownership" guards.
git config --global --add safe.directory "$FLUTTER_DIR" >/dev/null 2>&1 || true

echo "[init-codex-env] Flutter: $("$FLUTTER_BIN" --version | head -n 1)"
echo "[init-codex-env] Dart: $("$DART_BIN" --version 2>&1)"

echo "[init-codex-env] Running flutter precache (web + linux artifacts)..."
"$FLUTTER_BIN" precache --web --linux

echo "[init-codex-env] Environment ready."

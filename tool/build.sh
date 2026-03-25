#!/usr/bin/env bash
# tool/build.sh — One-click data pipeline execution.
#
# Usage:
#   cd tool/
#   chmod +x build.sh
#   ./build.sh
#
# Optional environment variables:
#   OUTPUT_DIR   Output directory (default: ../assets/bin)
#   MAX_MAG      Maximum visual magnitude to include (default: 6.5)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_DIR="${OUTPUT_DIR:-../assets/bin}"
MAX_MAG="${MAX_MAG:-6.5}"

echo "╔══════════════════════════════════════════════════════╗"
echo "║   Starling Data Pipeline                             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Regenerate FlatBuffers schema (optional, requires flatc) ───────
if command -v flatc &>/dev/null; then
  echo "=== Step 1: Compiling FlatBuffers schema ==="
  flatc --dart -o generated/ schema/stargazer.fbs
  echo "    ✅  generated/stargazer_generated.dart updated"
else
  echo "=== Step 1: flatc not found – using pre-generated Dart file ==="
  echo "    ℹ️   Install flatc to regenerate from schema/stargazer.fbs"
fi
echo ""

# ── Step 2: Get Dart dependencies ─────────────────────────────────────────
echo "=== Step 2: Fetching Dart dependencies ==="
dart pub get
echo ""

# ── Step 3: Run the pipeline ───────────────────────────────────────────────
echo "=== Step 3: Running pipeline (mag ≤ ${MAX_MAG}) ==="
dart run bin/pipeline.dart \
  --output "${OUTPUT_DIR}" \
  --mag "${MAX_MAG}"
echo ""

echo "=== Done! Check ${OUTPUT_DIR}/ ==="

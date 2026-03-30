#!/usr/bin/env bash
# generate_bins.sh — One-click script that downloads all raw astronomy data,
# runs the Dart pipeline, and writes the .bin files to ../assets/bin/.
#
# Usage:
#   cd tool/
#   chmod +x generate_bins.sh
#   ./generate_bins.sh
#
# Optional environment variables:
#   MAX_MAG   Maximum visual magnitude to include (default: 6.5)
#   OUTPUT    Output directory for .bin files (default: ../assets/bin)
#   FORCE_WESTERN_REFRESH  Force re-download of western line source (0/1)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MAX_MAG="${MAX_MAG:-6.5}"
OUTPUT="${OUTPUT:-../assets/bin}"
FORCE_WESTERN_REFRESH="${FORCE_WESTERN_REFRESH:-0}"

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "❌ Required command not found: $1"
    exit 1
  fi
}

require_cmd dart
require_cmd curl

# ── Step 1: Download raw data sources ────────────────────────────────────────
echo "═══════════════════════════════════════"
echo " Step 1: Downloading data sources…"
echo "═══════════════════════════════════════"
chmod +x download_sources.sh
FORCE_WESTERN_REFRESH="$FORCE_WESTERN_REFRESH" ./download_sources.sh

# ── Step 2: Install Dart dependencies ────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo " Step 2: Installing Dart dependencies…"
echo "═══════════════════════════════════════"
dart pub get

# ── Step 3: Run the pipeline ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo " Step 3: Running data pipeline…"
echo "═══════════════════════════════════════"
dart run bin/pipeline.dart --mag "$MAX_MAG" --skip-validate --output "$OUTPUT"

# ── Step 4: Verify output files ───────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo " Step 4: Verifying output files…"
echo "═══════════════════════════════════════"

OK=true
for f in catalog_base.bin culture_western.bin culture_chinese_modern.bin culture_chinese.bin; do
  path="${OUTPUT}/${f}"
  if [[ -f "$path" ]]; then
    size=$(wc -c < "$path")
    echo "   ✅ $f  ($(echo "$size / 1024" | bc) KB)"
  else
    echo "   ❌ $f not found at $path"
    OK=false
  fi
done

if [[ "$OK" == "false" ]]; then
  echo ""
  echo "❌ Some output files are missing.  Check pipeline output above."
  exit 1
fi

echo ""
echo "🎉 Done!  .bin files are ready in $OUTPUT"

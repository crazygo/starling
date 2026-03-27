#!/usr/bin/env bash
# download_sources.sh — Download all raw astronomy data sources required by
# the Starling data pipeline (tool/bin/pipeline.dart).
#
# Usage:
#   cd tool/
#   chmod +x download_sources.sh
#   ./download_sources.sh
#
# This script must be run from the tool/ directory.
#
# Data sources used:
#   Hipparcos (primary)  : ESA/CDS VizieR I/239
#   Hipparcos (fallback) : HYG Database v38 (CC BY-SA 4.0, David Nash)
#                          https://github.com/astronexus/HYG-Database
#   Constellation lines  : Stellarium modern skyculture (GPL-2.0+)
#   Constellation bounds : Davenhall & Leggett VI/49 (CDS, optional)
#   Chinese skyculture   : Stellarium Chinese skyculture (GPL-2.0+)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FORCE_WESTERN_REFRESH="${FORCE_WESTERN_REFRESH:-0}"

echo "📡 Downloading astronomy data sources…"
echo ""

# ── Helpers ──────────────────────────────────────────────────────────────────

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "❌ Required command not found: $1"
    exit 1
  fi
}

download() {
  local url="$1"
  local dest="$2"
  local desc="$3"

  if [[ -f "$dest" ]]; then
    echo "   ⏭  $desc already exists, skipping"
    return 0
  fi

  echo "   ⬇  $desc"
  mkdir -p "$(dirname "$dest")"
  if curl --fail --silent --show-error --location \
      --connect-timeout 15 --max-time 300 \
      --output "$dest" "$url"; then
    echo "   ✅ Saved → $dest"
    return 0
  else
    return 1
  fi
}

require_cmd curl
require_cmd awk

# ── a. Hipparcos main catalogue ───────────────────────────────────────────────
# Primary source: ESA/CDS VizieR catalogue I/239 (~50 MB pipe-delimited file).
# The file is already in the pipe-separated format that HipparcosParser expects.
# Fallback: HYG Database v38 (combines Hipparcos, Yale, Gliese catalogues).

echo "🌟 Hipparcos catalogue (I/239)…"

if [[ -f "sources/hipparcos/hip_main.csv" ]]; then
  echo "   ⏭  hip_main.csv already exists, skipping"
else
  mkdir -p sources/hipparcos

  # Try primary CDS source first.
  if download \
      "https://cdsarc.cds.unistra.fr/ftp/cats/I/239/hip_main.dat" \
      "sources/hipparcos/hip_main.csv" \
      "hip_main.dat (~50 MB) from ESA/CDS"; then
    : # success
  else
    echo "   ⚠️  CDS not reachable — trying HYG Database fallback…"
    HYG_GZ="$(mktemp /tmp/hyg_XXXXXX.csv.gz)"
    trap 'rm -f "$HYG_GZ"' EXIT

    # HYG Database v38 — same star data, different format; needs conversion.
    download \
      "https://raw.githubusercontent.com/astronexus/HYG-Database/c7f7f883fe678cc7680169a50ccd7dcc49b060ce/hyg/v3/hyg_v38.csv.gz" \
      "$HYG_GZ" \
      "hyg_v38.csv.gz (~14 MB) from GitHub"

    echo "   🔄 Converting HYG CSV → pipe-delimited Hipparcos format…"
    require_cmd python3

    python3 - "$HYG_GZ" "sources/hipparcos/hip_main.csv" << 'PYEOF'
import csv, gzip, sys

src, dst = sys.argv[1], sys.argv[2]
count = 0
with gzip.open(src, "rt", encoding="utf-8") as f, open(dst, "w") as out:
    for row in csv.DictReader(f):
        hip = row.get("hip", "").strip()
        if not hip:
            continue
        try:
            hip_int = int(float(hip))
        except (ValueError, TypeError):
            continue
        if hip_int <= 0:
            continue
        ra_h = row.get("ra",  "").strip()
        dec  = row.get("dec", "").strip()
        mag  = row.get("mag", "").strip()
        bv   = row.get("ci",  "").strip() or "0.000"
        if not (ra_h and dec and mag):
            continue
        try:
            ra_deg = float(ra_h) * 15.0
        except ValueError:
            continue
        fields = [''] * 38
        fields[1]  = str(hip_int)
        fields[5]  = mag
        fields[8]  = f"{ra_deg:.10f}"
        fields[9]  = dec
        fields[37] = bv
        out.write("|".join(fields) + "\n")
        count += 1
print(f"   Converted {count} stars")
PYEOF
    echo "   ✅ Saved → sources/hipparcos/hip_main.csv (via HYG)"
  fi
fi

# ── b. IAU constellation lines ────────────────────────────────────────────────
# Source: Stellarium modern skyculture constellationship.fab
# The FAB format is whitespace-separated; we convert to comma-separated CSV
# as expected by IauLinesParser.

echo ""
echo "⭐ IAU constellation lines (Stellarium modern skyculture)…"
FAB_TMP="$(mktemp /tmp/constellationship_XXXXXX.fab)"

if [[ "$FORCE_WESTERN_REFRESH" == "1" && -f "sources/iau/constellation_lines.csv" ]]; then
  echo "   ♻️  Removing cached constellation_lines.csv (FORCE_WESTERN_REFRESH=1)"
  rm -f "sources/iau/constellation_lines.csv"
fi

if [[ -f "sources/iau/constellation_lines.csv" ]]; then
  echo "   ⏭  constellation_lines.csv already exists, skipping"
else
  echo "   ⬇  constellationship.fab"

  # Try master first; fall back to a known-good tagged release.
  if ! curl --fail --silent --show-error --location \
      --connect-timeout 15 --max-time 60 \
      --output "$FAB_TMP" \
      "https://raw.githubusercontent.com/Stellarium/stellarium/master/skycultures/modern/constellationship.fab" 2>/dev/null; then
    echo "   ⚠️  master not reachable — trying v23.4 tag…"
    curl --fail --silent --show-error --location \
      --connect-timeout 15 --max-time 60 \
      --output "$FAB_TMP" \
      "https://raw.githubusercontent.com/Stellarium/stellarium/refs/tags/v23.4/skycultures/modern/constellationship.fab"
  fi

  mkdir -p sources/iau

  # Convert whitespace-separated FAB to comma-separated CSV.
  # Lines starting with # are comments — drop them.
  # Each line: ABBR num_pairs hip1 hip2 ...  →  ABBR,num_pairs,hip1,hip2,...
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      out = $1
      for (i = 2; i <= NF; i++) out = out "," $i
      print out
    }
  ' "$FAB_TMP" > "sources/iau/constellation_lines.csv"

  echo "   ✅ Saved → sources/iau/constellation_lines.csv"
fi
rm -f "$FAB_TMP"

# ── c. IAU constellation boundaries ──────────────────────────────────────────
# Source: Davenhall & Leggett VI/49 (CDS)
# Two available files (tried in order):
#   bound_20.dat.gz — space-separated, RA in degrees (÷15 → hours), 4 columns
#   constbnd.dat    — space-separated, RA in hours, 3+ columns
# Output CSV: ra_hours,dec_deg,abbr as expected by IauBoundaryParser.
# An empty file is acceptable — boundaries are decorative, not required for
# constellation line rendering.

echo ""
echo "🔲 IAU constellation boundaries (VI/49)…"

if [[ -f "sources/iau/constellation_boundaries.csv" ]]; then
  echo "   ⏭  constellation_boundaries.csv already exists, skipping"
else
  mkdir -p sources/iau
  require_cmd gzip

  BOUND_OK=0

  # ── c1. bound_20.dat.gz (space-separated, RA in degrees) ─────────────────
  # Format: ra_deg  dec_deg  abbr  I/O
  BOUND_GZ_TMP="$(mktemp /tmp/bound_XXXXXX.dat.gz)"
  for BOUND_GZ_URL in \
    "https://cdsarc.cds.unistra.fr/ftp/cats/VI/49/bound_20.dat.gz" \
    "https://vizier.cds.unistra.fr/ftp/cats/VI/49/bound_20.dat.gz" \
  ; do
    echo "   ⬇  bound_20.dat.gz from $BOUND_GZ_URL"
    if curl --fail --silent --show-error --location \
        --connect-timeout 15 --max-time 120 \
        --output "$BOUND_GZ_TMP" \
        "$BOUND_GZ_URL" 2>/dev/null; then
      echo "   ✅ Downloaded from $BOUND_GZ_URL"
      # RA is in degrees — divide by 15 to convert to hours.
      gzip -cd "$BOUND_GZ_TMP" | awk '
        /^[[:space:]]*$/ { next }
        NF >= 3 {
          ra_h = $1 / 15.0
          dec  = $2 + 0
          abbr = $3
          gsub(/[[:space:]]/, "", abbr)
          if (length(abbr) > 0) printf "%.6f,%.4f,%s\n", ra_h, dec, toupper(abbr)
        }
      ' > "sources/iau/constellation_boundaries.csv"
      BOUND_OK=1
      break
    else
      echo "   ⚠️  Failed: $BOUND_GZ_URL"
    fi
  done
  rm -f "$BOUND_GZ_TMP"

  # ── c2. constbnd.dat (space-separated, RA in hours) ──────────────────────
  # Format: ra_hours  dec_deg  abbr [abbr2]
  if [[ $BOUND_OK -eq 0 ]]; then
    BOUND_TMP="$(mktemp /tmp/constbnd_XXXXXX.dat)"
    for BOUND_URL in \
      "https://cdsarc.cds.unistra.fr/ftp/cats/VI/49/constbnd.dat" \
      "https://vizier.cds.unistra.fr/ftp/cats/VI/49/constbnd.dat" \
    ; do
      echo "   ⬇  constbnd.dat from $BOUND_URL"
      if curl --fail --silent --show-error --location \
          --connect-timeout 15 --max-time 120 \
          --output "$BOUND_TMP" \
          "$BOUND_URL" 2>/dev/null; then
        echo "   ✅ Downloaded from $BOUND_URL"
        # RA is already in hours.
        awk '
          /^[[:space:]]*$/ { next }
          NF >= 3 {
            ra_h = $1 + 0
            dec  = $2 + 0
            abbr = $3
            gsub(/[[:space:]]/, "", abbr)
            if (length(abbr) > 0) printf "%.6f,%.4f,%s\n", ra_h, dec, toupper(abbr)
          }
        ' "$BOUND_TMP" > "sources/iau/constellation_boundaries.csv"
        BOUND_OK=1
        break
      else
        echo "   ⚠️  Failed: $BOUND_URL"
      fi
    done
    rm -f "$BOUND_TMP"
  fi

  if [[ $BOUND_OK -eq 1 ]]; then
    echo "   ✅ Saved → sources/iau/constellation_boundaries.csv"
  else
    # All sources failed — create an empty placeholder so the pipeline
    # can still run (boundaries are decorative, not required for line rendering).
    echo "# ra_hours,dec_deg,abbr" > "sources/iau/constellation_boundaries.csv"
    echo "   ❌ All CDS sources failed — created empty placeholder"
    echo "      Constellation boundary rendering will be disabled."
    echo "      To fix manually: download bound_20.dat.gz from"
    echo "      https://cdsarc.cds.unistra.fr/viz-bin/cat/VI/49"
    echo "      and re-run this script."
  fi
fi

# ── d. Western star proper names ─────────────────────────────────────────────
# Source: Stellarium modern skyculture star_names.fab
# Format: <hip>|_("<name>") <catalog-ids>
# Saved as-is; the pipeline parser handles the format.

echo ""
echo "✨ Western star proper names (Stellarium modern skyculture)…"
STAR_NAMES_TMP="$(mktemp /tmp/star_names_XXXXXX.fab)"

if [[ -f "sources/iau/star_names.fab" ]]; then
  echo "   ⏭  star_names.fab already exists, skipping"
else
  mkdir -p sources/iau

  # Try master first; fall back to a known-good tagged release.
  if curl --fail --silent --show-error --location \
      --connect-timeout 15 --max-time 60 \
      --output "$STAR_NAMES_TMP" \
      "https://raw.githubusercontent.com/Stellarium/stellarium/master/skycultures/modern/star_names.fab" 2>/dev/null; then
    cp "$STAR_NAMES_TMP" "sources/iau/star_names.fab"
    echo "   ✅ Saved → sources/iau/star_names.fab (from master)"
  elif curl --fail --silent --show-error --location \
      --connect-timeout 15 --max-time 60 \
      --output "$STAR_NAMES_TMP" \
      "https://raw.githubusercontent.com/Stellarium/stellarium/refs/tags/v23.4/skycultures/modern/star_names.fab" 2>/dev/null; then
    cp "$STAR_NAMES_TMP" "sources/iau/star_names.fab"
    echo "   ✅ Saved → sources/iau/star_names.fab (from v23.4)"
  else
    # Not fatal — stars will fall back to "HIP <number>" identifiers.
    touch "sources/iau/star_names.fab"
    echo "   ⚠️  Could not download star_names.fab — created empty placeholder"
    echo "      Stars will fall back to HIP-number identifiers."
  fi
fi
rm -f "$STAR_NAMES_TMP"

# ── e. Stellarium Chinese skyculture ─────────────────────────────────────────
# Source: Stellarium GitHub skycultures/chinese/

echo ""
echo "🐉 Stellarium Chinese skyculture…"

# Use v23.4 tag for stability; the parser expects constellationship.fab,
# star_names.fab, and index.json (the latter two are optional).
BASE_TAG="https://raw.githubusercontent.com/Stellarium/stellarium/refs/tags/v23.4/skycultures/chinese"
BASE_MASTER="https://raw.githubusercontent.com/Stellarium/stellarium/master/skycultures/chinese"

download_chinese_file() {
  local fname="$1"
  local dest="sources/stellarium/chinese/$fname"
  mkdir -p sources/stellarium/chinese

  if [[ -f "$dest" ]]; then
    echo "   ⏭  chinese/$fname already exists, skipping"
    return
  fi

  echo "   ⬇  chinese/$fname"
  if curl --fail --silent --show-error --location \
      --connect-timeout 15 --max-time 60 \
      --output "$dest" "${BASE_TAG}/$fname" 2>/dev/null; then
    echo "   ✅ Saved → $dest"
  elif curl --fail --silent --show-error --location \
      --connect-timeout 15 --max-time 60 \
      --output "$dest" "${BASE_MASTER}/$fname" 2>/dev/null; then
    echo "   ✅ Saved → $dest (from master)"
  else
    echo "   ⚠️  $fname not available from Stellarium — will use bundled fallback"
    rm -f "$dest"
  fi
}

download_chinese_file "constellationship.fab"
download_chinese_file "star_names.fab"
download_chinese_file "index.json"

echo ""
echo "🎉 All sources downloaded successfully!"
echo "   Run ./generate_bins.sh (or dart run bin/pipeline.dart) to build .bin files."

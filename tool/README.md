# Starling Data Pipeline (`tool/`)

This directory contains an **independent Dart package** that converts raw
astronomy data sources into compact FlatBuffers `.bin` files consumed by the
Flutter application.

---

## Architecture

```
Raw sources (CSV / FAB / JSON)
        │
        ▼
  ┌────────────────────┐
  │  flatc --dart       │  ← build-time only (optional; pre-generated file
  │  schema/stargazer.fbs  included)
  └─────────┬──────────┘
            │ generates stargazer_generated.dart
            ▼
  ┌────────────────────┐
  │  dart run           │
  │  bin/pipeline.dart  │  ← pure-Dart parse + validate + serialise
  └────────┬───────────┘
           │
     ┌─────┼──────────┐
     ▼     ▼          ▼
catalog  culture   culture           culture
_base    _western  _chinese_modern   _chinese
 .bin     .bin      .bin             .bin
           │
           ▼
     ../assets/bin/    ← Flutter asset bundle
```

---

## Directory Layout

```
tool/
├── pubspec.yaml               ← independent Dart package (no Flutter deps)
├── build.sh                   ← one-click pipeline runner
├── schema/
│   └── stargazer.fbs          ← FlatBuffers schema (source of truth)
├── generated/
│   └── stargazer_generated.dart  ← pre-generated; re-run flatc to update
├── lib/
│   ├── parsers/
│   │   ├── models.dart              ← intermediate data models
│   │   ├── hipparcos_parser.dart    ← ESA Hipparcos CSV
│   │   ├── iau_lines_parser.dart    ← IAU stick-figure edges
│   │   ├── iau_boundary_parser.dart ← IAU constellation boundaries
│   │   └── stellarium_chinese_parser.dart
│   ├── validators/
│   │   └── integrity_checker.dart   ← acceptance criteria
│   └── builders/
│       ├── catalog_builder.dart     ← catalog_base.bin
│       ├── western_builder.dart     ← culture_western.bin
│       └── chinese_builder.dart     ← culture_chinese.bin
├── bin/
│   ├── pipeline.dart          ← entry point
│   └── investigate_chinese_links.dart  ← provenance investigation tool
└── sources/                   ← raw data (not Flutter-bundled)
    ├── hipparcos/
    │   └── hip_main.csv        ← download from ESA/CDS (see below)
    ├── iau/
    │   ├── constellation_lines.csv
    │   └── constellation_boundaries.csv
    └── stellarium/
        └── chinese/            ← copy from Stellarium repo (see below)
            ├── constellationship.fab
            ├── star_names.fab
            └── index.json
```

---

## Data Sources

| Data | Source | Placement |
|------|--------|-----------|
| Hipparcos main table | [ESA/CDS I/239](https://cdsarc.cds.unistra.fr/viz-bin/cat/I/239) – download `hip_main.dat` and convert to pipe-separated CSV | `sources/hipparcos/hip_main.csv` |
| IAU constellation lines | [Stellarium modern skyculture](https://github.com/Stellarium/stellarium/tree/master/skycultures/modern) – convert `constellationship.fab` to CSV | `sources/iau/constellation_lines.csv` |
| IAU constellation boundaries | [Davenhall & Leggett VI/49](https://cdsarc.cds.unistra.fr/viz-bin/cat/VI/49) | `sources/iau/constellation_boundaries.csv` |
| Chinese sky culture | [Stellarium Chinese skyculture](https://github.com/Stellarium/stellarium/tree/master/skycultures/chinese) | `sources/stellarium/chinese/` |

> **Note:** Raw data files are excluded from version control (see `.gitignore`).
> They are large and have their own licences.  Download them separately before
> running the pipeline.

---

## Automated Download

A helper script downloads all required data sources automatically:

```bash
cd tool/
chmod +x download_sources.sh
./download_sources.sh
```

Or use the all-in-one script that downloads sources **and** runs the pipeline:

```bash
cd tool/
chmod +x generate_bins.sh
./generate_bins.sh
```

The download script uses the following sources (with fallbacks):

| File | Primary Source | Fallback |
|------|---------------|---------|
| `hip_main.csv` | ESA/CDS VizieR I/239 | HYG Database v38 (GitHub) |
| `constellation_lines.csv` | Stellarium GitHub (master) | v23.4 tag |
| `constellation_boundaries.csv` | CDS VI/49 `bound_20.dat.gz` (cdsarc, RA in degrees) | vizier.cds `bound_20.dat.gz` → cdsarc `constbnd.dat` → vizier.cds `constbnd.dat` → empty placeholder |
| `chinese/constellationship.fab` | Stellarium GitHub (v23.4) | master |
| `chinese/star_names.fab` | Stellarium GitHub (v23.4) | master |
| `chinese/index.json` | Stellarium GitHub (v23.4) | master |

---

```bash
# 1. Download data sources (see table above) into sources/

# 2. Run the pipeline
cd tool/
./build.sh

# Output lands in ../assets/bin/
#   catalog_base.bin    ~178 KB  (~9,096 stars)
#   culture_western.bin         ~80 KB  (88 IAU constellations)
#   culture_chinese_modern.bin  ~80 KB  (88 modern lines + Chinese naming)
#   culture_chinese.bin         ~15 KB  (~283 asterisms)
```

### Manual steps

```bash
cd tool/

# (Optional) Regenerate Dart code from schema:
flatc --dart -o generated/ schema/stargazer.fbs

# Fetch dependencies:
dart pub get

# Run the pipeline:
dart run bin/pipeline.dart --mag 6.5 --output ../assets/bin
```

### CLI options

| Flag | Default | Description |
|------|---------|-------------|
| `--output` / `-o` | `../assets/bin` | Output directory |
| `--mag` | `6.5` | Maximum visual magnitude to include |
| `--skip-validate` | `false` | Bypass integrity checks (not recommended) |
| `--help` / `-h` | – | Show usage |

---

## Expected Output

```
📥 Phase 1: Parsing sources…
   ✅ Stars: 9096 (mag ≤ 6.5)
   ✅ Western constellations: 88
   ✅ Chinese asterisms: 283
🔍 Phase 2: Validating integrity…
   ✅ Integrity checks passed
📦 Phase 3: Building .bin files…
   ✅ catalog_base.bin     (178.3 KB)
   ✅ culture_western.bin         ( 79.8 KB)
   ✅ culture_chinese_modern.bin  ( 79.8 KB)
   ✅ culture_chinese.bin         ( 14.9 KB)

🎉 Done!  Total: 273.0 KB → ../assets/bin/
```

---

## Regenerating the FlatBuffers Schema

Install [FlatBuffers](https://flatbuffers.dev/flatbuffers_guide_building.html)
(`flatc`), then:

```bash
cd tool/
flatc --dart -o generated/ schema/stargazer.fbs
```

The generated file is committed to the repository so that the pipeline can run
without `flatc` installed.  Only re-run `flatc` when `schema/stargazer.fbs`
changes.

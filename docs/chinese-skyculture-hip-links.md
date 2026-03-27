# Chinese Sky-Culture: HIP 51384 / 51502 / 58874 Link Provenance

This document traces the complete chain of data provenance for the observed
rendering link `HIP 51384 → HIP 51502 → HIP 58874` in the Chinese sky-culture
mode of the Starling app.

---

## 1. What the user sees

In the app's Chinese sky-culture view, three stars near the north celestial
pole are connected by straight lines:

```
HIP 51384  ─────  HIP 51502  ─────  HIP 58874
```

Nearby (but **not** connected by a line) is a star labelled **四辅增一**,
which is HIP 47193.

---

## 2. Raw upstream source data

### Source: Stellarium v23.4 Chinese sky culture

Downloaded from:
```
https://raw.githubusercontent.com/Stellarium/stellarium/refs/tags/v23.4/skycultures/chinese/
```

The three relevant files live in `tool/sources/stellarium/chinese/` after
running `tool/download_sources.sh`.

---

### 2a. `constellationship.fab` – the line that creates the links

**File line 200** (plain text, whitespace-separated):

```
200 2 58874 51502 51502 51384
```

Interpretation:

| Field    | Value         | Meaning                                       |
|----------|---------------|-----------------------------------------------|
| `200`    | asterism ID   | bare string `"200"` – matches index.json's `"CON chinese 200"` after prefix stripping |
| `2`      | num_pairs     | two directed edge pairs follow                |
| `58874 51502` | edge 1   | HIP 58874 → HIP 51502                        |
| `51502 51384` | edge 2   | HIP 51502 → HIP 51384                        |

This single line is the **complete and sole raw-source origin** of both
observed links.

---

### 2b. `index.json` – asterism name metadata

The relevant entry (condensed):

```json
{
  "id": "CON chinese 200",
  "lines": [[58874, 51502, 51384]],
  "common_name": {
    "english": "Four Advisors",
    "native": "四辅",
    "pronounce": "Sì Fǔ"
  }
}
```

The `lines` array in index.json is used only for rendering in Stellarium itself;
this repo uses the FAB file for edges.

The `common_name` block supplies the display name "四辅" / "Four Advisors".

---

### 2c. `star_names.fab` – per-star name labels

The relevant entries (Stellarium `|_()` format):

```
#Four Advisors
51384|_("Four Advisors II") 1
51502|_("Four Advisors III") 1
58874|_("Four Advisors IV?") 2
47193|_("Four Advisors Added I") 1
```

Notes:
- HIP 51384, 51502, 58874 are named **四辅二 / 四辅三 / 四辅四?** and are
  the member stars of the 四辅 asterism.
- HIP 47193 (**四辅增一** / "Four Advisors Added I") is a nearby star with a
  name but **no entry in any constellationship.fab edge**; it is an 增星
  (added/supplementary star) that participates in the naming system but not
  in the line-drawing.
- There is **no "Four Advisors I"** in this version of the Stellarium Chinese
  sky-culture data. The asterism contains only II, III, and IV?.

The `star_names.fab` individual-star names reach the app via
`index.json`'s `common_names` section (parallel data; see §3 below).

---

## 3. Transformation through this repository

### Step 1 – `tool/download_sources.sh`

Downloads the three source files:

```
sources/stellarium/chinese/constellationship.fab
sources/stellarium/chinese/star_names.fab
sources/stellarium/chinese/index.json
```

### Step 2 – `tool/lib/parsers/stellarium_chinese_parser.dart`

`StellariumChineseParser.parse(directory)` performs three sub-steps:

**2a. `_parseIndexJson`** reads `index.json` and builds a map:

```
nameMeta["200"] = { "zh": "四辅", "en": "Four Advisors" }
```

Key implementation detail: the `id` field in index.json is `"CON chinese 200"`,
so the parser strips the well-known `"CON chinese "` prefix before storing
into `nameMeta`. (This prefix-stripping was introduced as a bug-fix; see §5.)

**2b. `_parseStarNames`** attempts to parse `star_names.fab` into a
`starNameMap`. The Stellarium Chinese `star_names.fab` uses the
`<hip>|_("<name>") <count>` format, which is **not** the space-separated
`<hip> <nameZh> <nameEn>` format the private `_parseStarNames` expects.
All entries fail `int.tryParse(parts[0])` and the resulting map is empty.
The `starNameMap` is passed to `_parseConstellationship` but is not used
there; it is effectively a no-op in the current implementation.

Chinese star proper names instead reach `catalog_base.bin` via a separate
code path: `StellariumChineseParser.parseStarNames(indexFile)` (public
method, called from `pipeline.dart`) reads the `common_names` section of
`index.json` — a parallel, fully functional mechanism.

**2c. `_parseConstellationship`** reads `constellationship.fab` line by line:

```
line: "200 2 58874 51502 51502 51384"
  id        = "200"
  num_pairs = 2
  edges     = [ EdgeRecord(58874, 51502), EdgeRecord(51502, 51384) ]
  nameMeta["200"] = { zh: "四辅", en: "Four Advisors" }   → match ✓
  → AsterismRecord(name="四辅", nameEn="Four Advisors", edges=…)
```

### Step 3 – `tool/lib/builders/chinese_builder.dart`

`ChineseBuilder.build(asterisms)` serialises each `AsterismRecord` into a
`ChineseAsterism` FlatBuffers table:

```
name    = "四辅"
nameEn  = "Four Advisors"
edges   = [ Edge(58874, 51502), Edge(51502, 51384) ]
```

The output is written to `assets/bin/culture_chinese.bin`.

### Step 4 – `lib/data/stargazer_reader.dart` (`ChineseCultureReader`)

At runtime the app reads `culture_chinese.bin` into a `BinChineseAsterism`:

```dart
BinChineseAsterism(
  name:   "四辅",
  nameEn: "Four Advisors",
  edges:  [58874, 51502, 51502, 51384],   // interleaved uint16 pairs
  …
)
```

### Step 5 – `lib/models/constellation.dart` (`Constellation.fromChineseBin`)

```dart
factory Constellation.fromChineseBin({
  required String name,   // "四辅"
  String? nameEn,         // "Four Advisors"
  required List<int> edgePairs,  // [58874, 51502, 51502, 51384]
  …
})
```

Each adjacent pair becomes a `ConstellationLine`:

```
edgePairs[0..1] → ConstellationLine.fromHip(58874, 51502)
edgePairs[2..3] → ConstellationLine.fromHip(51502, 51384)
```

The `starIds` set becomes `["hip_58874", "hip_51502", "hip_51384"]`.

### Step 6 – `lib/widgets/star_chart.dart`

For every `ConstellationLine` in the active `Constellation`, the renderer
calls `drawLine(p1, p2, …)` where `p1` and `p2` are the projected screen
coordinates of the two endpoint stars. This produces the visible line segments.

---

## 4. 星官 / asterism metadata provenance summary

| Metadata field | Raw source | Parser step | Binary field |
|----------------|-----------|-------------|--------------|
| Chinese name 四辅 | `index.json` → `common_name.native` | `_parseIndexJson` | `name` |
| English name Four Advisors | `index.json` → `common_name.english` | `_parseIndexJson` | `name_en` |
| Edges 58874↔51502↔51384 | `constellationship.fab` line 200 | `_parseConstellationship` | `edges` |
| Quadrant / Mansion | Derived from FAB ID prefix via `_classifyAsterism` | `_classifyAsterism` | `quadrant` / `mansion` |

**Star-level names** (四辅二, 四辅三, 四辅四?):
- Come from `index.json` → `common_names` section, parsed by
  `StellariumChineseParser.parseStarNames()`
- Stored in `catalog_base.bin` as `Star.nameZh`
- Displayed as the label for each individual star point, **independently** of
  asterism line membership

**HIP 47193 (四辅增一)**:
- Named in `star_names.fab` and `index.json` `common_names`
- Has no entry in any `constellationship.fab` edge; it is an 增星 only
- Appears as a labelled star near the asterism but has no connecting line

---

## 5. Parser bug discovered and fixed

### Root cause

`_parseIndexJson` was storing name metadata under the raw `"id"` string from
index.json (e.g. `"CON chinese 200"`), while `_parseConstellationship` looked
up `nameMeta["200"]` using the bare FAB token. The keys never matched.

**Consequence**: every Chinese asterism's `name` and `nameEn` fields fell back
to the bare FAB ID (e.g. `"200"`, `"001"`) instead of the correct Chinese
characters and English translation. All 318 asterisms in the pre-fix binary
had numeric-only names.

### Fix

In `tool/lib/parsers/stellarium_chinese_parser.dart`, `_parseIndexJson` now
strips the `"CON chinese "` prefix before storing the key:

```dart
var id = item['id']?.toString() ?? '';
const prefix = 'CON chinese ';
if (id.startsWith(prefix)) id = id.substring(prefix.length);
```

After this fix and binary regeneration, asterism 199 (index 0-based) in
`culture_chinese.bin` reads:

```
name   = "四辅"
nameEn = "Four Advisors"
edges  = [(58874, 51502), (51502, 51384)]
```

---

## 6. Is this correct per upstream Stellarium data?

**Yes** — the two links are correct per the upstream Stellarium v23.4
Chinese sky-culture data. Specifically:

- `constellationship.fab` line 200 explicitly encodes both edges.
- `index.json` confirms the asterism as 四辅 / Four Advisors.
- HIP 51384, 51502, 58874 are the known three stars of the Four Advisors
  asterism (四辅二, 四辅三, 四辅四?) near the north celestial pole in
  Camelopardalis.
- The absence of "Four Advisors I" from the edge set is consistent with
  the upstream data and is **not a repo-side error**.

---

## 7. Reproducible investigation

Run the bundled script (after downloading sources with
`tool/download_sources.sh`):

```bash
# By HIP numbers
python3 scripts/investigate_chinese_links.py 51384 51502 58874

# By asterism name
python3 scripts/investigate_chinese_links.py "Four Advisors"

# Any HIP in the area
python3 scripts/investigate_chinese_links.py 47193
```

Automated test coverage lives in `test/stargazer_reader_test.dart` in the
`ChineseCultureReader (culture_chinese.bin)` group.

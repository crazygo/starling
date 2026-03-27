# 四辅 Rendering Investigation

**Status: Root cause identified and fixed.**  
**Date: 2026-03-27**

---

## Observed Symptom

In the Starling app's star-chart view, users observed:

- HIP 51502, HIP 51384, and HIP 58874 were connected by lines.
- The string **`200`** appeared floating above / near the linework.
- HIP 47193 appeared nearby, labelled **四辅增一**.
- It was unclear whether `200` was HIP 200, a mislabelled artifact, or the
  asterism name.

---

## What `200` Actually Is

**`200` is the asterism label** — not a star.

In the app's rendered star-chart, Chinese asterism names are drawn near their
linework.  The asterism whose Stellarium ID is `"200"` corresponds to the star
pattern **四辅** (Sì Fǔ, *Four Advisors*).  Because of a parser bug (described
below), the binary stored the raw numeric Stellarium ID `"200"` as both the
Chinese and English name of this asterism, which the app then displayed as the
label.

**HIP 200 (a dim star in Pisces/Andromeda) plays no role whatsoever.**

---

## Exact Source Record

### `constellationship.fab` (line 200)

```
200 2 58874 51502 51502 51384
```

- Asterism ID: `200`
- Number of edge pairs: 2
- Edge 1: HIP 58874 ↔ HIP 51502
- Edge 2: HIP 51502 ↔ HIP 51384

### `index.json` entry

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

### Star names for member HIP numbers (from `index.json` `common_names`)

| HIP    | Native (Chinese) | English                     | Notes                         |
|--------|------------------|-----------------------------|-------------------------------|
| 58874  | 四辅四?           | Four Advisors IV?           | Member star; uncertain ID     |
| 51502  | 四辅三            | Four Advisors III           | Member star                   |
| 51384  | 四辅二            | Four Advisors II            | Member star                   |
| 47193  | 四辅增一           | Four Advisors Added I       | Supplemental star, **not** in edges |
| 200    | *(none)*          | *(no entry)*                | HIP 200 is irrelevant         |

### Why HIP 47193 appears nearby but is not connected

HIP 47193 (四辅增一, *Four Advisors Added I*) is a *supplemental* star: it is
named as part of the Four Advisors region but it is **not listed in the
`constellationship.fab` edge record for asterism `200`**.  The app draws lines
only for pairs listed in the edges, so HIP 47193 is labelled but unconnected.

---

## Root Cause: Parser Bug

**File:** `tool/lib/parsers/stellarium_chinese_parser.dart`  
**Method:** `_parseIndexJson()`

### Bug 1 — ID prefix mismatch

The Stellarium `index.json` format uses `"CON chinese NNN"` as the
`constellations[].id` field:

```json
{ "id": "CON chinese 200", "common_name": { "native": "四辅", ... } }
```

But `constellationship.fab` uses the **short numeric ID** (`200`, `001`, etc.):

```
200 2 58874 51502 51502 51384
```

The old parser code stored the **full ID** (`"CON chinese 200"`) as the lookup
key in `nameMeta`:

```dart
// OLD — stores "CON chinese 200" but lookup uses "200":
final id = item['id']?.toString() ?? '';
if (id.isNotEmpty) nameMeta[id] = {'zh': nameZh, 'en': nameEn};
```

When `_parseConstellationship()` later looked up `nameMeta["200"]` it found
nothing, so **every one of the 318 asterisms fell back to its raw numeric ID**
as both the Chinese name and English name.

### Bug 2 — Wrong JSON field for the Chinese name

The old code read the Chinese name from `item['name']`:

```dart
// OLD — item['name'] does not exist in Stellarium index.json:
final nameZh = item['name']?.toString() ?? id;
```

The correct field is `item['common_name']['native']`.

### Fix (committed in this PR)

```dart
// Strip "CON chinese " prefix to get the short id that matches
// constellationship.fab.
final fullId = item['id']?.toString() ?? '';
final id = fullId.startsWith('CON chinese ')
    ? fullId.substring('CON chinese '.length)
    : fullId;

// Chinese name lives under common_name.native (not item['name']).
final nameZh =
    (item['common_name'] as Map<String, dynamic>?)?['native']?.toString()
        ?? id;
final nameEn = item['common_name']?['english']?.toString()
    ?? item['common_name']?['transliteration']?.toString()
    ?? id;
if (id.isNotEmpty) nameMeta[id] = {'zh': nameZh, 'en': nameEn};
```

---

## Data Pipeline

```
constellationship.fab  ──→  StellariumChineseParser.parse()
                              ↓
index.json             ──→  _parseIndexJson()  (name lookup)
                              ↓
                           List<AsterismRecord>
                              ↓
                           ChineseBuilder.build()
                              ↓
                       assets/bin/culture_chinese.bin
                              ↓
                       ChineseCultureReader  (Dart/Flutter app)
                              ↓
                       Constellation.fromChineseBin()
                              ↓
                       StarChart renders lines + labels
```

The `200` label reached the app because the FlatBuffers binary
(`culture_chinese.bin`) contained `name = "200"` and `name_en = "200"` for the
Four Advisors asterism, which the renderer then drew as a text label near the
linework.

---

## Files Changed in This PR

| File | Change |
|------|--------|
| `tool/lib/parsers/stellarium_chinese_parser.dart` | Fix `_parseIndexJson`: strip `"CON chinese "` prefix; read `common_name.native` for Chinese name |
| `assets/bin/culture_chinese.bin` | Regenerated binary with correct names (`四辅`, `Four Advisors`, etc.) |
| `tool/inspect_chinese_asterisms.py` | New: analysis/inspection script |
| `tool/rebuild_chinese_bin.py` | New: Python rebuild script (requires `pip install flatbuffers`) |
| `docs/sifu-investigation.md` | New: this document |
| `test/stargazer_reader_test.dart` | Regression tests: correct 四辅 name, edges, and no purely-numeric names |
| `tool/README.md` | Fix expected asterism count (283 → 318) |

---

## Reproducing the Analysis

```bash
cd tool/
./download_sources.sh                 # download constellationship.fab + index.json
python3 inspect_chinese_asterisms.py  # show 四辅 data from binary and raw sources
python3 rebuild_chinese_bin.py        # rebuild binary with correct names
```

The `inspect_chinese_asterisms.py` script can be run at any time against the
committed binary (no download needed) to verify the current state.

---

## Verification

After the fix, the binary contains:

```
[199] name='四辅'  nameEn='Four Advisors'
      quadrant=Central (三垣)
      mansion=None
      edge pairs: [(58874, 51502), (51502, 51384)]
      all member HIPs: [51384, 51502, 58874]
```

No asterism has a purely numeric name; all 318 asterisms resolve to their
proper Chinese and English names from `index.json`.

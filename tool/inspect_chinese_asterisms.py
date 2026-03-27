#!/usr/bin/env python3
"""
inspect_chinese_asterisms.py — Inspect culture_chinese.bin and/or raw Stellarium
Chinese sky-culture sources for specific asterisms.

Usage:
    cd tool/
    python3 inspect_chinese_asterisms.py [--bin PATH] [--sources DIR] [--asterism NAME_OR_ID]

By default the script reads assets/bin/culture_chinese.bin (relative to the repo
root) and — if present — the raw Stellarium source files under
tool/sources/stellarium/chinese/.

Run `tool/download_sources.sh` first to populate the raw source files.
"""

import argparse
import json
import os
import struct
import sys

# ── FlatBuffers reader helpers ────────────────────────────────────────────────
# Mirrors the logic in lib/data/stargazer_reader.dart so this script can
# decode culture_chinese.bin without a Dart/Flutter toolchain.


def _u32(data: bytes, off: int) -> int:
    return struct.unpack_from("<I", data, off)[0]


def _u16(data: bytes, off: int) -> int:
    return struct.unpack_from("<H", data, off)[0]


def _i32(data: bytes, off: int) -> int:
    return struct.unpack_from("<i", data, off)[0]


def _u8(data: bytes, off: int) -> int:
    return struct.unpack_from("<B", data, off)[0]


def _fb_string(data: bytes, str_off: int) -> str:
    length = _u32(data, str_off)
    return data[str_off + 4 : str_off + 4 + length].decode("utf-8")


def _root(data: bytes) -> int:
    return _u32(data, 0)


def _field_off(data: bytes, toff: int, fi: int) -> int:
    vto = toff - _i32(data, toff)
    vsz = _u16(data, vto)
    fp = vto + 4 + fi * 2
    if fp >= vto + vsz:
        return 0
    return _u16(data, fp)


def _toff_field(data: bytes, toff: int, fi: int):
    rel = _field_off(data, toff, fi)
    if rel == 0:
        return None
    abs_fp = toff + rel
    return abs_fp + _u32(data, abs_fp)


def _t_str(data: bytes, toff: int, fi: int):
    ap = _toff_field(data, toff, fi)
    return None if ap is None else _fb_string(data, ap)


def _t_u8(data: bytes, toff: int, fi: int, default: int = 0) -> int:
    rel = _field_off(data, toff, fi)
    return default if rel == 0 else _u8(data, toff + rel)


def _t_u16vec(data: bytes, toff: int, fi: int):
    vp = _toff_field(data, toff, fi)
    if vp is None:
        return []
    count = _u32(data, vp)
    return [_u16(data, vp + 4 + i * 2) for i in range(count)]


def _t_offvec(data: bytes, toff: int, fi: int):
    vp = _toff_field(data, toff, fi)
    if vp is None:
        return []
    count = _u32(data, vp)
    result = []
    for i in range(count):
        ep = vp + 4 + i * 4
        result.append(ep + _u32(data, ep))
    return result


# ── Quadrant / Mansion labels ─────────────────────────────────────────────────

QUADRANT_NAMES = {
    0: "EastAzure (东方青龙)",
    1: "NorthBlack (北方玄武)",
    2: "WestWhite (西方白虎)",
    3: "SouthScarlet (南方朱雀)",
    4: "Central (三垣)",
}

MANSION_NAMES = {
    0: "None",
    1: "Horn (角)", 2: "Neck (亢)", 3: "Root (氐)", 4: "Room (房)",
    5: "Heart (心)", 6: "Tail (尾)", 7: "Winnowing (箕)",
    8: "Dipper (斗)", 9: "Ox (牛)", 10: "Girl (女)", 11: "Emptiness (虚)",
    12: "Rooftop (危)", 13: "Encampment (室)", 14: "Wall (壁)",
    15: "Stride (奎)", 16: "Bond (娄)", 17: "Stomach (胃)",
    18: "Hairy (昴)", 19: "Net (毕)", 20: "Turtle (觜)", 21: "Three (参)",
    22: "Well (井)", 23: "Ghost (鬼)", 24: "Willow (柳)", 25: "Star (星)",
    26: "Extended (张)", 27: "Wings (翼)", 28: "Chariot (轸)",
}


# ── Binary decoder ────────────────────────────────────────────────────────────


def load_bin(path: str):
    with open(path, "rb") as f:
        data = f.read()
    root = _root(data)
    offsets = _t_offvec(data, root, 0)
    asterisms = []
    for toff in offsets:
        edges = _t_u16vec(data, toff, 4)
        pairs = [(edges[i], edges[i + 1]) for i in range(0, len(edges) - 1, 2)]
        asterisms.append(
            {
                "name": _t_str(data, toff, 0) or "",
                "name_en": _t_str(data, toff, 1) or "",
                "quadrant": _t_u8(data, toff, 2),
                "mansion": _t_u8(data, toff, 3),
                "edges_raw": edges,
                "edge_pairs": pairs,
                "hip_set": set(edges),
            }
        )
    return asterisms


# ── Raw source reader ─────────────────────────────────────────────────────────


def load_constellationship(path: str):
    """Return {id: [edge_pair, …]} from constellationship.fab."""
    records = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            cid = parts[0]
            num_pairs = int(parts[1])
            pairs = []
            for i in range(num_pairs):
                fi = 2 + i * 2
                ti = 3 + i * 2
                if ti >= len(parts):
                    break
                pairs.append((int(parts[fi]), int(parts[ti])))
            records[cid] = pairs
    return records


def load_index_json(path: str):
    """Return {short_id: {native, english}} from index.json.

    Normalises Stellarium's "CON chinese NNN" identifiers to their short "NNN"
    form so they match the IDs used in constellationship.fab.
    """
    names = {}
    star_names = {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    for item in data.get("constellations", []):
        full_id = item.get("id", "")
        short_id = (
            full_id[len("CON chinese ") :]
            if full_id.startswith("CON chinese ")
            else full_id
        )
        cn = item.get("common_name", {})
        names[short_id] = {
            "native": cn.get("native", short_id),
            "english": cn.get("english", cn.get("transliteration", short_id)),
            "full_id": full_id,
        }

    for key, entries in data.get("common_names", {}).items():
        if not key.startswith("HIP "):
            continue
        hip = int(key[4:])
        if entries and isinstance(entries[0], dict):
            first = entries[0]
            star_names[hip] = {
                "native": first.get("native", ""),
                "english": first.get("english", ""),
            }

    return names, star_names


# ── Formatting helpers ────────────────────────────────────────────────────────


def fmt_edge_pairs(pairs):
    return " → ".join(f"HIP {a}↔{b}" for a, b in pairs)


def print_asterism(idx, a, label=""):
    q = QUADRANT_NAMES.get(a["quadrant"], str(a["quadrant"]))
    m = MANSION_NAMES.get(a["mansion"], str(a["mansion"]))
    print(f"  [{idx}] {label}name={a['name']!r}  nameEn={a['name_en']!r}")
    print(f"       quadrant={q}")
    print(f"       mansion={m}")
    print(f"       edge pairs ({len(a['edge_pairs'])}): {a['edge_pairs']}")
    hips = sorted(a["hip_set"])
    print(f"       all member HIPs: {hips}")


# ── Main ──────────────────────────────────────────────────────────────────────

TARGET_HIPS = {200, 47193, 51384, 51502, 58874}

REPO_ROOT = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..")
)


def main():
    parser = argparse.ArgumentParser(
        description="Inspect Chinese asterism data in culture_chinese.bin."
    )
    parser.add_argument(
        "--bin",
        default=os.path.join(REPO_ROOT, "assets", "bin", "culture_chinese.bin"),
        help="Path to culture_chinese.bin",
    )
    parser.add_argument(
        "--sources",
        default=os.path.join(REPO_ROOT, "tool", "sources", "stellarium", "chinese"),
        help="Path to Stellarium Chinese skyculture source directory",
    )
    parser.add_argument(
        "--asterism",
        default=None,
        help="Filter: show only asterisms whose name/nameEn contains this string",
    )
    args = parser.parse_args()

    # ── 1. Binary ─────────────────────────────────────────────────────────────
    print("=" * 68)
    print(f"culture_chinese.bin  →  {args.bin}")
    print("=" * 68)

    if not os.path.isfile(args.bin):
        print(f"  ❌ File not found: {args.bin}")
        print("     Run the Dart pipeline (tool/generate_bins.sh) to build it.")
    else:
        asterisms = load_bin(args.bin)
        print(f"  Total asterisms: {len(asterisms)}")

        # Check for purely-numeric names (naming bug indicator)
        numeric_names = [a for a in asterisms if a["name"].strip("0123456789") == ""]
        if numeric_names:
            print(
                f"\n  ⚠️  {len(numeric_names)} asterism(s) have purely numeric names"
                " (index.json lookup failed at build time)."
            )
            print(
                "     Root cause: the parser looked up Stellarium ID 'NNN' but\n"
                "     index.json keys are 'CON chinese NNN' — see parser fix in\n"
                "     tool/lib/parsers/stellarium_chinese_parser.dart.\n"
                "     Re-run tool/generate_bins.sh to rebuild with correct names."
            )

        print()

        # ── 2a. Search for 四辅 by Chinese name ───────────────────────────────
        print("── Searching for '四辅' (Four Advisors) ──")
        found_sifu = [
            (i, a)
            for i, a in enumerate(asterisms)
            if "四辅" in a["name"] or "Four Advisors" in a["name_en"]
        ]
        if found_sifu:
            for i, a in found_sifu:
                print_asterism(i, a, label="✅ ")
        else:
            print("  Not found by Chinese/English name.")

        # ── 2b. Search by target HIP membership ──────────────────────────────
        print()
        print(
            f"── Asterisms containing any of HIP {sorted(TARGET_HIPS)} ──"
        )
        for i, a in enumerate(asterisms):
            matched = a["hip_set"] & TARGET_HIPS
            if matched:
                print_asterism(i, a, label=f"HIP match {sorted(matched)}: ")

        # ── 2c. Filter by --asterism argument ─────────────────────────────────
        if args.asterism:
            filt = args.asterism.lower()
            print()
            print(f"── Filter: '{args.asterism}' ──")
            for i, a in enumerate(asterisms):
                if filt in a["name"].lower() or filt in a["name_en"].lower():
                    print_asterism(i, a)

    # ── 3. Raw sources ────────────────────────────────────────────────────────
    fab_path = os.path.join(args.sources, "constellationship.fab")
    idx_path = os.path.join(args.sources, "index.json")

    print()
    print("=" * 68)
    print(f"Raw Stellarium sources  →  {args.sources}")
    print("=" * 68)

    if not os.path.isfile(fab_path):
        print(
            f"  ⚠️  constellationship.fab not found.\n"
            f"     Run  cd tool && ./download_sources.sh  to download it."
        )
    else:
        fab = load_constellationship(fab_path)
        print(f"  constellationship.fab  ({len(fab)} records)")

        idx_names = {}
        star_names_map = {}
        if os.path.isfile(idx_path):
            idx_names, star_names_map = load_index_json(idx_path)
            print(
                f"  index.json             ({len(idx_names)} constellation entries,"
                f" {len(star_names_map)} star names)"
            )
        else:
            print(
                "  ⚠️  index.json not found — constellation names unavailable.\n"
                "     Run  cd tool && ./download_sources.sh  to download it."
            )

        # Find record "200" (= 四辅) in constellationship.fab
        print()
        print("── Record '200' in constellationship.fab ──")
        if "200" in fab:
            pairs = fab["200"]
            name_info = idx_names.get("200", {})
            print(f"  ID: 200")
            print(f"  Raw line: 200 {len(pairs)} " + " ".join(f"{a} {b}" for a, b in pairs))
            print(f"  Edge pairs: {pairs}")
            print(f"  All member HIPs: {sorted(set(h for p in pairs for h in p))}")
            if name_info:
                print(f"  index.json name (native):  {name_info.get('native', '—')!r}")
                print(f"  index.json name (english): {name_info.get('english', '—')!r}")
                print(f"  index.json full id:        {name_info.get('full_id', '—')!r}")
            else:
                print("  ⚠️  No matching entry in index.json for id '200'")
        else:
            print("  Record '200' not found.")

        # Show star name data for target HIPs
        if star_names_map:
            print()
            print(f"── Star names for target HIPs ──")
            for hip in sorted(TARGET_HIPS):
                info = star_names_map.get(hip, {})
                if info:
                    print(
                        f"  HIP {hip:6d}  native={info['native']!r:20s}"
                        f"  english={info['english']!r}"
                    )
                else:
                    print(f"  HIP {hip:6d}  (no name entry in index.json)")

    # ── 4. Summary ────────────────────────────────────────────────────────────
    print()
    print("=" * 68)
    print("Summary: 四辅 (Four Advisors) — root-cause analysis")
    print("=" * 68)
    print("""
  The app shows '200' floating near the line connecting HIP 51502,
  51384, and 58874.  '200' is NOT HIP 200 — it is the asterism LABEL
  for the Chinese star-pattern whose Stellarium ID is '200'.

  Root cause (parser bug in tool/lib/parsers/stellarium_chinese_parser.dart):
    • The parser's _parseIndexJson() read item['id'] as-is, storing e.g.
      'CON chinese 200' in nameMeta.
    • _parseConstellationship() then looked up the short key '200' which
      never matched, so every asterism fell back to its raw numeric ID
      ('001', '002', … '200', …) as both its Chinese and English name.
    • Additionally, the Chinese name was read from item['name'] (absent
      in the actual JSON) instead of item['common_name']['native'].

  Fix (committed in this PR):
    • Strip the 'CON chinese ' prefix when building the nameMeta map.
    • Read Chinese names from item['common_name']['native'].

  What 四辅 actually is:
    • Asterism ID '200' in constellationship.fab.
    • Chinese name: 四辅 (Sì Fǔ)  English: Four Advisors
    • Edges: HIP 58874↔51502, 51502↔51384  (stars in Camelopardalis,
      near the north pole — correct for 紫微垣).
    • HIP 47193 is labeled 四辅增一 (Four Advisors Added I); it is a
      supplemental star in the same region but NOT part of the drawing
      edges — that is why it appears nearby but unconnected.
    • HIP 200 plays NO role whatsoever in this asterism.
""")


if __name__ == "__main__":
    main()

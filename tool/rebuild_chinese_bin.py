#!/usr/bin/env python3
"""
rebuild_chinese_bin.py — Rebuild assets/bin/culture_chinese.bin with correct
Chinese/English asterism names by applying the fixed index.json lookup logic.

The existing binary already has correct edge data (stars, connections).  This
script reads those edges verbatim and replaces only the asterism *names* using
the corrected parser logic (strips "CON chinese " prefix, reads
common_name.native for Chinese).  That avoids re-encoding the HIP uint16
truncation that the original Dart pipeline applied.

Usage:
    cd tool/
    ./download_sources.sh          # populate sources/stellarium/chinese/
    python3 rebuild_chinese_bin.py

Prerequisites:
    pip install flatbuffers
"""

import argparse
import json
import os
import struct
import sys

try:
    from flatbuffers import builder as fb
except ImportError:
    print("❌ flatbuffers package not installed.  Run: pip install flatbuffers")
    sys.exit(1)

# ── FlatBuffers reader (mirrors lib/data/stargazer_reader.dart) ──────────────


def _u32(d, o): return struct.unpack_from("<I", d, o)[0]
def _u16(d, o): return struct.unpack_from("<H", d, o)[0]
def _i32(d, o): return struct.unpack_from("<i", d, o)[0]
def _u8(d, o):  return struct.unpack_from("<B", d, o)[0]


def _fb_str(d, so):
    n = _u32(d, so)
    return d[so+4:so+4+n].decode("utf-8")


def _foff(d, toff, fi):
    vto = toff - _i32(d, toff)
    vsz = _u16(d, vto)
    fp = vto + 4 + fi * 2
    return 0 if fp >= vto + vsz else _u16(d, fp)


def _toff_f(d, toff, fi):
    rel = _foff(d, toff, fi)
    if rel == 0: return None
    ap = toff + rel
    return ap + _u32(d, ap)


def _t_str(d, toff, fi):
    ap = _toff_f(d, toff, fi)
    return None if ap is None else _fb_str(d, ap)


def _t_u8(d, toff, fi, default=0):
    rel = _foff(d, toff, fi)
    return default if rel == 0 else _u8(d, toff + rel)


def _t_u16v(d, toff, fi):
    vp = _toff_f(d, toff, fi)
    if vp is None: return []
    c = _u32(d, vp)
    return [_u16(d, vp+4+i*2) for i in range(c)]


def _t_offv(d, toff, fi):
    vp = _toff_f(d, toff, fi)
    if vp is None: return []
    c = _u32(d, vp)
    result = []
    for i in range(c):
        ep = vp + 4 + i*4
        result.append(ep + _u32(d, ep))
    return result


def read_existing_bin(path: str):
    """Read all asterisms from an existing culture_chinese.bin."""
    with open(path, "rb") as f:
        data = f.read()
    root = _u32(data, 0)
    offsets = _t_offv(data, root, 0)
    asterisms = []
    for i, toff in enumerate(offsets):
        edges = _t_u16v(data, toff, 4)
        pairs = [(edges[j], edges[j+1]) for j in range(0, len(edges)-1, 2)]
        asterisms.append({
            "bin_index": i,
            "name": _t_str(data, toff, 0) or "",
            "name_en": _t_str(data, toff, 1) or "",
            "quadrant": _t_u8(data, toff, 2),
            "mansion": _t_u8(data, toff, 3),
            "edge_pairs": pairs,
        })
    return asterisms


# ── Index.json name resolver ──────────────────────────────────────────────────


def parse_index_json(path: str):
    """Return name_map: {short_id → (name_zh, name_en)}.

    Normalises "CON chinese NNN" → "NNN" so keys match constellationship.fab IDs.
    """
    name_map = {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    for item in data.get("constellations", []):
        full_id = item.get("id", "")
        short_id = (
            full_id[len("CON chinese "):]
            if full_id.startswith("CON chinese ")
            else full_id
        )
        cn = item.get("common_name") or {}
        # Chinese name: common_name.native  (NOT item['name'], which is absent)
        name_zh = cn.get("native") or short_id
        name_en = cn.get("english") or cn.get("transliteration") or short_id
        if short_id:
            name_map[short_id] = (name_zh, name_en)

    return name_map


# ── FlatBuffers builder ───────────────────────────────────────────────────────


def build_chinese_bin(asterisms):
    """Encode a list of asterism dicts as culture_chinese.bin bytes."""
    builder = fb.Builder(1024 * 256)

    asterism_offsets = []
    for a in asterisms:
        edge_data = [v for pair in a["edge_pairs"] for v in pair]
        n = len(edge_data)
        builder.StartVector(2, n, 1)
        for v in reversed(edge_data):
            builder.PrependUint16(v)
        edges_off = builder.EndVector(n)

        name_off = builder.CreateString(a["name"])
        name_en_off = builder.CreateString(a["name_en"])

        builder.StartObject(5)
        builder.PrependUOffsetTRelativeSlot(0, name_off, 0)
        builder.PrependUOffsetTRelativeSlot(1, name_en_off, 0)
        builder.PrependUint8Slot(2, a["quadrant"], 0)
        builder.PrependUint8Slot(3, a["mansion"], 0)
        builder.PrependUOffsetTRelativeSlot(4, edges_off, 0)
        asterism_offsets.append(builder.EndObject())

    builder.StartVector(4, len(asterism_offsets), 1)
    for off in reversed(asterism_offsets):
        builder.PrependUOffsetTRelative(off)
    vec_off = builder.EndVector(len(asterism_offsets))

    builder.StartObject(1)
    builder.PrependUOffsetTRelativeSlot(0, vec_off, 0)
    root_off = builder.EndObject()

    builder.Finish(root_off)
    return bytes(builder.Output())


# ── Verification ──────────────────────────────────────────────────────────────


def verify_bin(data: bytes, expected_count: int, sample_checks):
    """Quick sanity-check on the generated binary."""
    asterisms = read_existing_bin.__func__ if False else None  # reuse reader

    # Re-parse inline to avoid circular dependency.
    root = _u32(data, 0)
    offsets = _t_offv(data, root, 0)
    assert len(offsets) == expected_count, (
        f"Expected {expected_count} asterisms, got {len(offsets)}"
    )
    for name_zh, name_en, edge_pairs in sample_checks:
        found = False
        for toff in offsets:
            n = _t_str(data, toff, 0) or ""
            ne = _t_str(data, toff, 1) or ""
            if n == name_zh and ne == name_en:
                edges = _t_u16v(data, toff, 4)
                pairs = [(edges[i], edges[i+1]) for i in range(0, len(edges)-1, 2)]
                assert pairs == edge_pairs, (
                    f"{name_zh}: expected edges {edge_pairs}, got {pairs}"
                )
                found = True
                break
        assert found, f"Asterism '{name_zh}' ({name_en}) not found"


# ── Main ──────────────────────────────────────────────────────────────────────

REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Rebuild culture_chinese.bin: preserves edge data from the existing\n"
            "binary and replaces asterism names using the corrected index.json\n"
            "lookup (strips 'CON chinese ' prefix, reads common_name.native)."
        )
    )
    parser.add_argument(
        "--bin",
        default=os.path.join(REPO_ROOT, "assets", "bin", "culture_chinese.bin"),
        help="Existing culture_chinese.bin to read edges from",
    )
    parser.add_argument(
        "--index",
        default=os.path.join(
            REPO_ROOT, "tool", "sources", "stellarium", "chinese", "index.json"
        ),
        help="Path to Stellarium index.json",
    )
    parser.add_argument(
        "--output",
        default=os.path.join(REPO_ROOT, "assets", "bin", "culture_chinese.bin"),
        help="Output path (default: overwrite --bin)",
    )
    args = parser.parse_args()

    # Step 1: read existing binary
    if not os.path.isfile(args.bin):
        print(f"❌ culture_chinese.bin not found: {args.bin}")
        sys.exit(1)
    print(f"📖 Reading existing culture_chinese.bin …")
    asterisms = read_existing_bin(args.bin)
    print(f"   {len(asterisms)} asterisms read")

    # Step 2: load index.json names
    name_map = {}
    if not os.path.isfile(args.index):
        print(
            f"⚠️  index.json not found at {args.index}\n"
            "    Run: cd tool && ./download_sources.sh"
        )
    else:
        print(f"📖 Reading index.json …")
        name_map = parse_index_json(args.index)
        print(f"   {len(name_map)} constellation name entries")

    # Step 3: patch names
    numeric_count = sum(1 for a in asterisms if a["name"].strip("0123456789") == "")
    patched = 0
    for a in asterisms:
        short_id = a["name"] if a["name"].strip("0123456789") == "" else None
        if short_id and short_id in name_map:
            a["name"], a["name_en"] = name_map[short_id]
            patched += 1
    print(f"   Patched {patched} / {numeric_count} numeric-name asterisms with correct names")

    still_numeric = sum(1 for a in asterisms if a["name"].strip("0123456789") == "")
    if still_numeric:
        print(f"   ⚠️  {still_numeric} asterisms still have numeric names (no index.json match)")

    # Step 4: verify 四辅
    sifu = next((a for a in asterisms if a["name"] == "四辅"), None)
    if sifu:
        print(f"   ✅ 四辅 (Four Advisors) edges: {sifu['edge_pairs']}")
    else:
        print("   ⚠️  四辅 not found after patching")

    # Step 5: build new binary
    print(f"🔨 Building FlatBuffers binary …")
    data = build_chinese_bin(asterisms)
    print(f"   Binary size: {len(data):,} bytes")

    # Step 6: verify
    sample = []
    if sifu:
        sample.append(("四辅", "Four Advisors", sifu["edge_pairs"]))
    verify_bin(data, len(asterisms), sample)
    print(f"   ✅ Binary verification passed")

    # Step 7: write
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "wb") as f:
        f.write(data)
    print(f"✅ Written → {args.output}")
    print(f"   Total asterisms: {len(asterisms)}")


if __name__ == "__main__":
    main()

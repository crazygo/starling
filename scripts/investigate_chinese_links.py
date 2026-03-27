#!/usr/bin/env python3
"""
investigate_chinese_links.py – trace Chinese sky-culture star links.

Given one or more Hipparcos catalogue numbers (or an asterism name/keyword),
this script reads the three raw Stellarium Chinese sky-culture source files and
prints:

  • The raw constellationship.fab line(s) that contain any of the queried HIPs
  • The resolved asterism name from index.json
  • All edge pairs in that asterism
  • Star-name mappings from star_names.fab for all participating HIPs

Usage
-----
  # From the repo root (source files must have been downloaded first):
  python3 scripts/investigate_chinese_links.py 51384 51502 58874

  # Or by asterism name (English keyword):
  python3 scripts/investigate_chinese_links.py "Four Advisors"

  # Specify custom source directory:
  python3 scripts/investigate_chinese_links.py --srcdir tool/sources/stellarium/chinese 51384

Prerequisites
-------------
  Run  tool/download_sources.sh  first to populate
  tool/sources/stellarium/chinese/{constellationship.fab,star_names.fab,index.json}.
"""

import argparse
import json
import os
import re
import sys


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT  = os.path.dirname(_SCRIPT_DIR)
_DEFAULT_SRC = os.path.join(_REPO_ROOT, 'tool', 'sources', 'stellarium', 'chinese')


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_constellationship(path: str):
    """
    Parse constellationship.fab.

    Returns a list of dicts:
      { 'id': str, 'num_pairs': int, 'edges': [(from_hip, to_hip), ...],
        'raw_line': str, 'lineno': int }
    """
    records = []
    with open(path, encoding='utf-8') as fh:
        for lineno, raw in enumerate(fh, 1):
            line = raw.rstrip('\n')
            trimmed = line.strip()
            if not trimmed or trimmed.startswith('#'):
                continue
            parts = trimmed.split()
            if len(parts) < 2:
                continue
            record_id = parts[0]
            try:
                num_pairs = int(parts[1])
            except ValueError:
                continue
            edges = []
            for i in range(num_pairs):
                fi = 2 + i * 2
                ti = 3 + i * 2
                if ti >= len(parts):
                    break
                try:
                    edges.append((int(parts[fi]), int(parts[ti])))
                except ValueError:
                    pass
            records.append({
                'id':       record_id,
                'num_pairs': num_pairs,
                'edges':    edges,
                'raw_line': line,
                'lineno':   lineno,
            })
    return records


def parse_star_names(path: str) -> dict[int, list[str]]:
    """
    Parse the Stellarium Chinese star_names.fab.

    The file uses the Stellarium-native format:
        <hip>|_("<name>") <count>

    Multiple names for the same HIP produce multiple entries; all names are
    collected in a list (in file order).

    Returns a dict: hip_number → [name1, name2, …]
    """
    names: dict[int, list[str]] = {}
    pat = re.compile(r'^(\d+)\|_\("([^"]+)"\)')
    with open(path, encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            m = pat.match(line)
            if m:
                hip = int(m.group(1))
                name = m.group(2)
                names.setdefault(hip, []).append(name)
    return names


def parse_index_json(path: str):
    """
    Parse index.json for asterism name metadata.

    Modern Stellarium index.json uses IDs like "CON chinese 001".
    The bare numeric token ("001") is used as the lookup key so that it
    matches the first field in constellationship.fab.

    Returns:
      meta: dict of bare_id → {'zh': str, 'en': str, 'pronounce': str}
      star_common_names: dict of hip → {'native': str, 'english': str}
    """
    meta: dict[str, dict] = {}
    star_names: dict[int, dict] = {}
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)

    prefix = 'CON chinese '
    for item in data.get('constellations', []):
        raw_id = item.get('id', '')
        bare_id = raw_id[len(prefix):] if raw_id.startswith(prefix) else raw_id
        cn = item.get('common_name', {})
        meta[bare_id] = {
            'zh':       cn.get('native', bare_id),
            'en':       cn.get('english', cn.get('transliteration', bare_id)),
            'pronounce': cn.get('pronounce', ''),
            'raw_id':   raw_id,
        }

    for key, entries in data.get('common_names', {}).items():
        if not key.startswith('HIP '):
            continue
        try:
            hip = int(key[4:])
        except ValueError:
            continue
        if entries:
            first = entries[0]
            star_names[hip] = {
                'native':  first.get('native', ''),
                'english': first.get('english', ''),
            }

    return meta, star_names


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

def find_asterisms_by_hips(records, hips: set[int]):
    """Return records whose edge set overlaps with *hips*."""
    matches = []
    for rec in records:
        rec_hips = {h for edge in rec['edges'] for h in edge}
        if rec_hips & hips:
            matches.append(rec)
    return matches


def find_asterisms_by_name(records, meta, keyword: str):
    """Return records whose resolved name contains *keyword* (case-insensitive)."""
    kw = keyword.lower()
    matches = []
    for rec in records:
        m = meta.get(rec['id'], {})
        if kw in m.get('zh', '').lower() or kw in m.get('en', '').lower():
            matches.append(rec)
    return matches


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def report(records, meta, star_names_fab, star_names_idx, queried_hips):
    if not records:
        print('No matching asterisms found.')
        return

    for rec in records:
        m = meta.get(rec['id'], {})
        zh       = m.get('zh', rec['id'])
        en       = m.get('en', rec['id'])
        pronounce = m.get('pronounce', '')
        raw_id   = m.get('raw_id', f'(no index.json entry for "{rec["id"]}")')

        print('=' * 72)
        print(f'Asterism ID (FAB)  : {rec["id"]}')
        print(f'Asterism ID (JSON) : {raw_id}')
        print(f'Chinese name       : {zh}')
        print(f'English name       : {en}')
        if pronounce:
            print(f'Pronunciation      : {pronounce}')
        print()

        print(f'Raw constellationship.fab line (line {rec["lineno"]}):')
        print(f'  {rec["raw_line"]}')
        print()

        print(f'Edge pairs ({rec["num_pairs"]} pair(s)):')
        all_hips = set()
        for from_hip, to_hip in rec['edges']:
            marker = ' ◀── queried' if {from_hip, to_hip} & queried_hips else ''
            print(f'  HIP {from_hip:6d}  →  HIP {to_hip:6d}{marker}')
            all_hips.add(from_hip)
            all_hips.add(to_hip)
        print()

        print('Star-name mappings:')
        for hip in sorted(all_hips):
            marker = ' ◀── queried' if hip in queried_hips else ''
            fab_names  = star_names_fab.get(hip, [])
            idx_entry  = star_names_idx.get(hip, {})
            idx_native  = idx_entry.get('native', '')
            idx_english = idx_entry.get('english', '')

            print(f'  HIP {hip:6d}{marker}')
            if fab_names:
                for n in fab_names:
                    print(f'           star_names.fab : {n}')
            else:
                print(f'           star_names.fab : (no entry)')
            if idx_native or idx_english:
                print(f'           index.json     : native="{idx_native}"'
                      f'  english="{idx_english}"')
            else:
                print(f'           index.json     : (no common_names entry)')
        print()


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        'query', nargs='+',
        help='HIP number(s) or asterism name keyword',
    )
    parser.add_argument(
        '--srcdir', default=_DEFAULT_SRC,
        help='Path to the Stellarium Chinese skyculture source directory '
             f'(default: {_DEFAULT_SRC})',
    )
    args = parser.parse_args()

    srcdir = args.srcdir
    fab_path  = os.path.join(srcdir, 'constellationship.fab')
    names_path = os.path.join(srcdir, 'star_names.fab')
    index_path = os.path.join(srcdir, 'index.json')

    for p in (fab_path, names_path, index_path):
        if not os.path.exists(p):
            print(f'❌  Missing source file: {p}', file=sys.stderr)
            print('   Run tool/download_sources.sh first.', file=sys.stderr)
            sys.exit(1)

    # Parse sources.
    records        = parse_constellationship(fab_path)
    star_names_fab = parse_star_names(names_path)
    meta, star_names_idx = parse_index_json(index_path)

    # Determine if query is HIP numbers or a name keyword.
    queried_hips: set[int] = set()
    matched_records = []

    # Try to parse all tokens as HIP numbers.
    all_numeric = all(q.lstrip('-').isdigit() for q in args.query)
    if all_numeric:
        for q in args.query:
            try:
                queried_hips.add(int(q))
            except ValueError:
                pass
        matched_records = find_asterisms_by_hips(records, queried_hips)
    else:
        keyword = ' '.join(args.query)
        matched_records = find_asterisms_by_name(records, meta, keyword)

    report(matched_records, meta, star_names_fab, star_names_idx, queried_hips)


if __name__ == '__main__':
    main()

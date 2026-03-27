/// Chinese sky-culture link investigator.
///
/// Reads the three raw Stellarium Chinese sky-culture source files and prints
/// the full provenance for any asterism that contains the queried HIP numbers
/// or whose name matches a keyword.
///
/// Usage (from the tool/ directory):
///   dart run bin/investigate_chinese_links.dart 51384 51502 58874
///   dart run bin/investigate_chinese_links.dart --name "Four Advisors"
///   dart run bin/investigate_chinese_links.dart --name 四辅
///   dart run bin/investigate_chinese_links.dart --srcdir path/to/chinese 47193
///
/// Source files required (run ./download_sources.sh first):
///   sources/stellarium/chinese/constellationship.fab
///   sources/stellarium/chinese/star_names.fab
///   sources/stellarium/chinese/index.json

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main(List<String> rawArgs) {
  final argParser = ArgParser()
    ..addOption('srcdir',
        abbr: 's',
        help: 'Path to Stellarium Chinese skyculture source directory',
        defaultsTo: 'sources/stellarium/chinese')
    ..addOption('name',
        abbr: 'n',
        help: 'Search by asterism name keyword (Chinese or English)')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final ArgResults args;
  try {
    args = argParser.parse(rawArgs);
  } catch (e) {
    stderr.writeln('Error: $e');
    _printUsage(argParser);
    exit(1);
  }

  if (args['help'] as bool) {
    _printUsage(argParser);
    exit(0);
  }

  final srcDir = Directory(args['srcdir'] as String);
  final fabFile   = File('${srcDir.path}/constellationship.fab');
  final namesFile = File('${srcDir.path}/star_names.fab');
  final indexFile = File('${srcDir.path}/index.json');

  for (final f in [fabFile, namesFile, indexFile]) {
    if (!f.existsSync()) {
      stderr.writeln('❌  Missing source file: ${f.path}');
      stderr.writeln('   Run ./download_sources.sh first.');
      exit(1);
    }
  }

  // Parse raw sources.
  final fabRecords = _parseFab(fabFile);
  final starNames  = _parseStarNames(namesFile);
  final (astMeta, starNamesIdx) = _parseIndexJson(indexFile);

  // Resolve query.
  final keyword = args['name'] as String?;
  final hipArgs = args.rest;

  List<_FabRecord> matches;
  final Set<int> queriedHips = {};

  if (keyword != null && keyword.isNotEmpty) {
    final kw = keyword.toLowerCase();
    matches = fabRecords.where((r) {
      final m = astMeta[r.id];
      return (m?.zh ?? '').toLowerCase().contains(kw) ||
             (m?.en ?? '').toLowerCase().contains(kw);
    }).toList();
  } else if (hipArgs.isNotEmpty) {
    for (final h in hipArgs) {
      final hip = int.tryParse(h);
      if (hip != null) queriedHips.add(hip);
    }
    if (queriedHips.isEmpty) {
      stderr.writeln('No valid HIP numbers provided.');
      exit(1);
    }
    matches = fabRecords.where((r) {
      final hips = {for (final e in r.edges) e.from, for (final e in r.edges) e.to};
      return hips.intersection(queriedHips).isNotEmpty;
    }).toList();
  } else {
    stderr.writeln('Provide HIP number(s) or use --name <keyword>.');
    _printUsage(argParser);
    exit(1);
  }

  if (matches.isEmpty) {
    print('No matching asterisms found.');
    return;
  }

  for (final rec in matches) {
    _report(rec, astMeta, starNames, starNamesIdx, queriedHips);
  }
}

void _printUsage(ArgParser argParser) {
  print('''
Usage: dart run bin/investigate_chinese_links.dart [options] [HIP ...]

${argParser.usage}

Examples:
  dart run bin/investigate_chinese_links.dart 51384 51502 58874
  dart run bin/investigate_chinese_links.dart --name "Four Advisors"
  dart run bin/investigate_chinese_links.dart --name 四辅
  dart run bin/investigate_chinese_links.dart 47193
''');
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

void _report(
  _FabRecord rec,
  Map<String, _AstMeta> astMeta,
  Map<int, List<String>> starNames,
  Map<int, _StarNameEntry> starNamesIdx,
  Set<int> queriedHips,
) {
  final m = astMeta[rec.id];
  final zh = m?.zh ?? rec.id;
  final en = m?.en ?? rec.id;
  final pronounce = m?.pronounce ?? '';
  // index.json uses "CON chinese NNN" as the ID for all 318 asterisms.
  // The "CON chinese " prefix is Stellarium's standard naming convention
  // for every entry in the Chinese sky-culture file — it is not a fallback.
  final rawId = m?.rawId ?? '(no index.json entry for "${rec.id}")';

  final sep = '=' * 72;
  print(sep);
  print('Asterism ID (FAB)  : ${rec.id}');
  print('Asterism ID (JSON) : $rawId');
  print('Chinese name       : $zh');
  print('English name       : $en');
  if (pronounce.isNotEmpty) print('Pronunciation      : $pronounce');
  print('');
  print('Raw constellationship.fab line (line ${rec.lineno}):');
  print('  ${rec.rawLine}');
  print('');
  print('Edge pairs (${rec.edges.length} pair(s)):');
  final allHips = <int>{};
  for (final e in rec.edges) {
    final queried = queriedHips.contains(e.from) || queriedHips.contains(e.to);
    final marker  = queried ? ' ◀── queried' : '';
    print('  HIP ${e.from.toString().padLeft(6)}  →  HIP ${e.to.toString().padLeft(6)}$marker');
    allHips.add(e.from);
    allHips.add(e.to);
  }
  print('');
  print('Star-name mappings:');
  for (final hip in allHips.toList()..sort()) {
    final marker    = queriedHips.contains(hip) ? ' ◀── queried' : '';
    final fabNames  = starNames[hip] ?? [];
    final idxEntry  = starNamesIdx[hip];
    print('  HIP ${hip.toString().padLeft(6)}$marker');
    if (fabNames.isNotEmpty) {
      for (final n in fabNames) print('           star_names.fab : $n');
    } else {
      print('           star_names.fab : (no entry)');
    }
    if (idxEntry != null) {
      print('           index.json     : native="${idxEntry.native}"'
            '  english="${idxEntry.english}"');
    } else {
      print('           index.json     : (no common_names entry)');
    }
  }
  print('');
}

// ---------------------------------------------------------------------------
// Parsers
// ---------------------------------------------------------------------------

class _Edge {
  final int from;
  final int to;
  const _Edge(this.from, this.to);
}

class _FabRecord {
  final String id;
  final List<_Edge> edges;
  final String rawLine;
  final int lineno;
  const _FabRecord({
    required this.id,
    required this.edges,
    required this.rawLine,
    required this.lineno,
  });
}

class _AstMeta {
  final String zh;
  final String en;
  final String pronounce;
  final String rawId;
  const _AstMeta({
    required this.zh,
    required this.en,
    required this.pronounce,
    required this.rawId,
  });
}

class _StarNameEntry {
  final String native;
  final String english;
  const _StarNameEntry({required this.native, required this.english});
}

List<_FabRecord> _parseFab(File file) {
  final records = <_FabRecord>[];
  var lineno = 0;
  for (final raw in file.readAsLinesSync()) {
    lineno++;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final id = parts[0];
    final numPairs = int.tryParse(parts[1]);
    if (numPairs == null) continue;
    final edges = <_Edge>[];
    for (var i = 0; i < numPairs; i++) {
      final fi = 2 + i * 2;
      final ti = 3 + i * 2;
      if (ti >= parts.length) break;
      final from = int.tryParse(parts[fi]);
      final to   = int.tryParse(parts[ti]);
      if (from != null && to != null) edges.add(_Edge(from, to));
    }
    records.add(_FabRecord(id: id, edges: edges, rawLine: raw, lineno: lineno));
  }
  return records;
}

/// Parses Stellarium Chinese `star_names.fab`.
///
/// The format is:  `<hip>|_("<name>") <count>`
/// Multiple entries for the same HIP are collected in order.
Map<int, List<String>> _parseStarNames(File file) {
  final result = <int, List<String>>{};
  final pattern = RegExp(r'^(\d+)\|_\("([^"]+)"\)');
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final m = pattern.firstMatch(trimmed);
    if (m == null) continue;
    final hip  = int.parse(m.group(1)!);
    final name = m.group(2)!;
    result.putIfAbsent(hip, () => []).add(name);
  }
  return result;
}

/// Parses `index.json` for asterism name metadata and per-star common names.
///
/// Stellarium's Chinese sky-culture index.json assigns the ID format
///   `"CON chinese NNN"`
/// to every one of the 318 asterism entries (CON = constellation, followed by
/// the sky-culture name and a sequential number).  This prefix is the
/// standard Stellarium naming convention — it is present for ALL entries,
/// not just for special or missing records.
///
/// We strip the prefix so that the resulting keys match the bare token used
/// as the first field in `constellationship.fab`.
(Map<String, _AstMeta>, Map<int, _StarNameEntry>) _parseIndexJson(File file) {
  final astMeta  = <String, _AstMeta>{};
  final starIdx  = <int, _StarNameEntry>{};

  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  const prefix = 'CON chinese ';
  for (final item in (json['constellations'] as List<dynamic>? ?? [])) {
    if (item is! Map<String, dynamic>) continue;
    var id = item['id']?.toString() ?? '';
    final rawId = id;
    if (id.startsWith(prefix)) id = id.substring(prefix.length);
    if (id.isEmpty) continue;
    final cn = item['common_name'] as Map<String, dynamic>? ?? {};
    astMeta[id] = _AstMeta(
      zh:        cn['native']?.toString()         ?? item['name']?.toString() ?? id,
      en:        cn['english']?.toString()        ??
                 cn['transliteration']?.toString() ??
                 item['name']?.toString()          ?? id,
      pronounce: cn['pronounce']?.toString() ?? '',
      rawId:     rawId,
    );
  }

  for (final entry in (json['common_names'] as Map<String, dynamic>? ?? {}).entries) {
    final key = entry.key.trim();
    if (!key.startsWith('HIP ')) continue;
    final hip = int.tryParse(key.substring(4));
    if (hip == null) continue;
    final entries = entry.value;
    if (entries is! List || entries.isEmpty) continue;
    final first = entries[0];
    if (first is! Map<String, dynamic>) continue;
    starIdx[hip] = _StarNameEntry(
      native:  first['native']?.toString()  ?? '',
      english: first['english']?.toString() ?? '',
    );
  }

  return (astMeta, starIdx);
}

import 'dart:convert';
import 'dart:io';
import 'models.dart';
import '../../generated/stargazer_generated.dart' show Quadrant, Mansion;

/// Parses the Stellarium Chinese sky-culture directory.
///
/// The Chinese sky culture is located in Stellarium's repository at:
///   skycultures/chinese/
///
/// Key files consumed:
///   constellationship.fab – star-pattern edges in Stellarium FAB format
///   star_names.fab        – Chinese/English name mapping
///   index.json            – cultural metadata
///
/// FAB format (plain text, one record per line):
///   <abbr>  <num_pairs>  <hip1> <hip2> … (constellationship.fab)
///   <hip>   <name_zh>    <name_en>        (star_names.fab)
///
/// A `#` at the start of a line denotes a comment.
class StellariumChineseParser {
  StellariumChineseParser._();

  /// Parse `common_names` from `index.json` in the Stellarium Chinese
  /// sky-culture [directory] and return a map of HIP → Chinese proper name.
  ///
  /// Stars with multiple names take the first (primary) entry.
  static Map<int, String> parseStarNames(Directory directory) {
    final indexFile = File('${directory.path}/index.json');
    if (!indexFile.existsSync()) return const {};

    try {
      final json =
          jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
      final commonNames =
          json['common_names'] as Map<String, dynamic>? ?? const {};

      final result = <int, String>{};
      for (final entry in commonNames.entries) {
        // Key format: "HIP 12345"
        final key = entry.key;
        if (!key.startsWith('HIP ')) continue;
        final hip = int.tryParse(key.substring(4));
        if (hip == null) continue;

        final names = entry.value as List<dynamic>? ?? const [];
        if (names.isEmpty) continue;

        final first = names[0] as Map<String, dynamic>;
        final native = first['native']?.toString();
        if (native != null && native.isNotEmpty) {
          result.putIfAbsent(hip, () => native);
        }
      }
      return result;
    } catch (e) {
      // index.json is optional — return empty map on parse errors.
      stderr.writeln('⚠️  Could not parse Chinese star names: $e');
      return const {};
    }
  }

  /// Parse the Stellarium Chinese sky-culture [directory] and return a list
  /// of [AsterismRecord]s.
  static List<AsterismRecord> parse(Directory directory) {
    final constellationshipFile =
        File('${directory.path}/constellationship.fab');
    final starNamesFile = File('${directory.path}/star_names.fab');
    final indexFile     = File('${directory.path}/index.json');

    // Step 1: Parse name metadata from index.json (optional, may be absent).
    final nameMeta = <String, Map<String, String>>{};
    if (indexFile.existsSync()) {
      _parseIndexJson(indexFile, nameMeta);
    }

    // Step 2: Parse star name overrides (hip → zh/en names).
    final starNameMap = <int, (String, String)>{}; // hip → (nameZh, nameEn)
    if (starNamesFile.existsSync()) {
      _parseStarNames(starNamesFile, starNameMap);
    }

    // Step 3: Parse constellationship.fab for edges.
    if (!constellationshipFile.existsSync()) {
      throw FileSystemException(
        'constellationship.fab not found',
        constellationshipFile.path,
      );
    }

    return _parseConstellationship(
      constellationshipFile,
      nameMeta,
      starNameMap,
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  static void _parseIndexJson(
    File file,
    Map<String, Map<String, String>> nameMeta,
  ) {
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final constellations =
          json['constellations'] as List<dynamic>? ?? const [];
      for (final item in constellations) {
        if (item is! Map<String, dynamic>) continue;
        final id    = item['id']?.toString() ?? '';
        final nameZh = item['name']?.toString() ?? id;
        final nameEn = item['common_name']?['english']?.toString() ??
            item['common_name']?['transliteration']?.toString() ??
            id;
        if (id.isNotEmpty) nameMeta[id] = {'zh': nameZh, 'en': nameEn};
      }
    } catch (_) {
      // index.json is optional – ignore parse errors.
    }
  }

  static void _parseStarNames(
    File file,
    Map<int, (String, String)> starNameMap,
  ) {
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 3) continue;
      final hip    = int.tryParse(parts[0]);
      if (hip == null) continue;
      final nameZh = parts[1];
      final nameEn = parts.sublist(2).join(' ');
      starNameMap[hip] = (nameZh, nameEn);
    }
  }

  static List<AsterismRecord> _parseConstellationship(
    File file,
    Map<String, Map<String, String>> nameMeta,
    Map<int, (String, String)> starNameMap,
  ) {
    final results = <AsterismRecord>[];

    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final id       = parts[0];
      final numPairs = int.tryParse(parts[1]);
      if (numPairs == null) continue;

      final edges = <EdgeRecord>[];
      for (var i = 0; i < numPairs; i++) {
        final fromIdx = 2 + i * 2;
        final toIdx   = 3 + i * 2;
        if (toIdx >= parts.length) break;
        final fromHip = int.tryParse(parts[fromIdx]);
        final toHip   = int.tryParse(parts[toIdx]);
        if (fromHip == null || toHip == null) continue;
        edges.add(EdgeRecord(fromHip: fromHip, toHip: toHip));
      }

      // Resolve names: index.json > id string itself.
      final meta  = nameMeta[id];
      final nameZh = meta?['zh'] ?? id;
      final nameEn = meta?['en'] ?? id;

      // Map the asterism id to quadrant & mansion enumerations.
      final (quadrant, mansion) = _classifyAsterism(id);

      results.add(AsterismRecord(
        name:     nameZh,
        nameEn:   nameEn,
        quadrant: quadrant,
        mansion:  mansion,
        edges:    edges,
      ));
    }

    return results;
  }

  /// Map a Stellarium Chinese asterism ID to [Quadrant] + [Mansion] values.
  ///
  /// The Three Enclosures (三垣) get [Quadrant.central] and [Mansion.none].
  /// The 28 mansions are distributed across the four cardinal palaces.
  static (int, int) _classifyAsterism(String id) {
    final upper = id.toUpperCase();

    // Three Enclosures — 三垣
    if (_threeEnclosures.any((p) => upper.startsWith(p))) {
      return (Quadrant.central, Mansion.none);
    }

    // Check each mansion prefix map.
    for (final entry in _mansionPrefixes.entries) {
      if (upper.startsWith(entry.key)) {
        return entry.value;
      }
    }

    // Default: Central / None for unrecognised asterisms.
    return (Quadrant.central, Mansion.none);
  }

  static const _threeEnclosures = ['ZY', 'TW', 'TS'];

  /// Maps Stellarium ID prefix → (Quadrant, Mansion).
  static const Map<String, (int, int)> _mansionPrefixes = {
    // East Azure (东方青龙)
    'JI': (Quadrant.eastAzure, Mansion.horn),
    'KE': (Quadrant.eastAzure, Mansion.neck),
    'DI': (Quadrant.eastAzure, Mansion.root),
    'FN': (Quadrant.eastAzure, Mansion.room),
    'XN': (Quadrant.eastAzure, Mansion.heart),
    'WE': (Quadrant.eastAzure, Mansion.tail),
    'JX': (Quadrant.eastAzure, Mansion.winnowing),
    // North Black (北方玄武)
    'DO': (Quadrant.northBlack, Mansion.dipper),
    'NI': (Quadrant.northBlack, Mansion.ox),
    'NU': (Quadrant.northBlack, Mansion.girl),
    'XU': (Quadrant.northBlack, Mansion.emptiness),
    'WA': (Quadrant.northBlack, Mansion.rooftop),
    'SH': (Quadrant.northBlack, Mansion.encampment),
    'BI': (Quadrant.northBlack, Mansion.wall),
    // West White (西方白虎)
    'KU': (Quadrant.westWhite, Mansion.stride),
    'LO': (Quadrant.westWhite, Mansion.bond),
    'WE2': (Quadrant.westWhite, Mansion.stomach),
    'MA': (Quadrant.westWhite, Mansion.hairy),
    'BX': (Quadrant.westWhite, Mansion.net),
    'ZU': (Quadrant.westWhite, Mansion.turtle),
    'SN': (Quadrant.westWhite, Mansion.three),
    // South Scarlet (南方朱雀)
    'JN': (Quadrant.southScarlet, Mansion.well),
    'GU': (Quadrant.southScarlet, Mansion.ghost),
    'LI': (Quadrant.southScarlet, Mansion.willow),
    'QX': (Quadrant.southScarlet, Mansion.star),
    'ZH': (Quadrant.southScarlet, Mansion.extended),
    'YI': (Quadrant.southScarlet, Mansion.wings),
    'ZN': (Quadrant.southScarlet, Mansion.chariot),
  };
}

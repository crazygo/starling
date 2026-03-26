/// Data pipeline entry point.
///
/// Run with:
///   cd tool/
///   dart run bin/pipeline.dart
///
/// Optional flags:
///   --output  <path>   Output directory (default: ../assets/bin)
///   --mag     <float>  Maximum visual magnitude to include (default: 6.5)
///   --skip-validate    Skip integrity validation (not recommended)

import 'dart:io';
import 'package:args/args.dart';
import '../lib/parsers/hipparcos_parser.dart';
import '../lib/parsers/iau_lines_parser.dart';
import '../lib/parsers/iau_boundary_parser.dart';
import '../lib/parsers/western_star_names_parser.dart';
import '../lib/parsers/stellarium_chinese_parser.dart';
import '../lib/builders/catalog_builder.dart';
import '../lib/builders/western_builder.dart';
import '../lib/builders/chinese_builder.dart';
import '../lib/validators/integrity_checker.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('output',
        abbr: 'o',
        defaultsTo: '../assets/bin',
        help: 'Output directory for .bin files')
    ..addOption('mag',
        defaultsTo: '6.5',
        help: 'Maximum visual magnitude (brightest = lowest value)')
    ..addFlag('skip-validate',
        defaultsTo: false,
        negatable: false,
        help: 'Skip integrity validation checks')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  late ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stderr.writeln('Error: $e\n${parser.usage}');
    exit(1);
  }

  if (results['help'] as bool) {
    print(parser.usage);
    exit(0);
  }

  final outputPath    = results['output'] as String;
  final maxMagnitude  = double.tryParse(results['mag'] as String) ?? 6.5;
  final skipValidate  = results['skip-validate'] as bool;

  final outputDir = Directory(outputPath);
  if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

  // ── Phase 1: Parse raw data sources ────────────────────────────────────
  print('📥 Phase 1: Parsing sources…');

  final hipparcosFile  = File('sources/hipparcos/hip_main.csv');
  final linesFile      = File('sources/iau/constellation_lines.csv');
  final boundaryFile   = File('sources/iau/constellation_boundaries.csv');
  final starNamesFile  = File('sources/iau/star_names.fab');
  final chineseDir     = Directory('sources/stellarium/chinese');

  _requireFile(hipparcosFile);
  _requireFile(linesFile);
  _requireFile(boundaryFile);
  _requireDir(chineseDir);

  var stars = HipparcosParser.parse(hipparcosFile, maxMagnitude: maxMagnitude);
  print('   ✅ Stars: ${stars.length} (mag ≤ $maxMagnitude)');

  // Merge western proper names if the file is present (optional).
  if (starNamesFile.existsSync()) {
    final nameMap = WesternStarNamesParser.parse(starNamesFile);
    stars = stars.map((s) {
      final name = nameMap[s.hip];
      return name != null ? s.copyWith(nameEn: name) : s;
    }).toList(growable: false);
    final named = stars.where((s) => s.nameEn != null).length;
    if (named > 0) {
      print('   ✅ Star proper names: $named named out of ${stars.length}');
    } else {
      print('   ⚠️  Star proper names: none loaded'
            ' (star_names.fab was empty or unparseable)'
            ' — stars will use HIP-number identifiers');
    }
  }

  final westernLines    = IauLinesParser.parse(linesFile);
  final westernBounds   = IauBoundaryParser.parse(boundaryFile);
  print('   ✅ Western constellations: ${westernLines.length}');

  final chineseAsterisms = StellariumChineseParser.parse(chineseDir);
  print('   ✅ Chinese asterisms: ${chineseAsterisms.length}');

  // Merge Chinese proper star names from index.json (optional).
  final chineseIndexFile = File('${chineseDir.path}/index.json');
  final chineseNameMap =
      StellariumChineseParser.parseStarNames(chineseIndexFile);
  if (chineseNameMap.isNotEmpty) {
    stars = stars.map((s) {
      final names = chineseNameMap[s.hip];
      return names != null ? s.copyWith(nameZh: names.$1) : s;
    }).toList(growable: false);
    final namedZh = stars.where((s) => s.nameZh != null).length;
    print('   ✅ Chinese star names: $namedZh named out of ${stars.length}');
  } else {
    print('   ⚠️  Chinese star names: none loaded'
          ' (index.json was empty or absent)'
          ' — Chinese mode will fall back to English names');
  }

  // ── Phase 2: Validate integrity ─────────────────────────────────────────
  final hipSet = stars.map((s) => s.hip).toSet();

  if (skipValidate) {
    print('⚠️  Phase 2: Validation skipped (--skip-validate)');
  } else {
    print('🔍 Phase 2: Validating integrity…');

    IntegrityChecker.checkMagnitudeRange(stars);

    IntegrityChecker.checkEdges(
      label:     'Western',
      edges:     westernLines.values.expand((c) => c.edges),
      validHips: hipSet,
    );
    IntegrityChecker.checkEdges(
      label:     'Chinese',
      edges:     chineseAsterisms.expand((a) => a.edges),
      validHips: hipSet,
    );

    IntegrityChecker.checkWesternCount(westernLines.length);
    IntegrityChecker.checkChineseCount(chineseAsterisms.length);

    print('   ✅ Integrity checks passed');
  }

  // Filter out constellation edges that reference HIPs absent from the
  // catalog (e.g. dim stars just above the magnitude cutoff) so that the
  // binary only contains resolvable references.
  final filteredLines = Map.fromEntries(westernLines.entries.map((entry) {
    final filtered = entry.value.copyWith(
      edges: entry.value.edges
          .where((e) => hipSet.contains(e.fromHip) && hipSet.contains(e.toHip))
          .toList(growable: false),
    );
    return MapEntry(entry.key, filtered);
  }));

  // ── Phase 3: Build .bin files ────────────────────────────────────────────
  print('📦 Phase 3: Building .bin files…');

  final catalogBytes = CatalogBuilder.build(stars);
  final catalogFile  = File('${outputDir.path}/catalog_base.bin');
  catalogFile.writeAsBytesSync(catalogBytes);
  print('   ✅ catalog_base.bin     (${_kb(catalogBytes)} KB)');

  final westernBytes = WesternBuilder.build(filteredLines, westernBounds);
  final westernFile  = File('${outputDir.path}/culture_western.bin');
  westernFile.writeAsBytesSync(westernBytes);
  print('   ✅ culture_western.bin  (${_kb(westernBytes)} KB)');

  final chineseBytes = ChineseBuilder.build(chineseAsterisms);
  final chineseFile  = File('${outputDir.path}/culture_chinese.bin');
  chineseFile.writeAsBytesSync(chineseBytes);
  print('   ✅ culture_chinese.bin  (${_kb(chineseBytes)} KB)');

  final totalBytes = catalogBytes.length + westernBytes.length + chineseBytes.length;
  print('\n🎉 Done!  Total: ${_kb(List.filled(totalBytes, 0))} KB'
      ' → ${outputDir.path}/');
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String _kb(List<int> bytes) => (bytes.length / 1024).toStringAsFixed(1);

void _requireFile(File f) {
  if (!f.existsSync()) {
    stderr.writeln(
      '❌ Required source file not found: ${f.path}\n'
      '   See tool/README.md for data-source download instructions.',
    );
    exit(2);
  }
}

void _requireDir(Directory d) {
  if (!d.existsSync()) {
    stderr.writeln(
      '❌ Required source directory not found: ${d.path}\n'
      '   See tool/README.md for data-source download instructions.',
    );
    exit(2);
  }
}

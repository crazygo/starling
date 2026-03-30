import 'dart:convert';
import 'package:flutter/services.dart';
import '../data/stargazer_reader.dart';
import '../models/star.dart';
import '../models/constellation.dart';
import '../models/daily_card.dart';

/// Loads and caches star, constellation, and daily-card data.
///
/// Stars and constellation data are read from the pre-compiled FlatBuffers
/// binary assets in `assets/bin/`. Daily cards are still loaded from JSON.
class StarDataService {
  static StarDataService? _instance;
  // Shared Future so concurrent callers all await the same initialization work.
  static Future<StarDataService>? _initFuture;

  StarDataService._();

  /// Returns the shared singleton, creating and initialising it if needed.
  ///
  /// Concurrent callers all await the same initialization [Future], so the
  /// asset loading runs only once even when multiple pages call this at
  /// startup simultaneously.
  static Future<StarDataService> instance() {
    // Fast path: already fully initialized.
    if (_instance != null) return Future.value(_instance);
    // Lazily create (or reuse) the shared initialization future.
    _initFuture ??= _createAndLoad();
    return _initFuture!;
  }

  /// Constructs the service, loads all data, and stores the singleton.
  static Future<StarDataService> _createAndLoad() async {
    final service = StarDataService._();
    await service._load();
    _instance = service;
    return service;
  }

  List<Star> _stars = [];
  List<Constellation> _westernConstellations = [];
  List<Constellation> _chineseConstellations = [];
  List<Constellation> _chineseModernConstellations = [];
  List<DailyCard> _dailyCards = [];

  /// All stars, sorted by ascending magnitude (brightest first).
  List<Star> get stars => _stars;

  /// Western (IAU) constellations.
  List<Constellation> get constellations => _westernConstellations;

  /// Chinese asterisms (星官).
  List<Constellation> get chineseConstellations => _chineseConstellations;

  /// Modern 88-constellation lines with Chinese naming.
  List<Constellation> get chineseModernConstellations =>
      _chineseModernConstellations;

  /// All daily cards, sorted by descending date (newest first).
  List<DailyCard> get dailyCards => _dailyCards;

  /// Look up a single [Star] by its [id], or return `null` if not found.
  Star? starById(String id) {
    try {
      return _stars.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Return all stars whose name or Chinese name contains [query]
  /// (case-insensitive).
  List<Star> searchStars(String query) {
    if (query.isEmpty) return _stars;
    final q = query.toLowerCase();
    return _stars.where((s) {
      return s.name.toLowerCase().contains(q) ||
          (s.chineseName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    // Load all binary catalogs in parallel.
    final results = await Future.wait([
      rootBundle.load('assets/bin/catalog_base.bin'),
      rootBundle.load('assets/bin/culture_western.bin'),
      rootBundle.load('assets/bin/culture_chinese_modern.bin'),
      rootBundle.load('assets/bin/culture_chinese.bin'),
      rootBundle.loadString('assets/data/daily_cards.json'),
    ]);

    final catalogBuf = results[0] as ByteData;
    final westernBuf = results[1] as ByteData;
    final chineseModernBuf = results[2] as ByteData;
    final chineseBuf = results[3] as ByteData;
    final cardsJson = results[4] as String;

    // Parse star catalog.
    final catalogReader = StarCatalogReader(catalogBuf);
    _stars = catalogReader.readAll().map((b) {
      return Star.fromBin(
        hip: b.hip,
        ra: b.ra,
        dec: b.dec,
        mag: b.mag,
        colorIdx: b.colorIdx,
        nameEn: b.nameEn,
        nameZh: b.nameZh,
      );
    }).toList()..sort((a, b) => a.magnitude.compareTo(b.magnitude));

    // Parse western constellations.
    final westernReader = WesternCultureReader(westernBuf);
    _westernConstellations = westernReader.readAll().map((c) {
      return Constellation.fromWesternBin(
        abbr: c.abbr,
        nameEn: c.nameEn,
        nameZh: c.nameZh,
        edgePairs: c.edges,
      );
    }).toList();

    // Parse modern Chinese 88-constellation set.
    final chineseModernReader = WesternCultureReader(chineseModernBuf);
    _chineseModernConstellations = chineseModernReader.readAll().map((c) {
      return Constellation.fromWesternBin(
        abbr: c.abbr,
        nameEn: c.nameEn,
        nameZh: c.nameZh,
        edgePairs: c.edges,
      );
    }).toList();

    // Parse Chinese asterisms.
    final chineseReader = ChineseCultureReader(chineseBuf);
    _chineseConstellations = chineseReader.readAll().map((a) {
      return Constellation.fromChineseBin(
        name: a.name,
        nameEn: a.nameEn.isNotEmpty ? a.nameEn : null,
        edgePairs: a.edges,
      );
    }).toList();

    // Parse daily cards (still JSON).
    _dailyCards =
        (jsonDecode(cardsJson) as List)
            .map((j) => DailyCard.fromJson(j as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
  }
}

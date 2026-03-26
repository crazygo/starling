import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/star.dart';
import '../models/constellation.dart';
import '../models/daily_card.dart';

/// Loads and caches star, constellation, and daily-card data from bundled JSON
/// assets.
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
  List<Constellation> _constellations = [];
  List<Constellation> _chineseConstellations = [];
  List<DailyCard> _dailyCards = [];

  /// All stars, sorted by ascending magnitude (brightest first).
  List<Star> get stars => _stars;

  /// All Western (IAU) constellations.
  List<Constellation> get constellations => _constellations;

  /// All Chinese asterisms / sky culture constellations.
  List<Constellation> get chineseConstellations => _chineseConstellations;

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
    final starsJson =
        await rootBundle.loadString('assets/data/stars.json');
    final constellationsJson =
        await rootBundle.loadString('assets/data/constellations.json');
    final chineseConstellationsJson =
        await rootBundle.loadString('assets/data/constellations_chinese.json');
    final cardsJson =
        await rootBundle.loadString('assets/data/daily_cards.json');

    _stars = (jsonDecode(starsJson) as List)
        .map((j) => Star.fromJson(j as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.magnitude.compareTo(b.magnitude));

    _constellations = (jsonDecode(constellationsJson) as List)
        .map((j) => Constellation.fromJson(j as Map<String, dynamic>))
        .toList();

    _chineseConstellations = (jsonDecode(chineseConstellationsJson) as List)
        .map((j) => Constellation.fromJson(j as Map<String, dynamic>))
        .toList();

    _dailyCards = (jsonDecode(cardsJson) as List)
        .map((j) => DailyCard.fromJson(j as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

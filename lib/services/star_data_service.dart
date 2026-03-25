import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/star.dart';
import '../models/constellation.dart';
import '../models/daily_card.dart';

/// Loads and caches star, constellation, and daily-card data from bundled JSON
/// assets.
class StarDataService {
  static StarDataService? _instance;
  StarDataService._();

  /// Returns the shared singleton, creating and initialising it if needed.
  static Future<StarDataService> instance() async {
    if (_instance == null) {
      _instance = StarDataService._();
      await _instance!._load();
    }
    return _instance!;
  }

  List<Star> _stars = [];
  List<Constellation> _constellations = [];
  List<DailyCard> _dailyCards = [];

  /// All stars, sorted by ascending magnitude (brightest first).
  List<Star> get stars => _stars;

  /// All constellations.
  List<Constellation> get constellations => _constellations;

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
    final cardsJson =
        await rootBundle.loadString('assets/data/daily_cards.json');

    _stars = (jsonDecode(starsJson) as List)
        .map((j) => Star.fromJson(j as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.magnitude.compareTo(b.magnitude));

    _constellations = (jsonDecode(constellationsJson) as List)
        .map((j) => Constellation.fromJson(j as Map<String, dynamic>))
        .toList();

    _dailyCards = (jsonDecode(cardsJson) as List)
        .map((j) => DailyCard.fromJson(j as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

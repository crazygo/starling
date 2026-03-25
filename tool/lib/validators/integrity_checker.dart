import '../parsers/models.dart';

/// Validates the integrity of parsed data against the acceptance criteria.
///
/// All checks throw [StateError] on failure so that the pipeline aborts early
/// with a clear diagnostic message.
class IntegrityChecker {
  IntegrityChecker._();

  // ─────────────────────────────────────────────────────────────────────────
  // Edge referential integrity
  // ─────────────────────────────────────────────────────────────────────────

  /// Check that every HIP reference in [edges] exists in [validHips].
  ///
  /// If any orphan IDs are found a [StateError] is thrown listing up to
  /// the first 10 offending values.
  static void checkEdges({
    required String label,
    required Iterable<EdgeRecord> edges,
    required Set<int> validHips,
  }) {
    final orphans = <int>{};
    for (final e in edges) {
      if (!validHips.contains(e.fromHip)) orphans.add(e.fromHip);
      if (!validHips.contains(e.toHip))   orphans.add(e.toHip);
    }
    if (orphans.isNotEmpty) {
      throw StateError(
        '❌ [$label] ${orphans.length} orphan hip_id(s) found: '
        '${orphans.take(10).toList()}${orphans.length > 10 ? "…" : ""}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Count checks
  // ─────────────────────────────────────────────────────────────────────────

  /// Verify that the western constellation set contains exactly 88 entries.
  static void checkWesternCount(int count) {
    if (count != 88) {
      throw StateError('❌ Expected 88 IAU constellations, got $count');
    }
  }

  /// Verify that the Chinese asterism count is within the expected range.
  ///
  /// Stellarium's Chinese sky culture defines approximately 283 star officials
  /// (星官); values outside 250–320 indicate a parse error.
  static void checkChineseCount(int count) {
    if (count < 250 || count > 320) {
      throw StateError(
        '❌ Expected ~283 Chinese asterisms (250–320 range), got $count',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Enumeration cross-checks
  // ─────────────────────────────────────────────────────────────────────────

  /// Verify Quadrant × Mansion pairings are logically consistent.
  ///
  /// Rules enforced:
  ///   • Three Enclosures (Central quadrant) must have mansion == 0 (None).
  ///   • All other quadrants must have mansion ≠ 0.
  ///   • The 28 mansions are distributed correctly across the four palaces.
  static void checkQuadrantMansionPairing(List<AsterismRecord> asterisms) {
    // Allowed mansion values per quadrant (exclusive ranges).
    const eastMansions   = {1, 2, 3, 4, 5, 6, 7};      // 角亢氐房心尾箕
    const northMansions  = {8, 9, 10, 11, 12, 13, 14};  // 斗牛女虚危室壁
    const westMansions   = {15, 16, 17, 18, 19, 20, 21}; // 奎娄胃昴毕觜参
    const southMansions  = {22, 23, 24, 25, 26, 27, 28}; // 井鬼柳星张翼轸

    const quadrantToMansions = <int, Set<int>>{
      0: eastMansions,   // East Azure
      1: northMansions,  // North Black
      2: westMansions,   // West White
      3: southMansions,  // South Scarlet
      4: {0},            // Central – must use Mansion.none
    };

    final errors = <String>[];

    for (final a in asterisms) {
      final allowed = quadrantToMansions[a.quadrant];
      if (allowed == null) {
        errors.add('  "${a.name}": unknown quadrant ${a.quadrant}');
        continue;
      }
      if (!allowed.contains(a.mansion)) {
        errors.add(
          '  "${a.name}": quadrant=${a.quadrant} '
          'incompatible with mansion=${a.mansion} '
          '(allowed: $allowed)',
        );
      }
    }

    if (errors.isNotEmpty) {
      throw StateError(
        '❌ Quadrant/Mansion pairing errors '
        '(${errors.length}):\n${errors.join('\n')}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Magnitude range check
  // ─────────────────────────────────────────────────────────────────────────

  /// Verify that every star has a reasonable visual magnitude.
  ///
  /// Magnitude values outside −2.0–8.0 indicate a parse error in the
  /// Hipparcos data.
  static void checkMagnitudeRange(List<StarRecord> stars) {
    final bad = stars.where((s) => s.mag < -2.0 || s.mag > 8.0).toList();
    if (bad.isNotEmpty) {
      final sample = bad
          .take(5)
          .map((s) => 'HIP ${s.hip} (mag=${s.mag})')
          .join(', ');
      throw StateError(
        '❌ ${bad.length} star(s) with out-of-range magnitude: $sample',
      );
    }
  }
}

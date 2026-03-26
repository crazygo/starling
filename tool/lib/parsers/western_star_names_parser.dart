import 'dart:io';

/// Parses the Stellarium western sky-culture `star_names.fab` file and
/// returns a map of Hipparcos ID → primary English proper name.
///
/// File format (one entry per line):
///   <hip>|_("<name>") <catalog-ids>
///
/// The same HIP can appear multiple times with different names (aliases used
/// in different catalogues).  We take the first occurrence for each HIP as
/// the canonical name, as the file is ordered with the most commonly used
/// name listed first.
///
/// Lines starting with `#` are comments; blank lines are ignored.
///
/// Source:
///   https://github.com/Stellarium/stellarium/blob/master/skycultures/modern/star_names.fab
class WesternStarNamesParser {
  WesternStarNamesParser._();

  /// Parse [file] and return a map from HIP → primary English proper name.
  ///
  /// Stars with no named entry are absent from the map.
  static Map<int, String> parse(File file) {
    final result = <int, String>{};

    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Format: <hip>|_("<name>") <catalog-ids>
      final pipeIdx = trimmed.indexOf('|');
      if (pipeIdx <= 0) continue;

      final hip = int.tryParse(trimmed.substring(0, pipeIdx).trim());
      if (hip == null) continue;

      // Extract the name from  _("<name>")
      final rest = trimmed.substring(pipeIdx + 1);
      final nameStart = rest.indexOf('_("');
      final nameEnd   = rest.indexOf('")');
      if (nameStart < 0 || nameEnd < 0 || nameEnd <= nameStart + 3) continue;

      final name = rest.substring(nameStart + 3, nameEnd).trim();
      if (name.isEmpty) continue;

      // Only record the first (most canonical) name for each HIP.
      result.putIfAbsent(hip, () => name);
    }

    return result;
  }
}

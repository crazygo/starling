import 'dart:io';
import 'package:csv/csv.dart';
import 'models.dart';

/// Parses IAU constellation line (stick-figure) data.
///
/// Expected CSV format (header optional, comma-separated):
///   abbr, num_pairs, hip1, hip2, hip3, hip4, …
///
/// Where each row specifies the IAU abbreviation, the number of star pairs,
/// followed by that many HIP numbers grouped as sequential edge pairs
/// [from₁, to₁, from₂, to₂, …].
///
/// This format matches Stellarium's `constellationship.fab` when converted
/// to CSV, or the IAU stick-figure datasets available from:
///   https://github.com/Stellarium/stellarium/tree/master/skycultures/modern
class IauLinesParser {
  IauLinesParser._();

  /// Parse [file] and return a map from IAU abbreviation → [ConstellationRecord].
  ///
  /// The returned records have empty `boundary` lists – those are populated
  /// separately by [IauBoundaryParser].
  static Map<String, ConstellationRecord> parse(File file) {
    final content = file.readAsStringSync();
    final rows = const CsvToListConverter(eol: '\n').convert(content);

    final result = <String, ConstellationRecord>{};

    for (final row in rows) {
      if (row.isEmpty) continue;
      final abbr = (row[0] as Object).toString().trim().toUpperCase();
      if (abbr.isEmpty || abbr.startsWith('#')) continue;

      final numPairs = int.tryParse(row[1].toString().trim());
      if (numPairs == null) continue;

      final edges = <EdgeRecord>[];
      for (var i = 0; i < numPairs; i++) {
        final fromIdx = 2 + i * 2;
        final toIdx   = 3 + i * 2;
        if (toIdx >= row.length) break;

        final fromHip = int.tryParse(row[fromIdx].toString().trim());
        final toHip   = int.tryParse(row[toIdx].toString().trim());
        if (fromHip == null || toHip == null) continue;

        edges.add(EdgeRecord(fromHip: fromHip, toHip: toHip));
      }

      result[abbr] = ConstellationRecord(
        abbr:     abbr,
        nameEn:   _iauNameEn[abbr] ?? abbr,
        nameZh:   _iauNameZh[abbr] ?? abbr,
        family:   _iauFamily[abbr] ?? 8, // Other
        edges:    edges,
        boundary: const [],
      );
    }

    return result;
  }

  // ── Static lookup tables ────────────────────────────────────────────────

  /// English names for all 88 IAU constellations.
  static const Map<String, String> _iauNameEn = {
    'AND': 'Andromeda',      'ANT': 'Antlia',         'APS': 'Apus',
    'AQL': 'Aquila',         'AQR': 'Aquarius',       'ARA': 'Ara',
    'ARI': 'Aries',          'AUR': 'Auriga',         'BOO': 'Boötes',
    'CAE': 'Caelum',         'CAM': 'Camelopardalis', 'CAP': 'Capricornus',
    'CAR': 'Carina',         'CAS': 'Cassiopeia',     'CEN': 'Centaurus',
    'CEP': 'Cepheus',        'CET': 'Cetus',          'CHA': 'Chamaeleon',
    'CIR': 'Circinus',       'CMA': 'Canis Major',    'CMI': 'Canis Minor',
    'CNC': 'Cancer',         'COL': 'Columba',        'COM': 'Coma Berenices',
    'CRA': 'Corona Australis','CRB': 'Corona Borealis','CRT': 'Crater',
    'CRU': 'Crux',           'CRV': 'Corvus',         'CVN': 'Canes Venatici',
    'CYG': 'Cygnus',         'DEL': 'Delphinus',      'DOR': 'Dorado',
    'DRA': 'Draco',          'EQU': 'Equuleus',       'ERI': 'Eridanus',
    'FOR': 'Fornax',         'GEM': 'Gemini',         'GRU': 'Grus',
    'HER': 'Hercules',       'HOR': 'Horologium',     'HYA': 'Hydra',
    'HYI': 'Hydrus',         'IND': 'Indus',          'LAC': 'Lacerta',
    'LEO': 'Leo',            'LEP': 'Lepus',          'LIB': 'Libra',
    'LMI': 'Leo Minor',      'LUP': 'Lupus',          'LYN': 'Lynx',
    'LYR': 'Lyra',           'MEN': 'Mensa',          'MIC': 'Microscopium',
    'MON': 'Monoceros',      'MUS': 'Musca',          'NOR': 'Norma',
    'OCT': 'Octans',         'OPH': 'Ophiuchus',      'ORI': 'Orion',
    'PAV': 'Pavo',           'PEG': 'Pegasus',        'PER': 'Perseus',
    'PHE': 'Phoenix',        'PIC': 'Pictor',         'PSA': 'Piscis Austrinus',
    'PSC': 'Pisces',         'PUP': 'Puppis',         'PYX': 'Pyxis',
    'RET': 'Reticulum',      'SCL': 'Sculptor',       'SCO': 'Scorpius',
    'SCT': 'Scutum',         'SER': 'Serpens',        'SEX': 'Sextans',
    'SGE': 'Sagitta',        'SGR': 'Sagittarius',    'TAU': 'Taurus',
    'TEL': 'Telescopium',    'TRA': 'Triangulum Australe','TRI': 'Triangulum',
    'TUC': 'Tucana',         'UMA': 'Ursa Major',     'UMI': 'Ursa Minor',
    'VEL': 'Vela',           'VIR': 'Virgo',          'VOL': 'Volans',
    'VUL': 'Vulpecula',
  };

  /// Chinese names for all 88 IAU constellations.
  static const Map<String, String> _iauNameZh = {
    'AND': '仙女座',   'ANT': '唧筒座',   'APS': '天燕座',
    'AQL': '天鹰座',   'AQR': '宝瓶座',   'ARA': '天坛座',
    'ARI': '白羊座',   'AUR': '御夫座',   'BOO': '牧夫座',
    'CAE': '雕具座',   'CAM': '鹿豹座',   'CAP': '摩羯座',
    'CAR': '船底座',   'CAS': '仙后座',   'CEN': '半人马座',
    'CEP': '仙王座',   'CET': '鲸鱼座',   'CHA': '蝘蜓座',
    'CIR': '圆规座',   'CMA': '大犬座',   'CMI': '小犬座',
    'CNC': '巨蟹座',   'COL': '天鸽座',   'COM': '后发座',
    'CRA': '南冕座',   'CRB': '北冕座',   'CRT': '巨爵座',
    'CRU': '南十字座', 'CRV': '乌鸦座',   'CVN': '猎犬座',
    'CYG': '天鹅座',   'DEL': '海豚座',   'DOR': '剑鱼座',
    'DRA': '天龙座',   'EQU': '小马座',   'ERI': '波江座',
    'FOR': '天炉座',   'GEM': '双子座',   'GRU': '天鹤座',
    'HER': '武仙座',   'HOR': '时钟座',   'HYA': '长蛇座',
    'HYI': '水蛇座',   'IND': '印第安座', 'LAC': '蝎虎座',
    'LEO': '狮子座',   'LEP': '天兔座',   'LIB': '天秤座',
    'LMI': '小狮座',   'LUP': '豺狼座',   'LYN': '天猫座',
    'LYR': '天琴座',   'MEN': '山案座',   'MIC': '显微镜座',
    'MON': '麒麟座',   'MUS': '苍蝇座',   'NOR': '矩尺座',
    'OCT': '南极座',   'OPH': '蛇夫座',   'ORI': '猎户座',
    'PAV': '孔雀座',   'PEG': '飞马座',   'PER': '英仙座',
    'PHE': '凤凰座',   'PIC': '绘架座',   'PSA': '南鱼座',
    'PSC': '双鱼座',   'PUP': '船尾座',   'PYX': '罗盘座',
    'RET': '网罟座',   'SCL': '玉夫座',   'SCO': '天蝎座',
    'SCT': '盾牌座',   'SER': '巨蛇座',   'SEX': '六分仪座',
    'SGE': '天箭座',   'SGR': '人马座',   'TAU': '金牛座',
    'TEL': '望远镜座', 'TRA': '南三角座', 'TRI': '三角座',
    'TUC': '杜鹃座',   'UMA': '大熊座',   'UMI': '小熊座',
    'VEL': '船帆座',   'VIR': '室女座',   'VOL': '飞鱼座',
    'VUL': '狐狸座',
  };

  /// IAU constellation family (see [ConstellationFamily] in generated file).
  static const Map<String, int> _iauFamily = {
    // Zodiac (0)
    'ARI': 0, 'TAU': 0, 'GEM': 0, 'CNC': 0, 'LEO': 0, 'VIR': 0,
    'LIB': 0, 'SCO': 0, 'SGR': 0, 'CAP': 0, 'AQR': 0, 'PSC': 0,
    // Ursa (1)
    'UMA': 1, 'UMI': 1, 'DRA': 1, 'CVN': 1, 'COM': 1, 'BOO': 1,
    'CRB': 1,
    // Perseus (2)
    'PER': 2, 'AND': 2, 'TRI': 2, 'AUR': 2, 'CAS': 2, 'CEP': 2,
    'CAM': 2, 'LAC': 2,
    // Hercules (3)
    'HER': 3, 'LYR': 3, 'CYG': 3, 'VUL': 3, 'SGE': 3,
    'AQL': 3, 'DEL': 3, 'EQU': 3, 'SER': 3, 'OPH': 3, 'SCT': 3,
    // Orion (4)
    'ORI': 4, 'CMA': 4, 'CMI': 4, 'MON': 4, 'LEP': 4, 'ERI': 4,
    // Heavenly waters (5)
    'CET': 5, 'PSA': 5, 'COL': 5, 'PUP': 5, 'VEL': 5,
    'CAR': 5, 'HYA': 5, 'CRT': 5, 'CRV': 5, 'ARA': 5, 'CRA': 5,
    // Bayer (6)
    'HYI': 6, 'DOR': 6, 'RET': 6, 'PIC': 6, 'VOL': 6,
    'MUS': 6, 'CRU': 6, 'CEN': 6, 'CIR': 6, 'TRA': 6, 'APS': 6,
    'PAV': 6, 'IND': 6, 'GRU': 6, 'PHE': 6, 'TUC': 6, 'OCT': 6,
    'CHA': 6,
    // La Caille (7)
    'NOR': 7, 'LUP': 7, 'SCL': 7, 'FOR': 7, 'CAE': 7, 'HOR': 7,
    'MEN': 7, 'MIC': 7, 'TEL': 7, 'ANT': 7, 'PYX': 7, 'SEX': 7,
    // Other (8) – default for any not listed
  };
}

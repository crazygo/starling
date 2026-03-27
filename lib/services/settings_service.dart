import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available culture modes for star names and constellation data.
enum CultureMode { chinese, western }

/// Available language modes for the app UI.
enum LanguageMode {
  /// Follow the device's system locale.
  auto,

  /// Always show Chinese (Simplified).
  chinese,

  /// Always show English.
  english,
}

/// Available location modes for determining the observer's position.
enum LocationMode {
  /// Default: Beijing (lat 39.9042°N, lon 116.4074°E).
  beijing,

  /// Use the device GPS to determine the observer's position.
  gps,
}

/// Available rendering styles for the Voyage sky view.
enum ViewStyle {
  /// Immersive dome-style sky view with orientation framing.
  dome,

  /// Current flat rectangular chart.
  classic,
}

/// App-wide settings, backed by [SharedPreferences] for persistence.
///
/// Expose via [ChangeNotifierProvider] so any widget can read or update
/// settings and have the UI rebuild automatically.
class SettingsService extends ChangeNotifier {
  static const _keyCulture = 'culture_mode';
  static const _keyLocation = 'location_mode';
  static const _keyLanguage = 'language_mode';
  static const _keyViewStyle = 'view_style';

  CultureMode _cultureMode = CultureMode.chinese;
  LocationMode _locationMode = LocationMode.beijing;
  LanguageMode _languageMode = LanguageMode.auto;
  ViewStyle _viewStyle = ViewStyle.dome;

  /// The currently selected culture mode.
  CultureMode get cultureMode => _cultureMode;

  /// Whether Chinese cultural names and constellation data should be shown.
  bool get isChinese => _cultureMode == CultureMode.chinese;

  /// The currently selected location mode.
  LocationMode get locationMode => _locationMode;

  /// The currently selected language mode.
  LanguageMode get languageMode => _languageMode;

  /// The currently selected sky view style.
  ViewStyle get viewStyle => _viewStyle;

  /// Load persisted settings from [SharedPreferences].
  ///
  /// Call this from [State.initState] to kick off loading early in the
  /// widget lifecycle. The first frame will typically render with default
  /// values, and then rebuild when the persisted settings have been loaded.
  /// The [notifyListeners] call at the end is safe because [load] completes
  /// asynchronously after widgets have been mounted and are ready to listen.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCulture = prefs.getString(_keyCulture);
    if (storedCulture == CultureMode.western.name) {
      _cultureMode = CultureMode.western;
    } else {
      _cultureMode = CultureMode.chinese;
    }
    final storedLocation = prefs.getString(_keyLocation);
    if (storedLocation == LocationMode.gps.name) {
      _locationMode = LocationMode.gps;
    } else {
      _locationMode = LocationMode.beijing;
    }
    final storedLanguage = prefs.getString(_keyLanguage);
    if (storedLanguage == LanguageMode.chinese.name) {
      _languageMode = LanguageMode.chinese;
    } else if (storedLanguage == LanguageMode.english.name) {
      _languageMode = LanguageMode.english;
    } else {
      _languageMode = LanguageMode.auto;
    }
    final storedViewStyle = prefs.getString(_keyViewStyle);
    if (storedViewStyle == ViewStyle.classic.name) {
      _viewStyle = ViewStyle.classic;
    } else {
      _viewStyle = ViewStyle.dome;
    }
    notifyListeners();
  }

  /// Update the culture mode and persist the change.
  Future<void> setCultureMode(CultureMode mode) async {
    if (_cultureMode == mode) return;
    _cultureMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // If the culture mode changed again while we were waiting, don't
    // overwrite the newer value in SharedPreferences with this stale one.
    if (_cultureMode != mode) return;
    await prefs.setString(_keyCulture, mode.name);
  }

  /// Update the location mode and persist the change.
  Future<void> setLocationMode(LocationMode mode) async {
    if (_locationMode == mode) return;
    _locationMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_locationMode != mode) return;
    await prefs.setString(_keyLocation, mode.name);
  }

  /// Update the language mode and persist the change.
  Future<void> setLanguageMode(LanguageMode mode) async {
    if (_languageMode == mode) return;
    _languageMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_languageMode != mode) return;
    await prefs.setString(_keyLanguage, mode.name);
  }

  /// Update the view style and persist the change.
  Future<void> setViewStyle(ViewStyle style) async {
    if (_viewStyle == style) return;
    _viewStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_viewStyle != style) return;
    await prefs.setString(_keyViewStyle, style.name);
  }
}

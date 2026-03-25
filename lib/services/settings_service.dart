import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available culture modes for star names and constellation data.
enum CultureMode {
  chinese,
  western,
}

/// App-wide settings, backed by [SharedPreferences] for persistence.
///
/// Expose via [ChangeNotifierProvider] so any widget can read or update
/// settings and have the UI rebuild automatically.
class SettingsService extends ChangeNotifier {
  static const _keyCulture = 'culture_mode';

  CultureMode _cultureMode = CultureMode.chinese;

  /// The currently selected culture mode.
  CultureMode get cultureMode => _cultureMode;

  /// Whether Chinese cultural names and constellation data should be shown.
  bool get isChinese => _cultureMode == CultureMode.chinese;

  /// Load persisted settings from [SharedPreferences].
  ///
  /// Call this from [State.initState] before the widget tree is rendered.
  /// The [notifyListeners] call at the end is safe because [load] is async —
  /// by the time the [Future] completes, the first frame has already been
  /// scheduled and listeners are ready to respond.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyCulture);
    if (stored == CultureMode.western.name) {
      _cultureMode = CultureMode.western;
    } else {
      _cultureMode = CultureMode.chinese;
    }
    notifyListeners();
  }

  /// Update the culture mode and persist the change.
  Future<void> setCultureMode(CultureMode mode) async {
    if (_cultureMode == mode) return;
    _cultureMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCulture, mode.name);
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:starling/l10n/generated/app_localizations.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/star.dart';
import '../models/constellation.dart';
import '../services/gyro_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../services/star_data_service.dart';
import '../utils/astronomy.dart';
import '../utils/voyage_dome.dart';
import '../widgets/star_chart.dart';
import '../widgets/star_info_popup.dart';

/// The Explore page — a full-screen interactive star map with optional
/// gyroscope-driven panning and a quick-search bar.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // Data
  List<Star> _stars = [];
  List<Constellation> _westernConstellations = [];
  List<Constellation> _chineseConstellations = [];
  StarDataService? _dataService;
  bool _loading = true;

  // Chart state
  StarChartViewport _viewport = const StarChartViewport();
  Star? _selectedStar;

  // Observation date/time
  late DateTime _observeDate;
  late TimeOfDay _observeTime;

  // Services
  final GyroService _gyroService = GyroService();
  final LocationService _locationService = LocationService();
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<LocationData>? _locationSub;

  bool _gyroEnabled = false;
  Offset _gyroOffset = Offset.zero;
  DateTime? _lastGyroTime; // used to compute accurate Δt between events

  // Settings listener
  SettingsService? _settingsService;
  ViewStyle? _lastViewStyle;

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _searchVisible = false;
  List<Star> _searchResults = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _observeDate = DateTime(now.year, now.month, now.day);
    _observeTime = const TimeOfDay(hour: 22, minute: 0);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSettings = context.read<SettingsService>();
    if (_settingsService != newSettings) {
      _settingsService?.removeListener(_onSettingsChanged);
      _settingsService = newSettings;
      _settingsService!.addListener(_onSettingsChanged);
      _lastViewStyle = newSettings.viewStyle;
      _syncLocationMode(newSettings.locationMode);
    }
  }

  void _onSettingsChanged() {
    if (!mounted || _settingsService == null) return;
    _syncLocationMode(_settingsService!.locationMode);
    final nextViewStyle = _settingsService!.viewStyle;
    if (_lastViewStyle != nextViewStyle) {
      _viewport = nextViewStyle == ViewStyle.dome
          ? _defaultDomeViewport
          : _seasonalViewport(_observeDateTime);
      _lastViewStyle = nextViewStyle;
    }
    setState(() {});
  }

  void _syncLocationMode(LocationMode mode) {
    if (mode == LocationMode.gps) {
      _locationService.start();
      _locationSub ??= _locationService.locationStream.listen((_) {
        if (!mounted) return;
        setState(() {});
      });
    } else {
      _locationService.stop();
    }
  }

  Future<void> _loadData() async {
    final service = await StarDataService.instance();
    if (mounted) {
      setState(() {
        _dataService = service;
        _stars = service.stars;
        _westernConstellations = service.constellations;
        _chineseConstellations = service.chineseConstellations;
        _loading = false;
        _viewport = context.read<SettingsService>().viewStyle == ViewStyle.dome
            ? _defaultDomeViewport
            : _seasonalViewport(_observeDateTime);
      });
    }
  }

  StarChartViewport get _defaultDomeViewport {
    final camera = seasonalDomeCamera(
      localDateTime: _observeDateTime,
      latitudeDeg: _observerLatitude,
    );
    return StarChartViewport(
      centerRa: camera.azimuthDeg,
      centerDec: camera.altitudeDeg,
      zoom: camera.zoom,
    );
  }

  DateTime get _observeDateTime => DateTime(
        _observeDate.year,
        _observeDate.month,
        _observeDate.day,
        _observeTime.hour,
        _observeTime.minute,
      );

  double get _observerLatitude {
    final locationMode = _settingsService?.locationMode ?? LocationMode.beijing;
    final lastKnown = _locationService.lastKnown;
    if (locationMode == LocationMode.gps && lastKnown?.latitude != null) {
      return lastKnown!.latitude!;
    }
    return kBeijingLatitude;
  }

  double get _observerLongitude {
    final locationMode = _settingsService?.locationMode ?? LocationMode.beijing;
    final lastKnown = _locationService.lastKnown;
    if (locationMode == LocationMode.gps && lastKnown?.longitude != null) {
      return lastKnown!.longitude!;
    }
    return kBeijingLongitude;
  }

  /// Returns a [StarChartViewport] centred on the season's representative
  /// asterism for the given [dt].
  StarChartViewport _seasonalViewport(DateTime dt) {
    final month = dt.month;
    double ra;
    double dec;
    if (month == 11 || month == 12 || month == 1 || month == 2) {
      // 冬季：猎户座腰带中心
      ra = 83.8;
      dec = 0.0;
    } else if (month >= 3 && month <= 5) {
      // 春季：大熊座（北斗七星）
      ra = 165.9;
      dec = 56.4;
    } else if (month >= 6 && month <= 8) {
      // 夏季：夏季大三角（织女星）
      ra = 279.2;
      dec = 38.8;
    } else {
      // 秋季：飞马座（秋季四边形）
      ra = 345.0;
      dec = 15.0;
    }
    return StarChartViewport(centerRa: ra, centerDec: dec, zoom: 1.0);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _observeDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _observeDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _observeTime,
    );
    if (picked != null && mounted) {
      setState(() => _observeTime = picked);
    }
  }

  void _toggleGyro() {
    setState(() {
      _gyroEnabled = !_gyroEnabled;
      if (_gyroEnabled) {
        _gyroOffset = Offset.zero;
        _lastGyroTime = null;
        _gyroService.start();
        _gyroSub = _gyroService.gyroStream.listen(_onGyroEvent);
      } else {
        _gyroService.stop();
        _gyroSub?.cancel();
        _gyroSub = null;
        _lastGyroTime = null;
      }
    });
  }

  void _onGyroEvent(GyroscopeEvent event) {
    final now = DateTime.now();
    // Compute measured Δt between events; fall back to 50 ms on first event.
    final dt = _lastGyroTime != null
        ? now.difference(_lastGyroTime!).inMicroseconds / 1e6
        : 0.05;
    _lastGyroTime = now;

    // Convert angular velocity (rad/s) × Δt (s) = radians, then to degrees.
    const radToDeg = 180.0 / pi;
    const sensitivity = 0.5; // tunable panning sensitivity
    setState(() {
      _gyroOffset = Offset(
        _gyroOffset.dx + event.y * dt * radToDeg * sensitivity,
        _gyroOffset.dy + event.x * dt * radToDeg * sensitivity,
      );
    });
  }

  void _onSearch(String query) {
    if (_dataService == null) return;
    setState(() {
      _searchResults = query.isEmpty
          ? []
          : _dataService!.searchStars(query).take(6).toList();
    });
  }

  void _focusStar(Star star) {
    final viewStyle = _settingsService?.viewStyle ?? ViewStyle.dome;
    final focusedViewport = viewStyle == ViewStyle.dome
        ? (() {
            final horizontal = AstronomyUtils.equatorialToHorizontal(
              raDeg: star.rightAscension,
              decDeg: star.declination,
              latDeg: _observerLatitude,
              lonDeg: _observerLongitude,
              utc: _observeDateTime.toUtc(),
            );
            return _viewport.copyWith(
              centerRa: horizontal.azimuth,
              centerDec: horizontal.altitude,
              zoom: 2.5,
            );
          })()
        : _viewport.copyWith(
            centerRa: star.rightAscension,
            centerDec: star.declination,
            zoom: 2.5,
          );
    setState(() {
      _viewport = focusedViewport;
      _selectedStar = star;
      _searchVisible = false;
      _searchController.clear();
      _searchResults = [];
    });
  }

  @override
  void dispose() {
    _settingsService?.removeListener(_onSettingsChanged);
    _gyroService.dispose();
    _gyroSub?.cancel();
    _locationSub?.cancel();
    _locationService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChinese = context.select<SettingsService, bool>((s) => s.isChinese);
    final viewStyle = context.select<SettingsService, ViewStyle>(
      (s) => s.viewStyle,
    );
    final showNonConstellationStars = context.select<SettingsService, bool>(
      (s) => s.showNonConstellationStars,
    );
    final majorStarsOnlyLabels = context.select<SettingsService, bool>(
      (s) => s.majorStarsOnlyLabels,
    );
    final backgroundStarThreshold =
        context.select<SettingsService, BackgroundStarThreshold>(
      (s) => s.backgroundStarThreshold,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF05091A),
      body: _loading
          ? _buildLoading()
          : _buildChart(
              isChinese,
              viewStyle,
              showNonConstellationStars,
              majorStarsOnlyLabels,
              backgroundStarThreshold,
            ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.blueAccent),
          SizedBox(height: 16),
          Text('Loading star data…', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildChart(
    bool isChinese,
    ViewStyle viewStyle,
    bool showNonConstellationStars,
    bool majorStarsOnlyLabels,
    BackgroundStarThreshold backgroundStarThreshold,
  ) {
    final constellations =
        isChinese ? _chineseConstellations : _westernConstellations;
    return Stack(
      children: [
        // Star chart
        StarChart(
          stars: _stars,
          constellations: constellations,
          chineseConstellations: _chineseConstellations,
          showChineseName: isChinese,
          viewport: _viewport,
          viewStyle: viewStyle,
          observerLatitude: _observerLatitude,
          observerLongitude: _observerLongitude,
          observationTimeUtc: _observeDateTime.toUtc(),
          showNonConstellationStars: showNonConstellationStars,
          majorStarsOnlyLabels: majorStarsOnlyLabels,
          backgroundStarThreshold: backgroundStarThreshold,
          onViewportChanged: (vp) => setState(() => _viewport = vp),
          onStarTapped: (star) => setState(() => _selectedStar = star),
          gyroOffset: _gyroEnabled ? _gyroOffset : null,
        ),

        // Top bar (search + title)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.exploreTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _searchVisible ? Icons.close : Icons.search,
                        color: Colors.white,
                      ),
                      onPressed: () => setState(() {
                        _searchVisible = !_searchVisible;
                        if (!_searchVisible) {
                          _searchController.clear();
                          _searchResults = [];
                        }
                      }),
                    ),
                    _GyroButton(active: _gyroEnabled, onTap: _toggleGyro),
                  ],
                ),
                if (_searchVisible)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.searchHint,
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.black54,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white38,
                        ),
                      ),
                      onChanged: _onSearch,
                    ),
                  ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _searchResults
                          .map(
                            (star) => ListTile(
                              leading: const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              title: Text(
                                isChinese
                                    ? (star.chineseName ?? star.name)
                                    : star.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Mag ${star.magnitude.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                              dense: true,
                              onTap: () => _focusStar(star),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Star detail popup
        if (_selectedStar != null)
          StarInfoPopup(
            star: _selectedStar!,
            showChineseName: isChinese,
            onClose: () => setState(() => _selectedStar = null),
          ),

        // Bottom-left date/time card
        Positioned(
          left: 16,
          bottom: 32,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white54,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_observeDate.year.toString().padLeft(4, '0')}-'
                        '${_observeDate.month.toString().padLeft(2, '0')}-'
                        '${_observeDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _pickTime,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.white54,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_observeTime.hour.toString().padLeft(2, '0')}:'
                        '${_observeTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable widgets
// ---------------------------------------------------------------------------

class _GyroButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _GyroButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent.withAlpha(77) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.blueAccent : Colors.white30,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.screen_rotation,
              color: active ? Colors.blueAccent : Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              active
                  ? AppLocalizations.of(context)!.gyroOn
                  : AppLocalizations.of(context)!.gyroOff,
              style: TextStyle(
                color: active ? Colors.blueAccent : Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

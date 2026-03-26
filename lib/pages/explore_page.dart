import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/star.dart';
import '../models/constellation.dart';
import '../services/gyro_service.dart';
import '../services/location_service.dart';
import '../services/star_data_service.dart';
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
  List<Constellation> _constellations = [];
  StarDataService? _dataService;
  bool _loading = true;

  // Chart state
  StarChartViewport _viewport = const StarChartViewport();
  Star? _selectedStar;

  // Services
  final GyroService _gyroService = GyroService();
  final LocationService _locationService = LocationService();
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  bool _gyroEnabled = false;
  Offset _gyroOffset = Offset.zero;
  DateTime? _lastGyroTime; // used to compute accurate Δt between events

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _searchVisible = false;
  List<Star> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _locationService.start();
  }

  Future<void> _loadData() async {
    final service = await StarDataService.instance();
    if (mounted) {
      setState(() {
        _dataService = service;
        _stars = service.stars;
        _constellations = service.constellations;
        _loading = false;
      });
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
    setState(() {
      _viewport = _viewport.copyWith(
        centerRa: star.rightAscension,
        centerDec: star.declination,
        zoom: 2.5,
      );
      _selectedStar = star;
      _searchVisible = false;
      _searchController.clear();
      _searchResults = [];
    });
  }

  @override
  void dispose() {
    _gyroService.dispose();
    _gyroSub?.cancel();
    _locationService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05091A),
      body: _loading ? _buildLoading() : _buildChart(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.blueAccent),
          SizedBox(height: 16),
          Text('Loading star data…',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Stack(
      children: [
        // Star chart
        StarChart(
          stars: _stars,
          constellations: _constellations,
          viewport: _viewport,
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
                    const Text(
                      '星仔',
                      style: TextStyle(
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
                    _GyroButton(
                      active: _gyroEnabled,
                      onTap: _toggleGyro,
                    ),
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
                        hintStyle:
                            const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.black54,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white38),
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
                              leading: const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              title: Text(
                                star.chineseName ?? star.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                              subtitle: Text(
                                'Mag ${star.magnitude.toStringAsFixed(1)}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11),
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
            onClose: () => setState(() => _selectedStar = null),
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
          color: active
              ? Colors.blueAccent.withAlpha(77)
              : Colors.transparent,
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

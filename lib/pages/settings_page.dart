import 'package:flutter/material.dart';
import 'package:starling/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';

/// The Settings page — allows users to configure app-wide preferences.
///
/// Currently contains:
/// * **Culture Settings** (文化设置) — choose between Chinese and Western
///   star names / constellation data.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF05091A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF05091A),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              l10n.settingsSubtitle,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const _LocationSettingsSection(),
          const _CultureSettingsSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location Settings section
// ---------------------------------------------------------------------------
class _LocationSettingsSection extends StatefulWidget {
  const _LocationSettingsSection();

  @override
  State<_LocationSettingsSection> createState() =>
      _LocationSettingsSectionState();
}

class _LocationSettingsSectionState extends State<_LocationSettingsSection> {
  final LocationService _locationService = LocationService();
  bool _fetchingGps = false;
  String? _gpsLabel; // null = not yet fetched

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _selectGps(SettingsService settings) async {
    await settings.setLocationMode(LocationMode.gps);
    if (!mounted) return;
    setState(() {
      _fetchingGps = true;
      _gpsLabel = '正在获取位置…';
    });
    try {
      await _locationService.start();
      // Wait up to 10 s for the first fix.
      LocationData? fix = _locationService.lastKnown;
      if (fix == null) {
        fix = await _locationService.locationStream
            .timeout(const Duration(seconds: 10))
            .first;
      }
      if (!mounted) return;
      final lat = fix.latitude?.toStringAsFixed(4) ?? '?';
      final lon = fix.longitude?.toStringAsFixed(4) ?? '?';
      setState(() {
        _fetchingGps = false;
        _gpsLabel = '已定位  ${lat}°N, ${lon}°E';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fetchingGps = false;
        _gpsLabel = '获取失败，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isBeijing = settings.locationMode == LocationMode.beijing;
    final isGps = settings.locationMode == LocationMode.gps;

    String gpsSubtitle;
    if (!isGps) {
      gpsSubtitle = '使用 GPS 获取当前位置';
    } else if (_gpsLabel != null) {
      gpsSubtitle = _gpsLabel!;
    } else {
      gpsSubtitle = '使用 GPS 获取当前位置';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '地区设置',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withAlpha(51)),
          ),
          child: Column(
            children: [
              _CultureOptionTile(
                title: '北京',
                subtitle: 'Beijing  (39.9°N, 116.4°E)',
                selected: isBeijing,
                onTap: () => settings.setLocationMode(LocationMode.beijing),
                showDivider: true,
              ),
              ListTile(
                onTap: () => _selectGps(settings),
                title: const Text(
                  '定位',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: Row(
                  children: [
                    if (_fetchingGps) ...[
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        gpsSubtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                trailing: isGps
                    ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                    : const Icon(Icons.radio_button_unchecked,
                        color: Colors.white30),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Culture Settings section
// ---------------------------------------------------------------------------
class _CultureSettingsSection extends StatelessWidget {
  const _CultureSettingsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            l10n.cultureSettings,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withAlpha(51)),
          ),
          child: Column(
            children: [
              _CultureOptionTile(
                title: l10n.chineseCulture,
                subtitle: l10n.chineseCultureSubtitle,
                selected: settings.cultureMode == CultureMode.chinese,
                onTap: () => settings.setCultureMode(CultureMode.chinese),
                showDivider: true,
              ),
              _CultureOptionTile(
                title: l10n.westernCulture,
                subtitle: l10n.westernCultureSubtitle,
                selected: settings.cultureMode == CultureMode.western,
                onTap: () => settings.setCultureMode(CultureMode.western),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CultureOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  const _CultureOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: selected
              ? const Icon(Icons.check_circle, color: Colors.blueAccent)
              : const Icon(Icons.radio_button_unchecked,
                  color: Colors.white30),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFF1A2C3A),
          ),
      ],
    );
  }
}
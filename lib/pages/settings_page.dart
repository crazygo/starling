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
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: const [
          _LocationSettingsSection(),
          _CultureSettingsSection(),
          _LanguageSettingsSection(),
          _ViewStyleSettingsSection(),
          _VisualGroupingSettingsSection(),
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
      fix ??= await _locationService.locationStream
          .timeout(const Duration(seconds: 10))
          .first;
      if (!mounted) return;
      final lat = fix.latitude?.toStringAsFixed(4) ?? '?';
      final lon = fix.longitude?.toStringAsFixed(4) ?? '?';
      setState(() {
        _fetchingGps = false;
        _gpsLabel = '已定位  $lat°N, $lon°E';
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
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: isGps
                    ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                    : const Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.white30,
                      ),
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

// ---------------------------------------------------------------------------
// Language Settings section
// ---------------------------------------------------------------------------
class _LanguageSettingsSection extends StatelessWidget {
  const _LanguageSettingsSection();

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
            l10n.languageSettings,
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
                title: l10n.languageAuto,
                subtitle: l10n.languageAutoSubtitle,
                selected: settings.languageMode == LanguageMode.auto,
                onTap: () => settings.setLanguageMode(LanguageMode.auto),
                showDivider: true,
              ),
              _CultureOptionTile(
                title: l10n.languageChinese,
                subtitle: l10n.languageChineseSubtitle,
                selected: settings.languageMode == LanguageMode.chinese,
                onTap: () => settings.setLanguageMode(LanguageMode.chinese),
                showDivider: true,
              ),
              _CultureOptionTile(
                title: l10n.languageEnglish,
                subtitle: l10n.languageEnglishSubtitle,
                selected: settings.languageMode == LanguageMode.english,
                onTap: () => settings.setLanguageMode(LanguageMode.english),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// View Style section
// ---------------------------------------------------------------------------
class _ViewStyleSettingsSection extends StatelessWidget {
  const _ViewStyleSettingsSection();

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
            l10n.viewStyleSettings,
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
                title: l10n.viewStyleDome,
                subtitle: l10n.viewStyleDomeSubtitle,
                selected: settings.viewStyle == ViewStyle.dome,
                onTap: () => settings.setViewStyle(ViewStyle.dome),
                showDivider: true,
              ),
              _CultureOptionTile(
                title: l10n.viewStyleClassic,
                subtitle: l10n.viewStyleClassicSubtitle,
                selected: settings.viewStyle == ViewStyle.classic,
                onTap: () => settings.setViewStyle(ViewStyle.classic),
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
              : const Icon(Icons.radio_button_unchecked, color: Colors.white30),
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

// ---------------------------------------------------------------------------
// Visual Grouping section
// ---------------------------------------------------------------------------
class _VisualGroupingSettingsSection extends StatelessWidget {
  const _VisualGroupingSettingsSection();

  String _renderConditionLabel(StarRenderCondition condition) {
    return switch (condition) {
      StarRenderCondition.small => '星星可见度 小',
      StarRenderCondition.medium => '星星可见度 中',
      StarRenderCondition.large => '星星可见度 大',
      StarRenderCondition.constellationOnly => '仅参与星座连线的星星',
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final renderCondition = settings.starRenderCondition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '视觉分组',
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
              SwitchListTile(
                value: settings.majorStarsOnlyLabels,
                onChanged: settings.setMajorStarsOnlyLabels,
                title: const Text(
                  '仅对主要星星显示标签',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: const Text(
                  '默认开启',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                activeThumbColor: Colors.blueAccent,
              ),
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFF1A2C3A),
              ),
              ListTile(
                title: const Text(
                  '星星渲染条件',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                subtitle: const Text(
                  '控制背景星与星名密度',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                trailing: PopupMenuButton<StarRenderCondition>(
                  initialValue: renderCondition,
                  onSelected: settings.setStarRenderCondition,
                  color: const Color(0xFF122538),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: StarRenderCondition.small,
                      child: Text('星星可见度 小'),
                    ),
                    PopupMenuItem(
                      value: StarRenderCondition.medium,
                      child: Text('星星可见度 中'),
                    ),
                    PopupMenuItem(
                      value: StarRenderCondition.large,
                      child: Text('星星可见度 大'),
                    ),
                    PopupMenuItem(
                      value: StarRenderCondition.constellationOnly,
                      child: Text('仅参与星座连线的星星'),
                    ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _renderConditionLabel(renderCondition),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

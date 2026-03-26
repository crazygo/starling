import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
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
            const Text(
              'Settings',
              style: TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: const [
          _CultureSettingsSection(),
        ],
      ),
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
                subtitle: 'Chinese Culture',
                selected: settings.cultureMode == CultureMode.chinese,
                onTap: () => settings.setCultureMode(CultureMode.chinese),
                showDivider: true,
              ),
              _CultureOptionTile(
                title: l10n.westernCulture,
                subtitle: 'Western Culture',
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

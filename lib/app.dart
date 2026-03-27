import 'package:flutter/material.dart';
import 'package:starling/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'pages/explore_page.dart';
import 'pages/daily_cards_page.dart';
import 'pages/settings_page.dart';
import 'services/settings_service.dart';

/// Root application widget.  Configures global theme and the main tab
/// navigation between [ExplorePage], [DailyCardsPage], and [SettingsPage].
class StarlingApp extends StatefulWidget {
  const StarlingApp({super.key});

  @override
  State<StarlingApp> createState() => _StarlingAppState();
}

class _StarlingAppState extends State<StarlingApp> {
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsService>.value(
      value: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          final Locale? locale = switch (_settings.languageMode) {
            LanguageMode.chinese => const Locale('zh'),
            LanguageMode.english => const Locale('en'),
            LanguageMode.auto => null,
          };
          return MaterialApp(
            title: '星仔 Starling',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: locale,
            localeResolutionCallback: (deviceLocale, supportedLocales) {
              if (deviceLocale == null) return const Locale('zh');
              for (final supported in supportedLocales) {
                if (supported.languageCode == deviceLocale.languageCode) {
                  return supported;
                }
              }
              return const Locale('zh');
            },
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1E6EFF),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF05091A),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF05091A),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF0A1020),
                selectedItemColor: Colors.blueAccent,
                unselectedItemColor: Colors.white38,
              ),
              useMaterial3: true,
            ),
            home: const _MainScreen(),
          );
        },
      ),
    );
  }
}

class _MainScreen extends StatefulWidget {
  const _MainScreen();

  @override
  State<_MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    DailyCardsPage(),
    ExplorePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today),
            label: AppLocalizations.of(context)!.tabBallads,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore),
            label: AppLocalizations.of(context)!.tabVoyage,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: AppLocalizations.of(context)!.tabSettings,
          ),
        ],
      ),
    );
  }
}

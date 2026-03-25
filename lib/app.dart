import 'package:flutter/material.dart';
import 'pages/explore_page.dart';
import 'pages/daily_cards_page.dart';

/// Root application widget.  Configures global theme and the main tab
/// navigation between [ExplorePage] and [DailyCardsPage].
class StarlingApp extends StatelessWidget {
  const StarlingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '星仔 Starling',
      debugShowCheckedModeBanner: false,
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '每日卡片',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: '探索',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'game_history_screen.dart';
import 'leaderboard_screen.dart';
import 'enhanced_statistics_screen.dart';
import 'player_input_screen.dart';
import 'settings_screen.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardGameScoreTracker());
}

class CardGameScoreTracker extends StatefulWidget {
  const CardGameScoreTracker({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CardGameScoreTrackerState createState() => _CardGameScoreTrackerState();
}

class _CardGameScoreTrackerState extends State<CardGameScoreTracker> {
  bool _isDarkTheme = true;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final dark = await GameRepository.instance.isDarkTheme();
    if (!mounted) return;
    setState(() => _isDarkTheme = dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScoreMaster',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: MainScreen(
        isDarkTheme: _isDarkTheme,
        onThemeChanged: (isDarkTheme) {
          setState(() => _isDarkTheme = isDarkTheme);
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkTheme;

  const MainScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkTheme,
  });

  @override
  // ignore: library_private_types_in_public_api
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const int _tabCount = 5;
  int _selectedIndex = 0;

  /// Экран строится при каждом показе, поэтому история, лидеры и статистика
  /// всегда отражают актуальные данные после сыгранной партии.
  Widget _screenFor(int index) {
    switch (index) {
      case 1:
        return const GameHistoryScreen();
      case 2:
        return const LeaderboardScreen();
      case 3:
        return const EnhancedStatisticsScreen();
      case 4:
        return SettingsScreen(
          onThemeChanged: widget.onThemeChanged,
          isDarkTheme: widget.isDarkTheme,
        );
      case 0:
      default:
        return const PlayerInputScreen();
    }
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index < _tabCount) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screenFor(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Меню',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'История',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Лидеры',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Статистика',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}

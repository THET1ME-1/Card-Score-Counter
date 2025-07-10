import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievements_screen.dart';
import 'game_history_screen.dart';
import 'leaderboard_screen.dart';
import 'player_input_screen.dart';
import 'services/achievement_service.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'widgets/achievement_notification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize shared preferences
  await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AchievementService()),
      ],
      child: const CardGameScoreTracker(),
    ),
  );
}

// Achievement notification widget has been moved to widgets/achievement_notification.dart

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Score Master',
      debugShowCheckedModeBanner: false,
      theme: _isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      home: MainScreen(
        isDarkTheme: _isDarkTheme,
        onThemeChanged: (isDark) {
          setState(() {
            _isDarkTheme = isDark;
          });
        },
      ),
      builder: (context, child) {
        return AchievementNotifier(
          child: child!,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkTheme;
  final Function(List<String>)? startNewGame;
  final Function(Map<String, dynamic>)? continueGame;
  final Function()? endCurrentGame;
  final List<String>? currentPlayers;
  final Map<String, dynamic>? currentGameData;
  final bool hasSavedGames;

  const MainScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkTheme,
    this.startNewGame,
    this.continueGame,
    this.endCurrentGame,
    this.currentPlayers,
    this.currentGameData,
    this.hasSavedGames = false,
  });

  @override
  // ignore: library_private_types_in_public_api
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = [
      // Home screen (index 0)
      PlayerInputScreen(
        startNewGame: widget.startNewGame ??
            (_) {
              // Default implementation if not provided
              debugPrint('Starting new game');
            },
        endCurrentGame: widget.endCurrentGame ??
            () {
              // Default implementation if not provided
              debugPrint('Ending current game');
            },
      ),
      // Game History (index 1)
      GameHistoryScreen(
        continueGame: widget.continueGame ??
            (_) {
              // Default implementation if not provided
              debugPrint('Continuing game');
            },
      ),
      // Leaderboard (index 2)
      const LeaderboardScreen(),
      // Settings (index 3)
      SettingsScreen(
        onThemeChanged: widget.onThemeChanged,
        isDarkTheme: widget.isDarkTheme,
      ),
      // Stats (index 4)
      const StatsScreen(),
    ];
  }

  // Get the app bar title based on the selected tab
  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Главное меню';
      case 1:
        return 'История игр';
      case 2:
        return 'Таблица лидеров';
      case 3:
        return 'Настройки';
      case 4:
        return 'Статистика';
      default:
        return 'Card Game Score Tracker';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedItemColor =
        widget.isDarkTheme ? const Color(0xFFC2B8ED) : Colors.purple;
    final unselectedItemColor = widget.isDarkTheme
        ? const Color(0xFFC2B8ED).withAlpha((0.6 * 255).round())
        : Colors.grey;
    final hasUnseenAchievements = context.select<AchievementService, bool>(
      (service) => service.unlockedAchievements.any((a) =>
          a.unlockedAt?.isAfter(
            DateTime.now().subtract(const Duration(minutes: 5)),
          ) ??
          false),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(_selectedIndex)),
        actions: [
          if (_selectedIndex ==
              0) // Show achievements button only on home screen
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_events_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AchievementsScreen(),
                      ),
                    );
                  },
                ),
                if (hasUnseenAchievements)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'История',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Лидеры',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Настройки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Статистика',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: selectedItemColor,
        unselectedItemColor: unselectedItemColor,
        backgroundColor: widget.isDarkTheme ? Colors.black : Colors.white,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

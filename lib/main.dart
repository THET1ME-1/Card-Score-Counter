import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_input_screen.dart';
import 'game_history_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';

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
  List<String>? _currentPlayers;
  Map<String, dynamic>? _currentGameData;
  bool _hasSavedGames = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadSavedGames();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? true;
    });
  }

  Future<void> _loadSavedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final gameHistory = prefs.getStringList('gameHistory') ?? [];
    setState(() {
      _hasSavedGames = gameHistory.isNotEmpty;
    });
  }

  void _startNewGame(List<String> players) {
    setState(() {
      _currentPlayers = players;
      _currentGameData = null;
    });
  }

  void _continueGame(Map<String, dynamic> gameData) {
    setState(() {
      _currentPlayers = List<String>.from(gameData['players']);
      _currentGameData = gameData;
    });
  }

  void _endCurrentGame() {
    setState(() {
      _currentPlayers = null;
      _currentGameData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Game Score Tracker',
      theme: _isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      home: MainScreen(
        onThemeChanged: (isDarkTheme) {
          setState(() {
            _isDarkTheme = isDarkTheme;
          });
        },
        startNewGame: _startNewGame,
        continueGame: _continueGame,
        endCurrentGame: _endCurrentGame,
        currentPlayers: _currentPlayers,
        currentGameData: _currentGameData,
        hasSavedGames: _hasSavedGames,
        isDarkTheme: _isDarkTheme,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(List<String>) startNewGame;
  final Function(Map<String, dynamic>) continueGame;
  final Function() endCurrentGame;
  final List<String>? currentPlayers;
  final Map<String, dynamic>? currentGameData;
  final bool hasSavedGames;
  final bool isDarkTheme;

  const MainScreen({
    super.key,
    required this.onThemeChanged,
    required this.startNewGame,
    required this.continueGame,
    required this.endCurrentGame,
    required this.currentPlayers,
    required this.currentGameData,
    required this.hasSavedGames,
    required this.isDarkTheme,
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
      PlayerInputScreen(
        startNewGame: widget.startNewGame,
        endCurrentGame: widget.endCurrentGame,
      ),
      GameHistoryScreen(
        continueGame: widget.continueGame,
      ),
      const LeaderboardScreen(),
      SettingsScreen(
        onThemeChanged: widget.onThemeChanged,
        isDarkTheme: widget.isDarkTheme,
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedItemColor = widget.isDarkTheme ? const Color(0xFFC2B8ED) : Colors.purple;
    final unselectedItemColor = widget.isDarkTheme ? const Color(0xFFC2B8ED).withOpacity(0.6) : Colors.grey;

    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главное меню',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'История игр',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Таблица лидеров',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: selectedItemColor,
        unselectedItemColor: unselectedItemColor,
        backgroundColor: widget.isDarkTheme ? Colors.black : Colors.white,
        onTap: _onItemTapped,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game_history_screen.dart';
import 'enhanced_statistics_screen.dart';
import 'l10n/locale_controller.dart';
import 'l10n/strings.dart';
import 'player_input_screen.dart';
import 'settings_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  await LocaleController.instance.load();
  runApp(const CardGameScoreTracker());
}

class CardGameScoreTracker extends StatelessWidget {
  const CardGameScoreTracker({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final locale = LocaleController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([theme, locale]),
      builder: (context, _) => MaterialApp(
        title: 'ScoreMaster',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(theme.seedColor),
        darkTheme: AppTheme.dark(theme.seedColor),
        themeMode: theme.themeMode,
        locale: locale.locale,
        supportedLocales: LocaleController.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const int _tabCount = 4;
  int _selectedIndex = 0;

  /// Экран строится при каждом показе, поэтому история и статистика всегда
  /// отражают актуальные данные после сыгранной партии. Лидеры теперь живут
  /// внутри экрана статистики (вкладка «Лидеры»), отдельной вкладки нет.
  Widget _screenFor(int index) {
    switch (index) {
      case 1:
        return const GameHistoryScreen();
      case 2:
        return const EnhancedStatisticsScreen();
      case 3:
        return const SettingsScreen();
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
        // Только иконки, без подписей — компактно и по-M3. Контур → заливка
        // при выборе (rounded-вариант M3-иконок).
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined, size: 28),
            selectedIcon: const Icon(Icons.groups_rounded, size: 28),
            label: tr('nav_menu'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded, size: 28),
            selectedIcon: const Icon(Icons.history_rounded, size: 28),
            label: tr('nav_history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.leaderboard_outlined, size: 28),
            selectedIcon: const Icon(Icons.leaderboard_rounded, size: 28),
            label: tr('nav_stats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined, size: 28),
            selectedIcon: const Icon(Icons.settings_rounded, size: 28),
            label: tr('nav_settings'),
          ),
        ],
      ),
    );
  }
}

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game_history_screen.dart';
import 'enhanced_statistics_screen.dart';
import 'l10n/locale_controller.dart';
import 'player_input_screen.dart';
import 'services/sound_service.dart';
import 'services/update_service.dart';
import 'settings_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'utils/app_version.dart';
import 'widgets/update_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Приложение рассчитано на портрет: в ландшафте карточки табло становятся
  // слишком высокими и цифры не помещаются. Жёстко лочим вертикаль.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await ThemeController.instance.load();
  await LocaleController.instance.load();
  await SoundService.instance.load();
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
      builder: (context, _) => DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          // Material You: если включено и система отдала схему (Android 12+) —
          // берём акцент обоев как seed и генерируем полную M3-схему
          // (ColorScheme.fromSeed). Так корректно строятся тональные
          // поверхности (surfaceContainer*), иначе фоны блоков «исчезали»,
          // потому что surface и surfaceContainerHigh динамической схемы
          // совпадали.
          final useDyn = theme.useDynamicColor &&
              lightDynamic != null &&
              darkDynamic != null;
          final dynSeed = lightDynamic?.primary ?? theme.seedColor;
          final lightTheme = useDyn
              ? AppTheme.light(dynSeed)
              : AppTheme.light(theme.seedColor);
          final darkTheme = useDyn
              ? AppTheme.dark(dynSeed)
              : AppTheme.dark(theme.seedColor);
          return MaterialApp(
            title: 'ScoreMaster',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: theme.themeMode,
            locale: locale.locale,
            supportedLocales: LocaleController.supported,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainScreen(),
          );
        },
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

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  /// Тихая проверка обновления на GitHub при запуске. Если есть версия новее —
  /// сразу показываем нижнее меню с предложением обновиться.
  Future<void> _checkForUpdate() async {
    final current = await appVersionName();
    if (current.isEmpty) return;
    final info = await UpdateService.checkForUpdate(current);
    if (!mounted || info == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateSheet.show(context, info, current);
    });
  }

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
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screenFor(_selectedIndex),
      bottomNavigationBar: _CircleNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          _NavItem(Icons.groups_outlined, Icons.groups_rounded),
          _NavItem(Icons.history_outlined, Icons.history_rounded),
          _NavItem(Icons.leaderboard_outlined, Icons.leaderboard_rounded),
          _NavItem(Icons.settings_outlined, Icons.settings_rounded),
        ],
      ),
    );
  }
}

/// Описание пункта нижней навигации: иконка-контур и иконка-заливка.
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  const _NavItem(this.icon, this.selectedIcon);
}

/// Нижняя навигация в духе M3, но индикатор активного пункта — РОВНЫЙ КРУГ
/// (а не вытянутая «таблетка»). Круг плавно «переезжает» и пульсирует при
/// смене вкладки, иконка контур→заливка.
class _CircleNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;

  const _CircleNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _CircleNavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleNavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _CircleNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double d = 54;
    return InkResponse(
      onTap: onTap,
      radius: 40,
      containedInkWell: true,
      customBorder: const CircleBorder(),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: d,
          height: d,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              selected ? item.selectedIcon : item.icon,
              key: ValueKey(selected),
              size: 28,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

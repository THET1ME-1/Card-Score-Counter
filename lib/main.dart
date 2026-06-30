import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quick_actions/quick_actions.dart';

import 'game_history_screen.dart';
import 'enhanced_statistics_screen.dart';
import 'l10n/locale_controller.dart';
import 'l10n/strings.dart';
import 'lock_screen.dart';
import 'player_input_screen.dart';
import 'score_board_screen.dart';
import 'services/game_repository.dart';
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
          final seed = useDyn ? dynSeed : theme.seedColor;
          final lightTheme = AppTheme.light(seed);
          final darkTheme = AppTheme.dark(seed, amoled: theme.amoled);
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
            home: const _LockGate(),
          );
        },
      ),
    );
  }
}

/// Гейт замка приложения: пока не разблокировано (если замок включён) —
/// показывает [LockScreen], иначе главный экран. Перезапирается при возврате
/// из фона.
class _LockGate extends StatefulWidget {
  const _LockGate();

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> with WidgetsBindingObserver {
  bool _ready = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check() async {
    final enabled = await GameRepository.instance.lockEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _ready = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // При возврате из фона снова запираем (если замок включён и не заперт).
    if (state == AppLifecycleState.resumed && !_locked) {
      GameRepository.instance.lockEnabled().then((enabled) {
        if (mounted && enabled) setState(() => _locked = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (_locked) {
      return LockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return const MainScreen();
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

  static const QuickActions _quickActions = QuickActions();

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
    _setupQuickActions();
  }

  /// Ярлыки при удержании иконки приложения (Android/iOS): «Новая игра»,
  /// «Продолжить», «Статистика». Срабатывают через колбэк initialize.
  void _setupQuickActions() {
    _quickActions.initialize(_handleShortcut);
    _quickActions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(type: 'new_game', localizedTitle: tr('sc_new_game')),
      ShortcutItem(type: 'continue', localizedTitle: tr('resume')),
      ShortcutItem(type: 'stats', localizedTitle: tr('nav_stats')),
    ]);
  }

  Future<void> _handleShortcut(String type) async {
    switch (type) {
      case 'stats':
        if (mounted) setState(() => _selectedIndex = 2);
      case 'continue':
        if (mounted) setState(() => _selectedIndex = 0);
        await _resumeLatest();
      case 'new_game':
      default:
        if (mounted) setState(() => _selectedIndex = 0);
    }
  }

  /// Открывает табло последней незавершённой партии (для ярлыка «Продолжить»).
  Future<void> _resumeLatest() async {
    final repo = GameRepository.instance;
    final games = await repo.loadGames();
    final types = await repo.gameTypes();
    final candidates = games.where((g) => !g.isFinished && !g.isEmpty).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (candidates.isEmpty || !mounted) return;
    final game = candidates.first;
    final profile = await repo.gameById(types[game.gameId]);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoreBoardScreen(
          players: game.players,
          initialData: game.toJson(),
          profile: profile,
        ),
      ),
    );
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

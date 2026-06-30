import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_detail_screen.dart';
import 'l10n/strings.dart';
import 'models/game_profile.dart';
import 'models/game_session.dart';
import 'score_board_screen.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/reveal.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _GameHistoryScreenState createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  final GameRepository _repo = GameRepository.instance;

  static const Color _gold = Color(0xFFFFD700);

  List<GameSession> _games = [];
  Map<String, String> _names = {};
  Map<String, String> _types = {}; // gameId сессии → id профиля игры
  Map<String, GameProfile> _gamesById = {};
  String? _filter; // фильтр по профилю игры (null — все)
  String _query = ''; // поисковый запрос (название/игра/игроки)
  final TextEditingController _searchController = TextEditingController();
  bool _isDescending = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoChanged);
    _load();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final descending = await _repo.isDescending();
    final games = await _repo.loadGames();
    final names = await _repo.gameNames();
    final types = await _repo.gameTypes();
    final all = await _repo.allGames();
    games.sort((a, b) =>
        descending ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    if (!mounted) return;
    setState(() {
      _isDescending = descending;
      _games = games;
      _names = names;
      _types = types;
      _gamesById = {for (final g in all) g.id: g};
      _loading = false;
    });
  }

  /// Партии с учётом фильтра по игре и поискового запроса.
  List<GameSession> get _visible {
    final q = _query.trim().toLowerCase();
    return _games.where((g) {
      if (_filter != null && _types[g.gameId] != _filter) return false;
      if (q.isEmpty) return true;
      // Ищем по названию партии, названию игры и именам игроков.
      final name = (_names[g.gameId] ?? '').toLowerCase();
      final typeName =
          (_gamesById[_types[g.gameId]]?.displayName ?? '').toLowerCase();
      final players = g.players.join(' ').toLowerCase();
      return name.contains(q) ||
          typeName.contains(q) ||
          players.contains(q);
    }).toList();
  }

  GameProfile? _gameOf(GameSession g) => _gamesById[_types[g.gameId]];

  Future<void> _toggleSort() async {
    HapticFeedback.selectionClick();
    await _repo.setDescending(!_isDescending);
    await _load();
  }

  void _resume(GameSession game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScoreBoardScreen(
          players: game.players,
          initialData: game.toJson(),
          // Без профиля табло считало бы любую продолженную партию по правилу
          // «вылет до 101». Восстанавливаем тип игры по тегу истории.
          profile: _gameOf(game),
        ),
      ),
    ).then((_) => _load());
  }

  /// Открывает экран полной аналитики по партии (время, графики, доли).
  void _openDetail(GameSession game, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(
          game: game,
          profile: _gameOf(game),
          title: title,
        ),
      ),
    ).then((_) => _load());
  }

  String _defaultTitle(int index) => trf('game_n',
      {'n': _isDescending ? _games.length - index : index + 1});

  String _titleFor(GameSession game, int index) =>
      _names[game.gameId] ?? _defaultTitle(index);

  String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year}, '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _rename(GameSession game, String currentTitle) async {
    final controller = TextEditingController(text: _names[game.gameId] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('game_name_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: tr('name_label'),
            hintText: currentTitle,
            prefixIcon: const Icon(Icons.edit_rounded),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    if (result != null) await _repo.setGameName(game.gameId, result);
  }

  Future<void> _confirmDelete(GameSession game) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_game_q')),
        content: Text(tr('delete_game_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true) await _repo.deleteGame(game.gameId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible;

    // Игры, реально встречающиеся в истории — для фильтра.
    final usedGameIds = <String>{
      for (final g in _games)
        if (_types[g.gameId] != null) _types[g.gameId]!,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('history_title')),
        actions: [
          if (usedGameIds.length > 1)
            PopupMenuButton<String?>(
              tooltip: tr('all_games'),
              icon: Icon(
                _filter == null
                    ? Icons.filter_list_rounded
                    : Icons.filter_list_alt,
                color: _filter == null ? null : scheme.primary,
              ),
              onSelected: (v) => setState(() => _filter = v),
              itemBuilder: (context) => [
                PopupMenuItem<String?>(value: null, child: Text(tr('all_games'))),
                for (final id in usedGameIds)
                  PopupMenuItem<String?>(
                    value: id,
                    child: Text(_gamesById[id]?.displayName ?? id),
                  ),
              ],
            ),
          if (_games.isNotEmpty)
            IconButton(
              tooltip: _isDescending ? tr('sort_newest') : tr('sort_oldest'),
              icon: Icon(_isDescending
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded),
              onPressed: _toggleSort,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _games.isEmpty
              ? _emptyState(scheme)
              : Column(
                  children: [
                    _searchBar(scheme),
                    Expanded(
                      child: visible.isEmpty
                          ? _noResults(scheme)
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: visible.length,
                              itemBuilder: (context, index) => Reveal(
                                delay: Duration(milliseconds: 30 * index),
                                child:
                                    _gameCard(visible[index], index, scheme),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  /// M3-строка поиска по истории (название/игра/игроки).
  Widget _searchBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SearchBar(
        controller: _searchController,
        hintText: tr('search_games'),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor:
            WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        leading: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
        trailing: _query.isEmpty
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ],
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _noResults(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            tr('nothing_found'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 15,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameCard(GameSession game, int index, ColorScheme scheme) {
    final finished = game.isFinished;
    final title = _titleFor(game, index);
    final roundCount = game.scores.isEmpty ? 0 : game.scores.first.length;
    final profile = _gameOf(game);
    final typeId = _types[game.gameId];

    // Container transform (M3): карточка «морфится» в экран аналитики.
    final card = OpenContainer(
        closedColor: scheme.surfaceContainerHigh,
        openColor: scheme.surface,
        closedElevation: 0,
        openElevation: 0,
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 380),
        onClosed: (_) => _load(),
        openBuilder: (context, _) => GameDetailScreen(
          game: game,
          profile: _gameOf(game),
          title: title,
        ),
        closedBuilder: (context, openContainer) => InkWell(
          onTap: openContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Статус: золотой кубок (завершена) или часы (в процессе).
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: finished
                            ? _gold.withValues(alpha: 0.18)
                            : scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        finished
                            ? Icons.emoji_events_rounded
                            : Icons.hourglass_top_rounded,
                        size: 24,
                        color: finished ? _gold : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (profile != null && typeId != null) ...[
                                _gameTypePill(profile.displayName, typeId, scheme),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  [
                                    _formatDate(game.date),
                                    finished
                                        ? tr('finished_short')
                                        : trf('rounds_n', {'n': roundCount}),
                                  ].join('  ·  '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.bodyFont,
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _menu(game, title),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in game.players)
                        _playerChip(
                          p,
                          isWinner: game.winner == p,
                          isOut: game.eliminatedPlayers.contains(p),
                          scheme: scheme,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
    // Свайп: вправо — переименовать, влево — удалить (с «Отменить»).
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('hist_${game.gameId}'),
        background: _swipeBg(
          start: true,
          bg: scheme.primaryContainer,
          fg: scheme.onPrimaryContainer,
          icon: Icons.drive_file_rename_outline_rounded,
          label: tr('rename'),
        ),
        secondaryBackground: _swipeBg(
          start: false,
          bg: scheme.errorContainer,
          fg: scheme.onErrorContainer,
          icon: Icons.delete_rounded,
          label: tr('delete'),
        ),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            await _rename(game, title);
            return false; // переименование на месте — карточку не убираем
          }
          return true; // свайп влево — удалить
        },
        onDismissed: (_) => _swipeDelete(game),
        child: card,
      ),
    );
  }

  /// Фон под карточкой при свайпе (иконка + подпись с нужной стороны).
  Widget _swipeBg({
    required bool start,
    required Color bg,
    required Color fg,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
      padding: const EdgeInsets.symmetric(horizontal: 26),
      alignment: start ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  /// Удаление свайпом с возможностью отмены: карточку убираем сразу, а из
  /// репозитория удаляем только если «Отменить» не нажали (по закрытию снэкбара).
  void _swipeDelete(GameSession game) {
    setState(() => _games.removeWhere((g) => g.gameId == game.gameId));
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(tr('game_deleted')),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: tr('undo'), onPressed: () {}),
      ),
    );
    controller.closed.then((reason) {
      if (reason == SnackBarClosedReason.action) {
        _load(); // отменили — партия ещё на диске, возвращаем
      } else {
        _repo.deleteGame(game.gameId); // подтверждаем удаление
      }
    });
  }

  Widget _menu(GameSession game, String title) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
      tooltip: tr('settings_title'),
      onPressed: () => _showGameMenu(game, title),
    );
  }

  /// Контекстное меню партии — нижняя M3-панель в едином стиле приложения
  /// (как «Порядок хода», «Кто победил?» и т.п.): шапка с названием, крупные
  /// плитки действий.
  Future<void> _showGameMenu(GameSession game, String title) async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    game.isFinished
                        ? Icons.emoji_events_rounded
                        : Icons.hourglass_top_rounded,
                    color: game.isFinished ? _gold : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sheetItem(scheme, 'stats', Icons.insights_rounded,
                  tr('game_analytics'), scheme.onSurface),
              const SizedBox(height: 8),
              _sheetItem(scheme, 'open', Icons.play_arrow_rounded,
                  game.isFinished ? tr('open') : tr('resume'),
                  scheme.onSurface),
              const SizedBox(height: 8),
              _sheetItem(scheme, 'rename', Icons.edit_rounded, tr('rename'),
                  scheme.onSurface),
              const SizedBox(height: 8),
              _sheetItem(scheme, 'delete', Icons.delete_rounded, tr('delete'),
                  scheme.error,
                  danger: true),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'stats':
        _openDetail(game, title);
      case 'open':
        // Волейбол не открывается в обычном табло — показываем аналитику.
        if (_gameOf(game)?.winRule == WinRule.volleyball) {
          _openDetail(game, title);
        } else {
          _resume(game);
        }
      case 'rename':
        _rename(game, title);
      case 'delete':
        _confirmDelete(game);
    }
  }

  Widget _sheetItem(ColorScheme scheme, String value, IconData icon,
      String label, Color color,
      {bool danger = false}) {
    return Material(
      color: danger
          ? scheme.errorContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerChip(String name,
      {required bool isWinner,
      required bool isOut,
      required ColorScheme scheme}) {
    final Color bg;
    final Color fg;
    if (isWinner) {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    } else if (isOut) {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant;
    } else {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWinner)
            Icon(Icons.emoji_events_rounded, size: 15, color: _gold)
          else if (isOut)
            Icon(Icons.do_not_disturb_on_outlined,
                size: 15, color: fg.withValues(alpha: 0.7)),
          if (isWinner || isOut) const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  /// Яркая кликабельная «таблетка» типа игры — фильтрует историю по этому
  /// режиму. Повторный тап по активной — снимает фильтр.
  Widget _gameTypePill(String name, String typeId, ColorScheme scheme) {
    final active = _filter == typeId;
    return Material(
      color: active ? scheme.primary : scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _filter = active ? null : typeId);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_rounded,
                  size: 14,
                  color:
                      active ? scheme.onPrimary : scheme.onPrimaryContainer),
              const SizedBox(width: 5),
              Text(
                name,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? scheme.onPrimary : scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 80, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            tr('history_empty'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              tr('history_empty_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

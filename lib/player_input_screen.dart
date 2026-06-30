import 'dart:io';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_picker_sheet.dart';
import 'l10n/strings.dart';
import 'models/game_profile.dart';
import 'models/game_session.dart';
import 'player_profile.dart';
import 'models/player_company.dart';
import 'score_board_screen.dart';
import 'volleyball_screen.dart';
import 'widgets/table_tools_sheet.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/player_shapes.dart';
import 'widgets/pressable.dart';
import 'widgets/reveal.dart';
import 'utils/image_picker_util.dart';
import 'widgets/color_picker_sheet.dart';

class PlayerInputScreen extends StatefulWidget {
  const PlayerInputScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PlayerInputScreenState createState() => _PlayerInputScreenState();
}

class _PlayerInputScreenState extends State<PlayerInputScreen> {
  final GameRepository _repo = GameRepository.instance;

  List<PlayerProfile> profiles = [];
  List<int> selectedProfiles = [];
  GameProfile? _game;

  // Режим папок (компании). _openCompanyId: null — список папок,
  // 'all' — все игроки, иначе id открытой компании.
  bool _foldersMode = false;
  List<PlayerCompany> _companies = [];
  String? _openCompanyId;

  /// Последняя незавершённая партия (для подсказки «Продолжить»), и её игра.
  GameSession? _resumeGame;
  GameProfile? _resumeProfile;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoChanged);
    _loadProfiles();
    _loadGame();
    _loadResume();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    final mode = await _repo.playerFoldersEnabled();
    final companies = await _repo.loadCompanies();
    if (!mounted) return;
    setState(() {
      _foldersMode = mode;
      _companies = companies;
      if (!mode) _openCompanyId = null;
    });
  }

  /// Имена участников открытой компании (или null — показываем всех).
  List<String>? get _openMembers {
    if (!_foldersMode || _openCompanyId == null || _openCompanyId == 'all') {
      return null;
    }
    final idx = _companies.indexWhere((c) => c.id == _openCompanyId);
    return idx == -1 ? const <String>[] : _companies[idx].members;
  }

  /// Индексы профилей, видимых в текущем виде (все или участники компании).
  List<int> _visibleProfileIndices() {
    final members = _openMembers;
    if (members == null) {
      return [for (var i = 0; i < profiles.length; i++) i];
    }
    return [
      for (var i = 0; i < profiles.length; i++)
        if (members.contains(profiles[i].name)) i,
    ];
  }

  /// Ищет самую свежую незавершённую (и не пустую, и не скрытую) партию.
  Future<void> _loadResume() async {
    final games = await _repo.loadGames();
    final dismissed = await _repo.dismissedResume();
    final types = await _repo.gameTypes();
    final candidates = games
        .where((g) =>
            !g.isFinished && !g.isEmpty && !dismissed.contains(g.gameId))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = candidates.isEmpty ? null : candidates.first;
    final profile =
        latest == null ? null : await _repo.gameById(types[latest.gameId]);
    if (!mounted) return;
    setState(() {
      _resumeGame = latest;
      _resumeProfile = profile;
    });
  }

  /// Продолжить незавершённую партию (восстанавливаем тип игры по тегу).
  void _resume() {
    final game = _resumeGame;
    if (game == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoreBoardScreen(
          players: game.players,
          initialData: game.toJson(),
          profile: _resumeProfile,
        ),
      ),
    ).then((_) => _loadResume());
  }

  /// Скрыть подсказку «Продолжить» для этой партии (партия остаётся в истории).
  Future<void> _dismissResume() async {
    final game = _resumeGame;
    if (game == null) return;
    HapticFeedback.selectionClick();
    await _repo.dismissResume(game.gameId);
    await _loadResume();
  }

  Future<void> _loadGame() async {
    final g = await _repo.gameById(await _repo.selectedGameId());
    if (!mounted) return;
    setState(() => _game = g);
  }

  Future<void> _changeGame() async {
    final id = await showGamePicker(context);
    if (id == null) return;
    // Волейбол — отдельное табло без выбора игроков: открываем сразу.
    final picked = await _repo.gameById(id);
    if (picked?.winRule == WinRule.volleyball) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VolleyballScreen()),
      );
      return;
    }
    await _repo.setSelectedGameId(id);
    await _loadGame();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final loaded = await _repo.loadProfiles();
    if (!mounted) return;
    setState(() => profiles = loaded);
  }

  /// Список игроков изменился где-то ещё (или после своей правки/удаления) —
  /// перезагружаемся, сохраняя выбор по именам (а не по индексам, которые
  /// «съезжают» при удалении).
  Future<void> _onRepoChanged() async {
    final selectedNames = [
      for (final i in selectedProfiles)
        if (i >= 0 && i < profiles.length) profiles[i].name,
    ];
    final loaded = await _repo.loadProfiles();
    if (!mounted) return;
    final remapped = <int>[];
    for (final name in selectedNames) {
      final idx = loaded.indexWhere((p) => p.name == name);
      if (idx != -1 && !remapped.contains(idx)) remapped.add(idx);
    }
    setState(() {
      profiles = loaded;
      selectedProfiles
        ..clear()
        ..addAll(remapped);
    });
    _loadResume();
    _loadCompanies();
  }

  Future<void> _saveProfiles() async {
    await _repo.saveProfiles(profiles);
  }

  Future<void> _addProfile(String name, Color color,
      {String? imagePath}) async {
    setState(() {
      profiles.add(PlayerProfile(
        name: name,
        color: color,
        imagePath: imagePath,
      ));
    });
    await _saveProfiles();
  }

  Future<void> _editProfile(int index, String name, Color color,
      {String? imagePath}) async {
    final oldName = profiles[index].name;
    final oldImagePath = profiles[index].imagePath;
    final wins = profiles[index].wins;

    // Старое фото удаляем, если его сменили или убрали (imagePath — финальное
    // значение: null = аватарка удалена).
    if (oldImagePath != null && oldImagePath != imagePath) {
      await ImagePickerUtil.deleteImage(oldImagePath);
    }

    setState(() {
      profiles[index] = PlayerProfile(
        name: name,
        color: color,
        wins: wins,
        imagePath: imagePath,
      );
    });

    await _saveProfiles();

    // Имя — это ключ игрока в истории, поэтому переименовываем во всех играх.
    if (name != oldName) {
      await _repo.renamePlayerInGames(oldName, name);
      await _repo.renamePlayerInCompanies(oldName, name);
    }
  }

  void _toggleProfileSelection(int index) {
    setState(() {
      if (selectedProfiles.contains(index)) {
        selectedProfiles.remove(index);
      } else {
        selectedProfiles.add(index);
      }
    });
  }

  void _clearSelection() {
    setState(() => selectedProfiles.clear());
  }

  void _startGame() {
    HapticFeedback.mediumImpact();
    final selectedPlayerNames =
        selectedProfiles.map((index) => profiles[index].name).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScoreBoardScreen(
          players: selectedPlayerNames,
          profile: _game,
        ),
      ),
    );
  }

  /// Рулетка «кто первый?» + монетка. Берём отмеченных игроков, а если их
  /// меньше двух — всех созданных.
  void _openTableTools() {
    final source = selectedProfiles.length >= 2
        ? [for (final i in selectedProfiles) profiles[i]]
        : profiles;
    final list = [for (final p in source) WheelPlayer(p.name, p.color)];
    if (list.length < 2) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(tr('select_min_two'))));
      return;
    }
    TableToolsSheet.show(context, list);
  }

  void _deleteProfile(int index) {
    final name = index >= 0 && index < profiles.length ? profiles[index].name : null;
    setState(() {
      profiles.removeAt(index);
      selectedProfiles.remove(index);
    });
    _saveProfiles();
    if (name != null) _repo.removePlayerFromCompanies(name);
  }

  /// Нижняя панель «Порядок хода»: перетаскивание, перемешать, случайный первый.
  Future<void> _showOrderSheet() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            void apply(VoidCallback fn) {
              HapticFeedback.selectionClick();
              setState(fn);
              setSheet(() {});
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    tr('turn_order'),
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _orderActionTile(
                    scheme,
                    icon: Icons.shuffle_rounded,
                    title: tr('shuffle'),
                    subtitle: tr('shuffle_sub'),
                    onTap: () => apply(() => selectedProfiles.shuffle()),
                  ),
                  const SizedBox(height: 8),
                  _orderActionTile(
                    scheme,
                    icon: Icons.casino_rounded,
                    title: tr('random_first'),
                    subtitle: tr('random_first_sub'),
                    onTap: () => apply(() {
                      if (selectedProfiles.length < 2) return;
                      final i = Random().nextInt(selectedProfiles.length);
                      final first = selectedProfiles.removeAt(i);
                      selectedProfiles.insert(0, first);
                    }),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ReorderableListView(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      onReorder: (oldI, newI) => apply(() {
                        if (newI > oldI) newI--;
                        final it = selectedProfiles.removeAt(oldI);
                        selectedProfiles.insert(newI, it);
                      }),
                      children: [
                        for (var i = 0; i < selectedProfiles.length; i++)
                          _orderTile(scheme, i, selectedProfiles[i]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(tr('done')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Крупная кнопка-плитка действия в панели порядка хода: иконка + название +
  /// поясняющая подпись (чтобы было видно разницу «Перемешать» / «Случайный
  /// первый»).
  Widget _orderActionTile(
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12.5,
                        height: 1.2,
                        color: scheme.onSecondaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderTile(ColorScheme scheme, int position, int profileIndex) {
    final p = profiles[profileIndex];
    return Padding(
      key: ValueKey(profileIndex),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primary,
              child: Text(
                '${position + 1}',
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: scheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            p.getAvatar(radius: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
            ),
            ReorderableDragStartListener(
              index: position,
              child: Icon(Icons.drag_handle_rounded, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  /// Нижняя панель создания/редактирования игрока (выезжает снизу, M3).
  /// [index] == null — создание нового, иначе правка существующего.
  Future<void> _showPlayerEditor({int? index}) async {
    final existing = index != null ? profiles[index] : null;
    final result = await showModalBottomSheet<_PlayerEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PlayerEditorSheet(existing: existing),
    );
    if (result == null) return;
    if (result.deleted) {
      if (index != null) _deleteProfile(index);
      return;
    }
    if (index != null) {
      await _editProfile(index, result.name, result.color,
          imagePath: result.imagePath);
    } else {
      await _addProfile(result.name, result.color,
          imagePath: result.imagePath);
      // Если создаём игрока внутри компании — сразу добавляем его туда.
      final cid = _openCompanyId;
      if (_foldersMode && cid != null && cid != 'all') {
        final idx = _companies.indexWhere((c) => c.id == cid);
        if (idx != -1) {
          final members = [..._companies[idx].members, result.name];
          await _repo.setCompanyMembers(cid, members);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // На верхнем уровне папок (список компаний) нет выбора игроков —
    // нижнюю панель «Начать игру» прячем.
    final foldersList = _foldersMode && _openCompanyId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('who_plays')),
        actions: [
          IconButton(
            tooltip: _foldersMode ? tr('mode_folders') : tr('mode_single'),
            icon: Icon(
                _foldersMode ? Icons.folder_rounded : Icons.person_rounded),
            onPressed: _toggleFoldersMode,
          ),
          IconButton(
            tooltip: tr('who_first'),
            icon: const Icon(Icons.casino_rounded),
            onPressed: _openTableTools,
          ),
        ],
      ),
      body: Column(
        children: [
          _gameSelector(scheme),
          if (_resumeGame != null) _resumeBanner(scheme),
          if (_foldersMode && _openCompanyId != null) _folderHeader(scheme),
          Expanded(child: _grid(scheme)),
          if (!foldersList) _bottomBar(scheme),
        ],
      ),
    );
  }

  void _toggleFoldersMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _foldersMode = !_foldersMode;
      _openCompanyId = null;
    });
    _repo.setPlayerFoldersEnabled(_foldersMode);
  }

  /// Сетка: либо папки (верхний уровень), либо игроки (все/участники компании).
  Widget _grid(ColorScheme scheme) {
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
    );
    const pad = EdgeInsets.fromLTRB(16, 12, 16, 8);

    if (_foldersMode && _openCompanyId == null) {
      final items = <Widget>[
        _allFolderCard(scheme),
        for (final c in _companies) _companyFolderCard(c, scheme),
        _createCompanyCard(scheme),
      ];
      return GridView.builder(
        padding: pad,
        gridDelegate: delegate,
        itemCount: items.length,
        itemBuilder: (_, i) =>
            Reveal(delay: Duration(milliseconds: 45 * i), child: items[i]),
      );
    }

    final indices = _visibleProfileIndices();
    final inCompany =
        _foldersMode && _openCompanyId != null && _openCompanyId != 'all';
    return GridView.builder(
      padding: pad,
      gridDelegate: delegate,
      itemCount: indices.length + 1,
      itemBuilder: (context, i) {
        final tile = i == indices.length
            ? (inCompany
                ? _addCard(scheme,
                    onTap: () => _manageMembers(_openCompanyId!),
                    label: tr('manage_members'),
                    icon: Icons.group_add_rounded)
                : _addCard(scheme,
                    onTap: () => _showPlayerEditor(),
                    label: tr('create_player')))
            : _playerCard(indices[i], scheme);
        return Reveal(delay: Duration(milliseconds: 45 * i), child: tile);
      },
    );
  }

  /// Верхняя плашка — выбор игры во всю ширину. Тап открывает список игр.
  Widget _gameSelector(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _gamePickerCard(scheme),
    );
  }

  Widget _gamePickerCard(ColorScheme scheme) {
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _changeGame,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.style_rounded, color: scheme.onSecondaryContainer),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr('games'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12,
                        color:
                            scheme.onSecondaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                    AutoSizeText(
                      _game?.displayName ?? tr('game_g101'),
                      maxLines: 1,
                      minFontSize: 11,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.unfold_more_rounded,
                  color: scheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  /// Полноширинная кнопка «Продолжить» незавершённую партию — отдельной плашкой
  /// под выбором игры. Справа крестик «скрыть подсказку для этой партии».
  Widget _resumeBanner(ColorScheme scheme) {
    final game = _resumeGame!;
    final roundCount = game.scores.isEmpty ? 0 : game.scores.first.length;
    final sub = [
      if (_resumeProfile != null) _resumeProfile!.displayName,
      trf('rounds_n', {'n': roundCount}),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _resume,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_rounded,
                          size: 28, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr('resume'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.displayFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.bodyFont,
                                fontSize: 12.5,
                                color: scheme.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Крестик «скрыть подсказку для этой партии».
            InkWell(
              onTap: _dismissResume,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
                child: Icon(Icons.close_rounded,
                    size: 20,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка игрока — той же геометрии, что плитки на табло (радиус 28,
  /// отступ 16). Выбранный «выходит вперёд»: бирюзовая рамка и подсветка,
  /// яркий аватар, бейдж с номером хода. Невыбранный приглушён и нейтрален.
  Widget _playerCard(int index, ColorScheme scheme) {
    final profile = profiles[index];
    final isSelected = selectedProfiles.contains(index);
    final order = isSelected ? selectedProfiles.indexOf(index) + 1 : 0;

    final Color bg =
        isSelected ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final Color fg =
        isSelected ? scheme.onPrimaryContainer : scheme.onSurface;

    return GestureDetector(
      onTap: () => _toggleProfileSelection(index),
      onLongPress: () => _showPlayerEditor(index: index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: isSelected
              ? Border.all(color: scheme.primary, width: 2)
              : null,
        ),
        child: Stack(
          // Без обрезки — иначе лучи звезды-бейджа срезаются у края карточки.
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Цвет игрока живёт в фигуре аватара — у каждого своя форма.
                  // Невыбранный приглушён.
                  ShapedAvatar(
                    name: profile.name,
                    color: profile.color,
                    imagePath: profile.imagePath,
                    size: 88,
                    shape: avatarShape(index),
                    muted: !isSelected,
                  ),
                  const SizedBox(height: 12),
                  AutoSizeName(
                    profile.name,
                    color: fg,
                    bold: isSelected,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.wins > 0
                        ? trf('wins_n', {'n': profile.wins})
                        : tr('novice'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12,
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Один бейдж — и «выбран», и порядок хода (1, 2, 3…). Звёздочка.
            if (isSelected)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: scheme.primary,
                    shape: _badgeStar,
                  ),
                  child: Text(
                    '$order',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Пятая карточка-«плюс» с пунктиром — вписана в ту же сетку.
  Widget _addCard(
    ColorScheme scheme, {
    VoidCallback? onTap,
    String? label,
    IconData icon = Icons.add,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => _showPlayerEditor(),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: scheme.outline),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: _addShape,
                  ),
                  child: Icon(icon,
                      size: 36, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Text(
                  label ?? tr('create_player'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------- Папки (компании) -----------------------------

  /// Шапка внутри открытой папки: «назад», название, кнопка управления.
  Widget _folderHeader(ColorScheme scheme) {
    final isAll = _openCompanyId == 'all';
    final idx = _companies.indexWhere((c) => c.id == _openCompanyId);
    final name = isAll
        ? tr('all_players')
        : (idx == -1 ? '' : _companies[idx].name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: tr('companies'),
            onPressed: () => setState(() => _openCompanyId = null),
          ),
          Icon(isAll ? Icons.groups_rounded : Icons.folder_rounded,
              color: scheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (!isAll && idx != -1)
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded),
              tooltip: tr('settings_title'),
              onPressed: () => _companyMenu(_companies[idx]),
            ),
        ],
      ),
    );
  }

  Widget _folderTile(
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: fg),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12,
                  color: fg.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _allFolderCard(ColorScheme scheme) => _folderTile(
        scheme,
        icon: Icons.groups_rounded,
        title: tr('all_players'),
        subtitle: trf('members_n', {'n': profiles.length}),
        bg: scheme.secondaryContainer,
        fg: scheme.onSecondaryContainer,
        onTap: () => setState(() => _openCompanyId = 'all'),
      );

  Widget _companyFolderCard(PlayerCompany c, ColorScheme scheme) {
    // Считаем только реально существующих игроков.
    final names = profiles.map((p) => p.name).toSet();
    final count = c.members.where(names.contains).length;
    return _folderTile(
      scheme,
      icon: Icons.folder_rounded,
      title: c.name,
      subtitle: trf('members_n', {'n': count}),
      bg: scheme.surfaceContainerHigh,
      fg: scheme.onSurface,
      onTap: () => setState(() => _openCompanyId = c.id),
      onLongPress: () => _companyMenu(c),
    );
  }

  Widget _createCompanyCard(ColorScheme scheme) => _addCard(
        scheme,
        onTap: _createCompany,
        label: tr('create_company'),
        icon: Icons.create_new_folder_rounded,
      );

  Future<void> _createCompany() async {
    final name = await _askName(tr('create_company'), '');
    if (name == null || name.trim().isEmpty) return;
    final company = await _repo.addCompany(name.trim());
    await _loadCompanies();
    if (!mounted) return;
    setState(() => _openCompanyId = company.id);
  }

  /// Меню компании: переименовать / удалить.
  Future<void> _companyMenu(PlayerCompany c) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: Text(tr('rename')),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: scheme.error),
              title: Text(tr('delete'),
                  style: TextStyle(color: scheme.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((action) async {
      if (action == 'rename') {
        final name = await _askName(tr('rename'), c.name);
        if (name != null && name.trim().isNotEmpty) {
          await _repo.renameCompany(c.id, name.trim());
          await _loadCompanies();
        }
      } else if (action == 'delete') {
        await _repo.deleteCompany(c.id);
        if (mounted && _openCompanyId == c.id) {
          setState(() => _openCompanyId = null);
        }
        await _loadCompanies();
      }
    });
  }

  /// Управление составом компании: чекбоксы по всем игрокам + создать нового.
  Future<void> _manageMembers(String companyId) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final idx = _companies.indexWhere((c) => c.id == companyId);
          if (idx == -1) return const SizedBox.shrink();
          final members = _companies[idx].members.toSet();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.92,
            builder: (ctx, scrollCtrl) => Column(
              children: [
                const SizedBox(height: 12),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('manage_members'),
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await _showPlayerEditor();
                          if (mounted) setSheet(() {});
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(tr('create_player')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: profiles.isEmpty
                      ? Center(
                          child: Text(
                            tr('create_players_first'),
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: profiles.length,
                          itemBuilder: (_, i) {
                            final p = profiles[i];
                            final checked = members.contains(p.name);
                            return CheckboxListTile(
                              value: checked,
                              title: Text(p.name),
                              secondary: CircleAvatar(
                                backgroundColor: p.color,
                                radius: 14,
                              ),
                              onChanged: (v) async {
                                if (v == true) {
                                  members.add(p.name);
                                } else {
                                  members.remove(p.name);
                                }
                                await _repo.setCompanyMembers(
                                    companyId, members.toList());
                                await _loadCompanies();
                                setSheet(() {});
                              },
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(tr('done')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  /// Простой ввод названия (диалог) — для компаний.
  Future<String?> _askName(String title, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr('name_label')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(tr('save'))),
        ],
      ),
    );
  }

  Widget _bottomBar(ColorScheme scheme) {
    final count = selectedProfiles.length;
    final ready = count >= 2;
    final noPlayers = profiles.isEmpty;

    final String counterText;
    if (noPlayers) {
      counterText = tr('tap_plus_create');
    } else if (count == 0) {
      counterText = tr('mark_who_plays');
    } else {
      counterText = trf('players_selected', {'n': count});
    }

    final String buttonLabel = ready
        ? tr('start_game')
        : noPlayers
            ? tr('create_players_first')
            : tr('select_min_two');

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    counterText,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (count >= 2)
                  TextButton.icon(
                    onPressed: _showOrderSheet,
                    icon: const Icon(Icons.swap_vert_rounded, size: 18),
                    label: Text(tr('turn_order')),
                  ),
                if (count > 0)
                  TextButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(tr('reset')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            PressableScale(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: ready ? _startGame : null,
                  icon: Icon(
                      ready ? Icons.play_arrow_rounded : Icons.group_add),
                  label: Text(buttonLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Бейдж выбора / порядка хода — звёздочка. Лучи поглубже, чтобы читалась
/// именно звезда, но цифра внутри остаётся целой.
const ShapeBorder _badgeStar = StarBorder(
  points: 6,
  innerRadiusRatio: 0.62,
  pointRounding: 0.45,
  valleyRounding: 0.2,
);

/// «Печенька» для кнопки добавления игрока.
const ShapeBorder _addShape = StarBorder(
  points: 8,
  innerRadiusRatio: 0.86,
  pointRounding: 0.5,
  valleyRounding: 0.5,
);

/// Имя игрока в карточке — авто-ужимается под ширину, фирменный шрифт.
class AutoSizeName extends StatelessWidget {
  final String name;
  final Color color;
  final bool bold;

  const AutoSizeName(this.name,
      {super.key, required this.color, required this.bold});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.displayFont,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
        fontSize: 16,
        color: color,
      ),
    );
  }
}

/// Пунктирная рамка с тем же радиусом (28), что у карточек, — для «Создать игрока».
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  static const double _radius = 28;
  static const double _dash = 7;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = dist + _dash;
        canvas.drawPath(
          metric.extractPath(dist, next.clamp(0, metric.length)),
          paint,
        );
        dist = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}

/// Результат создания/правки игрока из нижней панели.
class _PlayerEditResult {
  final String name;
  final Color color;
  final String? imagePath;
  final bool deleted;
  const _PlayerEditResult({
    required this.name,
    required this.color,
    this.imagePath,
    this.deleted = false,
  });
}

/// Палитра цветов игрока — крупные кружки для быстрого выбора.
const List<Color> _playerPalette = [
  Color(0xFFEF5350),
  Color(0xFFEC407A),
  Color(0xFFAB47BC),
  Color(0xFF7E57C2),
  Color(0xFF5C6BC0),
  Color(0xFF42A5F5),
  Color(0xFF29B6F6),
  Color(0xFF26C6DA),
  Color(0xFF26A69A),
  Color(0xFF66BB6A),
  Color(0xFF9CCC65),
  Color(0xFFFFCA28),
  Color(0xFFFFA726),
  Color(0xFF8D6E63),
];

/// Нижняя панель создания/редактирования игрока в духе M3.
class _PlayerEditorSheet extends StatefulWidget {
  final PlayerProfile? existing;
  const _PlayerEditorSheet({this.existing});

  @override
  State<_PlayerEditorSheet> createState() => _PlayerEditorSheetState();
}

class _PlayerEditorSheetState extends State<_PlayerEditorSheet> {
  late final TextEditingController _nameController;
  late Color _color;
  String? _imagePath;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.color ?? _playerPalette.first;
    _imagePath = widget.existing?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.selectionClick();
    final path = await ImagePickerUtil.pickImage();
    if (path != null && mounted) setState(() => _imagePath = path);
  }

  void _removeImage() {
    HapticFeedback.selectionClick();
    setState(() => _imagePath = null);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _PlayerEditResult(name: name, color: _color, imagePath: _imagePath),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete_player_q')),
        content: Text(trf('delete_player_body', {'name': widget.existing!.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(
        context,
        _PlayerEditResult(name: '', color: _color, deleted: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = _imagePath != null && File(_imagePath!).existsSync();
    final name = _nameController.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEdit ? tr('edit_player') : tr('new_player'),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: _color,
                      backgroundImage:
                          hasPhoto ? FileImage(File(_imagePath!)) : null,
                      child: hasPhoto
                          ? null
                          : Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: AppTheme.displayFont,
                                fontWeight: FontWeight.w800,
                                fontSize: 40,
                              ),
                            ),
                    ),
                  ),
                  // Камера — добавить/сменить фото.
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: _avatarBadge(
                      icon: Icons.photo_camera_rounded,
                      bg: scheme.primary,
                      fg: scheme.onPrimary,
                      onTap: _pickImage,
                      scheme: scheme,
                    ),
                  ),
                  // Крестик — убрать фото (контекстно, только если оно есть).
                  if (hasPhoto)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: _avatarBadge(
                        icon: Icons.close_rounded,
                        bg: scheme.errorContainer,
                        fg: scheme.onErrorContainer,
                        onTap: _removeImage,
                        scheme: scheme,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: tr('name_label'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    tr('color_label'),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    colorToHex(_color),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Свой (не из палитры) цвет — отдельным выбранным кружком.
                  if (!_playerPalette
                      .any((c) => c.toARGB32() == _color.toARGB32()))
                    _swatch(_color, scheme),
                  for (final c in _playerPalette) _swatch(c, scheme),
                  _customColorButton(scheme),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: name.isEmpty ? null : _save,
                      child: Text(tr('save')),
                    ),
                  ),
                ],
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _confirmDelete,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.errorContainer,
                      foregroundColor: scheme.onErrorContainer,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(tr('delete_player')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarBadge({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    required ColorScheme scheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surfaceContainer, width: 3),
        ),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }

  /// Открыть настоящий колор-пикер (колесо + HEX + RGB) для своего цвета.
  Future<void> _pickCustomColor() async {
    HapticFeedback.selectionClick();
    final c = await showColorPickerSheet(
      context,
      initial: _color,
      title: tr('custom_color'),
    );
    if (c != null && mounted) setState(() => _color = c);
  }

  /// «Радужная» кнопка — открывает колор-пикер для произвольного цвета.
  Widget _customColorButton(ColorScheme scheme) {
    return GestureDetector(
      onTap: _pickCustomColor,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Color(0xFFFF1744),
              Color(0xFFFFEA00),
              Color(0xFF00E676),
              Color(0xFF00B0FF),
              Color(0xFFD500F9),
              Color(0xFFFF1744),
            ],
          ),
        ),
        child: const Icon(Icons.colorize_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _swatch(Color c, ColorScheme scheme) {
    final selected = c.toARGB32() == _color.toARGB32();
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _color = c);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: scheme.onSurface, width: 3)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

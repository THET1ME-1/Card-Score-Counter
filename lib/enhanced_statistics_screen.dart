import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/player_shapes.dart';

/// Период для графика динамики.
enum _Period { day, month, year }

/// Экран статистики — полностью на плоском Material 3 Expressive в духе
/// главного меню и табло: крупные цифры, скруглённые карточки без теней,
/// фирменный шрифт, кольцо винрейта и плоские столбики (без сторонних
/// чарт-библиотек). Данные считаются из истории партий по сохранённому
/// победителю [winnerName] — работает для всех правил, не только «на вылет».
class EnhancedStatisticsScreen extends StatefulWidget {
  const EnhancedStatisticsScreen({super.key});

  @override
  State<EnhancedStatisticsScreen> createState() =>
      _EnhancedStatisticsScreenState();
}

/// Сводная статистика одного игрока.
class _PlayerStat {
  final String name;
  final Color color;
  final String? imagePath;

  /// Индекс формы аватара (как в меню) — чтобы фигура игрока совпадала везде.
  int shapeIndex = 0;

  int wins = 0;
  int played = 0; // завершённые партии, в которых участвовал
  int streak = 0; // текущая серия побед (с последних партий)
  DateTime? lastPlayed;

  /// Ключ периода → [победы, игры].
  final Map<String, List<int>> byDay = {};
  final Map<String, List<int>> byMonth = {};
  final Map<String, List<int>> byYear = {};

  /// Результаты завершённых партий в хронологическом порядке (для серии).
  final List<bool> _chrono = [];

  _PlayerStat(this.name, this.color, this.imagePath);

  int get losses => (played - wins).clamp(0, 1 << 30);
  double get winRate => played > 0 ? wins / played * 100 : 0;

  Map<String, List<int>> mapFor(_Period p) => switch (p) {
        _Period.day => byDay,
        _Period.month => byMonth,
        _Period.year => byYear,
      };

  void _bump(Map<String, List<int>> m, String key, bool won) {
    final cell = m.putIfAbsent(key, () => [0, 0]);
    cell[1]++;
    if (won) cell[0]++;
  }

  void record(DateTime date, bool won) {
    played++;
    if (won) wins++;
    _chrono.add(won);
    if (lastPlayed == null || date.isAfter(lastPlayed!)) lastPlayed = date;

    String two(int v) => v.toString().padLeft(2, '0');
    final d = '${date.year}-${two(date.month)}-${two(date.day)}';
    final mo = '${date.year}-${two(date.month)}';
    final y = '${date.year}';
    _bump(byDay, d, won);
    _bump(byMonth, mo, won);
    _bump(byYear, y, won);
  }

  /// Считаем серию побед с конца хронологии.
  void finalizeStreak() {
    var s = 0;
    for (var i = _chrono.length - 1; i >= 0; i--) {
      if (_chrono[i]) {
        s++;
      } else {
        break;
      }
    }
    streak = s;
  }
}

class _EnhancedStatisticsScreenState extends State<EnhancedStatisticsScreen> {
  static const Color _gold = Color(0xFFFFD700);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  final GameRepository _repo = GameRepository.instance;

  List<_PlayerStat> _stats = [];
  String? _selectedName;
  int _section = 0; // 0 игрок, 1 лидеры, 2 аналитика
  _Period _period = _Period.month;
  bool _loading = true;

  int _totalFinished = 0;
  int _totalRounds = 0;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoChanged);
    _load();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final games = await _repo.loadGames();
    final profiles = await _repo.loadProfiles();

    final byName = <String, _PlayerStat>{};
    _PlayerStat statFor(String name) => byName.putIfAbsent(name, () {
          Color color = Colors.grey;
          String? image;
          for (final pr in profiles) {
            if (pr.name == name) {
              color = pr.color;
              image = pr.imagePath;
              break;
            }
          }
          final s = _PlayerStat(name, color, image);
          // Запасная форма для игроков без профиля — по имени (стабильно).
          s.shapeIndex = name.runes.fold(0, (a, b) => a + b);
          return s;
        });

    // Игроки без партий тоже видны (создали профиль — но ещё не играли).
    // Форму берём по позиции в профилях — ровно как в главном меню.
    for (var i = 0; i < profiles.length; i++) {
      statFor(profiles[i].name).shapeIndex = i;
    }

    var finished = 0;
    var rounds = 0;
    // По возрастанию даты — для корректного подсчёта серии.
    final sorted = [...games]..sort((a, b) => a.date.compareTo(b.date));
    for (final g in sorted) {
      rounds += g.rounds;
      if (!g.isFinished) continue;
      finished++;
      final winner = g.winner;
      for (final player in g.players) {
        statFor(player).record(g.date, player == winner);
      }
    }
    for (final s in byName.values) {
      s.finalizeStreak();
    }

    final list = byName.values.toList()
      ..sort((a, b) {
        final byWins = b.wins.compareTo(a.wins);
        if (byWins != 0) return byWins;
        return b.winRate.compareTo(a.winRate);
      });

    if (!mounted) return;
    setState(() {
      _stats = list;
      _totalFinished = finished;
      _totalRounds = rounds;
      _selectedName = list.any((s) => s.name == _selectedName)
          ? _selectedName
          : (list.isNotEmpty ? list.first.name : null);
      _loading = false;
    });
  }

  _PlayerStat? get _selected {
    if (_selectedName == null) return null;
    for (final s in _stats) {
      if (s.name == _selectedName) return s;
    }
    return _stats.isNotEmpty ? _stats.first : null;
  }

  // ------------------------------- BUILD -------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('statistics_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats.isEmpty
              ? _emptyState(scheme)
              : Column(
                  children: [
                    _segments(scheme),
                    Expanded(
                      child: IndexedStack(
                        index: _section,
                        children: [
                          _playerSection(scheme),
                          _leadersSection(scheme),
                          _analyticsSection(scheme),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ----------------------- Сегментированный переключатель -----------------------

  Widget _segments(ColorScheme scheme) {
    final labels = [tr('tab_player'), tr('tab_leaders'), tr('tab_analytics')];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _section = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _section == i
                          ? scheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _section == i
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------- ИГРОК -------------------------------

  Widget _playerSection(ColorScheme scheme) {
    final stat = _selected;
    if (stat == null) return _emptyState(scheme);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _playerPicker(scheme),
        const SizedBox(height: 16),
        _heroCard(stat, scheme),
        const SizedBox(height: 12),
        _statTiles(stat, scheme),
        const SizedBox(height: 16),
        _dynamicsCard(stat, scheme),
      ],
    );
  }

  Widget _playerPicker(ColorScheme scheme) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final s = _stats[i];
          final sel = s.name == _selected?.name;
          return GestureDetector(
            onTap: () => setState(() => _selectedName = s.name),
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? scheme.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: _avatar(s, sel ? 28 : 25),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Геро-карточка: крупное кольцо винрейта + имя и «X из Y».
  Widget _heroCard(_PlayerStat stat, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 184,
            height: 184,
            child: CustomPaint(
              painter: _RingPainter(
                progress: stat.winRate / 100,
                track: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${stat.winRate.round()}',
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 56,
                        height: 1.0,
                        letterSpacing: -2,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      '% ${tr('wins_label')}',
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _avatar(stat, 16),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  stat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            trf('win_of_total', {'w': stat.wins, 'g': stat.played}),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTiles(_PlayerStat stat, ColorScheme scheme) {
    final tiles = [
      _TileData(tr('stat_wins'), '${stat.wins}', Icons.emoji_events_rounded,
          _gold),
      _TileData(tr('stat_games'), '${stat.played}', Icons.casino_rounded,
          scheme.primary),
      _TileData(tr('stat_losses'), '${stat.losses}',
          Icons.heart_broken_rounded, scheme.error),
      _TileData(tr('stat_best_streak'), '${stat.streak}',
          Icons.local_fire_department_rounded, const Color(0xFFFF7043)),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [for (final t in tiles) _statTile(t, scheme)],
    );
  }

  Widget _statTile(_TileData t, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(t.icon, size: 20, color: t.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              t.value,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 38,
                height: 1.0,
                letterSpacing: -1,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Карточка «Динамика побед» с переключателем периода и плоскими столбиками.
  Widget _dynamicsCard(_PlayerStat stat, ColorScheme scheme) {
    final map = stat.mapFor(_period);
    final keys = map.keys.toList()..sort();
    final visible = keys.length > 8 ? keys.sublist(keys.length - 8) : keys;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('wins_dynamics'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _periodSelector(scheme),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            _inlineEmpty(tr('not_enough_data'), scheme)
          else
            _BarRow(
              keys: visible,
              cells: [for (final k in visible) map[k]!],
              labeler: _periodLabel,
              barColor: scheme.primary,
              trackColor: scheme.surfaceContainerHighest,
              textColor: scheme.onSurface,
              subColor: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }

  Widget _periodSelector(ColorScheme scheme) {
    final items = [
      (_Period.day, tr('period_day')),
      (_Period.month, tr('period_month')),
      (_Period.year, tr('period_year')),
    ];
    return Row(
      children: [
        for (final it in items) ...[
          _periodChip(it.$2, it.$1 == _period, () {
            setState(() => _period = it.$1);
          }, scheme),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _periodChip(
      String label, bool sel, VoidCallback onTap, ColorScheme scheme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: sel ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _periodLabel(String key) {
    final p = key.split('-');
    return switch (_period) {
      _Period.day => p.length == 3 ? '${p[2]}.${p[1]}' : key,
      _Period.month => p.length >= 2 ? '${p[1]}.${p[0].substring(2)}' : key,
      _Period.year => key,
    };
  }

  // ------------------------------- ЛИДЕРЫ -------------------------------

  Widget _leadersSection(ColorScheme scheme) {
    final ranked = _stats.where((s) => s.played > 0).toList();
    if (ranked.isEmpty) return _inlineCenter(tr('no_stats_data'), scheme);

    final podium = ranked.where((s) => s.wins > 0).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (podium.length >= 2) ...[
          _podium(podium, scheme),
          const SizedBox(height: 20),
        ],
        for (var i = 0; i < ranked.length; i++)
          _leaderRow(i, ranked[i], scheme),
      ],
    );
  }

  Widget _podium(List<_PlayerStat> top, ColorScheme scheme) {
    // Порядок на пьедестале: 2 — 1 — 3.
    final order = <int>[if (top.length > 1) 1, 0, if (top.length > 2) 2];
    final heights = {0: 104.0, 1: 78.0, 2: 62.0};
    final medals = {0: _gold, 1: _silver, 2: _bronze};

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final rank in order)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _avatar(top[rank], rank == 0 ? 30 : 24),
                      ),
                      Positioned(
                        top: -6,
                        child: Icon(Icons.emoji_events_rounded,
                            size: rank == 0 ? 26 : 20, color: medals[rank]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    top[rank].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: heights[rank],
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: medals[rank]!.withValues(alpha: 0.22),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${top[rank].wins}',
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w800,
                        fontSize: rank == 0 ? 30 : 24,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _leaderRow(int index, _PlayerStat s, ColorScheme scheme) {
    final medalColors = [_gold, _silver, _bronze];
    final isMedal = index < 3 && s.wins > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() {
            _selectedName = s.name;
            _section = 0;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: isMedal
                      ? Icon(Icons.emoji_events_rounded,
                          color: medalColors[index], size: 24)
                      : Text(
                          '${index + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: scheme.outline,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                _avatar(s, 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        '${s.played} ${tr('games_label')} · '
                        '${s.winRate.round()}% ${tr('stat_winrate').toLowerCase()}',
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${s.wins}',
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      tr('wins_label'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------- АНАЛИТИКА -------------------------------

  Widget _analyticsSection(ColorScheme scheme) {
    final topName = _stats.isNotEmpty && _stats.first.wins > 0
        ? _stats.first.name
        : '—';
    final tiles = [
      _TileData(tr('total_games'), '$_totalFinished', Icons.casino_rounded,
          scheme.primary),
      _TileData(tr('players_count'), '${_stats.length}', Icons.groups_rounded,
          scheme.tertiary),
      _TileData(tr('total_rounds'), '$_totalRounds', Icons.repeat_rounded,
          scheme.secondary),
      _TileData(tr('top_player'), topName, Icons.workspace_premium_rounded,
          _gold),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [for (final t in tiles) _statTile(t, scheme)],
        ),
        const SizedBox(height: 16),
        _distributionCard(scheme),
      ],
    );
  }

  Widget _distributionCard(ColorScheme scheme) {
    final withWins = _stats.where((s) => s.wins > 0).toList();
    final total = withWins.fold<int>(0, (a, b) => a + b.wins);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('wins_distribution'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            _inlineEmpty(tr('not_enough_data'), scheme)
          else ...[
            // Плоская горизонтальная полоса долей.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 22,
                child: Row(
                  children: [
                    for (final s in withWins)
                      Expanded(
                        flex: s.wins,
                        child: Container(
                          color: s.color,
                          margin: const EdgeInsets.only(right: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final s in withWins)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${s.wins} · ${(s.wins / total * 100).round()}%',
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ------------------------------- ОБЩЕЕ -------------------------------

  /// Аватар игрока той же выразительной формой, что и в главном меню.
  Widget _avatar(_PlayerStat s, double radius) {
    return ShapedAvatar(
      name: s.name,
      color: s.color,
      imagePath: s.imagePath,
      size: radius * 2,
      shape: avatarShape(s.shapeIndex),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: 80, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              tr('statistics_title'),
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('no_stats_data'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineCenter(String text, ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );

  Widget _inlineEmpty(String text, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
}

class _TileData {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  const _TileData(this.label, this.value, this.icon, this.accent);
}

/// Плоский ряд столбиков: высота = игры (фон), заливка = победы.
class _BarRow extends StatelessWidget {
  final List<String> keys;
  final List<List<int>> cells; // [победы, игры]
  final String Function(String) labeler;
  final Color barColor;
  final Color trackColor;
  final Color textColor;
  final Color subColor;

  const _BarRow({
    required this.keys,
    required this.cells,
    required this.labeler,
    required this.barColor,
    required this.trackColor,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxGames =
        cells.fold<int>(1, (m, c) => math.max(m, c[1])).toDouble();
    const maxBar = 120.0;

    return SizedBox(
      height: maxBar + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < keys.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${cells[i][0]}',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Столбик: трек (игры) + заливка (победы).
                  SizedBox(
                    height: maxBar,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 18,
                        height: math.max(6, maxBar * (cells[i][1] / maxGames)),
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: cells[i][1] == 0
                              ? 0
                              : (cells[i][0] / cells[i][1]).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labeler(keys[i]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 10,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Плоское кольцо прогресса (винрейт). Толстый штрих со скруглёнными концами.
class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color track;
  final Color color;

  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final p = progress.clamp(0.0, 1.0);
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * p,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

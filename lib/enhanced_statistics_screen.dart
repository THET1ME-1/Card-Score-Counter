import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/strings.dart';
import 'models/game_session.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';
import 'utils/format.dart';
import 'widgets/player_shapes.dart';
import 'widgets/reveal.dart';

/// Период для графика динамики.
enum _Period { day, month, year }

/// Режим календаря игр.
enum _CalMode { week, month, year }

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

  /// Максимальная серия побед подряд за всю историю (а не только текущая).
  int get bestStreak {
    var best = 0, cur = 0;
    for (final w in _chrono) {
      if (w) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 0;
      }
    }
    return best;
  }

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

  /// Завершённые партии (с победителем) — для очных встреч.
  List<GameSession> _finishedGames = [];

  // Тепловая карта «когда играем»: 7 дней недели × 6 интервалов по 4 часа.
  List<List<int>> _whenMatrix =
      List.generate(7, (_) => List<int>.filled(6, 0));
  int _whenMax = 0;

  // Календарь игр: игры по дням + режим/якорь периода.
  final Map<DateTime, List<GameSession>> _byDay = {};
  final Map<String, String> _typeOfGame = {}; // gameId → profileId
  final Map<String, String> _typeName = {}; // profileId → имя игры
  _CalMode _calMode = _CalMode.month;
  DateTime _calAnchor = DateTime(2026, 1, 1);
  bool _userTouchedCal = false;

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
    final types = await _repo.gameTypes();
    final allGameProfiles = await _repo.allGames();

    // Календарь: раскладываем игры по дням и запоминаем имена их типов.
    _byDay.clear();
    _typeOfGame
      ..clear()
      ..addAll(types);
    _typeName.clear();
    for (final gp in allGameProfiles) {
      _typeName[gp.id] = gp.displayName;
    }
    final when = List.generate(7, (_) => List<int>.filled(6, 0));
    var whenMax = 0;
    for (final g in games) {
      final key = DateTime(g.date.year, g.date.month, g.date.day);
      _byDay.putIfAbsent(key, () => []).add(g);
      // День недели (Пн=0) × интервал 4 часа.
      final row = g.date.weekday - 1;
      final col = (g.date.hour ~/ 4).clamp(0, 5);
      when[row][col]++;
      if (when[row][col] > whenMax) whenMax = when[row][col];
    }
    _whenMatrix = when;
    _whenMax = whenMax;
    // Пока пользователь сам не листал календарь — держим его на дне последней
    // сыгранной партии (иначе можно открыть пустой месяц без игр).
    if (!_userTouchedCal) {
      if (_byDay.isNotEmpty) {
        _calAnchor = _byDay.keys.reduce((a, b) => a.isAfter(b) ? a : b);
      } else {
        final now = DateTime.now();
        _calAnchor = DateTime(now.year, now.month, now.day);
      }
    }

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
    final finishedGames = <GameSession>[];
    // По возрастанию даты — для корректного подсчёта серии.
    final sorted = [...games]..sort((a, b) => a.date.compareTo(b.date));
    for (final g in sorted) {
      // Волейбол — командный счёт, в статистику игроков не идёт (иначе
      // «Хозяева»/«Гости» попадут в лидеров).
      if (types[g.gameId] == 'volleyball') continue;
      rounds += g.rounds;
      if (!g.isFinished) continue;
      finished++;
      finishedGames.add(g);
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
      _finishedGames = finishedGames;
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
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _section = i);
                  },
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
        if (_favoriteGameOf(stat.name) != null) ...[
          const SizedBox(height: 16),
          _favoriteGameCard(stat, scheme),
        ],
        if (_recentForm(stat.name).isNotEmpty) ...[
          const SizedBox(height: 16),
          _recentFormCard(stat, scheme),
        ],
        const SizedBox(height: 16),
        _dynamicsCard(stat, scheme),
        const SizedBox(height: 16),
        Reveal(child: _headToHeadCard(stat, scheme)),
      ],
    );
  }

  /// Любимая игра выбранного игрока: тип, где он сыграл больше всего партий.
  ({String type, String name, int played, int wins})? _favoriteGameOf(
      String player) {
    final played = <String, int>{};
    final wins = <String, int>{};
    for (final g in _finishedGames) {
      if (!g.players.contains(player)) continue;
      final t = _typeOfGame[g.gameId] ?? '';
      played[t] = (played[t] ?? 0) + 1;
      if (g.winner == player) wins[t] = (wins[t] ?? 0) + 1;
    }
    if (played.isEmpty) return null;
    var bestType = '';
    var bestN = 0;
    played.forEach((t, n) {
      if (n > bestN) {
        bestN = n;
        bestType = t;
      }
    });
    return (
      type: bestType,
      name: _typeName[bestType] ?? tr('scoreboard'),
      played: bestN,
      wins: wins[bestType] ?? 0,
    );
  }

  /// Форма игрока: исходы последних завершённых партий (самые свежие — первыми).
  List<bool> _recentForm(String player, {int max = 14}) {
    final list = _finishedGames.where((g) => g.players.contains(player)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return [for (final g in list.take(max)) g.winner == player];
  }

  Widget _favoriteGameCard(_PlayerStat stat, ColorScheme scheme) {
    final fav = _favoriteGameOf(stat.name)!;
    final pct = fav.played > 0 ? (fav.wins / fav.played * 100).round() : 0;
    return _panel(scheme, tr('favorite_game'), [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.style_rounded,
                  size: 22, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fav.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    '${trf('win_of_total', {'w': '${fav.wins}', 'g': '${fav.played}'})} · $pct%',
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _recentFormCard(_PlayerStat stat, ColorScheme scheme) {
    final form = _recentForm(stat.name);
    return _panel(scheme, tr('recent_form'), [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final won in form)
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: won ? stat.color : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  won ? Icons.check_rounded : Icons.close_rounded,
                  size: 16,
                  color: won
                      ? (ThemeData.estimateBrightnessForColor(stat.color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black)
                      : scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  // --------------------------- ОЧНЫЕ ВСТРЕЧИ ---------------------------

  /// Очная статистика выбранного игрока против каждого соперника: в скольких
  /// совместных завершённых партиях победил каждый из двоих.
  List<_H2H> _headToHead(String me) {
    final out = <_H2H>[];
    for (final s in _stats) {
      if (s.name == me) continue;
      var my = 0, their = 0, shared = 0;
      for (final g in _finishedGames) {
        if (g.players.contains(me) && g.players.contains(s.name)) {
          shared++;
          if (g.winner == me) {
            my++;
          } else if (g.winner == s.name) {
            their++;
          }
        }
      }
      if (shared > 0) out.add(_H2H(s, my, their, shared));
    }
    out.sort((a, b) {
      final byShared = b.shared.compareTo(a.shared);
      if (byShared != 0) return byShared;
      return (b.my - b.their).compareTo(a.my - a.their);
    });
    return out;
  }

  Widget _headToHeadCard(_PlayerStat me, ColorScheme scheme) {
    final rivals = _headToHead(me.name);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_kabaddi_rounded,
                  size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                tr('head_to_head'),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (rivals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                tr('h2h_no_rivals'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final h in rivals) _h2hRow(me.name, h, scheme),
        ],
      ),
    );
  }

  Widget _h2hRow(String me, _H2H h, ColorScheme scheme) {
    final oppColor = h.opp.color;
    final total = h.my + h.their;
    final leadColor = h.my > h.their
        ? scheme.primary
        : h.their > h.my
            ? oppColor
            : scheme.onSurfaceVariant;
    final caption = total == 0
        ? trf('h2h_shared', {'n': h.shared})
        : h.my == h.their
            ? '${trf('h2h_shared', {'n': h.shared})}  ·  ${tr('h2h_even')}'
            : '${trf('h2h_shared', {'n': h.shared})}  ·  '
                '${trf('h2h_lead_me', {'name': h.my > h.their ? me : h.opp.name})}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            _showPairGames(me, h.opp);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                _avatar(h.opp, 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              h.opp.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.bodyFont,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${h.my} : ${h.their}',
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: leadColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _h2hBar(h.my, h.their, oppColor, scheme),
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Полоса перевеса: слева доля побед игрока (primary), остальное — соперник.
  Widget _h2hBar(int my, int their, Color oppColor, ColorScheme scheme) {
    final total = my + their;
    final frac = total == 0 ? 0.0 : my / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: total == 0
                    ? scheme.surfaceContainerHighest
                    : oppColor,
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: frac),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, w, __) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: w,
                child: Container(color: scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Нижняя панель: все совместные завершённые партии пары (кто победил).
  Future<void> _showPairGames(String me, _PlayerStat opp) async {
    final scheme = Theme.of(context).colorScheme;
    final games = _finishedGames
        .where((g) => g.players.contains(me) && g.players.contains(opp.name))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    var my = 0, their = 0;
    for (final g in games) {
      if (g.winner == me) my++;
      if (g.winner == opp.name) their++;
    }
    final meStat = _statByName(me);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainer,
      isScrollControlled: true,
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
              const SizedBox(height: 16),
              // Крупное «X : Y» с аватарами обоих.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (meStat != null) _avatar(meStat, 22),
                  const SizedBox(width: 12),
                  Text(
                    '$my : $their',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _avatar(opp, 22),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$me  ·  ${opp.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: games.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _pairGameRow(games[i], me, opp, scheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pairGameRow(
      GameSession g, String me, _PlayerStat opp, ColorScheme scheme) {
    final typeId = _typeOfGame[g.gameId];
    final typeName = typeId != null ? _typeName[typeId] : null;
    final winner = g.winner;
    final iWon = winner == me;
    final oppWon = winner == opp.name;
    final accent = iWon
        ? scheme.primary
        : oppWon
            ? opp.color
            : scheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeName ?? tr('scoreboard'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateTimeShort(g.date),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                winner == null
                    ? Icons.remove_rounded
                    : Icons.emoji_events_rounded,
                size: 16,
                color: iWon
                    ? scheme.primary
                    : oppWon
                        ? opp.color
                        : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                winner ?? tr('h2h_other_won'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: iWon
                      ? scheme.primary
                      : oppWon
                          ? opp.color
                          : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _PlayerStat? _statByName(String name) {
    for (final s in _stats) {
      if (s.name == name) return s;
    }
    return null;
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
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedName = s.name);
            },
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
          Semantics(
            container: true,
            excludeSemantics: true,
            label: trf('a11y_winrate', {'v': stat.winRate.round()}),
            child: SizedBox(
            width: 184,
            height: 184,
            child: TweenAnimationBuilder<double>(
              // Анимируем по ключу игрока, чтобы при смене игрока кольцо
              // перерисовывалось заново.
              key: ValueKey(stat.name),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => CustomPaint(
                painter: _RingPainter(
                  progress: stat.winRate / 100 * t,
                  track: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(stat.winRate * t).round()}',
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
            HapticFeedback.selectionClick();
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
          Reveal(child: _podium(podium, scheme)),
          const SizedBox(height: 20),
        ],
        for (var i = 0; i < ranked.length; i++)
          Reveal(
            delay: Duration(milliseconds: 40 * i),
            child: _leaderRow(i, ranked[i], scheme),
          ),
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
        _calendarCard(scheme),
        const SizedBox(height: 16),
        _gamesPerDayCard(scheme),
        const SizedBox(height: 16),
        _distributionCard(scheme),
        if (_recordRows().isNotEmpty) ...[
          const SizedBox(height: 16),
          _recordsCard(scheme),
        ],
        if (_kingRows().isNotEmpty) ...[
          const SizedBox(height: 16),
          _kingsCard(scheme),
        ],
        if (_matrixPlayers().length >= 2) ...[
          const SizedBox(height: 16),
          _matrixCard(scheme),
        ],
        if (_whenMax > 0) ...[
          const SizedBox(height: 16),
          _whenCard(scheme),
        ],
      ],
    );
  }

  /// Тепловая карта «когда играем»: дни недели × интервалы суток.
  Widget _whenCard(ColorScheme scheme) {
    final days = weekdayShort;
    const cols = ['0', '4', '8', '12', '16', '20'];
    return _panel(scheme, tr('play_heatmap'), [
      const SizedBox(height: 4),
      // Шапка с часами.
      Padding(
        padding: const EdgeInsets.only(left: 34, bottom: 4),
        child: Row(
          children: [
            for (final c in cols)
              Expanded(
                child: Text(
                  c,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
      for (var d = 0; d < 7; d++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  days[d],
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (var c = 0; c < 6; c++)
                Expanded(
                  child: Container(
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _whenMatrix[d][c] == 0
                          ? scheme.surfaceContainerHighest
                          : scheme.primary.withValues(
                              alpha: (0.2 + 0.8 * _whenMatrix[d][c] / _whenMax)
                                  .clamp(0.0, 1.0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: _whenMatrix[d][c] > 0
                        ? Text(
                            '${_whenMatrix[d][c]}',
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _whenMatrix[d][c] / _whenMax > 0.5
                                  ? scheme.onPrimary
                                  : scheme.onSurface,
                            ),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
    ]);
  }

  // --------------------------- РЕКОРДЫ / КОРОЛИ ---------------------------

  String _gameTitleOf(GameSession g) =>
      _typeName[_typeOfGame[g.gameId]] ?? tr('scoreboard');

  /// Рекорды: длиннейшая/быстрейшая партия, больше всего кругов, лучшая серия.
  List<_RecordRow> _recordRows() {
    final rows = <_RecordRow>[];
    final timed = _finishedGames.where((g) => g.durationMs > 0).toList();
    if (timed.isNotEmpty) {
      final longest =
          timed.reduce((a, b) => a.durationMs >= b.durationMs ? a : b);
      rows.add(_RecordRow(Icons.hourglass_bottom_rounded, tr('rec_longest'),
          humanDuration(longest.duration), _gameTitleOf(longest)));
      final fastest =
          timed.reduce((a, b) => a.durationMs <= b.durationMs ? a : b);
      rows.add(_RecordRow(Icons.bolt_rounded, tr('rec_fastest'),
          humanDuration(fastest.duration), _gameTitleOf(fastest)));
    }
    if (_finishedGames.isNotEmpty) {
      final most =
          _finishedGames.reduce((a, b) => a.rounds >= b.rounds ? a : b);
      if (most.rounds > 0) {
        rows.add(_RecordRow(Icons.repeat_rounded, tr('rec_most_rounds'),
            '${most.rounds}', _gameTitleOf(most)));
      }
    }
    _PlayerStat? streaker;
    for (final s in _stats) {
      if (s.bestStreak > 1 &&
          (streaker == null || s.bestStreak > streaker.bestStreak)) {
        streaker = s;
      }
    }
    if (streaker != null) {
      rows.add(_RecordRow(Icons.local_fire_department_rounded, tr('rec_streak'),
          '${streaker.bestStreak}', streaker.name));
    }
    return rows;
  }

  Widget _recordsCard(ColorScheme scheme) {
    final rows = _recordRows();
    return _panel(scheme, tr('records'), [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) _thinDivider(scheme),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(rows[i].icon,
                    size: 21, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rows[i].label,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        )),
                    Text(rows[i].sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(rows[i].value,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: scheme.primary,
                  )),
            ],
          ),
        ),
      ],
    ]);
  }

  /// Король по каждому типу игры (у кого больше всего побед в этой игре).
  List<_KingRow> _kingRows() {
    final winsByType = <String, Map<String, int>>{};
    for (final g in _finishedGames) {
      final t = _typeOfGame[g.gameId];
      final w = g.winner;
      if (t == null || w == null) continue;
      (winsByType[t] ??= {})[w] = (winsByType[t]![w] ?? 0) + 1;
    }
    final rows = <_KingRow>[];
    winsByType.forEach((type, wins) {
      String? best;
      var bestN = 0;
      wins.forEach((name, n) {
        if (n > bestN) {
          bestN = n;
          best = name;
        }
      });
      if (best != null) {
        rows.add(_KingRow(_typeName[type] ?? tr('scoreboard'), best!, bestN));
      }
    });
    rows.sort((a, b) => b.wins.compareTo(a.wins));
    return rows;
  }

  Widget _kingsCard(ColorScheme scheme) {
    final rows = _kingRows();
    Color colorOf(String name) =>
        _stats.firstWhere((s) => s.name == name,
            orElse: () => _PlayerStat(name, scheme.primary, null)).color;
    return _panel(scheme, tr('game_type_kings'), [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) _thinDivider(scheme),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 20, color: _gold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(rows[i].gameName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    )),
              ),
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: colorOf(rows[i].player), shape: BoxShape.circle),
              ),
              Flexible(
                child: Text(rows[i].player,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: scheme.onSurface,
                    )),
              ),
              const SizedBox(width: 8),
              Text('${rows[i].wins}',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: scheme.primary,
                  )),
            ],
          ),
        ),
      ],
    ]);
  }

  /// Игроки для матрицы — самые активные (по числу партий), максимум 6.
  List<_PlayerStat> _matrixPlayers() {
    final active = _stats.where((s) => s.played > 0).toList()
      ..sort((a, b) => b.played.compareTo(a.played));
    return active.take(6).toList();
  }

  int _beats(String a, String b) => _finishedGames
      .where((g) =>
          g.players.contains(a) && g.players.contains(b) && g.winner == a)
      .length;

  Widget _matrixCard(ColorScheme scheme) {
    final players = _matrixPlayers();
    const cell = 38.0;
    const head = 78.0;
    Widget headCell(String name) => SizedBox(
          width: cell,
          height: cell,
          child: Center(
            child: Text(
              name.length <= 3 ? name : name.substring(0, 3),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
    return _panel(scheme, tr('h2h_matrix'), [
      Text(tr('h2h_matrix_hint'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 11.5,
            color: scheme.onSurfaceVariant,
          )),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Шапка столбцов.
            Row(
              children: [
                const SizedBox(width: head),
                for (final p in players) headCell(p.name),
              ],
            ),
            for (final r in players)
              Row(
                children: [
                  SizedBox(
                    width: head,
                    height: cell,
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                              color: r.color, shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Text(r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.bodyFont,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              )),
                        ),
                      ],
                    ),
                  ),
                  for (final c in players)
                    _matrixCell(r, c, scheme, cell),
                ],
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _matrixCell(
      _PlayerStat row, _PlayerStat col, ColorScheme scheme, double cell) {
    if (row.name == col.name) {
      return Container(
        width: cell,
        height: cell,
        alignment: Alignment.center,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
              color: scheme.outlineVariant, shape: BoxShape.circle),
        ),
      );
    }
    final n = _beats(row.name, col.name);
    return Container(
      width: cell,
      height: cell,
      alignment: Alignment.center,
      child: Container(
        width: cell - 6,
        height: cell - 6,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: n > 0
              ? scheme.primary.withValues(alpha: (0.18 + n * 0.12).clamp(0.18, 0.85))
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          n == 0 ? '·' : '$n',
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: n > 0 ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Карточка-обёртка аналитики: заголовок + содержимое в едином стиле.
  Widget _panel(ColorScheme scheme, String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: scheme.onSurface,
              )),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _thinDivider(ColorScheme scheme) => Divider(
        height: 1,
        thickness: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.4),
      );

  // ------------------------------- КАЛЕНДАРЬ -------------------------------

  int _countOn(DateTime day) =>
      _byDay[DateTime(day.year, day.month, day.day)]?.length ?? 0;

  void _shiftAnchor(int dir) {
    HapticFeedback.selectionClick();
    setState(() {
      _userTouchedCal = true;
      switch (_calMode) {
        case _CalMode.week:
          _calAnchor = _calAnchor.add(Duration(days: 7 * dir));
        case _CalMode.month:
          _calAnchor = DateTime(_calAnchor.year, _calAnchor.month + dir, 1);
        case _CalMode.year:
          _calAnchor = DateTime(_calAnchor.year + dir, _calAnchor.month, 1);
      }
    });
  }

  String _calTitle() {
    switch (_calMode) {
      case _CalMode.week:
        final monday =
            _calAnchor.subtract(Duration(days: _calAnchor.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        if (monday.month == sunday.month) {
          return '${monday.day}–${sunday.day} ${monthName(monday.month)}';
        }
        return '${monday.day} ${monthShort(monday.month)} – '
            '${sunday.day} ${monthShort(sunday.month)}';
      case _CalMode.month:
        return '${monthName(_calAnchor.month)} ${_calAnchor.year}';
      case _CalMode.year:
        return '${_calAnchor.year}';
    }
  }

  Widget _calendarCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('calendar'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          // Переключатель режима.
          Row(
            children: [
              for (final m in const [
                (_CalMode.week, 'cal_week'),
                (_CalMode.month, 'cal_month'),
                (_CalMode.year, 'cal_year'),
              ]) ...[
                _calModeChip(tr(m.$2), m.$1 == _calMode, () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _userTouchedCal = true;
                    _calMode = m.$1;
                  });
                }, scheme),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // Навигация по периоду.
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _shiftAnchor(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _calTitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _shiftAnchor(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Плавная смена периода/режима (M3): fade + лёгкий сдвиг.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('${_calMode.name}-${_calAnchor.toIso8601String()}'),
              child: switch (_calMode) {
                _CalMode.week => _weekGrid(scheme),
                _CalMode.month => _monthGrid(scheme),
                _CalMode.year => _yearGrid(scheme),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _calModeChip(
      String label, bool sel, VoidCallback onTap, ColorScheme scheme) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                sel ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
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
      ),
    );
  }

  /// Цвет ячейки дня по числу игр (чем больше, тем насыщеннее).
  Color _dayColor(int count, int maxCount, ColorScheme scheme) {
    if (count == 0) return scheme.surfaceContainerHighest;
    final t = maxCount <= 1 ? 1.0 : (count / maxCount).clamp(0.0, 1.0);
    return Color.lerp(
            scheme.primary.withValues(alpha: 0.30), scheme.primary, t) ??
        scheme.primary;
  }

  Widget _weekHeader(ColorScheme scheme) {
    return Row(
      children: [
        for (final d in weekdayShort)
          Expanded(
            child: Center(
              child: Text(
                d,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dayCell(DateTime day, int maxCount, ColorScheme scheme,
      {bool dim = false}) {
    final count = _countOn(day);
    final color = _dayColor(count, maxCount, scheme);
    final hasGames = count > 0;
    final fg = hasGames ? scheme.onPrimary : scheme.onSurfaceVariant;
    return GestureDetector(
      onTap: hasGames
          ? () {
              HapticFeedback.selectionClick();
              _showDayGames(day);
            }
          : null,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: dim ? color.withValues(alpha: 0.4) : color,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13,
                  fontWeight: hasGames ? FontWeight.w800 : FontWeight.w500,
                  color: dim ? fg.withValues(alpha: 0.6) : fg,
                ),
              ),
              if (hasGames)
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg.withValues(alpha: 0.9),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekGrid(ColorScheme scheme) {
    final monday = _calAnchor.subtract(Duration(days: _calAnchor.weekday - 1));
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final maxCount =
        days.map(_countOn).fold<int>(1, (m, c) => math.max(m, c));
    return Column(
      children: [
        _weekHeader(scheme),
        const SizedBox(height: 6),
        Row(
          children: [for (final d in days) Expanded(child: _dayCell(d, maxCount, scheme))],
        ),
      ],
    );
  }

  Widget _monthGrid(ColorScheme scheme) {
    final first = DateTime(_calAnchor.year, _calAnchor.month, 1);
    final daysInMonth =
        DateTime(_calAnchor.year, _calAnchor.month + 1, 0).day;
    final leadBlanks = first.weekday - 1; // понедельник = 0
    final cells = <Widget>[];
    // Максимум за месяц — для насыщенности.
    var maxCount = 1;
    for (var d = 1; d <= daysInMonth; d++) {
      maxCount = math.max(
          maxCount, _countOn(DateTime(_calAnchor.year, _calAnchor.month, d)));
    }
    for (var i = 0; i < leadBlanks; i++) {
      cells.add(const Expanded(child: SizedBox.shrink()));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(Expanded(
          child: _dayCell(
              DateTime(_calAnchor.year, _calAnchor.month, d), maxCount, scheme)));
    }
    while (cells.length % 7 != 0) {
      cells.add(const Expanded(child: SizedBox.shrink()));
    }
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(children: cells.sublist(i, i + 7)));
    }
    return Column(
      children: [
        _weekHeader(scheme),
        const SizedBox(height: 6),
        ...rows,
      ],
    );
  }

  Widget _yearGrid(ColorScheme scheme) {
    // Суммы игр по месяцам года.
    final counts = List<int>.generate(12, (m) {
      var c = 0;
      _byDay.forEach((day, games) {
        if (day.year == _calAnchor.year && day.month == m + 1) {
          c += games.length;
        }
      });
      return c;
    });
    final maxCount = counts.fold<int>(1, (a, b) => math.max(a, b));
    Widget monthCell(int m) {
      final count = counts[m];
      final has = count > 0;
      final color = _dayColor(count, maxCount, scheme);
      return GestureDetector(
        onTap: () => setState(() {
          _userTouchedCal = true;
          _calMode = _CalMode.month;
          _calAnchor = DateTime(_calAnchor.year, m + 1, 1);
        }),
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                monthShort(m + 1),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: has ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: has
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var r = 0; r < 4; r++) {
      rows.add(Row(
        children: [for (var c = 0; c < 3; c++) Expanded(child: monthCell(r * 3 + c))],
      ));
    }
    return Column(children: rows);
  }

  /// Нижняя панель со списком игр выбранного дня.
  Future<void> _showDayGames(DateTime day) async {
    final scheme = Theme.of(context).colorScheme;
    final games = List<GameSession>.from(
        _byDay[DateTime(day.year, day.month, day.day)] ?? const [])
      ..sort((a, b) => a.date.compareTo(b.date));
    await showModalBottomSheet<void>(
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
              Text(
                trf('games_on', {'d': longDate(day)}),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (games.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(tr('no_games_that_day'),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: games.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _dayGameRow(games[i], scheme),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayGameRow(GameSession g, ColorScheme scheme) {
    final typeId = _typeOfGame[g.gameId];
    final typeName = typeId != null ? _typeName[typeId] : null;
    final winner = g.winner;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: g.isFinished
                  ? _gold.withValues(alpha: 0.18)
                  : scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              g.isFinished
                  ? Icons.emoji_events_rounded
                  : Icons.hourglass_top_rounded,
              size: 20,
              color: g.isFinished ? _gold : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeName ?? tr('scoreboard'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (winner != null) '🏆 $winner',
                    if (g.durationMs > 0) humanDuration(g.duration),
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Простой график «игр по дням» за последние активные дни.
  Widget _gamesPerDayCard(ColorScheme scheme) {
    // Последние до 14 дней с играми (по возрастанию даты).
    final keys = _byDay.keys.toList()..sort();
    final visible = keys.length > 14 ? keys.sublist(keys.length - 14) : keys;

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
            tr('games_per_day'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            _inlineEmpty(tr('not_enough_data'), scheme)
          else
            _DayBars(
              days: visible,
              counts: [for (final k in visible) _byDay[k]!.length],
              barColor: scheme.primary,
              trackColor: scheme.surfaceContainerHighest,
              textColor: scheme.onSurface,
              subColor: scheme.onSurfaceVariant,
            ),
        ],
      ),
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

/// Строка раздела «Рекорды»: иконка, заголовок, значение и пояснение.
class _RecordRow {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  const _RecordRow(this.icon, this.label, this.value, this.sub);
}

/// Король игрового типа: имя игры, лучший игрок и число его побед в ней.
class _KingRow {
  final String gameName;
  final String player;
  final int wins;
  const _KingRow(this.gameName, this.player, this.wins);
}

/// Очная статистика против соперника: его профиль + счёт «мои : его» побед
/// в [shared] совместных завершённых партиях.
class _H2H {
  final _PlayerStat opp;
  final int my;
  final int their;
  final int shared;
  const _H2H(this.opp, this.my, this.their, this.shared);
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
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                              begin: 0,
                              end: cells[i][1] == 0
                                  ? 0.0
                                  : (cells[i][0] / cells[i][1]).clamp(0.0, 1.0)),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, hf, __) => FractionallySizedBox(
                            heightFactor: hf,
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

/// Столбики «игр по дням»: высота столбика = число игр в этот день.
class _DayBars extends StatelessWidget {
  final List<DateTime> days;
  final List<int> counts;
  final Color barColor;
  final Color trackColor;
  final Color textColor;
  final Color subColor;

  const _DayBars({
    required this.days,
    required this.counts,
    required this.barColor,
    required this.trackColor,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxC = counts.fold<int>(1, (m, c) => math.max(m, c)).toDouble();
    const maxBar = 110.0;
    String two(int v) => v.toString().padLeft(2, '0');

    return SizedBox(
      height: maxBar + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${counts[i]}',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0, end: math.max(6, maxBar * (counts[i] / maxC))),
                    duration: Duration(milliseconds: 500 + i * 30),
                    curve: Curves.easeOutCubic,
                    builder: (_, h, __) => Container(
                      width: 14,
                      height: h,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${days[i].day}.${two(days[i].month)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 9.5,
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

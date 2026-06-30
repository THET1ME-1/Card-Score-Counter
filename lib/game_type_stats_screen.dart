import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'player_profile.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';
import 'utils/format.dart';
import 'widgets/reveal.dart';

/// Детальная статистика по одному типу игры: сколько сыграно, таблица игроков
/// (победы/процент), длительности, последняя партия. Крупный Material 3.
class GameTypeStatsScreen extends StatefulWidget {
  final String typeId;
  final String typeName;

  const GameTypeStatsScreen({
    super.key,
    required this.typeId,
    required this.typeName,
  });

  @override
  State<GameTypeStatsScreen> createState() => _GameTypeStatsScreenState();
}

class _Row {
  final String name;
  final Color color;
  final String? image;
  int wins = 0;
  int played = 0;
  _Row(this.name, this.color, this.image);
  double get rate => played > 0 ? wins / played * 100 : 0;
}

class _GameTypeStatsScreenState extends State<GameTypeStatsScreen> {
  static const Color _gold = Color(0xFFFFD700);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  final GameRepository _repo = GameRepository.instance;
  bool _loading = true;

  int _total = 0;
  int _finished = 0;
  int? _avgMs;
  int? _longestMs;
  int? _fastestMs;
  DateTime? _last;
  List<_Row> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final games = await _repo.loadGames();
    final types = await _repo.gameTypes();
    final profiles = await _repo.loadProfiles();
    final byName = <String, _Row>{};
    PlayerProfile? prof(String n) {
      for (final p in profiles) {
        if (p.name == n) return p;
      }
      return null;
    }

    final mine = games
        .where((g) => types[g.gameId] == widget.typeId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final durations = <int>[];
    var finished = 0;
    for (final g in mine) {
      if (g.durationMs > 0) durations.add(g.durationMs);
      if (!g.isFinished) continue;
      finished++;
      final winner = g.winner;
      for (final name in g.players) {
        final r = byName.putIfAbsent(name, () {
          final p = prof(name);
          return _Row(name, p?.color ?? Colors.grey, p?.imagePath);
        });
        r.played++;
        if (name == winner) r.wins++;
      }
    }

    final rows = byName.values.toList()
      ..sort((a, b) {
        final w = b.wins.compareTo(a.wins);
        return w != 0 ? w : b.rate.compareTo(a.rate);
      });

    if (!mounted) return;
    setState(() {
      _total = mine.length;
      _finished = finished;
      _last = mine.isEmpty ? null : mine.first.date;
      _avgMs = durations.isEmpty
          ? null
          : durations.reduce((a, b) => a + b) ~/ durations.length;
      _longestMs =
          durations.isEmpty ? null : durations.reduce((a, b) => a > b ? a : b);
      _fastestMs =
          durations.isEmpty ? null : durations.reduce((a, b) => a < b ? a : b);
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('game_type_stats'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Reveal(child: _header(scheme)),
                const SizedBox(height: 16),
                Reveal(delay: const Duration(milliseconds: 60), child: _tiles(scheme)),
                if (_rows.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Reveal(
                      delay: const Duration(milliseconds: 120),
                      child: _leaderboard(scheme)),
                ],
              ],
            ),
    );
  }

  Widget _header(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerHigh],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.style_rounded, size: 40, color: scheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.typeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trf('games_count_n', {'n': _total})}'
                  '${_last != null ? '  ·  ${tr('last_played')}: ${longDate(_last!)}' : ''}',
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12.5,
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

  Widget _tiles(ColorScheme scheme) {
    final tiles = <List<String>>[
      [tr('total_games'), '$_finished'],
      if (_avgMs != null) [tr('avg_duration'), humanDuration(Duration(milliseconds: _avgMs!))],
      if (_longestMs != null)
        [tr('rec_longest'), humanDuration(Duration(milliseconds: _longestMs!))],
      if (_fastestMs != null)
        [tr('rec_fastest'), humanDuration(Duration(milliseconds: _fastestMs!))],
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        for (final t in tiles)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t[1],
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t[0],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _leaderboard(ColorScheme scheme) {
    final medals = [_gold, _silver, _bronze];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('tab_leaders'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: i < 3 && _rows[i].wins > 0
                        ? Icon(Icons.emoji_events_rounded,
                            size: 20, color: medals[i])
                        : Text(
                            '${i + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontWeight: FontWeight.w700,
                              color: scheme.outline,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: _rows[i].color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _rows[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${_rows[i].wins}/${_rows[i].played} · ${_rows[i].rate.round()}%',
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 13,
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
}

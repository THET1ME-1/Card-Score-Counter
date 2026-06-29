import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'models/game_profile.dart';
import 'models/game_session.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';

/// Одно достижение. Булевы — с [target] = 1, прогрессовые — с целью > 1.
class Achievement {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final int progress;
  final int target;

  const Achievement({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
  });

  bool get unlocked => progress >= target;
  double get fraction =>
      target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0).toDouble();
}

/// Считает все достижения «дома» (общие, не на отдельного игрока) из истории.
List<Achievement> computeAchievements({
  required List<GameSession> games,
  required Map<String, String> gameTypes,
  required List<GameProfile> allGames,
}) {
  // Сыгранные (с записанными очками) и завершённые партии.
  final played = games.where((g) => !g.isEmpty).toList();
  final finished = played.where((g) => g.isFinished).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  // Карта id-профиля → правило, чтобы определить опробованные режимы.
  final ruleById = {for (final p in allGames) p.id: p.winRule};
  final usedRules = <WinRule>{};
  final usedGames = <String>{};
  for (final g in played) {
    final pid = gameTypes[g.gameId];
    usedRules.add(pid != null
        ? (ruleById[pid] ?? WinRule.elimination)
        : WinRule.elimination);
    usedGames.add(pid ?? 'default_101');
  }

  // Максимальная серия побед подряд одним игроком (по дате).
  var maxStreak = 0, cur = 0;
  String? prev;
  for (final g in finished) {
    final w = g.winner;
    if (w == null) continue;
    cur = (w == prev) ? cur + 1 : 1;
    if (cur > maxStreak) maxStreak = cur;
    prev = w;
  }

  final fullTable = played.any((g) => g.players.length >= 6) ? 1 : 0;
  final marathon = played.any((g) => g.rounds >= 20) ? 1 : 0;
  final nightOwl = played.any((g) => g.date.hour < 5) ? 1 : 0;

  Achievement a(String id, IconData icon, int progress, int target) =>
      Achievement(
        id: id,
        icon: icon,
        title: tr('ach_${id}_t'),
        description: tr('ach_${id}_d'),
        progress: progress,
        target: target,
      );

  return [
    a('first_game', Icons.flag_rounded, played.length, 1),
    a('first_win', Icons.emoji_events_rounded, finished.length, 1),
    a('games_10', Icons.style_rounded, played.length, 10),
    a('games_50', Icons.casino_rounded, played.length, 50),
    a('games_100', Icons.workspace_premium_rounded, played.length, 100),
    a('wins_25', Icons.military_tech_rounded, finished.length, 25),
    a('streak_3', Icons.local_fire_department_rounded, maxStreak, 3),
    a('streak_5', Icons.bolt_rounded, maxStreak, 5),
    a('all_modes', Icons.dashboard_customize_rounded, usedRules.length, 7),
    a('variety_10', Icons.auto_awesome_rounded, usedGames.length, 10),
    a('full_table', Icons.groups_rounded, fullTable, 1),
    a('marathon', Icons.timelapse_rounded, marathon, 1),
    a('night_owl', Icons.nightlight_round, nightOwl, 1),
  ];
}

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final GameRepository _repo = GameRepository.instance;
  List<Achievement> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final games = await _repo.loadGames();
    final types = await _repo.gameTypes();
    final all = await _repo.allGames();
    if (!mounted) return;
    setState(() {
      _items = computeAchievements(
          games: games, gameTypes: types, allGames: all);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = _items.where((e) => e.unlocked).length;

    return Scaffold(
      appBar: AppBar(title: Text(tr('achievements'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _summary(scheme, unlocked, _items.length),
                const SizedBox(height: 16),
                for (final ach in _items) ...[
                  _tile(scheme, ach),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _summary(ColorScheme scheme, int unlocked, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded,
              color: scheme.onPrimaryContainer, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('achievements_unlocked'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '$unlocked / $total',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(ColorScheme scheme, Achievement ach) {
    const gold = Color(0xFFFFD700);
    final on = ach.unlocked;
    final iconBg = on ? gold.withValues(alpha: 0.18) : scheme.surfaceContainerHighest;
    final iconFg = on ? const Color(0xFFB8860B) : scheme.onSurfaceVariant;
    final showProgress = !on && ach.target > 1;

    return Semantics(
      label: '${ach.title}. ${ach.description}.'
          ' ${on ? tr('unlocked') : '${ach.progress}/${ach.target}'}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(ach.icon, color: iconFg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ach.title,
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ach.description,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ach.fraction,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ach.progress} / ${ach.target}',
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              on ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              color: on ? gold : scheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

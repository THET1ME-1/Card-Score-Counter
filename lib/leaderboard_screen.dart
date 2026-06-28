import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'player_profile.dart';
import 'services/game_repository.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final GameRepository _repo = GameRepository.instance;

  List<PlayerProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await _repo.loadProfiles();
    profiles.sort((a, b) => b.wins.compareTo(a.wins));
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalWins = _profiles.fold<int>(0, (sum, p) => sum + p.wins);

    return Scaffold(
      appBar: AppBar(title: const Text('Таблица лидеров')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? _emptyState(context)
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (totalWins > 0) _buildChart(totalWins),
                    ..._profiles.asMap().entries.map(
                          (entry) => _buildRow(entry.key, entry.value),
                        ),
                  ],
                ),
    );
  }

  Widget _buildChart(int totalWins) {
    final sections = <PieChartSectionData>[];
    for (final p in _profiles) {
      if (p.wins == 0) continue;
      final pct = p.wins / totalWins * 100;
      sections.add(
        PieChartSectionData(
          color: p.color,
          value: p.wins.toDouble(),
          title: '${pct.toStringAsFixed(0)}%',
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Text('Распределение побед',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                startDegreeOffset: -90,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int index, PlayerProfile profile) {
    final scheme = Theme.of(context).colorScheme;
    final medalColors = [
      const Color(0xFFFFD700), // золото
      const Color(0xFFC0C0C0), // серебро
      const Color(0xFFCD7F32), // бронза
    ];
    final isMedal = index < 3 && profile.wins > 0;

    return ListTile(
      leading: SizedBox(
        width: 56,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isMedal
                ? Icon(Icons.emoji_events, color: medalColors[index])
                : SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.outline,
                      ),
                    ),
                  ),
            const SizedBox(width: 4),
            profile.getAvatar(radius: 16),
          ],
        ),
      ),
      title: Text(profile.name),
      trailing: Text(
        'Победы: ${profile.wins}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard, size: 72, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text('Пока нет игроков',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Создайте игроков и сыграйте партию, чтобы увидеть рейтинг.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

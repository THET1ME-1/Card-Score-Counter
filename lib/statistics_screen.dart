import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_profile.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class PlayerStats {
  final String name;
  final Color color;
  final int totalWins;
  final int totalGames;
  final double winPercentage;
  final String? imagePath;

  PlayerStats({
    required this.name,
    required this.color,
    required this.totalWins,
    required this.totalGames,
    required this.winPercentage,
    this.imagePath,
  });
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<PlayerStats> allPlayersStats = [];
  PlayerStats? selectedPlayerStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final profilesStringList = prefs.getStringList('profiles') ?? [];
    final gameHistory = prefs.getStringList('gameHistory') ?? [];

    final Map<String, PlayerStats> statsMap = {};

    // Process game history to count total games per player
    for (var gameJson in gameHistory) {
      final gameData = jsonDecode(gameJson);
      final players = List<String>.from(gameData['players'] ?? []);
      
      for (var player in players) {
        statsMap.update(
          player,
          (existing) => PlayerStats(
            name: existing.name,
            color: existing.color,
            totalWins: existing.totalWins,
            totalGames: existing.totalGames + 1,
            winPercentage: 0, // Will be calculated later
            imagePath: existing.imagePath
          ),
          ifAbsent: () => PlayerStats(
            name: player,
            color: Colors.grey,
            totalWins: 0,
            totalGames: 1,
            winPercentage: 0,
            imagePath: null,
          ),
        );
      }
    }

    // Process profiles to get colors and wins
    for (var profileString in profilesStringList) {
      final profile = PlayerProfile.fromJson(jsonDecode(profileString));
      if (statsMap.containsKey(profile.name)) {
        final stats = statsMap[profile.name]!;
        statsMap[profile.name] = PlayerStats(
          name: profile.name,
          color: profile.color,
          totalWins: profile.wins,
          totalGames: stats.totalGames,
          winPercentage: stats.totalGames > 0 ? (profile.wins / stats.totalGames * 100) : 0,
          imagePath: profile.imagePath,
        );
      } else {
        statsMap[profile.name] = PlayerStats(
          name: profile.name,
          color: profile.color,
          totalWins: profile.wins,
          totalGames: 0,
          winPercentage: 0,
          imagePath: profile.imagePath,
        );
      }
    }

    final statsList = statsMap.values.toList()
      ..sort((a, b) => b.totalWins.compareTo(a.totalWins));

    if (mounted) {
      setState(() {
        allPlayersStats = statsList;
        if (statsList.isNotEmpty) {
          selectedPlayerStats = statsList.first;
        }
        _isLoading = false;
      });
    }
  }

  Widget _buildPlayerCard(PlayerStats stats) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        leading: stats.imagePath != null && File(stats.imagePath!).existsSync()
            ? CircleAvatar(
                radius: 24,
                backgroundColor: stats.color.withOpacity(0.3),
                child: ClipOval(
                  child: Image.file(
                    File(stats.imagePath!), // Non-null assertion is safe here due to the condition
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : CircleAvatar(
                radius: 24,
                backgroundColor: stats.color,
                child: Text(
                  stats.name.isNotEmpty ? stats.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
        title: Text(
          stats.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Побед: ${stats.totalWins} • Игр: ${stats.totalGames} • ${stats.winPercentage.toStringAsFixed(1)}% побед',
        ),
        onTap: () {
          setState(() {
            selectedPlayerStats = stats;
          });
        },
      ),
    );
  }

  Widget _buildPlayerStats(PlayerStats stats) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            stats.imagePath != null && File(stats.imagePath!).existsSync()
                ? CircleAvatar(
                    radius: 40,
                    backgroundColor: stats.color.withOpacity(0.3),
                    child: ClipOval(
                      child: Image.file(
                        File(stats.imagePath!), // Non-null assertion is safe here due to the condition
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 40,
                    backgroundColor: stats.color,
                    child: Text(
                      stats.name.isNotEmpty ? stats.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 32, color: Colors.white),
                    ),
                  ),
            const SizedBox(height: 16),
            Text(
              stats.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            _buildStatRow('Всего побед', '${stats.totalWins}'),
            _buildStatRow('Всего игр', '${stats.totalGames}'),
            _buildStatRow(
              'Процент побед',
              '${stats.winPercentage.toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика игроков'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : allPlayersStats.isEmpty
              ? const Center(child: Text('Нет данных о статистике игроков'))
              : Column(
                  children: [
                    // Player selection
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allPlayersStats.length,
                        itemBuilder: (context, index) {
                          final stats = allPlayersStats[index];
                          final isSelected = selectedPlayerStats?.name == stats.name;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedPlayerStats = stats;
                              });
                            },
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: stats.color,
                                    radius: 25,
                                    child: Text(
                                      stats.name[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stats.name.split(' ').map((s) => s[0]).join(''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Theme.of(context).primaryColor : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Selected player stats
                    if (selectedPlayerStats != null) _buildPlayerStats(selectedPlayerStats!),
                    // All players list
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'Все игроки',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: allPlayersStats.length,
                        itemBuilder: (context, index) {
                          return _buildPlayerCard(allPlayersStats[index]);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

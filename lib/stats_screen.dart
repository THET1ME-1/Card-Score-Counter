import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool isLoading = true;
  String? selectedPlayer;
  List<String> playerNames = [];
  Map<String, dynamic> stats = {
    'totalGames': 0,
    'totalWins': 0,
    'winRate': 0.0,
    'bestResult': 0,
    'favoritePlayer': 'Нет данных',
  };

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final gameHistory = prefs.getStringList('gameHistory') ?? [];
      final profiles = prefs.getStringList('profiles') ?? [];
      
      debugPrint('Found ${gameHistory.length} games in history');
      if (profiles.isNotEmpty) {
        debugPrint('First profile data: ${profiles.first}');
      }

      // Get all player names and wins from profiles
      final playerProfiles = <String, Map<String, dynamic>>{};
      final allPlayerNames = <String>[];
      
      for (final profileJson in profiles) {
        try {
          final profile = jsonDecode(profileJson);
          final name = profile['name'] as String;
          final wins = profile['wins'] as int? ?? 0;
          playerProfiles[name] = {'wins': wins};
          allPlayerNames.add(name);
        } catch (e) {
          debugPrint('Error parsing profile: $e');
        }
      }
      
      playerNames = ['Все игроки', ...allPlayerNames];

      final playerWins = <String, int>{};
      final playerGames = <String, int>{};
      double lowestWinningScore = double.infinity;
      int totalGames = gameHistory.length;
      int totalWins = 0;
      
      // Initialize player stats from profiles
      for (final player in allPlayerNames) {
        playerWins[player] = playerProfiles[player]?['wins'] ?? 0;
        playerGames[player] = 0; // Will be updated from game history
        totalWins += playerWins[player]!;
      }

      // Process each game to count games played per player and find lowest winning score
      for (final gameData in gameHistory) {
        try {
          final game = jsonDecode(gameData) as Map<String, dynamic>;
          final players = List<String>.from(game['players'] as List);
          final scoresData = game['scores'] as List<dynamic>;
          
          // Skip games with no scores or players
          if (scoresData.isEmpty || players.isEmpty) continue;
          
          // Get the last round scores
          final lastRoundScores = scoresData.isNotEmpty ? scoresData.last as List<dynamic> : [];
          
          // Find the winner (lowest score that's not null or empty)
          int? winnerIndex;
          int minScore = 1000; // Start with a high number
          bool hasValidScores = false;
          
          for (int i = 0; i < lastRoundScores.length && i < players.length; i++) {
            final score = lastRoundScores[i];
            if (score == null || score == '—' || score == '') continue;
            
            int? scoreValue;
            if (score is int) {
              scoreValue = score;
            } else if (score is String) {
              scoreValue = int.tryParse(score);
            }
            
            if (scoreValue != null) {
              hasValidScores = true;
              if (scoreValue <= minScore) {
                minScore = scoreValue;
                winnerIndex = i;
              }
            }
          }
          
          // Update lowest winning score if this was a win
          if (hasValidScores && winnerIndex != null && winnerIndex < players.length) {
            final winner = players[winnerIndex];
            // Only update lowest score if this player actually won (matches profile wins)
            if ((playerWins[winner] ?? 0) > 0 && minScore < lowestWinningScore) {
              lowestWinningScore = minScore.toDouble();
            }
          }
          
          // Update games played for each player in this game
          for (final player in players) {
            playerGames[player] = (playerGames[player] ?? 0) + 1;
          }
          
        } catch (e) {
          debugPrint('Error processing game data: $e');
          debugPrint('Problematic game data: $gameData');
        }
      }

      // Find favorite player (most wins)
      String favoritePlayer = 'Нет данных';
      int maxWins = 0;
      
      // Only consider players that exist in our profiles
      for (final player in allPlayerNames) {
        final wins = playerWins[player] ?? 0;
        if (wins > maxWins) {
          maxWins = wins;
          favoritePlayer = player;
        } else if (wins == maxWins && wins > 0) {
          // In case of tie, show both players
          favoritePlayer += ', $player';
        }
      }

      // Calculate win rate for the selected player
      double winRate = 0.0;
      if (selectedPlayer != null && selectedPlayer != 'Все игроки') {
        final games = playerGames[selectedPlayer] ?? 0;
        final wins = playerWins[selectedPlayer] ?? 0;
        winRate = games > 0 ? (wins / games) * 100 : 0.0;
      }
      
      setState(() {
        stats = {
          'totalGames': selectedPlayer == null || selectedPlayer == 'Все игроки' 
              ? totalGames 
              : playerGames[selectedPlayer] ?? 0,
          'totalWins': selectedPlayer == null || selectedPlayer == 'Все игроки'
              ? totalWins
              : playerWins[selectedPlayer] ?? 0,
          'winRate': winRate,
          'bestResult': lowestWinningScore == double.infinity ? 0 : lowestWinningScore,
          'favoritePlayer': favoritePlayer,
        };
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Player selection dropdown
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: selectedPlayer ?? 'Все игроки',
                    decoration: const InputDecoration(
                      labelText: 'Игрок',
                      border: OutlineInputBorder(),
                    ),
                    items: playerNames.map((name) => DropdownMenuItem(
                      value: name,
                      child: Text(name),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPlayer = value == 'Все игроки' ? null : value;
                      });
                      _loadStatistics();
                    },
                  ),
                ),

                // Statistics cards
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildStatCard('Всего игр', '${stats['totalGames']}'),
                      _buildStatCard('Побед', '${stats['totalWins']}'),
                      if (selectedPlayer != null && selectedPlayer != 'Все игроки')
                        _buildStatCard(
                          'Процент побед',
                          '${(stats['winRate'] as double).toStringAsFixed(1)}%',
                        ),
                      _buildStatCard(
                        'Лучший результат',
                        stats['bestResult'] == 0 
                            ? 'Нет данных' 
                            : '${stats['bestResult']} очков',
                      ),
                      if (selectedPlayer == null || selectedPlayer == 'Все игроки')
                        _buildStatCard('Лучший игрок', '${stats['favoritePlayer']}'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

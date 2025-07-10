import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'player_profile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_scores_screen.dart';
import 'services/achievement_service.dart';

class ScoreBoardScreen extends StatefulWidget {
  final List<String> players;
  final Function() endCurrentGame;
  final Map<String, dynamic>? initialData;
  final bool isNewGame; // <--- добавлено

  const ScoreBoardScreen({
    super.key,
    required this.players,
    required this.endCurrentGame,
    this.initialData,
    this.isNewGame = false, // <--- добавлено
  });

  @override
  // ignore: library_private_types_in_public_api
  _ScoreBoardScreenState createState() => _ScoreBoardScreenState();
}

class _ScoreBoardScreenState extends State<ScoreBoardScreen> {
  List<List<dynamic>> scores = [];
  List<String> remainingPlayers = [];
  List<String> eliminatedPlayers = [];
  int rounds = 0;
  List<int> dividerIndices = [];
  double _textSize = 16.0;
  int currentPlayerIndex = 0;
  String? gameId;

  @override
  void initState() {
    super.initState();
    _loadTextSize();
    if (widget.initialData != null) {
      scores = List<List<dynamic>>.from(widget.initialData!['scores'] ?? []);
      remainingPlayers =
          List<String>.from(widget.initialData!['remainingPlayers'] ?? []);
      eliminatedPlayers =
          List<String>.from(widget.initialData!['eliminatedPlayers'] ?? []);
      rounds = widget.initialData!['rounds'] ?? 0;
      dividerIndices =
          List<int>.from(widget.initialData!['dividerIndices'] ?? []);
      currentPlayerIndex = widget.initialData!['currentPlayerIndex'] ?? 0;
      gameId = widget.initialData!['gameId'];
    } else {
      scores = List.generate(widget.players.length, (_) => []);
      remainingPlayers = List.from(widget.players);
      gameId = DateTime.now()
          .millisecondsSinceEpoch
          .toString(); // Generate a unique game ID
      if (widget.isNewGame) {
        _saveNewGameToHistory();
      }
    }
  }

  Future<void> _loadTextSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _textSize = prefs.getDouble('textSize') ?? 16.0;
    });
  }

  Future<void> _saveNewGameToHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final gameHistory = prefs.getStringList('gameHistory') ?? [];
    final gameData = {
      'gameId': gameId,
      'players': widget.players,
      'scores': scores,
      'rounds': rounds,
      'remainingPlayers': remainingPlayers,
      'eliminatedPlayers': eliminatedPlayers,
      'dividerIndices': dividerIndices,
      'currentPlayerIndex': currentPlayerIndex,
      'date': DateTime.now().toIso8601String(),
    };
    gameHistory.add(jsonEncode(gameData));
    await prefs.setStringList('gameHistory', gameHistory);
  }

  Future<void> _updateGameHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final gameHistory = prefs.getStringList('gameHistory') ?? [];
    final gameData = {
      'gameId': gameId,
      'players': widget.players,
      'scores': scores,
      'rounds': rounds,
      'remainingPlayers': remainingPlayers,
      'eliminatedPlayers': eliminatedPlayers,
      'dividerIndices': dividerIndices,
      'currentPlayerIndex': currentPlayerIndex,
      'date': DateTime.now().toIso8601String(),
    };

    int gameIndex = gameHistory.indexWhere((entry) {
      final Map<String, dynamic> gameMap = jsonDecode(entry);
      return gameMap['gameId'] == gameId;
    });

    if (gameIndex != -1) {
      gameHistory[gameIndex] = jsonEncode(gameData);
    } else {
      gameHistory.add(jsonEncode(gameData));
    }

    await prefs.setStringList('gameHistory', gameHistory);
  }

  Future<void> _deleteEmptyGames() async {
    final prefs = await SharedPreferences.getInstance();
    final gameHistory = prefs.getStringList('gameHistory') ?? [];

    gameHistory.removeWhere((entry) {
      final Map<String, dynamic> gameMap = jsonDecode(entry);
      final List<dynamic> scores =
          List<List<dynamic>>.from(gameMap['scores'] ?? [])
              .expand((x) => x)
              .toList();
      return scores.isEmpty;
    });

    await prefs.setStringList('gameHistory', gameHistory);
  }

  Future<void> _incrementPlayerWin(String playerName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update wins in SharedPreferences
      final wins = prefs.getInt('wins_$playerName') ?? 0;
      final newWins = wins + 1;
      await prefs.setInt('wins_$playerName', newWins);
      
      // Update wins in PlayerProfile
      final profilesStringList = prefs.getStringList('profiles') ?? [];
      bool profileFound = false;
      
      final updatedProfiles = profilesStringList.map((profileString) {
        final profileData = jsonDecode(profileString);
        if (profileData['name'] == playerName) {
          profileFound = true;
          profileData['wins'] = (profileData['wins'] ?? 0) + 1;
        }
        return jsonEncode(profileData);
      }).toList();
      
      // If player doesn't have a profile yet, create one
      if (!profileFound) {
        final newProfile = PlayerProfile(
          name: playerName,
          color: Colors.primaries[playerName.length % Colors.primaries.length],
          wins: 1,
        );
        updatedProfiles.add(jsonEncode(newProfile.toJson()));
      }
      
      await prefs.setStringList('profiles', updatedProfiles);

      // Track consecutive wins for achievements
      final achievementService = Provider.of<AchievementService>(context, listen: false);
      
      // Get the current number of consecutive wins
      final consecutiveWins = prefs.getInt('consecutive_wins_$playerName') ?? 0;
      final newConsecutiveWins = consecutiveWins + 1;
      await prefs.setInt('consecutive_wins_$playerName', newConsecutiveWins);
      
      // Update achievement for consecutive wins
      if (newConsecutiveWins >= 5) {
        achievementService.onConsecutiveWin();
      }
      
      // Track session completion for the 'first_step' achievement
      achievementService.onSessionCompleted();
      
      // Mark achievements as seen after showing them
      WidgetsBinding.instance.addPostFrameCallback((_) {
        achievementService.markAchievementsAsSeen();
      });
      
      debugPrint('Win recorded for $playerName. Total wins: $newWins, Consecutive wins: $newConsecutiveWins');
    } catch (e) {
      debugPrint('Error in _incrementPlayerWin: $e');
    }
  }

  void addScores(List<int> roundScores) async {
    final achievementService = Provider.of<AchievementService>(context, listen: false);
    bool hasHighScore = false;
    
    // Check for high scores (10+ points) in this round
    for (final score in roundScores) {
      if (score >= 10) {
        hasHighScore = true;
        break;
      }
    }

    setState(() {
      List<String> playersToEliminate = [];
      int remainingIndex = 0;

      for (int i = 0; i < widget.players.length; i++) {
        if (eliminatedPlayers.contains(widget.players[i])) {
          scores[i].add('—');
          continue;
        }

        if (roundScores[remainingIndex] == 0) {
          scores[i].add('—');
        } else {
          int lastValidScore = 0;
          for (int j = scores[i].length - 1; j >= 0; j--) {
            if (scores[i][j] is int) {
              lastValidScore = scores[i][j];
              break;
            }
          }
          scores[i].add(lastValidScore + roundScores[remainingIndex]);
        }

        if (scores[i].last is int && scores[i].last >= 101) {
          playersToEliminate.add(widget.players[i]);
        }

        remainingIndex++;
      }

      for (var player in playersToEliminate) {
        remainingPlayers.remove(player);
        eliminatedPlayers.add(player);
      }

      if (remainingPlayers.length == 1) {
        _incrementPlayerWin(remainingPlayers.first);
        widget.endCurrentGame();
      } else if (remainingPlayers.isNotEmpty) {
        rounds++;
        if (rounds % remainingPlayers.length == 0) {
          dividerIndices.add(scores[0].length);
        }
      }

      // Track points scored in a round for achievements
      for (int i = 0; i < roundScores.length; i++) {
        if (i < scores.length) {
          if (roundScores[i] >= 10) {
            achievementService.onPointsScoredInRound(roundScores[i]);
          }
        }
      }

      // Track round completion
      achievementService.onRoundCounted();

      // Track high score if any
      if (hasHighScore) {
        achievementService.onPointsScoredInRound(10);
      }

      _updateGameHistory();
      _deleteEmptyGames(); // Удаление пустых игр
      _advanceToNextPlayer();
    });
  }

  void _advanceToNextPlayer() {
    setState(() {
      do {
        currentPlayerIndex = (currentPlayerIndex + 1) % widget.players.length;
      } while (eliminatedPlayers.contains(widget.players[currentPlayerIndex]));
    });
    _updateGameHistory();
  }

  void undoLastRound() {
    setState(() {
      if (rounds > 0) {
        // Get the current state of eliminated players before undoing
        final previousEliminatedPlayers = List<String>.from(eliminatedPlayers);
        
        // Remove the last scores
        for (int i = 0; i < widget.players.length; i++) {
          if (scores[i].isNotEmpty) {
            scores[i].removeLast();
          }
        }
        
        rounds--;
        if (dividerIndices.isNotEmpty && rounds % widget.players.length == 0) {
          dividerIndices.removeLast();
        }
        
        // Reset the player lists
        eliminatedPlayers.clear();
        remainingPlayers.clear();
        
        // Check each player's total score to determine elimination
        for (int i = 0; i < widget.players.length; i++) {
          bool isEliminated = false;
          
          // Find the last valid score (int) for this player
          int lastValidScore = 0;
          for (int j = scores[i].length - 1; j >= 0; j--) {
            if (scores[i][j] is int) {
              lastValidScore = scores[i][j];
              break;
            }
          }
          
          // Check if player was previously eliminated or has a score >= 101
          if (previousEliminatedPlayers.contains(widget.players[i]) || 
              (scores[i].isNotEmpty && lastValidScore >= 101)) {
            eliminatedPlayers.add(widget.players[i]);
            isEliminated = true;
          }
          
          if (!isEliminated) {
            remainingPlayers.add(widget.players[i]);
          }
        }
        
        // If all players are eliminated, something went wrong - reset to initial state
        if (remainingPlayers.isEmpty && widget.players.isNotEmpty) {
          remainingPlayers = List.from(widget.players);
          eliminatedPlayers.clear();
        }
        
        _updateGameHistory();
        _advanceToPreviousPlayer();
      }
    });
  }

  void _advanceToPreviousPlayer() {
    setState(() {
      do {
        currentPlayerIndex = (currentPlayerIndex - 1 + widget.players.length) %
            widget.players.length;
      } while (eliminatedPlayers.contains(widget.players[currentPlayerIndex]));
    });
    _updateGameHistory();
  }

  void editLastRoundScores() {
    if (rounds > 0) {
      List<int> lastRoundScores = [];
      for (int i = 0; i < widget.players.length; i++) {
        if (eliminatedPlayers.contains(widget.players[i])) {
          lastRoundScores.add(0);
          continue;
        }
        
        // Find the last valid score (int) before the last round
        int lastValidScore = 0;
        int lastRoundIndex = scores[i].length - 1;
        
        // If there's only one score, use it as is
        if (scores[i].length == 1 && scores[i].last is int) {
          lastRoundScores.add(scores[i].last);
          continue;
        }
        
        // For multiple scores, find the last valid score before the current round
        for (int j = lastRoundIndex - 1; j >= 0; j--) {
          if (scores[i][j] is int) {
            lastValidScore = scores[i][j];
            break;
          }
        }
        
        // Calculate the score for the last round only (current total - previous total)
        var currentScore = scores[i].last;
        if (currentScore is int) {
          lastRoundScores.add(currentScore - lastValidScore);
        } else {
          lastRoundScores.add(0);
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddScoresScreen(
            players: remainingPlayers,
            initialScores: lastRoundScores,
            onAddScores: (newScores) {
              setState(() {
                int remainingIndex = 0;
                for (int i = 0; i < widget.players.length; i++) {
                  if (eliminatedPlayers.contains(widget.players[i])) {
                    continue;
                  }
                  if (scores[i].isNotEmpty) {
                    if (newScores[remainingIndex] == 0) {
                      scores[i][scores[i].length - 1] = '—';
                    } else {
                      int lastValidScore = 0;
                      for (int j = scores[i].length - 2; j >= 0; j--) {
                        if (scores[i][j] is int) {
                          lastValidScore = scores[i][j];
                          break;
                        }
                      }
                      scores[i][scores[i].length - 1] =
                          lastValidScore + newScores[remainingIndex];
                    }
                    remainingIndex++;
                  }
                }
                _updateGameHistory();
              });
            },
          ),
        ),
      );
    }
  }

  void _restartGame() {
    _updateGameHistory(); // Сохраняем игру перед рестартом
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ScoreBoardScreen(
          players: widget.players,
          endCurrentGame: widget.endCurrentGame,
          isNewGame: true, // <-- только при реальном старте новой игры!
        ),
      ),
    );
  }

  @override
  void dispose() {
    _updateGameHistory(); // Сохраняем игру при выходе с экрана
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkTheme ? Colors.white : Colors.black;
    final currentPlayerColor =
        isDarkTheme ? const Color(0xFFC2B8ED) : Colors.purple;
    final currentPlayerTextColor = isDarkTheme ? Colors.black : Colors.white;

    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    );

    List<Widget> buildRemainingPoints() {
      List<Widget> widgets = [];
      for (int i = 0; i < widget.players.length; i++) {
        int lastValidScore = 0;
        for (int j = scores[i].length - 1; j >= 0; j--) {
          if (scores[i][j] is int) {
            lastValidScore = scores[i][j];
            break;
          }
        }
        if (lastValidScore >= 60 && lastValidScore < 101) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                '${100 - lastValidScore}',
                style: TextStyle(
                  fontSize: 12.0,
                  color: textColor,
                ),
              ),
            ),
          );
        } else {
          widgets.add(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                '',
                style: TextStyle(
                  fontSize: 12.0,
                ),
              ),
            ),
          );
        }
      }
      return widgets;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Табло'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: [
                          ...widget.players.asMap().entries.map((entry) {
                            int index = entry.key;
                            String player = entry.value;
                            bool isEliminated =
                                eliminatedPlayers.contains(player);
                            bool isCurrentPlayer = index == currentPlayerIndex;

                            return Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: isCurrentPlayer
                                          ? currentPlayerColor
                                          : Colors.transparent,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 8.0),
                                    child: AutoSizeText(
                                      player,
                                      maxLines: 1,
                                      minFontSize: 8,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18.0,
                                        color: isEliminated
                                            ? Colors.red
                                            : isCurrentPlayer
                                                ? currentPlayerTextColor
                                                : textColor,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    children: scores[index]
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      int roundIndex = entry.key;
                                      var score = entry.value;
                                      bool showTransparent = isEliminated &&
                                          roundIndex >=
                                              scores[index].indexWhere(
                                                  (s) => s is int && s >= 101);
                                      return Column(
                                        children: [
                                          AutoSizeText(
                                            score == '—' ? '—' : '$score',
                                            minFontSize: 8,
                                            style: TextStyle(
                                              fontSize: _textSize,
                                              color: score == '—' &&
                                                      showTransparent
                                                  ? Colors.transparent
                                                  : textColor,
                                            ),
                                          ),
                                          if (dividerIndices
                                              .contains(roundIndex + 1))
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 8.0),
                                              child: Divider(thickness: 2),
                                            ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: buildRemainingPoints(),
                ),
              ),
              if (remainingPlayers.length == 1)
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _restartGame,
                      style: buttonStyle,
                      child: const Text('Играть заново'),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ElevatedButton(
                          onPressed: remainingPlayers.length > 1
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddScoresScreen(
                                        players: remainingPlayers,
                                        onAddScores: addScores,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: buttonStyle,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ElevatedButton(
                          onPressed: undoLastRound,
                          style: buttonStyle,
                          child: const Icon(Icons.undo),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ElevatedButton(
                          onPressed: editLastRoundScores,
                          style: buttonStyle,
                          child: const Icon(Icons.edit),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

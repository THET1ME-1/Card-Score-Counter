import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'add_scores_screen.dart';
import 'player_profile.dart';

class ScoreBoardScreen extends StatefulWidget {
  final List<String> players;
  final Function() endCurrentGame;
  final Map<String, dynamic>? initialData;

  const ScoreBoardScreen({
    super.key,
    required this.players,
    required this.endCurrentGame,
    this.initialData,
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
  int dealerIndex = 0;
  double _textSize = 16.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      scores = List<List<dynamic>>.from(widget.initialData!['scores'] ?? []);
      remainingPlayers = List<String>.from(widget.initialData!['remainingPlayers'] ?? []);
      eliminatedPlayers = List<String>.from(widget.initialData!['eliminatedPlayers'] ?? []);
      rounds = widget.initialData!['rounds'] ?? 0;
      dividerIndices = List<int>.from(widget.initialData!['dividerIndices'] ?? []);
      dealerIndex = widget.initialData!['dealerIndex'] ?? 0;
    } else {
      scores = List.generate(widget.players.length, (_) => []);
      remainingPlayers = List.from(widget.players);
    }
    _fixDealerIndex();
    _loadTextSize();
  }

  void _fixDealerIndex() {
    if (dealerIndex >= remainingPlayers.length) {
      dealerIndex = remainingPlayers.length - 1;
    }
  }

  Future<void> _loadTextSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _textSize = prefs.getDouble('textSize') ?? 16.0;
    });
  }

  Future<void> _updateGameHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final gameHistory = prefs.getStringList('gameHistory') ?? [];
    final gameData = {
      'players': widget.players,
      'scores': scores,
      'rounds': rounds,
      'remainingPlayers': remainingPlayers,
      'eliminatedPlayers': eliminatedPlayers,
      'dividerIndices': dividerIndices,
      'dealerIndex': dealerIndex,
    };
    gameHistory.removeLast();
    gameHistory.add(jsonEncode(gameData));
    await prefs.setStringList('gameHistory', gameHistory);
  }

  Future<void> _incrementPlayerWin(String playerName) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? profilesStringList = prefs.getStringList('profiles');
    if (profilesStringList != null) {
      final List<PlayerProfile> profiles = profilesStringList
          .map((profileString) => PlayerProfile.fromJson(jsonDecode(profileString)))
          .toList();
      for (var profile in profiles) {
        if (profile.name == playerName) {
          profile.wins++;
          break;
        }
      }
      await prefs.setStringList(
        'profiles',
        profiles.map((profile) => jsonEncode(profile.toJson())).toList(),
      );
    }
  }

  void addScores(List<int> roundScores) {
    setState(() {
      List<String> playersToEliminate = [];
      int remainingIndex = 0;

      for (int i = 0; i < widget.players.length; i++) {
        if (eliminatedPlayers.contains(widget.players[i])) {
          scores[i].add('—'); // Добавляем длинное тире для проигравшего игрока
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

        if (scores[i].last is int && scores[i].last >= 100) {
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
        dealerIndex = (dealerIndex + 1) % remainingPlayers.length;
      }

      _updateGameHistory();
    });
  }

  void undoLastRound() {
    setState(() {
      if (rounds > 0) {
        for (int i = 0; i < widget.players.length; i++) {
          if (scores[i].isNotEmpty) {
            scores[i].removeLast();
          }
        }
        rounds--;
        if (dividerIndices.isNotEmpty && rounds % widget.players.length == 0) {
          dividerIndices.removeLast();
        }
        eliminatedPlayers.clear();
        remainingPlayers = List.from(widget.players);
        for (int i = 0; i < widget.players.length; i++) {
          if (scores[i].isNotEmpty && scores[i].last is int && scores[i].last >= 100) {
            eliminatedPlayers.add(widget.players[i]);
            remainingPlayers.remove(widget.players[i]);
          }
        }
        dealerIndex = rounds % remainingPlayers.length;
        _fixDealerIndex();
        _updateGameHistory();
      }
    });
  }

  void editLastRoundScores() {
    setState(() {
      if (rounds > 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddScoresScreen(
              players: remainingPlayers,
              onAddScores: (newScores) {
                setState(() {
                  int remainingIndex = 0;
                  for (int i = 0; i < widget.players.length; i++) {
                    if (eliminatedPlayers.contains(widget.players[i])) {
                      continue;
                    }
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
                      scores[i][scores[i].length - 1] = lastValidScore + newScores[remainingIndex];
                    }
                    remainingIndex++;
                  }
                  _fixDealerIndex();
                  _updateGameHistory();
                });
              },
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkTheme ? Colors.white : Colors.black;
    final currentPlayerColor = isDarkTheme ? const Color(0xFFC2B8ED) : Colors.purple;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Row(
              children: [
                ...widget.players.asMap().entries.map((entry) {
                  int index = entry.key;
                  String player = entry.value;
                  bool isEliminated = eliminatedPlayers.contains(player);
                  bool isCurrentPlayer = remainingPlayers.isNotEmpty && dealerIndex < remainingPlayers.length && remainingPlayers[dealerIndex] == player;

                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isCurrentPlayer ? currentPlayerColor : Colors.transparent,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                          child: Text(
                            player,
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.0,
                              color: isEliminated
                                  ? Colors.red
                                  : (isCurrentPlayer ? (isDarkTheme ? Colors.black : Colors.white) : textColor),
                            ),
                          ),
                        ),
                        Column(
                          children: scores[index].asMap().entries.map((entry) {
                            int roundIndex = entry.key;
                            var score = entry.value;
                            return Column(
                              children: [
                                Text(
                                  score == '—' ? '—' : '$score',
                                  style: TextStyle(
                                    fontSize: _textSize,
                                    color: isEliminated && score == '—' ? Colors.transparent : textColor,
                                  ),
                                ),
                                if (dividerIndices.contains(roundIndex + 1))
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
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
                  icon: const Icon(Icons.add, size: 30),
                ),
                IconButton(
                  onPressed: undoLastRound,
                  icon: const Icon(Icons.undo, size: 30),
                ),
                IconButton(
                  onPressed: editLastRoundScores,
                  icon: const Icon(Icons.edit, size: 30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

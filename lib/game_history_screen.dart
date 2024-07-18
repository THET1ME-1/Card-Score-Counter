import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'score_board_screen.dart';

class GameHistoryScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) continueGame;

  const GameHistoryScreen({
    super.key,
    required this.continueGame,
  });

  @override
  // ignore: library_private_types_in_public_api
  _GameHistoryScreenState createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  List<Map<String, dynamic>> gameHistory = [];
  bool isDescending = true; // Default sorting order

  @override
  void initState() {
    super.initState();
    _loadSortingPreference();
    _loadGameHistory();
  }

  Future<void> _loadGameHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final gameHistoryData = prefs.getStringList('gameHistory') ?? [];
    setState(() {
      gameHistory = gameHistoryData.map((entry) {
        final Map<String, dynamic> gameMap = jsonDecode(entry);
        gameMap['date'] = gameMap.containsKey('date') && gameMap['date'] != null 
            ? DateTime.parse(gameMap['date']) 
            : DateTime.now(); // Assign current date if 'date' is null
        return gameMap;
      }).toList();
    });
  }

  Future<void> _saveSortingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDescending', isDescending);
  }

  Future<void> _loadSortingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDescending = prefs.getBool('isDescending') ?? true;
    });
  }

  Future<void> _deleteSingleGame(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final gameHistoryData = prefs.getStringList('gameHistory') ?? [];
    gameHistoryData.removeAt(index);
    await prefs.setStringList('gameHistory', gameHistoryData);
    setState(() {
      gameHistory.removeAt(index);
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Дата неизвестна';
    }
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('История игр'),
      ),
      body: ListView.builder(
        itemCount: gameHistory.length,
        itemBuilder: (context, index) {
          final game = gameHistory[index];
          final date = game['date'] as DateTime?;
          final formattedDate = _formatDate(date);
          final title = game['title'] ?? 'Игра ${index + 1}';

          final titleColor = isDarkTheme ? const Color(0xFFC2B8ED) : Colors.purple;
          final dateColor = isDarkTheme ? Colors.white : Colors.black;

          return ListTile(
            title: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: <TextSpan>[
                  TextSpan(
                    text: '$title ',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: '- $formattedDate',
                    style: TextStyle(color: dateColor, fontSize: 16),
                  ),
                ],
              ),
            ),
            subtitle: Text('Игроки: ${game['players'].join(', ')}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Удалить эту игру?'),
                    content: const Text('Вы уверены, что хотите удалить эту игру из истории?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () {
                          _deleteSingleGame(index);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                );
              },
            ),
            onTap: () {
              widget.continueGame(game);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScoreBoardScreen(
                    players: List<String>.from(game['players']),
                    endCurrentGame: () {},
                    initialData: game,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'player_profile.dart';
import 'score_board_screen.dart';

class PlayerInputScreen extends StatefulWidget {
  final Function(List<String>) startNewGame;
  final Function() endCurrentGame;

  const PlayerInputScreen({
    super.key,
    required this.startNewGame,
    required this.endCurrentGame,
  });

  @override
  // ignore: library_private_types_in_public_api
  _PlayerInputScreenState createState() => _PlayerInputScreenState();
}

class _PlayerInputScreenState extends State<PlayerInputScreen> {
  List<PlayerProfile> profiles = [];
  List<int> selectedProfiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? profilesStringList = prefs.getStringList('profiles');
    if (profilesStringList != null) {
      final List<dynamic> profileList = profilesStringList.map((profile) => jsonDecode(profile)).toList();
      setState(() {
        profiles = profileList.map((profile) => PlayerProfile.fromJson(profile)).toList();
      });
    }
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesStringList = profiles.map((profile) => jsonEncode(profile.toJson())).toList();
    await prefs.setStringList('profiles', profilesStringList);
  }

  void _addProfile(String name, Color color) {
    setState(() {
      profiles.add(PlayerProfile(name: name, color: color));
    });
    _saveProfiles();
  }

  void _editProfile(int index, String name, Color color) {
    setState(() {
      profiles[index] = PlayerProfile(name: name, color: color);
    });
    _saveProfiles();
  }

  void _toggleProfileSelection(int index) {
    setState(() {
      if (selectedProfiles.contains(index)) {
        selectedProfiles.remove(index);
      } else {
        selectedProfiles.add(index);
      }
    });
  }

  void _deleteProfile(int index) {
    setState(() {
      profiles.removeAt(index);
      selectedProfiles.remove(index);
    });
    _saveProfiles();
  }

  Future<void> _saveGameToHistory(List<String> playerNames) async {
    final prefs = await SharedPreferences.getInstance();
    final gameHistory = prefs.getStringList('gameHistory') ?? [];
    final gameData = jsonEncode({
      'players': playerNames,
      'scores': List.generate(playerNames.length, (_) => []),
      'rounds': 0,
      'remainingPlayers': playerNames,
      'eliminatedPlayers': [],
      'dividerIndices': [],
      'dealerIndex': 0,
      'date': DateTime.now().toIso8601String(),
    });
    gameHistory.insert(0, gameData); // Добавляем новую игру в начало списка
    await prefs.setStringList('gameHistory', gameHistory);
  }

  void _showEditProfileDialog(int index) {
    String name = profiles[index].name;
    Color color = profiles[index].color;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Редактировать профиль'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Имя'),
                    onChanged: (value) {
                      name = value;
                    },
                    controller: TextEditingController(text: name),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Цвет: '),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Выберите цвет'),
                                content: SingleChildScrollView(
                                  child: BlockPicker(
                                    pickerColor: color,
                                    onColorChanged: (newColor) {
                                      setState(() {
                                        color = newColor;
                                      });
                                    },
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Готово'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _deleteProfile(index);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Удалить'),
                ),
                TextButton(
                  onPressed: () {
                    _editProfile(index, name, color);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Главное меню'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  const Text(
                    'Создай игрока:',
                    style: TextStyle(fontSize: 18),
                  ),
                  const Spacer(),
                  GestureDetector(
                    child: const Icon(Icons.add),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          String name = '';
                          Color color = Colors.blue;
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return AlertDialog(
                                title: const Text('Новый профиль'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      decoration: const InputDecoration(labelText: 'Имя'),
                                      onChanged: (value) {
                                        name = value;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        const Text('Цвет: '),
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                return AlertDialog(
                                                  title: const Text('Выберите цвет'),
                                                  content: SingleChildScrollView(
                                                    child: BlockPicker(
                                                      pickerColor: color,
                                                      onColorChanged: (newColor) {
                                                        setState(() {
                                                          color = newColor;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.of(context).pop();
                                                      },
                                                      child: const Text('Готово'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _addProfile(name, color);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Сохранить'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            Wrap(
              spacing: 8.0, // Горизонтальный отступ между элементами
              runSpacing: 8.0, // Вертикальный отступ между элементами
              children: profiles.asMap().entries.map((entry) {
                int index = entry.key;
                PlayerProfile profile = entry.value;
                return GestureDetector(
                  onLongPress: () => _showEditProfileDialog(index),
                  child: ChoiceChip(
                    label: Text(profile.name),
                    selected: selectedProfiles.contains(index),
                    onSelected: (_) => _toggleProfileSelection(index),
                    backgroundColor: profile.color.withOpacity(0.5),
                    selectedColor: profile.color,
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: selectedProfiles.length >= 2
                  ? () async {
                      List<String> selectedPlayerNames = selectedProfiles
                          .map((index) => profiles[index].name)
                          .toList();
                      await _saveGameToHistory(selectedPlayerNames);
                      widget.startNewGame(selectedPlayerNames);
                      Navigator.push(
                        // ignore: use_build_context_synchronously
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScoreBoardScreen(
                            players: selectedPlayerNames,
                            endCurrentGame: widget.endCurrentGame,
                          ),
                        ),
                      );
                    }
                  : null,
              style: buttonStyle,
              child: const Text('Начать игру'), // Применяем стиль для кнопки
            ),
          ],
        ),
      ),
    );
  }
}

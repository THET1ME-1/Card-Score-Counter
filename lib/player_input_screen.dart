import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final List<dynamic> profileList =
          profilesStringList.map((profile) => jsonDecode(profile)).toList();
      setState(() {
        profiles = profileList
            .map((profile) => PlayerProfile.fromJson(profile))
            .toList();
      });
    }
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesStringList =
        profiles.map((profile) => jsonEncode(profile.toJson())).toList();
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

  void _showEditProfileDialog(int index) {
    String name = profiles[index].name;
    Color color = profiles[index].color;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Редактировать игрока'),
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
                IconButton(
                  onPressed: () {
                    _deleteProfile(index);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Отменить'),
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
                                title: const Text('Новый игрок'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      decoration: const InputDecoration(
                                          labelText: 'Имя'),
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
                                                  title: const Text(
                                                      'Выберите цвет'),
                                                  content:
                                                      SingleChildScrollView(
                                                    child: BlockPicker(
                                                      pickerColor: color,
                                                      onColorChanged:
                                                          (newColor) {
                                                        setState(() {
                                                          color = newColor;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      child:
                                                          const Text('Готово'),
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
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  PlayerProfile profile = profiles[index];
                  bool isSelected = selectedProfiles.contains(index);
                  int selectionOrder =
                      isSelected ? selectedProfiles.indexOf(index) + 1 : 0;
                  return GestureDetector(
                    onLongPress: () => _showEditProfileDialog(index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: profile.color.withAlpha((isSelected ? 180 : 128)),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: ListTile(
                        leading: isSelected
                            ? CircleAvatar(
                                backgroundColor: profile.color,
                                child: Text(
                                  '$selectionOrder',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              )
                            : null,
                        title: Text(
                          profile.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                              )
                            : null,
                        onTap: () => _toggleProfileSelection(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: selectedProfiles.length >= 2
                  ? () async {
                      List<String> selectedPlayerNames = selectedProfiles
                          .map((index) => profiles[index].name)
                          .toList();
                      widget.startNewGame(selectedPlayerNames);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScoreBoardScreen(
                            players: selectedPlayerNames,
                            endCurrentGame: widget.endCurrentGame,
                            isNewGame: true,
                          ),
                        ),
                      );
                    }
                  : null,
              style: buttonStyle,
              child: const Text('Начать игру'),
            ),
          ],
        ),
      ),
    );
  }
}

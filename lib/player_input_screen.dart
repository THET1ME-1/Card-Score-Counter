import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_profile.dart';
import 'score_board_screen.dart';
import 'utils/image_picker_util.dart';

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
  final _formKey = GlobalKey<FormState>();

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

  Future<void> _addProfile(String name, Color color,
      {String? imagePath}) async {
    setState(() {
      profiles.add(PlayerProfile(
        name: name,
        color: color,
        imagePath: imagePath,
      ));
    });
    await _saveProfiles();
  }

  Future<void> _editProfile(int index, String name, Color color,
      {String? imagePath}) async {
    final oldName = profiles[index].name;
    final oldImagePath = profiles[index].imagePath;
    final wins = profiles[index].wins;
    
    // Delete old image if it's being replaced
    if (imagePath != null && imagePath != oldImagePath) {
      await ImagePickerUtil.deleteImage(oldImagePath);
    }

    // Update the profile
    setState(() {
      profiles[index] = PlayerProfile(
        name: name,
        color: color,
        wins: wins,
        imagePath: imagePath ?? oldImagePath,
      );
    });
    
    await _saveProfiles();
    
    // If the name changed, update all game history and statistics
    if (name != oldName) {
      await _updatePlayerNameInGameData(oldName, name);
    }
  }
  
  Future<void> _updatePlayerNameInGameData(String oldName, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update game history
    final gameHistory = prefs.getStringList('gameHistory') ?? [];
    final updatedGameHistory = <String>[];
    
    for (final gameJson in gameHistory) {
      try {
        final gameData = jsonDecode(gameJson);
        
        // Update players list
        if (gameData['players'] != null) {
          final players = List<String>.from(gameData['players']);
          final playerIndex = players.indexOf(oldName);
          if (playerIndex != -1) {
            players[playerIndex] = newName;
            gameData['players'] = players;
          }
        }
        
        // Update remainingPlayers list
        if (gameData['remainingPlayers'] != null) {
          final remainingPlayers = List<String>.from(gameData['remainingPlayers']);
          final playerIndex = remainingPlayers.indexOf(oldName);
          if (playerIndex != -1) {
            remainingPlayers[playerIndex] = newName;
            gameData['remainingPlayers'] = remainingPlayers;
          }
        }
        
        // Update eliminatedPlayers list
        if (gameData['eliminatedPlayers'] != null) {
          final eliminatedPlayers = List<String>.from(gameData['eliminatedPlayers']);
          final playerIndex = eliminatedPlayers.indexOf(oldName);
          if (playerIndex != -1) {
            eliminatedPlayers[playerIndex] = newName;
            gameData['eliminatedPlayers'] = eliminatedPlayers;
          }
        }
        
        updatedGameHistory.add(jsonEncode(gameData));
      } catch (e) {
        // Skip corrupted game data
        debugPrint('Error updating game data: $e');
        updatedGameHistory.add(gameJson);
      }
    }
    
    await prefs.setStringList('gameHistory', updatedGameHistory);
    
    // Update statistics will be handled by the statistics screen
    // by reloading the data from the updated game history
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
    final formKey = GlobalKey<FormState>();
    String name = profiles[index].name;
    Color color = profiles[index].color;
    String? currentImagePath = profiles[index].imagePath;
    String? newImagePath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Редактировать игрока'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile Picture Section
                      GestureDetector(
                        onTap: () async {
                          final imagePath = await ImagePickerUtil.pickImage();
                          if (imagePath != null) {
                            setState(() {
                              newImagePath = imagePath;
                            });
                          }
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: color.withOpacity(0.3),
                              child: newImagePath != null
                                  ? ClipOval(
                                      child: Image.file(
                                        File(
                                            newImagePath!), // Non-null assertion is safe here as we're in a conditional
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : currentImagePath != null &&
                                          File(currentImagePath).existsSync()
                                      ? ClipOval(
                                          child: Image.file(
                                            File(
                                                currentImagePath), // Non-null assertion is safe here as we're in a conditional
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              fontSize: 32,
                                              color: Colors.white),
                                        ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 20, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Имя',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: name,
                        onChanged: (value) {
                          name = value;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Пожалуйста, введите имя';
                          }
                          return null;
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
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await _editProfile(
                        index,
                        name,
                        color,
                        imagePath: newImagePath,
                      );
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    }
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

  void _showAddProfileDialog() {
    final formKey = GlobalKey<FormState>();
    String name = '';
    Color color = Colors.primaries[0];
    String? imagePath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Добавить игрока'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile Picture Section
                      GestureDetector(
                        onTap: () async {
                          final path = await ImagePickerUtil.pickImage();
                          if (path != null) {
                            setState(() {
                              imagePath = path;
                            });
                          }
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: color.withOpacity(0.3),
                              child: imagePath != null
                                  ? ClipOval(
                                      child: Image.file(
                                        File(
                                            imagePath!), // Non-null assertion is safe here as we're in a conditional
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          fontSize: 32, color: Colors.white),
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 20, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Имя',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          name = value;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Пожалуйста, введите имя';
                          }
                          return null;
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
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await _addProfile(name, color, imagePath: imagePath);
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    }
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
                      _showAddProfileDialog();
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
                        color:
                            profile.color.withOpacity(isSelected ? 0.7 : 0.5),
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'player_profile.dart';
import 'score_board_screen.dart';
import 'services/game_repository.dart';
import 'utils/image_picker_util.dart';

class PlayerInputScreen extends StatefulWidget {
  const PlayerInputScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PlayerInputScreenState createState() => _PlayerInputScreenState();
}

class _PlayerInputScreenState extends State<PlayerInputScreen> {
  final GameRepository _repo = GameRepository.instance;

  List<PlayerProfile> profiles = [];
  List<int> selectedProfiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final loaded = await _repo.loadProfiles();
    if (!mounted) return;
    setState(() => profiles = loaded);
  }

  Future<void> _saveProfiles() async {
    await _repo.saveProfiles(profiles);
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

    // Имя — это ключ игрока в истории, поэтому переименовываем во всех играх.
    if (name != oldName) {
      await _repo.renamePlayerInGames(oldName, name);
    }
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
                              backgroundColor: color.withValues(alpha: 0.3),
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
                      final navigator = Navigator.of(context);
                      await _editProfile(
                        index,
                        name,
                        color,
                        imagePath: newImagePath,
                      );
                      navigator.pop();
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
                              backgroundColor: color.withValues(alpha: 0.3),
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
                      final navigator = Navigator.of(context);
                      await _addProfile(name, color, imagePath: imagePath);
                      navigator.pop();
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
              child: profiles.isEmpty
                  ? _emptyState(context)
                  : ListView.builder(
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        PlayerProfile profile = profiles[index];
                        bool isSelected = selectedProfiles.contains(index);
                        int selectionOrder = isSelected
                            ? selectedProfiles.indexOf(index) + 1
                            : 0;
                        return GestureDetector(
                          onLongPress: () => _showEditProfileDialog(index),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            decoration: BoxDecoration(
                              color: profile.color
                                  .withValues(alpha: isSelected ? 0.7 : 0.5),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: ListTile(
                              leading: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  profile.getAvatar(radius: 20),
                                  if (isSelected)
                                    CircleAvatar(
                                      radius: 9,
                                      backgroundColor: Colors.black87,
                                      child: Text(
                                        '$selectionOrder',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                profile.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.white)
                                  : null,
                              onTap: () => _toggleProfileSelection(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (profiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  selectedProfiles.length >= 2
                      ? 'Выбрано игроков: ${selectedProfiles.length}'
                      : 'Выберите минимум 2 игроков (нажмите по именам)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 13,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedProfiles.length >= 2
                    ? () {
                        final selectedPlayerNames = selectedProfiles
                            .map((index) => profiles[index].name)
                            .toList();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScoreBoardScreen(
                              players: selectedPlayerNames,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Начать игру'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_add, size: 72, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text('Нет игроков', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Нажмите «+» вверху, чтобы создать первого игрока.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

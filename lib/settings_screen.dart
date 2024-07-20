import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'player_profile.dart';

class GameProfile {
  String name;
  int maxPoints;
  bool winWithMaxPoints;

  GameProfile({required this.name, required this.maxPoints, required this.winWithMaxPoints});

  factory GameProfile.fromJson(Map<String, dynamic> json) {
    return GameProfile(
      name: json['name'],
      maxPoints: json['maxPoints'],
      winWithMaxPoints: json['winWithMaxPoints'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'maxPoints': maxPoints,
      'winWithMaxPoints': winWithMaxPoints,
    };
  }
}

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkTheme;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkTheme,
  });

  @override
  // ignore: library_private_types_in_public_api
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkTheme;
  double _textSize = 16.0;
  String _appVersion = 'Загрузка...';
  List<GameProfile> _gameProfiles = [];
  GameProfile? _selectedGameProfile;

  @override
  void initState() {
    super.initState();
    _isDarkTheme = widget.isDarkTheme;
    loadPreferences();
    _loadAppVersion();
    _loadGameProfiles();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? widget.isDarkTheme;
      _textSize = prefs.getDouble('textSize') ?? 16.0;
    });
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _loadGameProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesStringList = prefs.getStringList('gameProfiles');
    if (profilesStringList != null) {
      setState(() {
        _gameProfiles = profilesStringList.map((profileString) {
          return GameProfile.fromJson(jsonDecode(profileString));
        }).toList();
      });
    }
    if (_gameProfiles.isEmpty) {
      _gameProfiles.add(GameProfile(name: 'КунКен', maxPoints: 101, winWithMaxPoints: false));
      _selectedGameProfile = _gameProfiles[0];
      _saveGameProfiles();
    } else {
      final selectedProfileName = prefs.getString('selectedGameProfile');
      _selectedGameProfile = _gameProfiles.firstWhere((profile) => profile.name == selectedProfileName, orElse: () => _gameProfiles[0]);
    }
  }

  Future<void> _saveGameProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesStringList = _gameProfiles.map((profile) => jsonEncode(profile.toJson())).toList();
    await prefs.setStringList('gameProfiles', profilesStringList);
    if (_selectedGameProfile != null) {
      await prefs.setString('selectedGameProfile', _selectedGameProfile!.name);
    }
  }

  Future<void> savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', _isDarkTheme);
    await prefs.setDouble('textSize', _textSize);
  }

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkTheme = value;
      widget.onThemeChanged(value);
      savePreferences();
    });
  }

  void _updateTextSize(double value) {
    setState(() {
      _textSize = value;
      savePreferences();
    });
  }

  Future<void> _clearGameHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gameHistory');
  }

  Future<void> _resetWinCounters() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? profilesStringList = prefs.getStringList('profiles');
    if (profilesStringList != null) {
      final List<PlayerProfile> profiles = profilesStringList
          .map((profileString) => PlayerProfile.fromJson(jsonDecode(profileString)))
          .toList();
      for (var profile in profiles) {
        profile.wins = 0;
      }
      await prefs.setStringList(
        'profiles',
        profiles.map((profile) => jsonEncode(profile.toJson())).toList(),
      );
    }
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю игр?'),
        content: const Text('Это действие удалит все записи из истории игр.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              _clearGameHistory();
              Navigator.of(context).pop();
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showResetWinsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить счетчики побед?'),
        content: const Text('Это действие сбросит все счетчики побед у всех игроков.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              _resetWinCounters();
              Navigator.of(context).pop();
            },
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }

  void _showAddEditGameProfileDialog({GameProfile? profile}) {
    String name = profile?.name ?? '';
    int maxPoints = profile?.maxPoints ?? 100;
    bool winWithMaxPoints = profile?.winWithMaxPoints ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(profile == null ? 'Новый профиль игры' : 'Редактировать профиль игры'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Название'),
                  onChanged: (value) {
                    name = value;
                  },
                  controller: TextEditingController(text: name),
                  style: const TextStyle(fontSize: 14.0),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Максимальные очки'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    maxPoints = int.tryParse(value) ?? maxPoints;
                  },
                  controller: TextEditingController(text: maxPoints.toString()),
                  style: const TextStyle(fontSize: 14.0),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Победа при наборе максимальных очков',
                        style: const TextStyle(fontSize: 14.0),
                      ),
                    ),
                    Switch(
                      value: winWithMaxPoints,
                      onChanged: (value) {
                        setState(() {
                          winWithMaxPoints = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена', style: TextStyle(fontSize: 14.0)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (profile == null) {
                    _gameProfiles.add(GameProfile(name: name, maxPoints: maxPoints, winWithMaxPoints: winWithMaxPoints));
                  } else {
                    profile.name = name;
                    profile.maxPoints = maxPoints;
                    profile.winWithMaxPoints = winWithMaxPoints;
                  }
                  _saveGameProfiles();
                });
                Navigator.of(context).pop();
              },
              child: const Text('Сохранить', style: TextStyle(fontSize: 14.0)),
            ),
          ],
        );
      },
    );
  }

  void _deleteGameProfile(GameProfile profile) {
    setState(() {
      _gameProfiles.remove(profile);
      if (_selectedGameProfile == profile) {
        _selectedGameProfile = _gameProfiles.isNotEmpty ? _gameProfiles[0] : null;
      }
      _saveGameProfiles();
    });
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
        title: const Text('Настройки'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Темная тема'),
              value: _isDarkTheme,
              onChanged: _toggleTheme,
              secondary: const Icon(Icons.brightness_6),
            ),
            const SizedBox(height: 20),
            const Text('Размер текста:'),
            Slider(
              value: _textSize,
              min: 10.0,
              max: 30.0,
              divisions: 20,
              label: _textSize.toString(),
              onChanged: _updateTextSize,
            ),
            const Divider(),
            const SizedBox(height: 20),
            const Text('Профиль игры:'),
            DropdownButton<GameProfile>(
              isExpanded: true,
              value: _selectedGameProfile,
              onChanged: (GameProfile? newValue) {
                setState(() {
                  _selectedGameProfile = newValue;
                  _saveGameProfiles();
                });
              },
              items: _gameProfiles.map<DropdownMenuItem<GameProfile>>((GameProfile profile) {
                return DropdownMenuItem<GameProfile>(
                  value: profile,
                  child: Text(profile.name),
                );
              }).toList(),
            ),
            ElevatedButton(
              onPressed: () => _showAddEditGameProfileDialog(),
              style: buttonStyle,
              child: const Text('Добавить профиль игры'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _gameProfiles.length,
                itemBuilder: (context, index) {
                  final profile = _gameProfiles[index];
                  return ListTile(
                    title: Text(profile.name),
                    subtitle: Text('Максимальные очки: ${profile.maxPoints}, Победа при ${profile.winWithMaxPoints ? 'максимальных' : 'минимальных'} очках'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showAddEditGameProfileDialog(profile: profile),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteGameProfile(profile),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showResetWinsDialog,
                icon: const Icon(Icons.refresh),
                label: const Text('Сбросить счетчики побед'),
                style: buttonStyle,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showClearHistoryDialog,
                icon: const Icon(Icons.delete),
                label: const Text('Очистить историю игр'),
                style: buttonStyle,
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                'Версия приложения: $_appVersion',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

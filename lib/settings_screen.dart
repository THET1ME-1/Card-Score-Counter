import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_profile.dart';

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

  @override
  void initState() {
    super.initState();
    _isDarkTheme = widget.isDarkTheme;
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? widget.isDarkTheme;
      _textSize = prefs.getDouble('textSize') ?? 16.0;
    });
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
          ],
        ),
      ),
    );
  }
}

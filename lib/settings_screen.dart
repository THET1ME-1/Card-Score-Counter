import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'services/game_repository.dart';
import 'rules_screen.dart';

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
  final GameRepository _repo = GameRepository.instance;

  late bool _isDarkTheme;
  double _textSize = 16.0;
  String _appVersion = '…';

  @override
  void initState() {
    super.initState();
    _isDarkTheme = widget.isDarkTheme;
    _loadPreferences();
    _loadAppVersion();
  }

  Future<void> _loadPreferences() async {
    final dark = await _repo.isDarkTheme(fallback: widget.isDarkTheme);
    final size = await _repo.textSize();
    if (!mounted) return;
    setState(() {
      _isDarkTheme = dark;
      _textSize = size;
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersion = '—');
    }
  }

  void _toggleTheme(bool value) {
    setState(() => _isDarkTheme = value);
    widget.onThemeChanged(value);
    _repo.setDarkTheme(value);
  }

  void _updateTextSize(double value) {
    setState(() => _textSize = value);
    _repo.setTextSize(value);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ----------------------- Опасные действия -----------------------

  Future<void> _confirm({
    required String title,
    required String content,
    required String actionLabel,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm();
  }

  // ------------------------ Бэкап / восстановление ------------------------

  Future<void> _exportData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await _repo.exportData();
      final bytes = utf8.encode(json);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить резервную копию',
        fileName: 'scoremaster_backup.json',
        bytes: bytes,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(path == null
            ? 'Экспорт отменён'
            : 'Резервная копия сохранена'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
    }
  }

  Future<void> _importData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Выберите резервную копию',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Не удалось прочитать файл')));
        return;
      }
      final ok = await _repo.importData(utf8.decode(bytes));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? 'Данные восстановлены из копии'
            : 'Неверный формат файла резервной копии'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _sectionTitle('Внешний вид'),
          SwitchListTile(
            title: const Text('Тёмная тема'),
            value: _isDarkTheme,
            onChanged: _toggleTheme,
            secondary: const Icon(Icons.brightness_6),
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Размер текста в табло'),
            subtitle: Slider(
              value: _textSize,
              min: 10.0,
              max: 30.0,
              divisions: 20,
              label: _textSize.toStringAsFixed(0),
              onChanged: _updateTextSize,
            ),
          ),
          const Divider(height: 32),

          _sectionTitle('Данные'),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Создать резервную копию'),
            subtitle: const Text('Сохранить игроков и историю в файл'),
            onTap: _exportData,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Восстановить из копии'),
            subtitle: const Text('Заменить текущие данные данными из файла'),
            onTap: () => _confirm(
              title: 'Восстановить данные?',
              content:
                  'Текущие игроки и история будут заменены данными из файла.',
              actionLabel: 'Выбрать файл',
              onConfirm: _importData,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.refresh, color: Theme.of(context).colorScheme.error),
            title: const Text('Сбросить счётчики побед'),
            onTap: () => _confirm(
              title: 'Сбросить счётчики побед?',
              content:
                  'Это действие обнулит все счётчики побед у всех игроков.',
              actionLabel: 'Сбросить',
              onConfirm: () async {
                await _repo.resetWins();
                _snack('Счётчики побед сброшены');
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever,
                color: Theme.of(context).colorScheme.error),
            title: const Text('Очистить историю игр'),
            onTap: () => _confirm(
              title: 'Очистить историю игр?',
              content: 'Это действие удалит все записи из истории игр.',
              actionLabel: 'Удалить',
              onConfirm: () async {
                await _repo.clearGames();
                _snack('История игр очищена');
              },
            ),
          ),
          const Divider(height: 32),

          _sectionTitle('Справка'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Правила игры КунКен'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RulesScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Версия приложения: $_appVersion',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

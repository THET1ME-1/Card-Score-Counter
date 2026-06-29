import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'l10n/locale_controller.dart';
import 'l10n/strings.dart';
import 'services/game_repository.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/color_picker_sheet.dart';
import 'game_rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GameRepository _repo = GameRepository.instance;
  final ThemeController _theme = ThemeController.instance;

  double _textSize = 16.0;
  String _appVersion = '…';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAppVersion();
  }

  Future<void> _loadPreferences() async {
    final size = await _repo.textSize();
    if (!mounted) return;
    setState(() => _textSize = size);
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
    _theme.setDark(value);
    setState(() {});
  }

  void _updateTextSize(double value) {
    setState(() => _textSize = value);
    _repo.setTextSize(value);
  }

  /// Живой колор-пикер темы — настоящая панель с колесом, HEX и RGB,
  /// выезжает снизу. Единый центр цветов приложения.
  Future<void> _pickSeedColor() async {
    final result = await showColorPickerSheet(
      context,
      initial: _theme.seedColor,
      title: tr('theme_color'),
      resetTo: AppTheme.defaultSeed,
    );
    if (result == null) return;
    await _theme.setSeedColor(result);
    if (mounted) setState(() {});
  }

  /// Выбор языка интерфейса — нижняя панель с двумя вариантами.
  Future<void> _pickLanguage() async {
    final scheme = Theme.of(context).colorScheme;
    final current = LocaleController.instance.code;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            for (final lang in const [('ru', 'Русский'), ('en', 'English')])
              ListTile(
                title: Text(lang.$2),
                trailing: current == lang.$1
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, lang.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      await LocaleController.instance.setCode(picked);
      if (mounted) setState(() {});
    }
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
            child: Text(tr('cancel')),
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
        dialogTitle: tr('backup_save_dialog'),
        fileName: 'scoremaster_backup.json',
        bytes: bytes,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(path == null ? tr('export_cancelled') : tr('export_done')),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text(trf('export_error', {'e': e}))));
    }
  }

  /// Отправляет резервную копию через системный share-sheet — её можно
  /// сохранить в Google Drive / Dropbox / Mega / Telegram, что установлено.
  Future<void> _shareBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await _repo.exportData();
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/scoremaster_backup.json')
          .writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'ScoreMaster backup',
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text(trf('export_error', {'e': e}))));
    }
  }

  Future<void> _importData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: tr('backup_pick_dialog'),
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        messenger.showSnackBar(
            SnackBar(content: Text(tr('import_read_error'))));
        return;
      }
      final ok = await _repo.importData(utf8.decode(bytes));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(ok ? tr('import_done') : tr('import_bad_format')),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text(trf('import_error', {'e': e}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('settings_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // --------------------------- Внешний вид ---------------------------
          _sectionHeader(tr('appearance'), scheme.primary),
          _groupCard(scheme, [
            _row(
              scheme: scheme,
              icon: Icons.language_rounded,
              iconBg: scheme.primaryContainer,
              iconFg: scheme.onPrimaryContainer,
              title: tr('language'),
              subtitle: LocaleController.instance.code == 'en'
                  ? 'English'
                  : 'Русский',
              onTap: _pickLanguage,
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ),
            _rowDivider(scheme),
            _row(
              scheme: scheme,
              icon: _theme.isDark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              iconBg: scheme.primaryContainer,
              iconFg: scheme.onPrimaryContainer,
              title: tr('dark_theme'),
              subtitle: _theme.isDark ? tr('on') : tr('off'),
              onTap: () => _toggleTheme(!_theme.isDark),
              trailing: Switch(value: _theme.isDark, onChanged: _toggleTheme),
            ),
            _rowDivider(scheme),
            _row(
              scheme: scheme,
              icon: Icons.palette_rounded,
              iconBg: scheme.primaryContainer,
              iconFg: scheme.onPrimaryContainer,
              title: tr('theme_color'),
              subtitle: _theme.isDefaultSeed
                  ? tr('theme_color_default')
                  : colorToHex(_theme.seedColor),
              onTap: _pickSeedColor,
              trailing: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _theme.seedColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant, width: 2),
                ),
              ),
            ),
            _rowDivider(scheme),
            _textSizeRow(scheme),
          ]),

          // ----------------------------- Данные -----------------------------
          _sectionHeader(tr('data'), scheme.primary),
          _groupCard(scheme, [
            _row(
              scheme: scheme,
              icon: Icons.save_alt_rounded,
              iconBg: scheme.secondaryContainer,
              iconFg: scheme.onSecondaryContainer,
              title: tr('create_backup'),
              subtitle: tr('create_backup_sub'),
              onTap: _exportData,
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ),
            _rowDivider(scheme),
            _row(
              scheme: scheme,
              icon: Icons.cloud_upload_rounded,
              iconBg: scheme.secondaryContainer,
              iconFg: scheme.onSecondaryContainer,
              title: tr('share_backup'),
              subtitle: tr('share_backup_sub'),
              onTap: _shareBackup,
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ),
            _rowDivider(scheme),
            _row(
              scheme: scheme,
              icon: Icons.restore_rounded,
              iconBg: scheme.secondaryContainer,
              iconFg: scheme.onSecondaryContainer,
              title: tr('restore_backup'),
              subtitle: tr('restore_backup_sub'),
              onTap: () => _confirm(
                title: tr('restore_q_title'),
                content: tr('restore_q_body'),
                actionLabel: tr('choose_file'),
                onConfirm: _importData,
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ),
          ]),

          // -------------------------- Опасная зона --------------------------
          _sectionHeader(tr('danger_zone'), scheme.error),
          _groupCard(scheme, [
            _row(
              scheme: scheme,
              icon: Icons.refresh_rounded,
              iconBg: scheme.errorContainer,
              iconFg: scheme.onErrorContainer,
              title: tr('reset_wins'),
              subtitle: tr('reset_wins_sub'),
              titleColor: scheme.error,
              onTap: () => _confirm(
                title: tr('reset_wins_q_title'),
                content: tr('reset_wins_q_body'),
                actionLabel: tr('reset'),
                onConfirm: () async {
                  await _repo.resetWins();
                  _snack(tr('wins_reset_done'));
                },
              ),
            ),
            _rowDivider(scheme),
            _row(
              scheme: scheme,
              icon: Icons.delete_forever_rounded,
              iconBg: scheme.errorContainer,
              iconFg: scheme.onErrorContainer,
              title: tr('clear_history'),
              subtitle: tr('clear_history_sub'),
              titleColor: scheme.error,
              onTap: () => _confirm(
                title: tr('clear_history_q_title'),
                content: tr('clear_history_q_body'),
                actionLabel: tr('delete'),
                onConfirm: () async {
                  await _repo.clearGames();
                  _snack(tr('history_cleared_done'));
                },
              ),
            ),
          ]),

          // ----------------------------- Справка -----------------------------
          _sectionHeader(tr('help'), scheme.primary),
          _groupCard(scheme, [
            _row(
              scheme: scheme,
              icon: Icons.menu_book_rounded,
              iconBg: scheme.tertiaryContainer,
              iconFg: scheme.onTertiaryContainer,
              title: tr('rules'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GameRulesScreen()),
                );
              },
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ),
          ]),

          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  'ScoreMaster',
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trf('app_version', {'v': _appVersion}),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------- UI-хелперы -----------------------------

  Widget _sectionHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.displayFont,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: color,
        ),
      ),
    );
  }

  Widget _groupCard(ColorScheme scheme, List<Widget> children) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _rowDivider(ColorScheme scheme) => Divider(
        height: 1,
        thickness: 1,
        indent: 76,
        endIndent: 16,
        color: scheme.outlineVariant.withValues(alpha: 0.4),
      );

  Widget _iconChip(IconData icon, Color bg, Color fg) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 22, color: fg),
    );
  }

  Widget _row({
    required ColorScheme scheme,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _iconChip(icon, iconBg, iconFg),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
          ],
        ),
      ),
    );
  }

  Widget _textSizeRow(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconChip(Icons.format_size_rounded, scheme.primaryContainer,
                  scheme.onPrimaryContainer),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  tr('scoreboard_text_size'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _textSize.toStringAsFixed(0),
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _textSize,
            min: 10.0,
            max: 30.0,
            divisions: 20,
            label: _textSize.toStringAsFixed(0),
            onChanged: _updateTextSize,
          ),
        ],
      ),
    );
  }
}

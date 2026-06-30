import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'achievements_screen.dart';

import 'l10n/locale_controller.dart';
import 'l10n/strings.dart';
import 'services/game_repository.dart';
import 'services/sound_service.dart';
import 'services/update_service.dart';
import 'utils/app_version.dart';
import 'widgets/update_sheet.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/color_picker_sheet.dart';
import 'widgets/pressable.dart';
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
  bool _soundEnabled = SoundService.instance.enabled;
  bool _timerEnabled = true;
  bool _featureNotes = false;
  bool _featureFolders = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAppVersion();
  }

  Future<void> _loadPreferences() async {
    final size = await _repo.textSize();
    final timer = await _repo.timerEnabled();
    final notes = await _repo.featureNotesEnabled();
    final folders = await _repo.playerFoldersEnabled();
    if (!mounted) return;
    setState(() {
      _textSize = size;
      _timerEnabled = timer;
      _featureNotes = notes;
      _featureFolders = folders;
    });
  }

  Future<void> _loadAppVersion() async {
    // Версия — НАПРЯМУЮ из pubspec.yaml (не хардкод). Если по какой-то причине
    // не прочиталась — запасной вариант из платформенных метаданных сборки.
    var version = await appVersionFromPubspec();
    if (version.isEmpty) {
      try {
        version = (await PackageInfo.fromPlatform()).version;
      } catch (_) {
        version = '—';
      }
    }
    if (!mounted) return;
    setState(() => _appVersion = version);
  }

  void _toggleTheme(bool value) {
    _theme.setDark(value);
    setState(() {});
  }

  void _toggleSound(bool value) {
    SoundService.instance.setEnabled(value);
    setState(() => _soundEnabled = value);
    if (value) SoundService.instance.play(Sfx.point); // короткий пример
  }

  void _toggleTimer(bool value) {
    setState(() => _timerEnabled = value);
    _repo.setTimerEnabled(value);
  }

  void _toggleFeatureNotes(bool value) {
    setState(() => _featureNotes = value);
    _repo.setFeatureNotesEnabled(value);
  }

  void _toggleFeatureFolders(bool value) {
    setState(() => _featureFolders = value);
    _repo.setPlayerFoldersEnabled(value);
  }

  void _toggleDynamic(bool value) {
    _theme.setUseDynamicColor(value);
    setState(() {});
  }

  void _toggleAmoled(bool value) {
    _theme.setAmoled(value);
    setState(() {});
  }

  void _pickPreset(Color color) {
    _theme.setSeedColor(color);
    setState(() {});
  }

  /// Готовые палитры цвета оформления.
  static const List<Color> _presets = [
    AppTheme.defaultSeed, // бирюзовый
    Color(0xFF1E88E5), // синий
    Color(0xFF7E57C2), // фиолетовый
    Color(0xFF43A047), // зелёный
    Color(0xFFFB8C00), // оранжевый
    Color(0xFFE53935), // красный
    Color(0xFFEC407A), // розовый
    Color(0xFF00897B), // изумрудный
  ];

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
            for (final lang in LocaleController.languages)
              ListTile(
                title: Text(lang.nativeName),
                trailing: current == lang.code
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, lang.code),
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

  /// Ручная проверка обновления: показывает меню обновления или сообщает, что
  /// установлена последняя версия.
  Future<void> _checkUpdates() async {
    _snack(tr('check_updates'));
    final current = await appVersionName();
    final info =
        current.isEmpty ? null : await UpdateService.checkForUpdate(current);
    if (!mounted) return;
    if (info == null) {
      _snack(tr('up_to_date'));
    } else {
      await UpdateSheet.show(context, info, current);
    }
  }

  // ----------------------- Опасные действия -----------------------

  /// Подтверждение действия — нижней M3-панелью (в едином стиле приложения),
  /// а не центральным диалогом. [danger] красит главную кнопку в «опасный» цвет.
  Future<void> _confirm({
    required String title,
    required String content,
    required String actionLabel,
    required VoidCallback onConfirm,
    IconData icon = Icons.help_rounded,
    bool danger = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: danger
                          ? scheme.errorContainer
                          : scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: danger
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                content,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              PressableScale(
                child: FilledButton(
                  style: danger
                      ? FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        )
                      : null,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(actionLabel),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('cancel')),
              ),
            ],
          ),
        ),
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
      if (ok) {
        // Применяем восстановленные настройки на лету (без перезапуска).
        await _theme.load();
        await LocaleController.instance.load();
        await SoundService.instance.load();
        await _loadPreferences();
        if (mounted) {
          setState(() => _soundEnabled = SoundService.instance.enabled);
        }
      }
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
          // -------------------------- Достижения --------------------------
          _sectionHeader(tr('achievements'), scheme.primary),
          _groupCard(scheme, [
            _row(
              scheme: scheme,
              icon: Icons.emoji_events_rounded,
              iconBg: const Color(0xFFFFD700).withValues(alpha: 0.18),
              iconFg: const Color(0xFFB8860B),
              title: tr('achievements'),
              subtitle: tr('achievements_sub'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AchievementsScreen()),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ),
          ]),

          // --------------------------- Внешний вид ---------------------------
          _sectionHeader(tr('appearance'), scheme.primary),
          _groupCard(scheme, [
            _row(
              scheme: scheme,
              icon: Icons.language_rounded,
              iconBg: scheme.primaryContainer,
              iconFg: scheme.onPrimaryContainer,
              title: tr('language'),
              subtitle: LocaleController.languages
                  .firstWhere((l) => l.code == LocaleController.instance.code,
                      orElse: () => LocaleController.languages.first)
                  .nativeName,
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
            // AMOLED — только когда включена тёмная тема.
            if (_theme.isDark) ...[
              _rowDivider(scheme),
              _row(
                scheme: scheme,
                icon: Icons.contrast_rounded,
                iconBg: scheme.primaryContainer,
                iconFg: scheme.onPrimaryContainer,
                title: tr('amoled'),
                subtitle: tr('amoled_sub'),
                onTap: () => _toggleAmoled(!_theme.amoled),
                trailing:
                    Switch(value: _theme.amoled, onChanged: _toggleAmoled),
              ),
            ],
            _rowDivider(scheme),
            _row(
              scheme: scheme,
              icon: _soundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              iconBg: scheme.primaryContainer,
              iconFg: scheme.onPrimaryContainer,
              title: tr('sound'),
              subtitle: _soundEnabled ? tr('on') : tr('off'),
              onTap: () => _toggleSound(!_soundEnabled),
              trailing: Switch(value: _soundEnabled, onChanged: _toggleSound),
            ),
            _rowDivider(scheme),
            _row(
              scheme: scheme,
              icon: _timerEnabled
                  ? Icons.timer_rounded
                  : Icons.timer_off_rounded,
              iconBg: scheme.primaryContainer,
              iconFg: scheme.onPrimaryContainer,
              title: tr('timer_setting'),
              subtitle: tr('timer_setting_sub'),
              onTap: () => _toggleTimer(!_timerEnabled),
              trailing: Switch(value: _timerEnabled, onChanged: _toggleTimer),
            ),
            _rowDivider(scheme),
            _row(
              scheme: scheme,
              icon: Icons.auto_awesome_rounded,
              iconBg: scheme.primaryContainer,
              iconFg: scheme.onPrimaryContainer,
              title: tr('dynamic_color'),
              subtitle: tr('dynamic_color_sub'),
              onTap: () => _toggleDynamic(!_theme.useDynamicColor),
              trailing: Switch(
                value: _theme.useDynamicColor,
                onChanged: _toggleDynamic,
              ),
            ),
            // Свой цвет оформления — только когда Material You выключен.
            if (!_theme.useDynamicColor) ...[
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
                    border:
                        Border.all(color: scheme.outlineVariant, width: 2),
                  ),
                ),
              ),
              _presetsRow(scheme),
            ],
            _rowDivider(scheme),
            _textSizeRow(scheme),
          ]),

          // ----------------------------- Функции -----------------------------
          _sectionHeader(tr('features'), scheme.primary),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              tr('features_sub'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _groupCard(scheme, [
            _row(
              scheme: scheme,
              icon: Icons.sticky_note_2_rounded,
              iconBg: scheme.primaryContainer,
              iconFg: scheme.onPrimaryContainer,
              title: tr('feature_notes'),
              subtitle: tr('feature_notes_sub'),
              onTap: () => _toggleFeatureNotes(!_featureNotes),
              trailing: Switch(
                value: _featureNotes,
                onChanged: _toggleFeatureNotes,
              ),
            ),
            _rowDivider(scheme),
            _row(
              scheme: scheme,
              icon: Icons.folder_rounded,
              iconBg: scheme.primaryContainer,
              iconFg: scheme.onPrimaryContainer,
              title: tr('feature_folders'),
              subtitle: tr('feature_folders_sub'),
              onTap: () => _toggleFeatureFolders(!_featureFolders),
              trailing: Switch(
                value: _featureFolders,
                onChanged: _toggleFeatureFolders,
              ),
            ),
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
                icon: Icons.restore_rounded,
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
                icon: Icons.refresh_rounded,
                danger: true,
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
                icon: Icons.delete_forever_rounded,
                danger: true,
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
              icon: Icons.system_update_rounded,
              iconBg: scheme.tertiaryContainer,
              iconFg: scheme.onTertiaryContainer,
              title: tr('check_updates'),
              subtitle: tr('check_updates_sub'),
              onTap: _checkUpdates,
              trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ),
            _rowDivider(scheme),
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

  /// Ряд готовых палитр: тапнул кружок — сменился цвет оформления. Выбранный
  /// обведён и с галочкой.
  Widget _presetsRow(ColorScheme scheme) {
    final current = _theme.seedColor.toARGB32();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 14),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              tr('theme_presets'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final c in _presets)
                  _PresetDot(
                    color: c,
                    selected: c.toARGB32() == current,
                    onTap: () => _pickPreset(c),
                  ),
              ],
            ),
          ),
        ],
      ),
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

/// Кружок-палитра в ряду пресетов: при выборе обведён кольцом и с галочкой.
class _PresetDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PresetDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Контрастная галочка для светлых/тёмных цветов.
    final check = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: AppTheme.emphasized,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? Icon(Icons.check_rounded, size: 18, color: check)
            : null,
      ),
    );
  }
}

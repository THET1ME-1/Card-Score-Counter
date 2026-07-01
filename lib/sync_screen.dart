import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'services/sound_service.dart';
import 'services/sync/backup_folder_service.dart';
import 'services/sync/sync_merge.dart';
import 'services/sync/webdav_service.dart';
import 'sync_p2p_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'l10n/locale_controller.dart';

/// Экран «Синхронизация» — центр всех трёх способов уберечь данные:
/// авто-бэкап в папку/облако (SAF), двусторонний WebDAV-синк и обмен по Wi-Fi
/// (QR). Все три построены на одном ядре снимка/слияния.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _folder = BackupFolderService.instance;
  final _webdav = WebdavService.instance;

  // Папка
  String? _folderName;
  bool _folderAuto = true;
  DateTime? _folderLast;
  bool _folderBusy = false;

  // WebDAV
  bool _webdavConfigured = false;
  bool _webdavAuto = true;
  DateTime? _webdavLast;
  bool _webdavBusy = false;
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final fName = await _folder.folderName();
    final fAuto = await _folder.autoEnabled();
    final fLast = await _folder.lastBackupAt();
    final wConf = await _webdav.isConfigured();
    final wAuto = await _webdav.autoEnabled();
    final wLast = await _webdav.lastSyncAt();
    _urlCtrl.text = await _webdav.url() ?? '';
    _userCtrl.text = await _webdav.user() ?? '';
    _passCtrl.text = await _webdav.password() ?? '';
    if (!mounted) return;
    setState(() {
      _folderName = fName;
      _folderAuto = fAuto;
      _folderLast = fLast;
      _webdavConfigured = wConf;
      _webdavAuto = wAuto;
      _webdavLast = wLast;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return tr('sync_never');
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  String _statsText(SyncStats s) {
    if (!s.changed) return tr('sync_up_to_date');
    return trf('sync_result',
        {'a': s.addedGames + s.newProfiles, 'u': s.updatedGames, 'd': s.deletedGames});
  }

  // Применяем настройки, приехавшие с восстановлением/синком (тема/язык/звук).
  Future<void> _reloadAppState() async {
    await ThemeController.instance.load();
    await LocaleController.instance.load();
    await SoundService.instance.load();
  }

  // ----------------------------- Папка -----------------------------

  Future<void> _chooseFolder() async {
    setState(() => _folderBusy = true);
    try {
      final ok = await _folder.chooseFolder();
      if (ok) {
        await _folder.backupNow();
        _snack(tr('backup_done'));
      }
    } catch (e) {
      _snack(trf('sync_error', {'e': e}));
    } finally {
      await _load();
      if (mounted) setState(() => _folderBusy = false);
    }
  }

  Future<void> _backupNow() async {
    setState(() => _folderBusy = true);
    try {
      await _folder.backupNow();
      _snack(tr('backup_done'));
    } catch (e) {
      _snack(trf('sync_error', {'e': e}));
    } finally {
      await _load();
      if (mounted) setState(() => _folderBusy = false);
    }
  }

  Future<void> _restoreFolder() async {
    final ok = await _confirm(tr('restore_from_folder'), tr('restore_folder_q'));
    if (ok != true) return;
    setState(() => _folderBusy = true);
    try {
      final done = await _folder.restoreFromFolder();
      if (done) {
        await _reloadAppState();
        _snack(tr('import_done'));
      } else {
        _snack(tr('no_backup_in_folder'));
      }
    } catch (e) {
      _snack(trf('sync_error', {'e': e}));
    } finally {
      if (mounted) setState(() => _folderBusy = false);
    }
  }

  // ----------------------------- WebDAV -----------------------------

  Future<void> _connectWebdav() async {
    if (_urlCtrl.text.trim().isEmpty) return;
    setState(() => _webdavBusy = true);
    try {
      await _webdav.saveConfig(
        url: _urlCtrl.text,
        user: _userCtrl.text,
        password: _passCtrl.text,
      );
      await _webdav.testConnection();
      final stats = await _webdav.sync();
      await _reloadAppState();
      _snack('${tr('webdav_connected')} · ${_statsText(stats)}');
    } catch (e) {
      _snack(tr('webdav_bad'));
    } finally {
      await _load();
      if (mounted) setState(() => _webdavBusy = false);
    }
  }

  Future<void> _syncWebdav() async {
    setState(() => _webdavBusy = true);
    try {
      final stats = await _webdav.sync();
      await _reloadAppState();
      _snack(_statsText(stats));
    } catch (e) {
      _snack(trf('sync_error', {'e': e}));
    } finally {
      await _load();
      if (mounted) setState(() => _webdavBusy = false);
    }
  }

  Future<void> _forgetWebdav() async {
    await _webdav.forget();
    _urlCtrl.clear();
    _userCtrl.clear();
    _passCtrl.clear();
    await _load();
  }

  Future<bool?> _confirm(String title, String body) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('sync_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text(
              tr('sync_intro'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 14,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _folderCard(scheme),
          const SizedBox(height: 14),
          _webdavCard(scheme),
          const SizedBox(height: 14),
          _p2pCard(scheme),
        ],
      ),
    );
  }

  // ------------------------------ Карточки ------------------------------

  Widget _cardShell(
    ColorScheme scheme, {
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconFg, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: scheme.onSurface,
                      ),
                    ),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _statusChip(ColorScheme scheme, String text, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _fill(ColorScheme scheme, IconData icon, String label,
      VoidCallback? onTap,
      {bool tonal = false, bool busy = false}) {
    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final style = tonal
        ? FilledButton.tonal(onPressed: busy ? null : onTap, child: child)
        : FilledButton(onPressed: busy ? null : onTap, child: child);
    return SizedBox(width: double.infinity, child: style);
  }

  Widget _folderCard(ColorScheme scheme) {
    final configured = _folderName != null;
    return _cardShell(
      scheme,
      icon: Icons.cloud_sync_rounded,
      iconBg: scheme.secondaryContainer,
      iconFg: scheme.onSecondaryContainer,
      title: tr('backup_folder'),
      subtitle: tr('backup_folder_sub'),
      children: [
        Text(
          tr('backup_folder_how'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13,
            height: 1.3,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (configured) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(scheme, trf('folder_label', {'name': _folderName!}),
                  active: true),
              _statusChip(scheme, trf('sync_last', {'t': _fmtTime(_folderLast)})),
            ],
          ),
          const SizedBox(height: 12),
          _fill(scheme, Icons.backup_rounded, tr('backup_now'), _backupNow,
              busy: _folderBusy),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _fill(scheme, Icons.restore_rounded,
                    tr('restore_from_folder'), _restoreFolder,
                    tonal: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _fill(scheme, Icons.folder_open_rounded,
                    tr('change_folder'), _chooseFolder,
                    tonal: true),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('auto_backup_toggle'),
                style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 14,
                    color: scheme.onSurface)),
            value: _folderAuto,
            onChanged: (v) async {
              await _folder.setAutoEnabled(v);
              setState(() => _folderAuto = v);
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await _folder.forget();
                await _load();
              },
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: Text(tr('disconnect')),
            ),
          ),
        ] else
          _fill(scheme, Icons.create_new_folder_rounded, tr('choose_folder'),
              _chooseFolder,
              busy: _folderBusy),
      ],
    );
  }

  Widget _webdavCard(ColorScheme scheme) {
    return _cardShell(
      scheme,
      icon: Icons.dns_rounded,
      iconBg: scheme.tertiaryContainer,
      iconFg: scheme.onTertiaryContainer,
      title: tr('webdav'),
      subtitle: tr('webdav_sub'),
      children: [
        Text(
          tr('webdav_how'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13,
            height: 1.3,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (_webdavConfigured) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(scheme, tr('webdav_connected'), active: true),
              _statusChip(scheme, trf('sync_last', {'t': _fmtTime(_webdavLast)})),
            ],
          ),
          const SizedBox(height: 12),
          _fill(scheme, Icons.sync_rounded, tr('sync_now'), _syncWebdav,
              busy: _webdavBusy),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('auto_sync_toggle'),
                style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 14,
                    color: scheme.onSurface)),
            value: _webdavAuto,
            onChanged: (v) async {
              await _webdav.setAutoEnabled(v);
              setState(() => _webdavAuto = v);
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _forgetWebdav,
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: Text(tr('disconnect')),
            ),
          ),
        ] else ...[
          _field(scheme, _urlCtrl, tr('webdav_url'),
              hint: 'https://webdav.yandex.ru'),
          const SizedBox(height: 8),
          _field(scheme, _userCtrl, tr('webdav_user')),
          const SizedBox(height: 8),
          _field(scheme, _passCtrl, tr('webdav_pass'), obscure: true),
          const SizedBox(height: 12),
          _fill(scheme, Icons.link_rounded, tr('connect'), _connectWebdav,
              busy: _webdavBusy),
        ],
      ],
    );
  }

  Widget _field(ColorScheme scheme, TextEditingController ctrl, String label,
      {String? hint, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        isDense: true,
      ),
    );
  }

  Widget _p2pCard(ColorScheme scheme) {
    return _cardShell(
      scheme,
      icon: Icons.wifi_tethering_rounded,
      iconBg: scheme.primaryContainer,
      iconFg: scheme.onPrimaryContainer,
      title: tr('p2p'),
      subtitle: tr('p2p_sub'),
      children: [
        Text(
          tr('p2p_how'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13,
            height: 1.3,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _fill(scheme, Icons.qr_code_2_rounded, tr('p2p_show'), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SyncP2pScreen(host: true)),
                );
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _fill(scheme, Icons.qr_code_scanner_rounded, tr('p2p_scan'),
                  () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SyncP2pScreen(host: false)),
                );
                await _reloadAppState();
                if (mounted) setState(() {});
              }, tonal: true),
            ),
          ],
        ),
      ],
    );
  }
}

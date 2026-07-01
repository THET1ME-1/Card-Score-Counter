import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game_repository.dart';

/// Транспорт A — авто-бэкап полного снимка в выбранную пользователем папку
/// (Storage Access Framework). Если указать папку, которую синхронизирует
/// облачное приложение (Google Drive / Dropbox / Nextcloud / Яндекс.Диск), —
/// получается облачный бэкап без секретов в коде.
///
/// Это односторонний бэкап (перезаписываем один файл), а не двусторонний синк.
/// Восстановление — полная замена данных (как обычный «Восстановить из копии»).
class BackupFolderService {
  BackupFolderService._();
  static final BackupFolderService instance = BackupFolderService._();

  static const _kFolderUri = 'backupFolderUri';
  static const _kFolderName = 'backupFolderName';
  static const _kLastBackupAt = 'backupLastAt';
  static const _kAutoBackup = 'backupAuto';
  static const _fileName = 'scoremaster-backup.json';

  final SafUtil _saf = SafUtil();
  final SafStream _stream = SafStream();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> folderUri() async => (await _prefs).getString(_kFolderUri);
  Future<String?> folderName() async => (await _prefs).getString(_kFolderName);
  Future<bool> isConfigured() async => (await folderUri()) != null;

  Future<bool> autoEnabled() async =>
      (await _prefs).getBool(_kAutoBackup) ?? true;
  Future<void> setAutoEnabled(bool value) async =>
      (await _prefs).setBool(_kAutoBackup, value);

  Future<DateTime?> lastBackupAt() async {
    final ms = (await _prefs).getInt(_kLastBackupAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Просит пользователя выбрать папку (постоянный доступ на запись). Возвращает
  /// true, если папка выбрана.
  Future<bool> chooseFolder() async {
    final dir = await _saf.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    if (dir == null) return false;
    final prefs = await _prefs;
    await prefs.setString(_kFolderUri, dir.uri);
    await prefs.setString(_kFolderName, dir.name);
    return true;
  }

  Future<void> forget() async {
    final prefs = await _prefs;
    await prefs.remove(_kFolderUri);
    await prefs.remove(_kFolderName);
    await prefs.remove(_kLastBackupAt);
  }

  /// Пишет полный бэкап в выбранную папку (перезаписывает файл). Бросает при
  /// ошибке — вызывающий показывает её пользователю.
  Future<void> backupNow() async {
    final uri = await folderUri();
    if (uri == null) throw StateError('Папка для бэкапа не выбрана');
    final json = await GameRepository.instance.exportData();
    final bytes = Uint8List.fromList(utf8.encode(json));
    await _stream.writeFileBytes(
      uri,
      _fileName,
      'application/json',
      bytes,
      overwrite: true,
    );
    await (await _prefs)
        .setInt(_kLastBackupAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Тихий авто-бэкап (например, при сворачивании приложения): не бросает,
  /// возвращает true при успехе.
  Future<bool> backupSilently() async {
    try {
      if (!await isConfigured()) return false;
      if (!await autoEnabled()) return false;
      await backupNow();
      return true;
    } catch (e) {
      debugPrint('ScoreMaster: авто-бэкап в папку не удался: $e');
      return false;
    }
  }

  /// Восстанавливает данные из файла бэкапа в выбранной папке (полная замена).
  /// Возвращает true при успехе, false если файла нет или формат не распознан.
  Future<bool> restoreFromFolder() async {
    final uri = await folderUri();
    if (uri == null) return false;
    final child = await _saf.child(uri, [_fileName]);
    if (child == null) return false;
    final bytes = await _stream.readFileBytes(child.uri);
    return GameRepository.instance.importData(utf8.decode(bytes));
  }
}

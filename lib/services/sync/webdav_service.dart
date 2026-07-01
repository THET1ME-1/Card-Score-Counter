import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../game_repository.dart';
import 'sync_merge.dart';

/// Транспорт B — двусторонняя синхронизация через WebDAV (Nextcloud, ownCloud,
/// Яндекс.Диск и любой WebDAV-сервер). Данные пользователя лежат на ЕГО сервере,
/// секретов в коде нет.
///
/// Один цикл синка: скачать удалённый снимок → слить с локальным → залить
/// объединённый обратно. Настройки подключения храним локально (в бэкап и в
/// синк они НЕ входят).
class WebdavService {
  WebdavService._();
  static final WebdavService instance = WebdavService._();

  static const _kUrl = 'webdavUrl';
  static const _kUser = 'webdavUser';
  static const _kPass = 'webdavPass';
  static const _kAuto = 'webdavAuto';
  static const _kLastAt = 'webdavLastAt';
  static const _dir = '/ScoreMaster';
  static const _file = '/ScoreMaster/sync.json';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> url() async => (await _prefs).getString(_kUrl);
  Future<String?> user() async => (await _prefs).getString(_kUser);
  Future<String?> password() async => (await _prefs).getString(_kPass);
  Future<bool> isConfigured() async => ((await url()) ?? '').isNotEmpty;

  Future<bool> autoEnabled() async => (await _prefs).getBool(_kAuto) ?? true;
  Future<void> setAutoEnabled(bool value) async =>
      (await _prefs).setBool(_kAuto, value);

  Future<DateTime?> lastSyncAt() async {
    final ms = (await _prefs).getInt(_kLastAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> saveConfig({
    required String url,
    required String user,
    required String password,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_kUrl, url.trim());
    await prefs.setString(_kUser, user.trim());
    await prefs.setString(_kPass, password);
  }

  Future<void> forget() async {
    final prefs = await _prefs;
    for (final k in [_kUrl, _kUser, _kPass, _kLastAt]) {
      await prefs.remove(k);
    }
  }

  Future<webdav.Client> _client() async {
    final c = webdav.newClient(
      (await url()) ?? '',
      user: (await user()) ?? '',
      password: (await password()) ?? '',
    );
    c.setConnectTimeout(15000);
    c.setSendTimeout(30000);
    c.setReceiveTimeout(30000);
    return c;
  }

  /// Проверка соединения (для кнопки «Подключить»). Бросает при ошибке.
  Future<void> testConnection() async {
    final c = await _client();
    await c.ping();
  }

  /// Полный цикл синка. Возвращает статистику локальных изменений.
  Future<SyncStats> sync() async {
    final c = await _client();
    // Каталог на сервере (если уже есть — ошибку игнорируем).
    try {
      await c.mkdirAll(_dir);
    } catch (_) {}
    // Скачиваем удалённый снимок, если он есть.
    Map<String, dynamic> remote = {};
    try {
      final bytes = await c.read(_file);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic> && decoded['kind'] == kSyncKind) {
        remote = decoded;
      }
    } catch (_) {
      // Файла ещё нет — это первый синк, remote остаётся пустым.
    }
    final stats = await GameRepository.instance.mergeSyncSnapshot(remote);
    // Заливаем объединённый снимок обратно.
    final merged = await GameRepository.instance.buildSyncSnapshot();
    final data = Uint8List.fromList(utf8.encode(jsonEncode(merged)));
    await c.write(_file, data);
    await (await _prefs)
        .setInt(_kLastAt, DateTime.now().millisecondsSinceEpoch);
    return stats;
  }

  /// Тихий авто-синк (при старте/выходе): не бросает, возвращает null при
  /// ошибке или если выключен.
  Future<SyncStats?> syncSilently() async {
    try {
      if (!await isConfigured() || !await autoEnabled()) return null;
      return await sync();
    } catch (e) {
      debugPrint('ScoreMaster: WebDAV авто-синк не удался: $e');
      return null;
    }
  }
}

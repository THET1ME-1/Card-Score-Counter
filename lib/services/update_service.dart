import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Данные о доступном обновлении с GitHub Releases.
class UpdateInfo {
  final String version; // тег без «v», напр. «1.0.1»
  final String notes; // тело релиза (описание)
  final String? apkUrl; // прямая ссылка на .apk-ассет (или null)
  final String releaseUrl; // страница релиза на GitHub

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.releaseUrl,
  });
}

/// Проверка обновлений приложения по последнему релизу на GitHub и загрузка
/// APK для установки (sideload-обновление, без магазинов).
class UpdateService {
  UpdateService._();

  // Репозиторий с релизами приложения.
  static const String _owner = 'THET1ME-1';
  static const String _repo = 'Card-Score-Counter';

  static Uri get _latestReleaseUri =>
      Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest');

  /// Возвращает [UpdateInfo], если на GitHub есть релиз новее [currentVersion];
  /// иначе null (в т.ч. при отсутствии сети или ошибке — молча).
  static Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(_latestReleaseUri);
      // GitHub API требует User-Agent, иначе 403.
      request.headers.set(HttpHeaders.userAgentHeader, 'ScoreMaster-Updater');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] ?? '').toString();
      final latest = _normalize(tag);
      if (latest.isEmpty) return null;

      if (!_isNewer(latest, _normalize(currentVersion))) return null;

      String? apkUrl;
      final assets = json['assets'];
      if (assets is List) {
        for (final a in assets) {
          final name = (a['name'] ?? '').toString().toLowerCase();
          if (name.endsWith('.apk')) {
            apkUrl = (a['browser_download_url'] ?? '').toString();
            break;
          }
        }
      }

      return UpdateInfo(
        version: latest,
        notes: (json['body'] ?? '').toString().trim(),
        apkUrl: (apkUrl != null && apkUrl.isNotEmpty) ? apkUrl : null,
        releaseUrl: (json['html_url'] ??
                'https://github.com/$_owner/$_repo/releases/latest')
            .toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Скачивает APK по ссылке во временный файл, дёргая [onProgress] (0..1).
  /// Возвращает путь к файлу или null при ошибке.
  static Future<String?> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'ScoreMaster-Updater');
      final response = await request.close(); // редиректы следуются по умолчанию
      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      // Внешняя app-папка надёжнее открывается системным установщиком; если
      // недоступна — временная.
      final dir =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final file = File('${dir.path}/scoremaster_update.apk');
      if (await file.exists()) await file.delete();
      final sink = file.openWrite();

      final total = response.contentLength; // может быть -1
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress((received / total).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
      await sink.close();
      client.close();
      onProgress?.call(1.0);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// «1.0.10» > «1.0.2» (числовое сравнение по компонентам).
  static bool _isNewer(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static List<int> _parts(String v) =>
      v.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();

  /// Убираем ведущую «v» и лишнее: «v1.0.1» → «1.0.1».
  static String _normalize(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    return s;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:network_info_plus/network_info_plus.dart';

import '../game_repository.dart';
import 'sync_merge.dart';

/// Запущенный «хост» P2P-обмена: держит локальный HTTP-сервер и знает свой
/// адрес/токен для показа в QR.
class P2pHost {
  final HttpServer _server;
  final StreamController<SyncStats> _controller;
  final String ip;
  final int port;
  final String token;

  P2pHost._(this._server, this._controller, this.ip, this.port, this.token);

  /// Событие каждый раз, когда гость успешно синхронизировался с нами.
  Stream<SyncStats> get onSynced => _controller.stream;

  /// Данные для QR-кода, которые сканирует второе устройство.
  String get qrData => '${P2pService.scheme}://$ip:$port/$token';

  Future<void> stop() async {
    await _server.close(force: true);
    if (!_controller.isClosed) await _controller.close();
  }
}

/// Транспорт C — прямой обмен между устройствами по локальной сети (одному
/// Wi-Fi), без сервера и аккаунтов. Пары через QR: хост показывает код, гость
/// сканирует и шлёт свой снимок; обе стороны сливают данные.
///
/// dart:io-сокеты не подпадают под запрет cleartext-трафика Android, поэтому
/// обычного http по локальной сети достаточно.
class P2pService {
  P2pService._();
  static final P2pService instance = P2pService._();

  static const String scheme = 'smsync';

  /// Запускает хост: поднимает сервер на случайном порту, генерит токен, узнаёт
  /// Wi-Fi-адрес. Бросает, если нет Wi-Fi.
  Future<P2pHost> startHost() async {
    final ip = await NetworkInfo().getWifiIP();
    if (ip == null || ip.isEmpty) {
      throw const P2pException(
          'Нет Wi-Fi. Подключите оба телефона к одной сети.');
    }
    final rnd = Random.secure();
    final token =
        List.generate(10, (_) => rnd.nextInt(16).toRadixString(16)).join();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final controller = StreamController<SyncStats>.broadcast();

    server.listen((HttpRequest req) async {
      try {
        final ok = req.method == 'POST' &&
            req.uri.path == '/sync' &&
            req.uri.queryParameters['token'] == token;
        if (!ok) {
          req.response.statusCode = HttpStatus.forbidden;
          await req.response.close();
          return;
        }
        final body = await utf8.decoder.bind(req).join();
        final decoded = jsonDecode(body);
        final guest =
            decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
        final stats = await GameRepository.instance.mergeSyncSnapshot(guest);
        final merged = await GameRepository.instance.buildSyncSnapshot();
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(merged));
        await req.response.close();
        if (!controller.isClosed) controller.add(stats);
      } catch (_) {
        try {
          req.response.statusCode = HttpStatus.internalServerError;
          await req.response.close();
        } catch (_) {}
      }
    });

    return P2pHost._(server, controller, ip, server.port, token);
  }

  /// Гость: шлёт свой снимок хосту и сливает его ответ. Возвращает статистику
  /// изменений на СВОЁМ устройстве.
  Future<SyncStats> connectAndSync(String ip, int port, String token) async {
    final snap = await GameRepository.instance.buildSyncSnapshot();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client
          .postUrl(Uri.parse('http://$ip:$port/sync?token=$token'));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(snap)));
      final resp = await req.close().timeout(const Duration(seconds: 30));
      if (resp.statusCode != HttpStatus.ok) {
        throw P2pException('Хост ответил ${resp.statusCode}');
      }
      final body = await utf8.decoder.bind(resp).join();
      final decoded = jsonDecode(body);
      final host =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      return await GameRepository.instance.mergeSyncSnapshot(host);
    } finally {
      client.close(force: true);
    }
  }

  /// Разбирает данные из QR: smsync://ip:port/token. null — если формат не тот.
  ({String ip, int port, String token})? parse(String data) {
    try {
      final uri = Uri.parse(data.trim());
      if (uri.scheme != scheme) return null;
      final ip = uri.host;
      final port = uri.port;
      final token = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (ip.isEmpty || port == 0 || token.isEmpty) return null;
      return (ip: ip, port: port, token: token);
    } catch (_) {
      return null;
    }
  }
}

class P2pException implements Exception {
  final String message;
  const P2pException(this.message);
  @override
  String toString() => message;
}

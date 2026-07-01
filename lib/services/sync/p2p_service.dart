import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

  /// Локальный LAN-адрес устройства. Определяем через список сетевых
  /// интерфейсов (dart:io), а не через WifiManager — тот на MIUI/Android 12+ и
  /// при нескольких интерфейсах часто отдаёт null или чужой IP. Предпочитаем
  /// Wi-Fi (`wlan`), исключаем USB-tether/VPN/loopback.
  Future<String?> localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      String? fallback;
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('rndis') ||
            name.contains('usb') ||
            name.contains('tun') ||
            name.contains('ppp') ||
            name.contains('dummy') ||
            name.contains('p2p')) {
          continue; // не-LAN интерфейсы
        }
        for (final addr in iface.addresses) {
          if (!_isPrivateV4(addr.address)) continue;
          if (name.contains('wlan') || name.contains('wifi')) {
            return addr.address; // Wi-Fi — самый предпочтительный
          }
          fallback ??= addr.address;
        }
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  static bool _isPrivateV4(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    final m = RegExp(r'^172\.(\d{1,3})\.').firstMatch(ip);
    if (m != null) {
      final o = int.tryParse(m.group(1)!) ?? 0;
      return o >= 16 && o <= 31;
    }
    return false;
  }

  /// Запускает хост: поднимает сервер на случайном порту, генерит токен, узнаёт
  /// LAN-адрес. Бросает, если устройство не в локальной сети.
  Future<P2pHost> startHost() async {
    final ip = await localIp();
    if (ip == null || ip.isEmpty) {
      throw const P2pException(
          'Нет Wi-Fi. Подключите оба телефона к одной сети.');
    }
    final rnd = Random.secure();
    final token =
        List.generate(10, (_) => rnd.nextInt(16).toRadixString(16)).join();
    // Биндим на конкретный адрес интерфейса — так сервер слушает ровно там, где
    // мы показываем QR. Фолбэк на 0.0.0.0, если конкретный адрес не удался.
    HttpServer server;
    try {
      server = await HttpServer.bind(ip, 0, shared: true);
    } catch (_) {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    }
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

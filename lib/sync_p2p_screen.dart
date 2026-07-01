import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'l10n/strings.dart';
import 'services/sync/p2p_service.dart';
import 'services/sync/sync_merge.dart';
import 'theme/app_theme.dart';

/// Экран P2P-обмена по Wi-Fi. Два режима:
///   host=true  — показывает QR-код (это устройство ждёт подключения),
///   host=false — сканирует QR другого устройства и синхронизируется.
class SyncP2pScreen extends StatefulWidget {
  final bool host;
  const SyncP2pScreen({super.key, required this.host});

  @override
  State<SyncP2pScreen> createState() => _SyncP2pScreenState();
}

class _SyncP2pScreenState extends State<SyncP2pScreen> {
  final _p2p = P2pService.instance;

  // Хост
  P2pHost? _host;
  String? _error;
  StreamSubscription<SyncStats>? _sub;

  // Общий результат синка
  SyncStats? _result;

  // Гость
  MobileScannerController? _scanner;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    if (widget.host) {
      _startHost();
    } else {
      _scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  Future<void> _startHost() async {
    try {
      final host = await _p2p.startHost();
      if (!mounted) {
        await host.stop();
        return;
      }
      setState(() => _host = host);
      _sub = host.onSynced.listen((stats) {
        if (mounted) setState(() => _result = stats);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _host?.stop();
    _scanner?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final parsed = _p2p.parse(raw);
      if (parsed == null) continue;
      _handling = true;
      _scanner?.stop();
      _connect(parsed.ip, parsed.port, parsed.token);
      return;
    }
  }

  Future<void> _connect(String ip, int port, String token) async {
    setState(() {}); // покажем «соединение…»
    try {
      final stats = await _p2p.connectAndSync(ip, port, token);
      if (mounted) setState(() => _result = stats);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
        _handling = false;
      }
    }
  }

  String _statsText(SyncStats s) {
    if (!s.changed) return tr('sync_up_to_date');
    return trf('sync_result', {
      'a': s.addedGames + s.newProfiles,
      'u': s.updatedGames,
      'd': s.deletedGames
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.host ? tr('p2p_show') : tr('p2p_scan')),
      ),
      body: _result != null
          ? _successView(scheme)
          : widget.host
              ? _hostView(scheme)
              : _guestView(scheme),
    );
  }

  Widget _successView(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 96, color: scheme.primary),
            const SizedBox(height: 20),
            Text(
              tr('p2p_synced'),
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statsText(_result!),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 15,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('done')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hostView(ColorScheme scheme) {
    if (_error != null) return _errorView(scheme, _error!);
    if (_host == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QrImageView(
                data: _host!.qrData,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('p2p_show_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 15,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('p2p_waiting'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _guestView(ColorScheme scheme) {
    if (_error != null) return _errorView(scheme, _error!);
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _scanner,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _errorView(
            scheme,
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? tr('p2p_no_camera')
                : '${error.errorCode}',
          ),
        ),
        // Рамка-визир.
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _handling ? tr('p2p_connecting') : tr('p2p_scan_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorView(ColorScheme scheme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 15,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('done')),
            ),
          ],
        ),
      ),
    );
  }
}

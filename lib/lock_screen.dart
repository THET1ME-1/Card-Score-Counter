import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'l10n/strings.dart';
import 'services/game_repository.dart';
import 'widgets/pin_pad.dart';

/// Экран блокировки на входе: PIN + (если включено) биометрия.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final GameRepository _repo = GameRepository.instance;
  final LocalAuthentication _auth = LocalAuthentication();
  int _errorTick = 0;
  bool _biometricOn = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    final on = await _repo.lockBiometric();
    if (!mounted) return;
    setState(() => _biometricOn = on);
    if (on) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    try {
      final can = await _auth.isDeviceSupported();
      if (!can) return;
      final ok = await _auth.authenticate(
        localizedReason: tr('lock_biometric_reason'),
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {
      // Биометрия недоступна/отменена — остаётся PIN.
    }
  }

  Future<void> _check(String pin) async {
    if (await _repo.verifyPin(pin)) {
      if (mounted) widget.onUnlocked();
    } else {
      if (mounted) setState(() => _errorTick++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded,
                      size: 34, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 24),
                PinPad(
                  title: tr('lock_title'),
                  subtitle: _errorTick > 0 ? tr('lock_wrong') : null,
                  errorTick: _errorTick,
                  onCompleted: _check,
                  onBiometric: _biometricOn ? _tryBiometric : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Экран создания/смены PIN: ввод и подтверждение. Возвращает новый PIN
/// (Navigator.pop) или null при отмене.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;
  int _errorTick = 0;

  void _onCompleted(String pin) {
    if (_first == null) {
      setState(() => _first = pin);
    } else if (_first == pin) {
      Navigator.pop(context, pin);
    } else {
      setState(() {
        _first = null;
        _errorTick++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('feature_lock'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: PinPad(
              key: ValueKey(_first == null), // сброс панели между шагами
              title: _first == null ? tr('lock_create') : tr('lock_confirm'),
              subtitle: _errorTick > 0 ? tr('lock_mismatch') : null,
              errorTick: _errorTick,
              onCompleted: _onCompleted,
            ),
          ),
        ),
      ),
    );
  }
}

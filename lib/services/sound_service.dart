import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'game_repository.dart';

/// Звуковые эффекты приложения.
enum Sfx { win, eliminate, point }

/// Проигрывание коротких звуков + тактильная отдача на ключевых событиях.
/// Звук можно отключить в Настройках; вибрация остаётся всегда.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;
  bool _loaded = false;

  static const Map<Sfx, String> _assets = {
    Sfx.win: 'sounds/win.mp3',
    Sfx.eliminate: 'sounds/eliminate.mp3',
    Sfx.point: 'sounds/point.mp3',
  };

  Future<void> load() async {
    _enabled = await GameRepository.instance.soundEnabled();
    _loaded = true;
  }

  bool get enabled => _enabled;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    _loaded = true;
    await GameRepository.instance.setSoundEnabled(value);
  }

  /// Проигрывает эффект [sfx]. Тактильная отдача срабатывает независимо от
  /// настройки звука (если [haptic] не выключен явно).
  Future<void> play(Sfx sfx, {bool haptic = true}) async {
    if (haptic) {
      switch (sfx) {
        case Sfx.win:
          HapticFeedback.heavyImpact();
        case Sfx.eliminate:
          HapticFeedback.mediumImpact();
        case Sfx.point:
          HapticFeedback.selectionClick();
      }
    }
    if (!_loaded) await load();
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(_assets[sfx]!));
    } catch (_) {
      // Звук — не критично: молча игнорируем сбои воспроизведения.
    }
  }
}

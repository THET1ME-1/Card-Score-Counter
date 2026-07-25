/// Часы партии: считают время всей партии, время текущего хода и время
/// каждого игрока.
///
/// Время меряется по настенным часам (`DateTime.now`), а не по счётчику
/// кадров, поэтому идёт и когда приложение свёрнуто — партия за столом не
/// останавливается оттого, что кто-то заглянул в мессенджер.
///
/// Время партии и время хода живут раздельно: фиксация накопленного отрезка
/// (сохранение в историю, уход в фон, пауза) не трогает счётчик хода — он
/// обнуляется только при передаче хода или сбросе.
class GameClock {
  GameClock({
    required int playerCount,
    int matchMs = 0,
    List<int>? playerMs,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _matchMs = matchMs,
        _playerMs = List<int>.generate(
          playerCount,
          (i) => (playerMs != null && i < playerMs.length) ? playerMs[i] : 0,
        );

  final DateTime Function() _now;

  int _matchMs;
  List<int> _playerMs;

  /// Накопленное время текущего хода без идущего отрезка.
  int _turnMs = 0;

  /// Начало идущего отрезка; `null` — часы стоят.
  DateTime? _segmentStart;

  /// Кому идёт время (индекс игрока).
  int owner = 0;

  /// Засчитывать ли время игрокам. В режимах без передачи хода («Дурак»,
  /// «Президент», Phase 10) считается только время партии.
  bool creditsPlayers = true;

  bool get running => _segmentStart != null;

  /// Длительность идущего отрезка. Часы, переведённые назад, не уводят время
  /// в минус.
  int get _segmentMs {
    final start = _segmentStart;
    if (start == null) return 0;
    final ms = _now().difference(start).inMilliseconds;
    return ms > 0 ? ms : 0;
  }

  /// Время партии с учётом идущего отрезка.
  int get liveMatchMs => _matchMs + _segmentMs;

  /// Время текущего хода с учётом идущего отрезка.
  int get liveTurnMs => _turnMs + _segmentMs;

  /// Время по игрокам с учётом идущего отрезка.
  List<int> livePlayerMs() {
    final out = List<int>.from(_playerMs);
    if (creditsPlayers && owner >= 0 && owner < out.length) {
      out[owner] += _segmentMs;
    }
    return out;
  }

  /// Запускает часы (повторный вызов ничего не меняет).
  void start() {
    _segmentStart ??= _now();
  }

  /// Фиксирует накопленное и останавливает часы. Время хода сохраняется.
  void stop() {
    flush();
    _segmentStart = null;
  }

  /// Переносит идущий отрезок в накопленные счётчики. Часы продолжают идти —
  /// это нужно перед сохранением в историю и при уходе в фон.
  void flush() {
    final ms = _segmentMs;
    if (ms > 0) {
      _matchMs += ms;
      _turnMs += ms;
      if (creditsPlayers && owner >= 0 && owner < _playerMs.length) {
        _playerMs[owner] += ms;
      }
    }
    if (_segmentStart != null) _segmentStart = _now();
  }

  /// Передаёт ход: время уходящего игрока фиксируется, счётчик хода обнуляется.
  void switchTurn(int newOwner) {
    flush();
    _turnMs = 0;
    owner = newOwner;
  }

  /// Обнуляет время партии, игроков и хода. Часы продолжают идти, если шли.
  void resetTotals() {
    _matchMs = 0;
    _turnMs = 0;
    _playerMs = List<int>.filled(_playerMs.length, 0);
    if (_segmentStart != null) _segmentStart = _now();
  }

  /// Приложение свернули: фиксируем накопленное, но счёт НЕ останавливаем —
  /// партия идёт и с выключенным экраном.
  void onBackground() => flush();

  /// Приложение вернулось на экран.
  void onForeground() => flush();
}

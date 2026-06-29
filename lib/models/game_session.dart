/// Типизированная модель одной игровой сессии.
///
/// Раньше игра везде передавалась как `Map<String, dynamic>`, что приводило к
/// разбросанному парсингу и легко ломалось при опечатке в ключе. Теперь это
/// единая модель с безопасным разбором JSON.
class GameSession {
  final String gameId;
  final List<String> players;

  /// Очки по раундам для каждого игрока. Элемент — либо `int` (накопленный
  /// счёт), либо `'—'` (пропуск/закрытие раунда). Формат сохранён ради
  /// совместимости с ранее сохранёнными данными.
  final List<List<dynamic>> scores;

  final int rounds;
  final List<String> remainingPlayers;
  final List<String> eliminatedPlayers;
  final List<int> dividerIndices;
  final int currentPlayerIndex;
  final DateTime date;

  /// Победа уже засчитана в счётчик профиля (`PlayerProfile.wins`).
  /// Флаг защищает от двойного начисления при повторном завершении/отмене.
  final bool winCredited;

  /// Имя победителя партии по правилу игры. Сохраняется явно, потому что для
  /// игр НЕ на вылет (гонка до порога, минимум при пороге, ручной режим)
  /// победителя нельзя вывести только из [remainingPlayers]. Для старых игр и
  /// игр «на вылет» — может быть null, тогда работает запасной вывод по
  /// оставшимся игрокам (см. [winner]).
  final String? winnerName;

  const GameSession({
    required this.gameId,
    required this.players,
    required this.scores,
    required this.rounds,
    required this.remainingPlayers,
    required this.eliminatedPlayers,
    required this.dividerIndices,
    required this.currentPlayerIndex,
    required this.date,
    this.winCredited = false,
    this.winnerName,
  });

  /// Победитель партии (или null, если не завершена).
  ///
  /// Приоритет у явно сохранённого [winnerName] (работает для всех правил);
  /// если его нет — запасной вывод «на вылет»: остался один игрок из многих.
  String? get winner {
    if (winnerName != null && winnerName!.isNotEmpty) return winnerName;
    if (players.length > 1 && remainingPlayers.length == 1) {
      return remainingPlayers.first;
    }
    return null;
  }

  /// Игра завершена, когда есть победитель.
  bool get isFinished => winner != null;

  /// В игре не записано ни одного очка.
  bool get isEmpty => scores.every((row) => row.isEmpty);

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      gameId: json['gameId']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      players: List<String>.from(json['players'] ?? const <String>[]),
      scores: (json['scores'] as List?)
              ?.map((row) => List<dynamic>.from(row as List))
              .toList() ??
          <List<dynamic>>[],
      rounds: json['rounds'] as int? ?? 0,
      remainingPlayers:
          List<String>.from(json['remainingPlayers'] ?? const <String>[]),
      eliminatedPlayers:
          List<String>.from(json['eliminatedPlayers'] ?? const <String>[]),
      dividerIndices: List<int>.from(json['dividerIndices'] ?? const <int>[]),
      currentPlayerIndex: json['currentPlayerIndex'] as int? ?? 0,
      date: json['date'] != null
          ? (DateTime.tryParse(json['date'].toString()) ?? DateTime.now())
          : DateTime.now(),
      winCredited: json['winCredited'] as bool? ?? false,
      winnerName: json['winnerName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'players': players,
        'scores': scores,
        'rounds': rounds,
        'remainingPlayers': remainingPlayers,
        'eliminatedPlayers': eliminatedPlayers,
        'dividerIndices': dividerIndices,
        'currentPlayerIndex': currentPlayerIndex,
        'date': date.toIso8601String(),
        'winCredited': winCredited,
        'winnerName': winnerName,
      };
}

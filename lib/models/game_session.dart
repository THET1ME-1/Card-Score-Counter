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
  });

  /// Игра завершена, когда остался ровно один игрок.
  bool get isFinished => remainingPlayers.length == 1;

  /// Победитель завершённой игры (или null).
  String? get winner => isFinished ? remainingPlayers.first : null;

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
      };
}

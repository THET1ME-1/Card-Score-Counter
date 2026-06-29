// Юнит-тесты чистой логики достижений (без UI).

import 'package:flutter_test/flutter_test.dart';
import 'package:score_master/achievements_screen.dart';
import 'package:score_master/models/game_profile.dart';
import 'package:score_master/models/game_session.dart';

GameSession _game(
  String id,
  List<String> players,
  String? winner, {
  int rounds = 1,
  DateTime? date,
}) {
  return GameSession(
    gameId: id,
    players: players,
    scores: [for (final _ in players) const [1]],
    rounds: rounds,
    remainingPlayers: winner != null ? [winner] : players,
    eliminatedPlayers: const [],
    dividerIndices: const [],
    currentPlayerIndex: 0,
    date: date ?? DateTime(2026, 6, 1, 12),
    winnerName: winner,
  );
}

Map<String, Achievement> _byId(List<Achievement> list) =>
    {for (final a in list) a.id: a};

void main() {
  test('первая партия и первая победа открываются', () {
    final a = _byId(computeAchievements(
      games: [_game('1', ['A', 'B'], 'A')],
      gameTypes: const {},
      allGames: kBuiltInGames,
    ));
    expect(a['first_game']!.unlocked, isTrue);
    expect(a['first_win']!.unlocked, isTrue);
    expect(a['games_10']!.unlocked, isFalse);
    expect(a['games_10']!.progress, 1);
  });

  test('серия из 3 побед подряд определяется по дате', () {
    final a = _byId(computeAchievements(
      games: [
        _game('1', ['A', 'B'], 'A', date: DateTime(2026, 1, 1, 12)),
        _game('2', ['A', 'B'], 'A', date: DateTime(2026, 1, 2, 12)),
        _game('3', ['A', 'B'], 'A', date: DateTime(2026, 1, 3, 12)),
        _game('4', ['A', 'B'], 'B', date: DateTime(2026, 1, 4, 12)),
      ],
      gameTypes: const {},
      allGames: kBuiltInGames,
    ));
    expect(a['streak_3']!.unlocked, isTrue);
    expect(a['streak_5']!.unlocked, isFalse);
  });

  test('полный стол — партия на 6 игроков', () {
    final a = _byId(computeAchievements(
      games: [
        _game('1', ['A', 'B', 'C', 'D', 'E', 'F'], 'A'),
      ],
      gameTypes: const {},
      allGames: kBuiltInGames,
    ));
    expect(a['full_table']!.unlocked, isTrue);
  });

  test('пустые партии не считаются сыгранными', () {
    final empty = GameSession(
      gameId: 'x',
      players: const ['A', 'B'],
      scores: const [[], []],
      rounds: 0,
      remainingPlayers: const ['A', 'B'],
      eliminatedPlayers: const [],
      dividerIndices: const [],
      currentPlayerIndex: 0,
      date: DateTime(2026, 6, 1, 12),
    );
    final a = _byId(computeAchievements(
      games: [empty],
      gameTypes: const {},
      allGames: kBuiltInGames,
    ));
    expect(a['first_game']!.unlocked, isFalse);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:score_master/services/sync/sync_merge.dart';

/// Мини-конструктор json-строки партии (как она лежит в gameHistory).
String game(String id, {List<String> players = const ['A', 'B']}) =>
    jsonEncode({'gameId': id, 'players': players, 'scores': []});

String profile(String name, {int wins = 0, String? imagePath}) =>
    jsonEncode({'name': name, 'color': 0xFF000000, 'wins': wins, 'imagePath': imagePath});

Map<String, dynamic> snap({
  List<String> games = const [],
  Map<String, int> updated = const {},
  Map<String, int> deleted = const {},
  List<String> profiles = const [],
  List<String> customGames = const [],
  List<String> companies = const [],
  Map<String, dynamic> gameNames = const {},
  Map<String, dynamic> gameTypes = const {},
}) =>
    {
      'kind': kSyncKind,
      'v': kSyncVersion,
      'gameHistory': games,
      'gameUpdated': updated,
      'gameDeleted': deleted,
      'profiles': profiles,
      'customGames': customGames,
      'companies': companies,
      'gameNames': gameNames,
      'gameTypes': gameTypes,
    };

List<String> gameIds(Map<String, dynamic> merged) => snapshotStrList(merged['gameHistory'])
    .map((s) => (jsonDecode(s) as Map)['gameId'].toString())
    .toList()
  ..sort();

void main() {
  group('mergeSnapshots — игры', () {
    test('объединяет непересекающиеся партии', () {
      final local = snap(games: [game('a')], updated: {'a': 100});
      final remote = snap(games: [game('b')], updated: {'b': 100});
      final stats = SyncStats();
      final merged = mergeSnapshots(local, remote, stats);
      expect(gameIds(merged), ['a', 'b']);
      expect(stats.addedGames, 1);
    });

    test('при конфликте побеждает более новая версия', () {
      final local = snap(games: [game('a', players: ['A'])], updated: {'a': 100});
      final remote =
          snap(games: [game('a', players: ['A', 'B', 'C'])], updated: {'a': 200});
      final stats = SyncStats();
      final merged = mergeSnapshots(local, remote, stats);
      final g = jsonDecode(snapshotStrList(merged['gameHistory']).single) as Map;
      expect((g['players'] as List).length, 3); // взяли удалённую (новее)
      expect(stats.updatedGames, 1);
    });

    test('локальная версия не откатывается более старой удалённой', () {
      final local = snap(games: [game('a', players: ['A', 'B', 'C'])], updated: {'a': 300});
      final remote = snap(games: [game('a', players: ['A'])], updated: {'a': 100});
      final merged = mergeSnapshots(local, remote, SyncStats());
      final g = jsonDecode(snapshotStrList(merged['gameHistory']).single) as Map;
      expect((g['players'] as List).length, 3);
    });

    test('надгробие удаляет партию, которая у другой стороны старее', () {
      final local = snap(deleted: {'a': 500});
      final remote = snap(games: [game('a')], updated: {'a': 200});
      final merged = mergeSnapshots(local, remote, SyncStats());
      expect(gameIds(merged), isEmpty);
      expect((merged['gameDeleted'] as Map)['a'], 500);
    });

    test('правка новее надгробия — партия воскресает', () {
      final local = snap(deleted: {'a': 200});
      final remote = snap(games: [game('a')], updated: {'a': 500});
      final merged = mergeSnapshots(local, remote, SyncStats());
      expect(gameIds(merged), ['a']);
      expect((merged['gameDeleted'] as Map).containsKey('a'), false);
    });

    test('удаление на удалённой стороне доезжает к нам', () {
      final local = snap(games: [game('a')], updated: {'a': 100});
      final remote = snap(deleted: {'a': 300});
      final stats = SyncStats();
      final merged = mergeSnapshots(local, remote, stats);
      expect(gameIds(merged), isEmpty);
      expect(stats.deletedGames, 1);
    });
  });

  group('mergeSnapshots — профили и спутники', () {
    test('профили сливаются, побед берётся максимум', () {
      final local = snap(profiles: [profile('Саша', wins: 3)]);
      final remote = snap(profiles: [profile('Саша', wins: 5), profile('Папа', wins: 1)]);
      final stats = SyncStats();
      final merged = mergeSnapshots(local, remote, stats);
      final byName = {
        for (final s in snapshotStrList(merged['profiles']))
          (jsonDecode(s) as Map)['name']: (jsonDecode(s) as Map)['wins']
      };
      expect(byName['Саша'], 5);
      expect(byName['Папа'], 1);
      expect(stats.newProfiles, 1);
    });

    test('локальная аватарка не теряется при слиянии профиля', () {
      final local = snap(profiles: [profile('Саша', imagePath: '/local/a.jpg')]);
      final remote = snap(profiles: [profile('Саша', imagePath: null)]);
      final merged = mergeSnapshots(local, remote, SyncStats());
      final p = jsonDecode(snapshotStrList(merged['profiles']).single) as Map;
      expect(p['imagePath'], '/local/a.jpg');
    });

    test('карта-спутник (имя партии) идёт за победившей стороной', () {
      final local = snap(games: [game('a')], updated: {'a': 100}, gameNames: {'a': 'Старое'});
      final remote =
          snap(games: [game('a')], updated: {'a': 200}, gameNames: {'a': 'Новое'});
      final merged = mergeSnapshots(local, remote, SyncStats());
      expect((merged['gameNames'] as Map)['a'], 'Новое');
    });

    test('спутники удалённых партий отбрасываются', () {
      final local = snap(deleted: {'a': 500}, gameNames: {'a': 'Имя'});
      final remote = snap(games: [game('a')], updated: {'a': 200}, gameNames: {'a': 'Имя'});
      final merged = mergeSnapshots(local, remote, SyncStats());
      expect((merged['gameNames'] as Map).containsKey('a'), false);
    });
  });
}

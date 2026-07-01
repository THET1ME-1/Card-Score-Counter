import 'dart:convert';

/// Общий формат «снимка для синхронизации» и чистые функции слияния двух
/// снимков по записям. Держим это отдельным, не зависящим от Flutter файлом —
/// так его легко покрыть юнит-тестами (см. test/sync_merge_test.dart).
///
/// Снимок для синка НЕ содержит настроек (тема/язык/звук и т.п.) — это
/// device-local вещи, их синхронизировать между устройствами не нужно. Полный
/// бэкап (с настройками) — отдельный путь через exportData/importData.
///
/// Слияние — по записям, с версиями и «надгробиями» удалений:
///   * игры (gameHistory) — объединение по gameId; при конфликте побеждает та,
///     у которой новее версия (`gameUpdated[id]`); удаление (`gameDeleted[id]`)
///     побеждает, только если оно строго новее последней правки.
///   * профили — объединение по имени; побед берём max (счётчик только растёт),
///     локальную аватарку не теряем.
///   * свои игры / компании — объединение по id (при конфликте держим локальную).
///   * карты-спутники партий (имена/заметки/типы/касса/команды) — идут за
///     «победившей» стороной игры, для удалённых игр отбрасываются.

const String kSyncKind = 'scoremaster-sync';
const int kSyncVersion = 1;

/// Что изменилось в результате слияния (для сообщения пользователю).
class SyncStats {
  int addedGames = 0;
  int updatedGames = 0;
  int deletedGames = 0;
  int newProfiles = 0;

  bool get changed =>
      addedGames + updatedGames + deletedGames + newProfiles > 0;

  @override
  String toString() =>
      'SyncStats(added:$addedGames, updated:$updatedGames, '
      'deleted:$deletedGames, profiles:$newProfiles)';
}

List<String> snapshotStrList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

Map<String, int> _intMap(dynamic v) {
  final out = <String, int>{};
  if (v is Map) {
    v.forEach((k, val) {
      if (val is num) out[k.toString()] = val.toInt();
    });
  }
  return out;
}

Map<String, dynamic> _genericMap(dynamic v) {
  final out = <String, dynamic>{};
  if (v is Map) v.forEach((k, val) => out[k.toString()] = val);
  return out;
}

String? _fieldOf(String jsonStr, String key) {
  try {
    final m = jsonDecode(jsonStr);
    if (m is Map && m[key] != null) return m[key].toString();
  } catch (_) {}
  return null;
}

int _maxInt(int a, int b) => a > b ? a : b;

/// Сливает два снимка (`local` — наш, `remote` — пришедший) и возвращает новый
/// снимок-результат, которым нужно заменить локальное состояние. Статистику
/// изменений пишет в [stats].
Map<String, dynamic> mergeSnapshots(
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
  SyncStats stats,
) {
  // ------------------------------- Игры -------------------------------
  final localGames = <String, String>{};
  for (final s in snapshotStrList(local['gameHistory'])) {
    final id = _fieldOf(s, 'gameId');
    if (id != null) localGames[id] = s;
  }
  final remoteGames = <String, String>{};
  for (final s in snapshotStrList(remote['gameHistory'])) {
    final id = _fieldOf(s, 'gameId');
    if (id != null) remoteGames[id] = s;
  }
  final lUpd = _intMap(local['gameUpdated']);
  final rUpd = _intMap(remote['gameUpdated']);
  final lDel = _intMap(local['gameDeleted']);
  final rDel = _intMap(remote['gameDeleted']);

  final allIds = <String>{
    ...localGames.keys,
    ...remoteGames.keys,
    ...lUpd.keys,
    ...rUpd.keys,
    ...lDel.keys,
    ...rDel.keys,
  };

  final mergedGames = <String, String>{};
  final mergedUpd = <String, int>{};
  final mergedDel = <String, int>{};
  // Какая сторона «победила» по каждой живой игре: 0 — локальная, 1 — удалённая.
  final winnerSide = <String, int>{};

  for (final id in allIds) {
    final lHas = localGames.containsKey(id);
    final rHas = remoteGames.containsKey(id);
    final lm = lUpd[id] ?? 0;
    final rm = rUpd[id] ?? 0;
    final delMs = _maxInt(lDel[id] ?? 0, rDel[id] ?? 0);

    String? content;
    int contentMs = 0;
    int side = -1;
    if (lHas && rHas) {
      if (rm > lm) {
        side = 1;
        content = remoteGames[id];
        contentMs = rm;
      } else {
        side = 0;
        content = localGames[id];
        contentMs = lm;
      }
    } else if (lHas) {
      side = 0;
      content = localGames[id];
      contentMs = lm;
    } else if (rHas) {
      side = 1;
      content = remoteGames[id];
      contentMs = rm;
    }

    if (content == null) {
      // Живого содержимого нет ни у кого — это удалённая партия.
      if (delMs > 0) mergedDel[id] = delMs;
      continue;
    }
    if (delMs > contentMs) {
      // Удаление новее любой правки — партия остаётся удалённой.
      mergedDel[id] = delMs;
      if (lHas) stats.deletedGames++;
      continue;
    }
    // Содержимое выживает.
    mergedGames[id] = content;
    mergedUpd[id] = contentMs;
    winnerSide[id] = side;
    if (!lHas && rHas) {
      stats.addedGames++;
    } else if (lHas && rHas && side == 1 && content != localGames[id]) {
      stats.updatedGames++;
    }
  }

  // ------------------------------ Профили ------------------------------
  Map<String, Map<String, dynamic>> profileMap(dynamic v) {
    final out = <String, Map<String, dynamic>>{};
    for (final s in snapshotStrList(v)) {
      try {
        final m = jsonDecode(s);
        if (m is Map && m['name'] != null) {
          out[m['name'].toString()] = Map<String, dynamic>.from(m);
        }
      } catch (_) {}
    }
    return out;
  }

  final lp = profileMap(local['profiles']);
  final rp = profileMap(remote['profiles']);
  final mergedProfiles = <String>[];
  for (final name in <String>{...lp.keys, ...rp.keys}) {
    final a = lp[name];
    final b = rp[name];
    Map<String, dynamic> m;
    if (a != null && b != null) {
      m = Map<String, dynamic>.from(a);
      final aw = (a['wins'] as num?)?.toInt() ?? 0;
      final bw = (b['wins'] as num?)?.toInt() ?? 0;
      m['wins'] = _maxInt(aw, bw);
      // Не теряем локальную аватарку; если её нет — берём из удалённого.
      m['imagePath'] = a['imagePath'] ?? b['imagePath'];
    } else if (a != null) {
      m = a;
    } else {
      m = b!;
      stats.newProfiles++;
    }
    mergedProfiles.add(jsonEncode(m));
  }

  // ------------------- Свои игры и компании (по id) -------------------
  List<String> unionById(dynamic lv, dynamic rv, String key) {
    final map = <String, String>{};
    for (final s in snapshotStrList(lv)) {
      final id = _fieldOf(s, key);
      if (id != null) map[id] = s;
    }
    for (final s in snapshotStrList(rv)) {
      final id = _fieldOf(s, key);
      // При конфликте оставляем локальную запись.
      if (id != null) map.putIfAbsent(id, () => s);
    }
    return map.values.toList();
  }

  final mergedCustom =
      unionById(local['customGames'], remote['customGames'], 'id');
  final mergedCompanies =
      unionById(local['companies'], remote['companies'], 'id');

  // ------------- Карты-спутники партий (идут за победителем) -------------
  Map<String, dynamic> mergeSide(String field) {
    final lmp = _genericMap(local[field]);
    final rmp = _genericMap(remote[field]);
    final out = <String, dynamic>{};
    for (final id in mergedGames.keys) {
      final side = winnerSide[id];
      dynamic value;
      if (side == 1) {
        value = rmp.containsKey(id) ? rmp[id] : lmp[id];
      } else {
        value = lmp.containsKey(id) ? lmp[id] : rmp[id];
      }
      if (value != null) out[id] = value;
    }
    return out;
  }

  return <String, dynamic>{
    'kind': kSyncKind,
    'v': kSyncVersion,
    'gameHistory': mergedGames.values.toList(),
    'gameUpdated': mergedUpd,
    'gameDeleted': mergedDel,
    'profiles': mergedProfiles,
    'customGames': mergedCustom,
    'companies': mergedCompanies,
    'gameNames': mergeSide('gameNames'),
    'gameNotes': mergeSide('gameNotes'),
    'gameTypes': mergeSide('gameTypes'),
    'gameKassa': mergeSide('gameKassa'),
    'gameTeams': mergeSide('gameTeams'),
  };
}

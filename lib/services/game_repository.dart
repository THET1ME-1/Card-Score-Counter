import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_profile.dart';
import '../models/game_session.dart';
import '../models/player_company.dart';
import '../models/volleyball_match.dart';
import '../player_profile.dart';

/// Единый слой доступа к данным приложения поверх [SharedPreferences].
///
/// Сюда собрана вся работа с историей игр, профилями и настройками, которая
/// раньше дублировалась прямыми обращениями к prefs в каждом экране. Это
/// упрощает поддержку и делает формат хранения единообразным.
///
/// Репозиторий — [ChangeNotifier]: после любого изменения данных (игры или
/// профили) он зовёт [notifyListeners], а экраны слушают его и перезагружаются
/// мгновенно. Так добавление/удаление/правка игры или игрока сразу видны везде.
class GameRepository extends ChangeNotifier {
  GameRepository._();
  static final GameRepository instance = GameRepository._();

  static const String _kGameHistory = 'gameHistory';
  static const String _kGameNames = 'gameNames';
  static const String _kCustomGames = 'customGames';
  static const String _kSelectedGame = 'selectedGame';
  static const String _kGameTypes = 'gameTypes';
  static const String _kProfiles = 'profiles';
  static const String _kIsDarkTheme = 'isDarkTheme';
  static const String _kSeedColor = 'seedColor';
  static const String _kLanguage = 'languageCode';
  static const String _kTextSize = 'textSize';
  static const String _kIsDescending = 'isDescending';
  static const String _kSoundEnabled = 'soundEnabled';
  static const String _kTimerEnabled = 'timerEnabled';
  static const String _kResumeDismissed = 'resumeDismissed';
  static const String _kDynamicColor = 'dynamicColor';
  static const String _kAmoled = 'amoled';
  static const String _kVolleyballActive = 'volleyballActive';
  static const String _kGameNotes = 'gameNotes';
  static const String _kFeatureNotes = 'featureNotes';
  static const String _kCompanies = 'companies';
  static const String _kPlayerFolders = 'playerFolders';
  static const String _kFeatureKassa = 'featureKassa';
  static const String _kFeatureTeams = 'featureTeams';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ----------------------------- Игры -----------------------------

  Future<List<GameSession>> loadGames() async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_kGameHistory) ?? const <String>[];
    final games = <GameSession>[];
    for (final entry in raw) {
      try {
        games.add(GameSession.fromJson(jsonDecode(entry)));
      } catch (_) {
        // Пропускаем повреждённую запись, не роняя загрузку остальных.
      }
    }
    return games;
  }

  Future<void> _saveGames(List<GameSession> games) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      _kGameHistory,
      games.map((g) => jsonEncode(g.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Создаёт или обновляет игру по [GameSession.gameId].
  ///
  /// Если игра с таким id уже есть и [preserveDate] = true, исходная дата
  /// создания сохраняется (правка не «омолаживает» игру в истории).
  Future<void> upsertGame(GameSession game, {bool preserveDate = true}) async {
    final games = await loadGames();
    final index = games.indexWhere((g) => g.gameId == game.gameId);
    if (index == -1) {
      games.add(game);
    } else {
      final existing = games[index];
      games[index] = preserveDate
          ? GameSession(
              gameId: game.gameId,
              players: game.players,
              scores: game.scores,
              rounds: game.rounds,
              remainingPlayers: game.remainingPlayers,
              eliminatedPlayers: game.eliminatedPlayers,
              dividerIndices: game.dividerIndices,
              currentPlayerIndex: game.currentPlayerIndex,
              date: existing.date,
              winCredited: game.winCredited,
              winnerName: game.winnerName,
              durationMs: game.durationMs,
              playerTimesMs: game.playerTimesMs,
            )
          : game;
    }
    await _saveGames(games);
  }

  Future<void> deleteGame(String gameId) async {
    final games = await loadGames();
    games.removeWhere((g) => g.gameId == gameId);
    await _saveGames(games);
    final prefs = await _prefs;
    // Заодно убираем сохранённое имя и заметку этой партии.
    final names = await gameNames();
    if (names.remove(gameId) != null) {
      await prefs.setString(_kGameNames, jsonEncode(names));
    }
    final notes = await gameNotes();
    if (notes.remove(gameId) != null) {
      await prefs.setString(_kGameNotes, jsonEncode(notes));
    }
  }

  // --------------------------- Имена партий ---------------------------
  // Пользовательские названия игр храним отдельно (gameId → имя), чтобы не
  // менять модель GameSession и логику табло.

  Future<Map<String, String>> gameNames() async {
    final raw = (await _prefs).getString(_kGameNames);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setGameName(String gameId, String name) async {
    final prefs = await _prefs;
    final names = await gameNames();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      names.remove(gameId);
    } else {
      names[gameId] = trimmed;
    }
    await prefs.setString(_kGameNames, jsonEncode(names));
    notifyListeners();
  }

  // --------------------------- Заметки к партиям ---------------------------
  // Свободный текст-комментарий к партии (gameId → заметка), как и имена —
  // отдельно от модели GameSession.

  Future<Map<String, String>> gameNotes() async {
    final raw = (await _prefs).getString(_kGameNotes);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setGameNote(String gameId, String note) async {
    final prefs = await _prefs;
    final notes = await gameNotes();
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      notes.remove(gameId);
    } else {
      notes[gameId] = trimmed;
    }
    await prefs.setString(_kGameNotes, jsonEncode(notes));
    notifyListeners();
  }

  /// Функция «Заметки к партиям» включена в настройках (по умолчанию выкл).
  Future<bool> featureNotesEnabled({bool fallback = false}) async =>
      (await _prefs).getBool(_kFeatureNotes) ?? fallback;

  Future<void> setFeatureNotesEnabled(bool value) async {
    await (await _prefs).setBool(_kFeatureNotes, value);
    notifyListeners();
  }

  /// Функция «Касса» (деньги) включена.
  Future<bool> featureKassaEnabled({bool fallback = false}) async =>
      (await _prefs).getBool(_kFeatureKassa) ?? fallback;

  Future<void> setFeatureKassaEnabled(bool value) async {
    await (await _prefs).setBool(_kFeatureKassa, value);
    notifyListeners();
  }

  /// Функция «Командный режим» включена.
  Future<bool> featureTeamsEnabled({bool fallback = false}) async =>
      (await _prefs).getBool(_kFeatureTeams) ?? fallback;

  Future<void> setFeatureTeamsEnabled(bool value) async {
    await (await _prefs).setBool(_kFeatureTeams, value);
    notifyListeners();
  }

  // ----------------------- Профили игр (что играем) -----------------------

  /// Свои (пользовательские) профили игр.
  Future<List<GameProfile>> customGames() async {
    final raw = (await _prefs).getStringList(_kCustomGames) ?? const <String>[];
    final list = <GameProfile>[];
    for (final e in raw) {
      try {
        list.add(GameProfile.fromJson(jsonDecode(e)));
      } catch (_) {}
    }
    return list;
  }

  Future<void> saveCustomGames(List<GameProfile> games) async {
    await (await _prefs).setStringList(
      _kCustomGames,
      games.map((g) => jsonEncode(g.toJson())).toList(),
    );
    notifyListeners();
  }

  /// Встроенные + свои игры.
  Future<List<GameProfile>> allGames() async =>
      [...kBuiltInGames, ...await customGames()];

  /// Профиль игры по id (встроенный или свой), либо null.
  Future<GameProfile?> gameById(String? id) async {
    if (id == null) return null;
    for (final g in await allGames()) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Выбранная сейчас игра (для старта новой партии). По умолчанию — 101.
  Future<String> selectedGameId() async =>
      (await _prefs).getString(_kSelectedGame) ?? 'g101';

  Future<void> setSelectedGameId(String id) async {
    await (await _prefs).setString(_kSelectedGame, id);
    notifyListeners();
  }

  /// Тег «какая это игра» для партий истории: gameId сессии → id профиля игры.
  Future<Map<String, String>> gameTypes() async {
    final raw = (await _prefs).getString(_kGameTypes);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setGameType(String gameId, String profileId) async {
    final prefs = await _prefs;
    final types = await gameTypes();
    types[gameId] = profileId;
    await prefs.setString(_kGameTypes, jsonEncode(types));
    notifyListeners();
  }

  /// Удаляет игры без единого записанного очка (брошенные на старте).
  Future<void> removeEmptyGames() async {
    final games = await loadGames();
    games.removeWhere((g) => g.isEmpty);
    await _saveGames(games);
  }

  // --------------------------- Волейбол ---------------------------

  /// Текущий незавершённый волейбольный матч (или null).
  Future<VolleyballMatch?> loadActiveVolleyball() async {
    final raw = (await _prefs).getString(_kVolleyballActive);
    if (raw == null) return null;
    try {
      return VolleyballMatch.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActiveVolleyball(VolleyballMatch m) async {
    await (await _prefs)
        .setString(_kVolleyballActive, jsonEncode(m.toJson()));
  }

  Future<void> clearActiveVolleyball() async {
    await (await _prefs).remove(_kVolleyballActive);
  }

  /// Сохраняет завершённый матч в историю как [GameSession] (две «команды»,
  /// очки по сетам), отмеченную типом «Волейбол».
  Future<void> saveVolleyballToHistory(
      VolleyballMatch m, VbState state) async {
    if (state.completedSets.isEmpty) return;
    final scores = <List<dynamic>>[
      [for (final s in state.completedSets) s[0]],
      [for (final s in state.completedSets) s[1]],
    ];
    final session = GameSession(
      gameId: m.id,
      players: m.teamNames,
      scores: scores,
      rounds: state.completedSets.length,
      remainingPlayers: m.teamNames,
      eliminatedPlayers: const [],
      dividerIndices: const [],
      currentPlayerIndex: 0,
      date: m.date,
      winCredited: false,
      winnerName: state.winner == null ? null : m.teamNames[state.winner!],
      durationMs: 0,
      playerTimesMs: const [],
    );
    await upsertGame(session, preserveDate: false);
    await setGameType(m.id, 'volleyball');
  }

  Future<void> clearGames() async {
    final prefs = await _prefs;
    await prefs.remove(_kGameHistory);
    await prefs.remove(_kGameNames);
    notifyListeners();
  }

  // --------------------------- Профили ---------------------------

  Future<List<PlayerProfile>> loadProfiles() async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_kProfiles) ?? const <String>[];
    final profiles = <PlayerProfile>[];
    for (final entry in raw) {
      try {
        profiles.add(PlayerProfile.fromJson(jsonDecode(entry)));
      } catch (_) {}
    }
    return profiles;
  }

  Future<void> saveProfiles(List<PlayerProfile> profiles) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      _kProfiles,
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
    notifyListeners();
  }

  // ------------------------- Компании (папки) игроков -------------------------
  // Папка = именованный набор имён игроков. Один игрок может быть в нескольких
  // папках. Хранится отдельным JSON-списком.

  Future<bool> playerFoldersEnabled({bool fallback = false}) async =>
      (await _prefs).getBool(_kPlayerFolders) ?? fallback;

  Future<void> setPlayerFoldersEnabled(bool value) async {
    await (await _prefs).setBool(_kPlayerFolders, value);
    notifyListeners();
  }

  Future<List<PlayerCompany>> loadCompanies() async {
    final raw = (await _prefs).getStringList(_kCompanies) ?? const <String>[];
    final out = <PlayerCompany>[];
    for (final e in raw) {
      try {
        out.add(PlayerCompany.fromJson(jsonDecode(e)));
      } catch (_) {}
    }
    return out;
  }

  Future<void> saveCompanies(List<PlayerCompany> companies) async {
    await (await _prefs).setStringList(
      _kCompanies,
      companies.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }

  Future<PlayerCompany> addCompany(String name) async {
    final companies = await loadCompanies();
    final company = PlayerCompany(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      members: [],
    );
    companies.add(company);
    await saveCompanies(companies);
    return company;
  }

  Future<void> renameCompany(String id, String name) async {
    final companies = await loadCompanies();
    final idx = companies.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    companies[idx].name = name.trim();
    await saveCompanies(companies);
  }

  Future<void> deleteCompany(String id) async {
    final companies = await loadCompanies()
      ..removeWhere((c) => c.id == id);
    await saveCompanies(companies);
  }

  /// Полностью задаёт состав компании (для экрана управления участниками).
  Future<void> setCompanyMembers(String id, List<String> members) async {
    final companies = await loadCompanies();
    final idx = companies.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    companies[idx].members = members.toSet().toList();
    await saveCompanies(companies);
  }

  /// Игрок переименован — обновляем его имя во всех папках.
  Future<void> renamePlayerInCompanies(String oldName, String newName) async {
    final companies = await loadCompanies();
    var changed = false;
    for (final c in companies) {
      for (var i = 0; i < c.members.length; i++) {
        if (c.members[i] == oldName) {
          c.members[i] = newName;
          changed = true;
        }
      }
      c.members = c.members.toSet().toList();
    }
    if (changed) await saveCompanies(companies);
  }

  /// Игрок удалён — убираем его из всех папок.
  Future<void> removePlayerFromCompanies(String name) async {
    final companies = await loadCompanies();
    var changed = false;
    for (final c in companies) {
      if (c.members.remove(name)) changed = true;
    }
    if (changed) await saveCompanies(companies);
  }

  /// Изменяет счётчик побед игрока на [delta] (с защитой от ухода ниже нуля).
  Future<void> adjustWins(String playerName, int delta) async {
    final profiles = await loadProfiles();
    for (final profile in profiles) {
      if (profile.name == playerName) {
        profile.wins = (profile.wins + delta).clamp(0, 1 << 31);
        break;
      }
    }
    await saveProfiles(profiles);
  }

  Future<void> resetWins() async {
    final profiles = await loadProfiles();
    for (final profile in profiles) {
      profile.wins = 0;
    }
    await saveProfiles(profiles);
  }

  /// Переименование игрока во всех сохранённых играх (имена в истории — ключи).
  Future<void> renamePlayerInGames(String oldName, String newName) async {
    if (oldName == newName) return;
    final games = await loadGames();
    List<String> rename(List<String> list) =>
        list.map((p) => p == oldName ? newName : p).toList();
    final updated = games
        .map((g) => GameSession(
              gameId: g.gameId,
              players: rename(g.players),
              scores: g.scores,
              rounds: g.rounds,
              remainingPlayers: rename(g.remainingPlayers),
              eliminatedPlayers: rename(g.eliminatedPlayers),
              dividerIndices: g.dividerIndices,
              currentPlayerIndex: g.currentPlayerIndex,
              date: g.date,
              winCredited: g.winCredited,
              winnerName: g.winnerName == oldName ? newName : g.winnerName,
              durationMs: g.durationMs,
              playerTimesMs: g.playerTimesMs,
            ))
        .toList();
    await _saveGames(updated);
  }

  // --------------------------- Настройки ---------------------------

  Future<bool> isDarkTheme({bool fallback = true}) async =>
      (await _prefs).getBool(_kIsDarkTheme) ?? fallback;

  Future<void> setDarkTheme(bool value) async =>
      (await _prefs).setBool(_kIsDarkTheme, value);

  /// Звуковые эффекты (победа/вылет/очко). По умолчанию включены.
  Future<bool> soundEnabled({bool fallback = true}) async =>
      (await _prefs).getBool(_kSoundEnabled) ?? fallback;

  Future<void> setSoundEnabled(bool value) async =>
      (await _prefs).setBool(_kSoundEnabled, value);

  /// Показывать ли таймер партии на табло. По умолчанию включён.
  Future<bool> timerEnabled({bool fallback = true}) async =>
      (await _prefs).getBool(_kTimerEnabled) ?? fallback;

  Future<void> setTimerEnabled(bool value) async {
    await (await _prefs).setBool(_kTimerEnabled, value);
    notifyListeners();
  }

  /// Партии, для которых пользователь скрыл подсказку «Продолжить» (по gameId).
  Future<Set<String>> dismissedResume() async =>
      (await _prefs).getStringList(_kResumeDismissed)?.toSet() ?? <String>{};

  Future<void> dismissResume(String gameId) async {
    final prefs = await _prefs;
    final set = await dismissedResume()
      ..add(gameId);
    await prefs.setStringList(_kResumeDismissed, set.toList());
    notifyListeners();
  }

  /// Material You — брать цвет из системных обоев. По умолчанию выключено.
  Future<bool> dynamicColorEnabled({bool fallback = false}) async =>
      (await _prefs).getBool(_kDynamicColor) ?? fallback;

  Future<void> setDynamicColorEnabled(bool value) async {
    await (await _prefs).setBool(_kDynamicColor, value);
    notifyListeners();
  }

  /// AMOLED-режим тёмной темы (чистый чёрный фон). По умолчанию выключен.
  Future<bool> amoledEnabled({bool fallback = false}) async =>
      (await _prefs).getBool(_kAmoled) ?? fallback;

  Future<void> setAmoledEnabled(bool value) async {
    await (await _prefs).setBool(_kAmoled, value);
    notifyListeners();
  }

  /// ARGB-значение seed-цвета темы, или null если пользователь не выбирал.
  Future<int?> seedColorValue() async => (await _prefs).getInt(_kSeedColor);

  Future<void> setSeedColorValue(int argb) async =>
      (await _prefs).setInt(_kSeedColor, argb);

  /// Код языка интерфейса ('ru'/'en'), или null если не выбран.
  Future<String?> languageCode() async =>
      (await _prefs).getString(_kLanguage);

  Future<void> setLanguageCode(String code) async =>
      (await _prefs).setString(_kLanguage, code);

  Future<double> textSize({double fallback = 16.0}) async =>
      (await _prefs).getDouble(_kTextSize) ?? fallback;

  Future<void> setTextSize(double value) async =>
      (await _prefs).setDouble(_kTextSize, value);

  Future<bool> isDescending({bool fallback = true}) async =>
      (await _prefs).getBool(_kIsDescending) ?? fallback;

  Future<void> setDescending(bool value) async =>
      (await _prefs).setBool(_kIsDescending, value);

  // ------------------------ Бэкап / восстановление ------------------------

  /// Сериализует ВСЕ важные данные приложения в один JSON-документ.
  ///
  /// Кроме истории игр (в ней уже лежит и время партий, и время по игрокам) и
  /// профилей игроков сохраняем: имена партий, свои игры, типы партий (какой
  /// игрой сыграна каждая партия — иначе аналитика «теряет» тип), выбранную
  /// игру и пользовательские настройки. Так после восстановления всё на месте.
  Future<String> exportData() async {
    final prefs = await _prefs;
    final data = <String, dynamic>{
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      // Данные игр и игроков.
      _kGameHistory: prefs.getStringList(_kGameHistory) ?? const <String>[],
      _kProfiles: prefs.getStringList(_kProfiles) ?? const <String>[],
      _kCustomGames: prefs.getStringList(_kCustomGames) ?? const <String>[],
      _kCompanies: prefs.getStringList(_kCompanies) ?? const <String>[],
      _kGameNames: prefs.getString(_kGameNames),
      _kGameNotes: prefs.getString(_kGameNotes),
      _kGameTypes: prefs.getString(_kGameTypes),
      _kSelectedGame: prefs.getString(_kSelectedGame),
      // Настройки.
      _kIsDarkTheme: prefs.getBool(_kIsDarkTheme),
      _kSeedColor: prefs.getInt(_kSeedColor),
      _kLanguage: prefs.getString(_kLanguage),
      _kTextSize: prefs.getDouble(_kTextSize),
      _kIsDescending: prefs.getBool(_kIsDescending),
      _kSoundEnabled: prefs.getBool(_kSoundEnabled),
      _kTimerEnabled: prefs.getBool(_kTimerEnabled),
      _kDynamicColor: prefs.getBool(_kDynamicColor),
      _kAmoled: prefs.getBool(_kAmoled),
      _kFeatureNotes: prefs.getBool(_kFeatureNotes),
      _kPlayerFolders: prefs.getBool(_kPlayerFolders),
      _kFeatureKassa: prefs.getBool(_kFeatureKassa),
      _kFeatureTeams: prefs.getBool(_kFeatureTeams),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Восстанавливает данные из ранее экспортированного JSON. Поддерживает и
  /// старый формат (v1: только история и профили), и новый (v2: всё).
  /// Возвращает false, если формат не распознан.
  Future<bool> importData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final games = data[_kGameHistory];
      final profiles = data[_kProfiles];
      // Минимально обязательная часть бэкапа — история и профили.
      if (games is! List || profiles is! List) return false;

      final prefs = await _prefs;

      Future<void> setStrList(String key, dynamic v) async {
        if (v is List) {
          await prefs.setStringList(key, v.map((e) => e.toString()).toList());
        }
      }

      await setStrList(_kGameHistory, games);
      await setStrList(_kProfiles, profiles);
      await setStrList(_kCustomGames, data[_kCustomGames]);
      await setStrList(_kCompanies, data[_kCompanies]);

      // Строковые карты (имена/заметки партий, типы) и прочие строки.
      for (final key in [
        _kGameNames,
        _kGameNotes,
        _kGameTypes,
        _kSelectedGame,
        _kLanguage
      ]) {
        final v = data[key];
        if (v is String) await prefs.setString(key, v);
      }
      // Числа.
      if (data[_kSeedColor] is num) {
        await prefs.setInt(_kSeedColor, (data[_kSeedColor] as num).toInt());
      }
      if (data[_kTextSize] is num) {
        await prefs.setDouble(
            _kTextSize, (data[_kTextSize] as num).toDouble());
      }
      // Флаги.
      for (final key in [
        _kIsDarkTheme,
        _kIsDescending,
        _kSoundEnabled,
        _kTimerEnabled,
        _kDynamicColor,
        _kAmoled,
        _kFeatureNotes,
        _kPlayerFolders,
        _kFeatureKassa,
        _kFeatureTeams
      ]) {
        final v = data[key];
        if (v is bool) await prefs.setBool(key, v);
      }

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_profile.dart';
import '../models/game_session.dart';
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
            )
          : game;
    }
    await _saveGames(games);
  }

  Future<void> deleteGame(String gameId) async {
    final games = await loadGames();
    games.removeWhere((g) => g.gameId == gameId);
    await _saveGames(games);
    // Заодно убираем сохранённое имя этой партии.
    final names = await gameNames();
    if (names.remove(gameId) != null) {
      await (await _prefs).setString(_kGameNames, jsonEncode(names));
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
            ))
        .toList();
    await _saveGames(updated);
  }

  // --------------------------- Настройки ---------------------------

  Future<bool> isDarkTheme({bool fallback = true}) async =>
      (await _prefs).getBool(_kIsDarkTheme) ?? fallback;

  Future<void> setDarkTheme(bool value) async =>
      (await _prefs).setBool(_kIsDarkTheme, value);

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

  /// Сериализует все данные приложения в один JSON-документ для экспорта.
  Future<String> exportData() async {
    final prefs = await _prefs;
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      _kGameHistory: prefs.getStringList(_kGameHistory) ?? const <String>[],
      _kProfiles: prefs.getStringList(_kProfiles) ?? const <String>[],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Восстанавливает данные из ранее экспортированного JSON.
  /// Возвращает false, если формат не распознан.
  Future<bool> importData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final games = data[_kGameHistory];
      final profiles = data[_kProfiles];
      if (games is! List || profiles is! List) return false;

      final prefs = await _prefs;
      await prefs.setStringList(
          _kGameHistory, games.map((e) => e.toString()).toList());
      await prefs.setStringList(
          _kProfiles, profiles.map((e) => e.toString()).toList());
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/achievement.dart';

class AchievementService extends ChangeNotifier {
  static const String _achievementsKey = 'user_achievements';
  static const String _userStatsKey = 'user_stats';

  final Map<String, Achievement> _achievements = {};
  
  // User statistics
  int _gamesPlayed = 0;
  int _gamesWon = 0;
  int _consecutiveWins = 0;
  int _perfectGames = 0;
  int _consecutiveDays = 0;
  DateTime? _lastPlayedDate;
  
  // Getters for statistics
  int get gamesPlayed => _gamesPlayed;
  int get gamesWon => _gamesWon;
  int get consecutiveWins => _consecutiveWins;
  int get perfectGames => _perfectGames;
  int get consecutiveDays => _consecutiveDays;

  final Map<String, Achievement> _achievementTemplates = {
    // Game Sessions
    'first_game': Achievement(
      id: 'first_game',
      title: 'Первая игра',
      description: 'Сыграйте свою первую игру',
      icon: '🎮',
      progressRequired: 1,
      type: AchievementType.sessionsCompleted,
    ),
    'seasoned_player': Achievement(
      id: 'seasoned_player',
      title: 'Опытный игрок',
      description: 'Сыграйте 10 игр',
      icon: '🎲',
      progressRequired: 10,
      type: AchievementType.sessionsCompleted,
    ),
    'veteran': Achievement(
      id: 'veteran',
      title: 'Ветеран',
      description: 'Сыграйте 50 игр',
      icon: '🏅',
      progressRequired: 50,
      type: AchievementType.sessionsCompleted,
    ),
    
    // Game Wins
    'first_win': Achievement(
      id: 'first_win',
      title: 'Первая победа',
      description: 'Одержите свою первую победу',
      icon: '🥇',
      progressRequired: 1,
      type: AchievementType.gamesWon,
    ),
    'champion': Achievement(
      id: 'champion',
      title: 'Чемпион',
      description: 'Одержите 10 побед',
      icon: '🏆',
      progressRequired: 10,
      type: AchievementType.gamesWon,
    ),
    'legend': Achievement(
      id: 'legend',
      title: 'Легенда',
      description: 'Одержите 50 побед',
      icon: '🌟',
      progressRequired: 50,
      type: AchievementType.gamesWon,
    ),
    
    // Perfect Games
    'perfectionist': Achievement(
      id: 'perfectionist',
      title: 'Перфекционист',
      description: 'Выиграйте игру с идеальным счетом',
      icon: '💯',
      progressRequired: 1,
      type: AchievementType.perfectGame,
    ),
    
    // Activity
    'dedicated': Achievement(
      id: 'dedicated',
      title: 'Преданный игрок',
      description: 'Играйте 7 дней подряд',
      icon: '🔥',
      progressRequired: 7,
      type: AchievementType.consecutiveDays,
    ),
    'unstoppable': Achievement(
      id: 'unstoppable',
      title: 'Неудержимый',
      description: 'Играйте 30 дней подряд',
      icon: '⚡',
      progressRequired: 30,
      type: AchievementType.consecutiveDays,
    ),
    
    // Mastery
    'master': Achievement(
      id: 'master',
      title: 'Мастер игры',
      description: 'Получите все достижения',
      icon: '👑',
      progressRequired: 1,
      type: AchievementType.mastery,
    ),
    'long_battle': Achievement(
      id: 'long_battle',
      title: 'Долгая битва',
      description: 'Сессия с 15+ раундами',
      icon: '⏳',
      progressRequired: 1,
      type: AchievementType.longSession,
    ),
    'balance': Achievement(
      id: 'balance',
      title: 'Равновесие',
      description: 'Все игроки закончили с одинаковым счетом',
      icon: '⚖️',
      progressRequired: 1,
      type: AchievementType.tieGame,
    ),
    'quick_win': Achievement(
      id: 'quick_win',
      title: 'Быстрая победа',
      description: 'Завершите сессию менее чем за 5 раундов',
      icon: '⚡',
      progressRequired: 1,
      type: AchievementType.quickWin,
    ),
    'consistency': Achievement(
      id: 'consistency',
      title: 'Стабильность',
      description: '10 сессий с разницей очков менее 5',
      icon: '📊',
      progressRequired: 10,
      type: AchievementType.consistentScores,
    ),
    'golden_player': Achievement(
      id: 'golden_player',
      title: 'Золотой игрок',
      description: 'Одержите победу в 3 сессиях подряд',
      icon: '🥇',
      progressRequired: 3,
      type: AchievementType.consecutiveSessionWins,
    ),
    'patience': Achievement(
      id: 'patience',
      title: 'Терпение',
      description: '50 раундов без отмены хода',
      icon: '🧘',
      progressRequired: 50,
      type: AchievementType.roundsWithoutUndo,
    ),
    'high_risk': Achievement(
      id: 'high_risk',
      title: 'Высокий риск',
      description: 'Наберите 20+ очков за сессию',
      icon: '🎲',
      progressRequired: 1,
      type: AchievementType.highScore,
    ),
    'comeback_master': Achievement(
      id: 'comeback_master',
      title: 'Мастер возрождения',
      description: 'Вернитесь в игру после выбытия',
      icon: '🔄',
      progressRequired: 1,
      type: AchievementType.comeback,
    ),
    'legend_rounds': Achievement(
      id: 'legend_rounds',
      title: 'Легенда',
      description: 'Подсчитайте 100 раундов за всё время',
      icon: '🏛️',
      progressRequired: 100,
      type: AchievementType.totalRoundsCounted,
    ),
    'equal_battle': Achievement(
      id: 'equal_battle',
      title: 'Равный бой',
      description: 'Два игрока набрали одинаковое количество побед',
      icon: '🤝',
      progressRequired: 1,
      type: AchievementType.equalWins,
    ),
    'economy': Achievement(
      id: 'economy',
      title: 'Экономия',
      description: '10 сессий с менее чем 5 редактированиями',
      icon: '💾',
      progressRequired: 10,
      type: AchievementType.fewEdits,
    ),
    'night_player': Achievement(
      id: 'night_player',
      title: 'Ночной игрок',
      description: 'Завершите сессию после 22:00',
      icon: '🌙',
      progressRequired: 1,
      type: AchievementType.nightSession,
    ),
    'perfect_sessions': Achievement(
      id: 'perfect_sessions',
      title: 'Перфекционист',
      description: '5 сессий без ошибок',
      icon: '🌟',
      progressRequired: 5,
      type: AchievementType.perfectSessions,
    ),
  };

  AchievementService() {
    _loadAchievements();
  }

  List<Achievement> get allAchievements =>
      _achievements.values.toList()..sort((a, b) => a.title.compareTo(b.title));

  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final achievementsJson = prefs.getString(_achievementsKey);

    if (achievementsJson != null) {
      final Map<String, dynamic> achievementsMap = jsonDecode(achievementsJson);
      _achievements.clear();
      
      achievementsMap.forEach((key, value) {
        final template = _achievementTemplates[key];
        if (template != null) {
          _achievements[key] = Achievement.fromJson(value, template);
        }
      });
    } else {
      // Initialize with default achievements
      _achievements.addAll(Map.fromEntries(
        _achievementTemplates.entries.map((e) => 
          MapEntry(e.key, Achievement(
            id: e.value.id,
            title: e.value.title,
            description: e.value.description,
            icon: e.value.icon,
            progressRequired: e.value.progressRequired,
            type: e.value.type,
            currentProgress: 0,
            isUnlocked: false,
            unlockedAt: null,
            isSeen: false,
          ))
        )
      ));
      await _saveAchievements();
    }
    
    // Load user statistics
    await _loadUserStats();
    
    // Check for consecutive days
    _checkConsecutiveDays();
    
    notifyListeners();
  }

  // Save achievements to shared preferences
  Future<void> _saveAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final achievementsMap = <String, dynamic>{};
    
    _achievements.forEach((key, value) {
      achievementsMap[key] = value.toJson();
    });
    
    await prefs.setString(_achievementsKey, jsonEncode(achievementsMap));
  }
  
  // Load user statistics
  Future<void> _loadUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString(_userStatsKey);
    
    if (statsJson != null) {
      final stats = jsonDecode(statsJson);
      _gamesPlayed = stats['gamesPlayed'] ?? 0;
      _gamesWon = stats['gamesWon'] ?? 0;
      _consecutiveWins = stats['consecutiveWins'] ?? 0;
      _perfectGames = stats['perfectGames'] ?? 0;
      _consecutiveDays = stats['consecutiveDays'] ?? 0;
      _lastPlayedDate = stats['lastPlayedDate'] != null 
          ? DateTime.parse(stats['lastPlayedDate']) 
          : null;
    }
  }
  
  // Save user statistics
  Future<void> _saveUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = {
      'gamesPlayed': _gamesPlayed,
      'gamesWon': _gamesWon,
      'consecutiveWins': _consecutiveWins,
      'perfectGames': _perfectGames,
      'consecutiveDays': _consecutiveDays,
      'lastPlayedDate': _lastPlayedDate?.toIso8601String(),
    };
    
    await prefs.setString(_userStatsKey, jsonEncode(stats));
  }
  
  // Check and update consecutive days
  void _checkConsecutiveDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_lastPlayedDate == null) {
      _consecutiveDays = 1;
    } else {
      final lastPlayed = DateTime(
        _lastPlayedDate!.year, 
        _lastPlayedDate!.month, 
        _lastPlayedDate!.day
      );
      
      final difference = today.difference(lastPlayed).inDays;
      
      if (difference == 1) {
        _consecutiveDays++;
      } else if (difference > 1) {
        _consecutiveDays = 1; // Reset if more than one day has passed
      }
    }
    
    _lastPlayedDate = now;
    _saveUserStats();
    
    // Update consecutive days achievements
    _updateAchievementProgress('dedicated', 1);
    _updateAchievementProgress('unstoppable', 1);
  }

  // Get list of unlocked achievements
  List<Achievement> get unlockedAchievements =>
      _achievements.values.where((a) => a.isUnlocked).toList()
        ..sort((a, b) => (b.unlockedAt ?? DateTime.now())
            .compareTo(a.unlockedAt ?? DateTime.now()));

  // Helper method to update achievement progress (used internally)
  Future<void> _updateAchievementProgress(String achievementId, int progress) async {
    await updateAchievementProgress(
      achievementId,
      progress: progress,
    );
  }

  // Update achievement progress
  Future<void> updateAchievementProgress(String achievementId, {int? progress, bool increment = false, int incrementBy = 1}) async {
    if (!_achievementTemplates.containsKey(achievementId)) return;

    final achievement = _achievements[achievementId] ?? _achievementTemplates[achievementId]!;
    
    // Don't update if already unlocked and we're not forcing an update
    if (achievement.isUnlocked) return;

    // Update progress
    if (increment) {
      achievement.incrementProgress(incrementBy);
    } else if (progress != null) {
      achievement.updateProgress(progress);
    }

    // Check if achievement was just unlocked
    bool wasJustUnlocked = false;
    if (achievement.isUnlocked && achievement.unlockedAt == null) {
      achievement.unlockedAt = DateTime.now();
      wasJustUnlocked = true;
    }

    // Save to persistent storage
    _achievements[achievementId] = achievement;
    await _saveAchievements();
    
    // Notify listeners about the change
    if (wasJustUnlocked) {
      // Show notification for newly unlocked achievements
      _showAchievementNotification(achievement);
    }
    notifyListeners();
  }

  // Show achievement notification
  void _showAchievementNotification(Achievement achievement) {
    // This will be handled by the UI layer through a listener
    debugPrint('Achievement unlocked: ${achievement.title}');
    // The actual notification is shown by the AchievementNotification widget in main.dart
  }
  
  // Get list of newly unlocked achievements that haven't been seen yet
  List<Achievement> getNewUnlockedAchievements() {
    return _achievements.values
        .where((a) => a.isUnlocked && !a.isSeen)
        .toList();
  }

  void resetAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_achievementsKey);
    _achievements.clear();
    await _loadAchievements();
  }

  // Mark all achievements as seen (hide notifications)
  void markAchievementsAsSeen() {
    bool needsUpdate = false;
    
    for (final achievement in _achievements.values) {
      if (achievement.isUnlocked && !achievement.isSeen) {
        achievement.isSeen = true;
        needsUpdate = true;
      }
    }
    
    if (needsUpdate) {
      _saveAchievements();
      notifyListeners();
    }
  }

  // Helper methods to track game events
  void onSessionCompleted() {
    updateAchievementProgress('first_step', increment: true);
    updateAchievementProgress('legend', increment: true);
  }

  void onRoundCounted() {
    updateAchievementProgress('counter_master', increment: true);
  }

  void onConsecutiveWin() {
    updateAchievementProgress('invincible', increment: true);
  }

  void onPointsScoredInRound(int points) {
    if (points >= 10) {
      updateAchievementProgress('great_comeback', progress: 1);
    }
  }

  // Add more helper methods as needed for other achievement types
}

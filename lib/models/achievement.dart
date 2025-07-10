class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int progressRequired;
  final AchievementType type;
  int currentProgress;
  bool isUnlocked;
  DateTime? unlockedAt;
  bool isSeen;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.progressRequired,
    required this.type,
    this.currentProgress = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    this.isSeen = false,
  });

  double get progress => progressRequired > 0
      ? (currentProgress / progressRequired).clamp(0.0, 1.0)
      : 0.0;

  void updateProgress(int newProgress) {
    currentProgress = newProgress;
    if (!isUnlocked && currentProgress >= progressRequired) {
      isUnlocked = true;
      unlockedAt = DateTime.now();
      // A notification will be triggered by the AchievementService
    }
  }

  void incrementProgress([int amount = 1]) {
    updateProgress(currentProgress + amount);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'currentProgress': currentProgress,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'isSeen': isSeen,
      };

  factory Achievement.fromJson(
      Map<String, dynamic> json, Achievement template) {
    return Achievement(
      id: template.id,
      title: template.title,
      description: template.description,
      icon: template.icon,
      progressRequired: template.progressRequired,
      type: template.type,
      currentProgress: json['currentProgress'] ?? 0,
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'])
          : null,
      isSeen: json['isSeen'] ?? false,
    );
  }
}

enum AchievementType {
  sessionsCompleted,      // For tracking total games played
  gamesWon,               // For tracking total games won
  perfectGame,            // For winning with perfect score
  consecutiveDays,        // For tracking consecutive days played
  mastery,                // For unlocking all achievements
  longSession,            // For playing a long game session
  tieGame,                // For games that end in a tie
  quickWin,               // For winning a game quickly
  consistentScores,       // For consistent scoring across games
  consecutiveSessionWins, // For winning multiple sessions in a row
  roundsWithoutUndo,      // For playing rounds without using undo
  highScore,              // For achieving a high score
  noEliminations,         // For winning without eliminating any players
  comeback,               // For coming from behind to win
  perfectRounds,          // For playing perfect rounds
  totalRoundsCounted,     // For counting total rounds played
  equalWins,              // For games with equal number of wins
  fewEdits,               // For minimal edits during gameplay
  nightSession,           // For playing late at night
  perfectSessions,        // For perfect game sessions
}

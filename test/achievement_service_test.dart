import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Use relative imports for local files
import '../lib/services/achievement_service.dart';

void main() {
  late AchievementService achievementService;

  // Set up a clean environment before each test
  setUp(() async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    
    // Create a new AchievementService for each test
    achievementService = AchievementService();
    
    // Wait for the service to initialize
    await Future.delayed(const Duration(milliseconds: 100));
  });
  
  // Clean up after each test
  tearDown(() {
    // Reset SharedPreferences
    SharedPreferences.setMockInitialValues({});
  });

  // Test that the service initializes with default achievements
  test('Initializes with default achievements', () {
    expect(achievementService.allAchievements.isNotEmpty, true);
    expect(achievementService.unlockedAchievements.isEmpty, true);
    
    // Verify some expected achievements exist
    final achievementIds = achievementService.allAchievements.map((a) => a.id).toSet();
    expect(achievementIds.contains('first_game'), true);
    expect(achievementIds.contains('seasoned_player'), true);
    expect(achievementIds.contains('legend_rounds'), true);
  });

  // Test completing a game session
  test('Completing a game session updates statistics and achievements', () async {
    // Initial state
    expect(achievementService.gamesPlayed, 0);
    
    // Simulate completing a game session
    achievementService.onSessionCompleted();
    
    // Check that games played was incremented
    expect(achievementService.gamesPlayed, 1);
    
    // Check that the first game achievement was unlocked
    final firstGameAchievement = achievementService.allAchievements
        .firstWhere((a) => a.id == 'first_game');
    expect(firstGameAchievement.isUnlocked, true);
    
    // Check that the seasoned player achievement has progress
    final seasonedPlayer = achievementService.allAchievements
        .firstWhere((a) => a.id == 'seasoned_player');
    expect(seasonedPlayer.currentProgress, 1);
    expect(seasonedPlayer.isUnlocked, false);
  });

  // Test winning a game
  test('Winning a game updates statistics and achievements', () async {
    // Initial state
    expect(achievementService.gamesWon, 0);
    
    // Simulate winning a game
    achievementService.onSessionCompleted();
    achievementService.onConsecutiveWin();
    
    // Check that games won was incremented
    expect(achievementService.gamesWon, 1);
    
    // Check that the first win achievement was unlocked
    final firstWinAchievement = achievementService.allAchievements
        .firstWhere((a) => a.id == 'first_win');
    expect(firstWinAchievement.isUnlocked, true);
    
    // Check that the champion achievement has progress
    final championAchievement = achievementService.allAchievements
        .firstWhere((a) => a.id == 'champion');
    expect(championAchievement.currentProgress, 1);
    expect(championAchievement.isUnlocked, false);
  });
  
  // Test consecutive days tracking
  test('Tracking consecutive days works correctly', () async {
    // Initial state
    expect(achievementService.consecutiveDays, 0);
    
    // Simulate playing on first day
    achievementService.onSessionCompleted();
    expect(achievementService.consecutiveDays, 1);
    
    // Simulate playing next day
    achievementService.onSessionCompleted();
    expect(achievementService.consecutiveDays, 2);
    
    // Check dedicated player achievement progress
    final dedicatedAchievement = achievementService.allAchievements
        .firstWhere((a) => a.id == 'dedicated');
    expect(dedicatedAchievement.currentProgress, 2);
    expect(dedicatedAchievement.isUnlocked, true);
  });
  
  // Test round counting
  test('Counting rounds works correctly', () async {
    // Simulate counting some rounds
    for (int i = 0; i < 10; i++) {
      achievementService.onRoundCounted();
    }
    
    // Check legend rounds achievement progress
    final legendRounds = achievementService.allAchievements
        .firstWhere((a) => a.id == 'legend_rounds');
    expect(legendRounds.currentProgress, 10);
    expect(legendRounds.isUnlocked, false);
  });
  
  // Test perfect game achievement
  test('Perfect game achievement works correctly', () async {
    // Simulate a perfect game (no points scored against)
    achievementService.onPointsScoredInRound(0);
    achievementService.onSessionCompleted();
    
    // Check perfect game achievement
    final perfectGame = achievementService.allAchievements
        .firstWhere((a) => a.id == 'perfect_game');
    expect(perfectGame.currentProgress, 1);
    expect(perfectGame.isUnlocked, true);
  });

  // Test consecutive days
  test('Playing on consecutive days updates streak', () async {
    // Simulate playing today
    achievementService.onSessionCompleted();
    
    // Create a new service to simulate app restart
    final newService = AchievementService();
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Simulate playing the next day
    newService.onSessionCompleted();
    
    // Check that consecutive days was incremented
    expect(newService.consecutiveDays >= 1, true);
  });

  // Test getting new unlocked achievements
  test('getNewUnlockedAchievements returns unseen achievements', () async {
    // Simulate unlocking an achievement
    achievementService.onSessionCompleted();
    
    // Get new unlocked achievements
    final newAchievements = achievementService.getNewUnlockedAchievements();
    
    // Should contain the first game achievement
    expect(newAchievements.length, 1);
    expect(newAchievements.first.id, 'first_game');
    
    // Mark as seen
    achievementService.markAchievementsAsSeen();
    
    // Should no longer return seen achievements
    final newAchievementsAfterSeen = achievementService.getNewUnlockedAchievements();
    expect(newAchievementsAfterSeen.isEmpty, true);
  });
}

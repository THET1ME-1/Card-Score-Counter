import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/achievement.dart';
import 'services/achievement_service.dart';

// Helper function to get category name from achievement type
String _getCategoryName(AchievementType type) {
  switch (type) {
    case AchievementType.sessionsCompleted:
    case AchievementType.perfectSessions:
    case AchievementType.longSession:
      return 'Игровые сессии';
    case AchievementType.gamesWon:
    case AchievementType.consecutiveSessionWins:
    case AchievementType.quickWin:
    case AchievementType.comeback:
      return 'Победы';
    case AchievementType.perfectGame:
    case AchievementType.perfectRounds:
    case AchievementType.highScore:
      return 'Идеальные игры';
    case AchievementType.consecutiveDays:
    case AchievementType.nightSession:
      return 'Активность';
    case AchievementType.mastery:
    case AchievementType.consistentScores:
    case AchievementType.roundsWithoutUndo:
    case AchievementType.noEliminations:
    case AchievementType.totalRoundsCounted:
    case AchievementType.equalWins:
    case AchievementType.fewEdits:
      return 'Мастерство';
    default:
      return 'Другие';
  }
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final achievementService = Provider.of<AchievementService>(context);
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Достижения'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.star), text: 'Все'),
              Tab(icon: Icon(Icons.emoji_events), text: 'Полученные'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildStatsSummary(achievementService, context),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAllAchievementsView(achievementService, context),
                  _buildUnlockedAchievementsView(achievementService, context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build stats summary widget
  Widget _buildStatsSummary(AchievementService service, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика игрока',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Игр сыграно', '${service.gamesPlayed}'),
              _buildStatItem('Побед', '${service.gamesWon}'),
              _buildStatItem('Дней подряд', '${service.consecutiveDays}'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
  
  // Build all achievements view with categories
  Widget _buildAllAchievementsView(AchievementService service, BuildContext context) {
    final achievements = service.allAchievements;
    
    // Group achievements by category
    final Map<AchievementType, List<Achievement>> achievementsByCategory = {};
    for (var achievement in achievements) {
      achievementsByCategory.putIfAbsent(achievement.type, () => []).add(achievement);
    }
    
    return ListView.builder(
      itemCount: achievementsByCategory.length,
      itemBuilder: (context, index) {
        final category = achievementsByCategory.keys.elementAt(index);
        final categoryAchievements = achievementsByCategory[category]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _getCategoryName(category),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...categoryAchievements.map((achievement) => _buildAchievementItem(achievement, context)),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
  
  // Build unlocked achievements view
  Widget _buildUnlockedAchievementsView(AchievementService service, BuildContext context) {
    final unlocked = service.unlockedAchievements;
    
    if (unlocked.isEmpty) {
      return const Center(
        child: Text('У вас пока нет достижений'),
      );
    }
    
    return ListView.builder(
      itemCount: unlocked.length,
      itemBuilder: (context, index) {
        return _buildAchievementItem(unlocked[index], context);
      },
    );
  }
  
  // Build individual achievement item
  Widget _buildAchievementItem(Achievement achievement, BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isUnlocked ? Colors.green[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              achievement.icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          achievement.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isUnlocked ? Colors.black87 : Colors.grey[600],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              achievement.description,
              style: TextStyle(
                color: isUnlocked ? Colors.black87 : Colors.grey[600],
              ),
            ),
            if (achievement.progressRequired > 1) ...[
              const SizedBox(height: 4.0),
              LinearProgressIndicator(
                value: achievement.progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isUnlocked ? Colors.green : Theme.of(context).primaryColor,
                ),
              ),
              Text(
                '${achievement.currentProgress} из ${achievement.progressRequired} (${(achievement.progress * 100).toInt()}%)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isUnlocked ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        trailing: isUnlocked
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.lock, color: Colors.grey),
      ),
    );
  }
}

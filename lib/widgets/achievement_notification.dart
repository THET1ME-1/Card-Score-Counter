import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';

class AchievementNotification extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismissed;
  
  const AchievementNotification({
    super.key,
    required this.achievement,
    required this.onDismissed,
  });

  @override
  _AchievementNotificationState createState() => _AchievementNotificationState();
}

class _AchievementNotificationState extends State<AchievementNotification> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
    
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    widget.achievement.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Достижение разблокировано!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.achievement.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.achievement.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _dismiss,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AchievementNotifier extends StatefulWidget {
  final Widget child;
  
  const AchievementNotifier({
    super.key,
    required this.child,
  });

  @override
  _AchievementNotifierState createState() => _AchievementNotifierState();
}

class _AchievementNotifierState extends State<AchievementNotifier> {
  List<Achievement> _pendingAchievements = [];
  bool _isShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to achievement service
    final achievementService = Provider.of<AchievementService>(context, listen: false);
    achievementService.addListener(_checkForNewAchievements);
  }

  void _checkForNewAchievements() {
    final achievementService = Provider.of<AchievementService>(context, listen: false);
    final newAchievements = achievementService.getNewUnlockedAchievements();
    
    if (newAchievements.isNotEmpty && !_isShowing) {
      setState(() {
        _pendingAchievements = newAchievements;
        _isShowing = true;
      });
    }
  }

  void _onDismissed() {
    if (_pendingAchievements.isNotEmpty) {
      // Mark the current achievement as seen
      final achievementService = Provider.of<AchievementService>(context, listen: false);
      achievementService.markAchievementsAsSeen();
      
      setState(() {
        _pendingAchievements.removeAt(0);
        if (_pendingAchievements.isEmpty) {
          _isShowing = false;
        }
      });
    } else {
      setState(() {
        _isShowing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isShowing && _pendingAchievements.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: AchievementNotification(
              achievement: _pendingAchievements.first,
              onDismissed: _onDismissed,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    final achievementService = Provider.of<AchievementService>(context, listen: false);
    achievementService.removeListener(_checkForNewAchievements);
    super.dispose();
  }
}

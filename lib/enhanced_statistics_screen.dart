import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'services/game_repository.dart';

enum TimePeriod { day, month, year }

class EnhancedStatisticsScreen extends StatefulWidget {
  const EnhancedStatisticsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _EnhancedStatisticsScreenState createState() =>
      _EnhancedStatisticsScreenState();
}

class PlayerStats {
  final String name;
  final Color color;
  final int totalWins;
  final int totalGames;
  final double winPercentage;
  final String? imagePath;
  final Map<String, int> dailyWins;
  final Map<String, int> dailyGames;
  final Map<String, int> monthlyWins;
  final Map<String, int> monthlyGames;
  final Map<String, int> yearlyWins;
  final Map<String, int> yearlyGames;

  PlayerStats({
    required this.name,
    required this.color,
    required this.totalWins,
    required this.totalGames,
    required this.winPercentage,
    this.imagePath,
    Map<String, int>? dailyWins,
    Map<String, int>? dailyGames,
    Map<String, int>? monthlyWins,
    Map<String, int>? monthlyGames,
    Map<String, int>? yearlyWins,
    Map<String, int>? yearlyGames,
  })  : dailyWins = dailyWins ?? {},
        dailyGames = dailyGames ?? {},
        monthlyWins = monthlyWins ?? {},
        monthlyGames = monthlyGames ?? {},
        yearlyWins = yearlyWins ?? {},
        yearlyGames = yearlyGames ?? {};

  String get formattedWinPercentage => winPercentage.toStringAsFixed(1);

  double get gamesPerWin => totalWins > 0 ? totalGames / totalWins : 0;

  String get lastActiveMonth {
    if (monthlyGames.isEmpty) return 'Нет данных';
    final sortedMonths = monthlyGames.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final lastMonth = sortedMonths.first;
    return '${_formatMonth(lastMonth)} (${monthlyGames[lastMonth]} игр)';
  }

  static String _formatMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final year = int.tryParse(parts[0]) ?? 0;
    final monthNum = int.tryParse(parts[1]) ?? 0;
    if (monthNum < 1 || monthNum > 12) return month;

    final monthNames = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь'
    ];

    return '${monthNames[monthNum - 1]} $year';
  }
}

class _EnhancedStatisticsScreenState extends State<EnhancedStatisticsScreen>
    with SingleTickerProviderStateMixin {
  List<PlayerStats> allPlayersStats = [];
  PlayerStats? selectedPlayerStats;
  bool _isLoading = true;
  late TabController _tabController;
  final int _tabsCount = 3;
  final PageController _pageController = PageController();

  // Chart data
  TimePeriod _selectedPeriod = TimePeriod.month;
  
  // Date formatters
  final _dayFormat = DateFormat('yyyy-MM-dd');
  final _monthFormat = DateFormat('yyyy-MM');
  final _yearFormat = DateFormat('yyyy');
  final _displayDayFormat = DateFormat('dd.MM.yy');
  final _displayMonthFormat = DateFormat('MMM yyyy');

  List<Color> gradientColors = [
    const Color(0xff23b6e6),
    const Color(0xff02d39a),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: _tabsCount);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    final games = await GameRepository.instance.loadGames();
    final profiles = await GameRepository.instance.loadProfiles();

    final Map<String, PlayerStats> statsMap = {};

    // Process game history to count total games and stats per player
    for (final game in games) {
      try {
        final players = game.players;
        final gameDate = game.date;

        // Create keys for different time periods
        final dayKey = _dayFormat.format(gameDate);
        final monthKey = _monthFormat.format(gameDate);
        final yearKey = _yearFormat.format(gameDate);

        // Check if this game has a winner (last remaining player)
        final String? winner = game.winner;

        for (var player in players) {
          final isWinner = winner == player;
          statsMap.update(
            player,
            (existing) {
              // Create copies of the maps to avoid modifying them directly
              final dailyWins = Map<String, int>.from(existing.dailyWins);
              final dailyGames = Map<String, int>.from(existing.dailyGames);
              final monthlyWins = Map<String, int>.from(existing.monthlyWins);
              final monthlyGames = Map<String, int>.from(existing.monthlyGames);
              final yearlyWins = Map<String, int>.from(existing.yearlyWins);
              final yearlyGames = Map<String, int>.from(existing.yearlyGames);

              // Update daily stats
              dailyGames.update(dayKey, (value) => value + 1, ifAbsent: () => 1);
              if (isWinner) {
                dailyWins.update(dayKey, (value) => value + 1, ifAbsent: () => 1);
              }
              
              // Update monthly stats
              monthlyGames.update(monthKey, (value) => value + 1, ifAbsent: () => 1);
              if (isWinner) {
                monthlyWins.update(monthKey, (value) => value + 1, ifAbsent: () => 1);
              }
              
              // Update yearly stats
              yearlyGames.update(yearKey, (value) => value + 1, ifAbsent: () => 1);
              if (isWinner) {
                yearlyWins.update(yearKey, (value) => value + 1, ifAbsent: () => 1);
              }

              return PlayerStats(
                name: existing.name,
                color: existing.color,
                totalWins: isWinner ? existing.totalWins + 1 : existing.totalWins,
                totalGames: existing.totalGames + 1,
                winPercentage: 0, // Will be calculated later
                imagePath: existing.imagePath,
                dailyWins: dailyWins,
                dailyGames: dailyGames,
                monthlyWins: monthlyWins,
                monthlyGames: monthlyGames,
                yearlyWins: yearlyWins,
                yearlyGames: yearlyGames,
              );
            },
            ifAbsent: () {
              final dailyWins = <String, int>{};
              final dailyGames = <String, int>{dayKey: 1};
              final monthlyWins = <String, int>{};
              final monthlyGames = <String, int>{monthKey: 1};
              final yearlyWins = <String, int>{};
              final yearlyGames = <String, int>{yearKey: 1};

              if (isWinner) {
                dailyWins[dayKey] = 1;
                monthlyWins[monthKey] = 1;
                yearlyWins[yearKey] = 1;
              }

              return PlayerStats(
                name: player,
                color: Colors.grey,
                totalWins: isWinner ? 1 : 0,
                totalGames: 1,
                winPercentage: isWinner ? 100.0 : 0.0,
                dailyWins: dailyWins,
                dailyGames: dailyGames,
                monthlyWins: monthlyWins,
                monthlyGames: monthlyGames,
                yearlyWins: yearlyWins,
                yearlyGames: yearlyGames,
              );
            },
          );
        }
      } catch (e) {
        debugPrint('Error processing game history: $e');
      }
    }

    // Process profiles to get colors and update stats
    for (final profile in profiles) {
      try {
        if (statsMap.containsKey(profile.name)) {
          final stats = statsMap[profile.name]!;
          final winPercentage = stats.totalGames > 0
              ? (stats.totalWins / stats.totalGames * 100)
              : 0;

          statsMap[profile.name] = PlayerStats(
            name: profile.name,
            color: profile.color,
            totalWins: profile.wins,
            totalGames: stats.totalGames,
            winPercentage: winPercentage.toDouble(),
            imagePath: profile.imagePath,
            dailyWins: stats.dailyWins,
            dailyGames: stats.dailyGames,
            monthlyWins: stats.monthlyWins,
            monthlyGames: stats.monthlyGames,
            yearlyWins: stats.yearlyWins,
            yearlyGames: stats.yearlyGames,
          );
        } else {
          statsMap[profile.name] = PlayerStats(
            name: profile.name,
            color: profile.color,
            totalWins: profile.wins,
            totalGames: 0,
            winPercentage: 0,
            imagePath: profile.imagePath,
          );
        }
      } catch (e) {
        debugPrint('Error processing profile: $e');
      }
    }

    final statsList = statsMap.values.toList()
      ..sort((a, b) => b.totalWins.compareTo(a.totalWins));

    if (mounted) {
      setState(() {
        allPlayersStats = statsList;
        if (statsList.isNotEmpty) {
          selectedPlayerStats = statsList.first;
        }
        _isLoading = false;
      });
    }
  }

  Widget _buildPlayerAvatar(PlayerStats stats, {double radius = 30}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: stats.color.withValues(alpha: 0.3),
      child: stats.imagePath != null && File(stats.imagePath!).existsSync()
          ? ClipOval(
              child: Image.file(
                File(stats.imagePath!), // Safe due to the condition above
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
              ),
            )
          : Text(
              stats.name.isNotEmpty ? stats.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: radius * 0.7,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPeriodButton('День', TimePeriod.day),
          const SizedBox(width: 8),
          _buildPeriodButton('Месяц', TimePeriod.month),
          const SizedBox(width: 8),
          _buildPeriodButton('Год', TimePeriod.year),
        ],
      ),
    );
  }
  
  Widget _buildPeriodButton(String label, TimePeriod period) {
    final isSelected = _selectedPeriod == period;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildWinRateChart() {
    if (selectedPlayerStats == null) return const SizedBox.shrink();
    final stats = selectedPlayerStats!;
    
    // Get data based on selected period
    Map<String, int> periodGames;
    Map<String, int> periodWins;
    
    switch (_selectedPeriod) {
      case TimePeriod.day:
        periodGames = stats.dailyGames;
        periodWins = stats.dailyWins;
        break;
      case TimePeriod.year:
        periodGames = stats.yearlyGames;
        periodWins = stats.yearlyWins;
        break;
      case TimePeriod.month:
        periodGames = stats.monthlyGames;
        periodWins = stats.monthlyWins;
    }
    
    // Sort periods chronologically
    final periods = periodGames.keys.toList()..sort((a, b) {
      try {
        if (_selectedPeriod == TimePeriod.day) {
          return _dayFormat.parse(a).compareTo(_dayFormat.parse(b));
        } else if (_selectedPeriod == TimePeriod.month) {
          return _monthFormat.parse(a).compareTo(_monthFormat.parse(b));
        } else {
          return int.parse(a).compareTo(int.parse(b));
        }
      } catch (e) {
        return a.compareTo(b);
      }
    });

    if (periods.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Недостаточно данных для отображения графика',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Выберите другой период или дождитесь накопления данных',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    // Group data for better visualization if there are many points
    final int maxVisibleBars = 12;
    final Map<String, int> groupedGames = {};
    final Map<String, int> groupedWins = {};
    
    if (periods.length > maxVisibleBars) {
      final groupSize = (periods.length / maxVisibleBars).ceil();
      
      for (int i = 0; i < periods.length; i += groupSize) {
        final end = (i + groupSize < periods.length) ? i + groupSize : periods.length;
        final groupKey = '${periods[i]} - ${periods[end - 1]}';
        
        int totalGames = 0;
        int totalWins = 0;
        
        for (int j = i; j < end; j++) {
          final period = periods[j];
          totalGames += periodGames[period] ?? 0;
          totalWins += periodWins[period] ?? 0;
        }
        
        groupedGames[groupKey] = totalGames;
        groupedWins[groupKey] = totalWins;
      }
    } else {
      for (final period in periods) {
        groupedGames[period] = periodGames[period] ?? 0;
        groupedWins[period] = periodWins[period] ?? 0;
      }
    }
    
    final visiblePeriods = groupedGames.keys.toList();
    
    // Format period for display
    String formatPeriod(String periodStr) {
      try {
        if (periodStr.contains(' - ')) {
          final parts = periodStr.split(' - ');
          if (parts.length == 2) {
            if (_selectedPeriod == TimePeriod.day) {
              final start = _displayDayFormat.format(_dayFormat.parse(parts[0]));
              final end = _displayDayFormat.format(_dayFormat.parse(parts[1]));
              return '$start - $end';
            } else if (_selectedPeriod == TimePeriod.month) {
              final start = _displayMonthFormat.format(_monthFormat.parse(parts[0]));
              final end = _displayMonthFormat.format(_monthFormat.parse(parts[1]));
              return '$start - $end';
            }
            return periodStr;
          }
        }
        
        if (_selectedPeriod == TimePeriod.day) {
          final date = _dayFormat.parse(periodStr);
          return _displayDayFormat.format(date);
        } else if (_selectedPeriod == TimePeriod.month) {
          final date = _monthFormat.parse(periodStr);
          return _displayMonthFormat.format(date);
        }
        return periodStr;
      } catch (e) {
        return periodStr;
      }
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статистика побед по ${_selectedPeriod == TimePeriod.day ? 'дням' : _selectedPeriod == TimePeriod.month ? 'месяцам' : 'годам'},',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final period = visiblePeriods[group.x.toInt()];
                        final games = groupedGames[period] ?? 0;
                        final wins = groupedWins[period] ?? 0;
                        final winRate = rod.toY;
                        
                        return BarTooltipItem(
                          '${formatPeriod(period)}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: '${winRate.toStringAsFixed(1)}% побед\n',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: '$wins из $games игр',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < visiblePeriods.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                formatPeriod(visiblePeriods[value.toInt()]),
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    visiblePeriods.length,
                    (index) {
                      final period = visiblePeriods[index];
                      final games = groupedGames[period] ?? 0;
                      final wins = groupedWins[period] ?? 0;
                      final winRate = games > 0 ? (wins / games) * 100 : 0;

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: winRate.toDouble(),
                            color: Theme.of(context).primaryColor,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 100,
                              color: Colors.grey[200]!,
                            ),
                          ),
                        ],
                        showingTooltipIndicators: [0],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinPieChart() {
    if (allPlayersStats.isEmpty) return const SizedBox.shrink();

    final totalWins =
        allPlayersStats.fold<int>(0, (sum, player) => sum + player.totalWins);
    if (totalWins == 0) {
      return const Center(
        child: Text('Нет данных о победах'),
      );
    }

    // Sort players by wins (descending)
    final sortedPlayers = List<PlayerStats>.from(allPlayersStats)
      ..sort((a, b) => b.totalWins.compareTo(a.totalWins));

    // Take top 5 players + group others
    final topPlayers = sortedPlayers.take(5).toList();
    final otherWins = sortedPlayers
        .skip(5)
        .fold<int>(0, (sum, player) => sum + player.totalWins);

    final pieSections = <PieChartSectionData>[];

    // Add top players
    for (var player in topPlayers) {
      if (player.totalWins == 0) continue;

      final percentage =
          (player.totalWins / totalWins * 100).toStringAsFixed(1);

      pieSections.add(
        PieChartSectionData(
          color: player.color,
          value: player.totalWins.toDouble(),
          title: '${player.name}\n$percentage%',
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 2),
            ],
          ),
        ),
      );
    }

    // Add "Others" section if needed
    if (otherWins > 0) {
      final otherPercentage = (otherWins / totalWins * 100).toStringAsFixed(1);

      pieSections.add(
        PieChartSectionData(
          color: Colors.grey,
          value: otherWins.toDouble(),
          title: 'Другие\n$otherPercentage%',
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 2),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Распределение побед',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: pieSections,
                  startDegreeOffset: -90,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStats() {
    if (selectedPlayerStats == null) return const SizedBox.shrink();

    final stats = selectedPlayerStats!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Player header
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildPlayerAvatar(stats, radius: 40),
                  const SizedBox(height: 16),
                  Text(
                    stats.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${stats.totalWins} побед • ${stats.totalGames} игр • ${stats.formattedWinPercentage}% побед',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Stats grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(
                  'Побед',
                  '${stats.totalWins}',
                  Icons.emoji_events,
                  Colors.amber,
                ),
                _buildStatCard(
                  'Игр',
                  '${stats.totalGames}',
                  Icons.games,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Побед/игру',
                  stats.gamesPerWin.toStringAsFixed(1),
                  Icons.trending_up,
                  Colors.green,
                ),
                _buildStatCard(
                  'Последняя игра',
                  stats.lastActiveMonth,
                  Icons.calendar_today,
                  Colors.purple,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Period selector for the chart
          _buildPeriodSelector(),
          
          // Win rate chart
          _buildWinRateChart(),
          
          // Win distribution chart
          _buildWinPieChart(),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика игроков'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.brightness == Brightness.dark ? Colors.white : theme.primaryColor,
          unselectedLabelColor:
              theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
          indicator: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            color: theme.primaryColor.withValues(alpha: 0.1),
          ),
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Игрок'),
            Tab(icon: Icon(Icons.leaderboard), text: 'Лидеры'),
            Tab(icon: Icon(Icons.analytics), text: 'Аналитика'),
          ],
          onTap: (index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : allPlayersStats.isEmpty
              ? const Center(child: Text('Нет данных о статистике игроков'))
              : Column(
                  children: [
                    // Player selector
                    if (selectedPlayerStats != null &&
                        _tabController.index == 0)
                      Container(
                        height: 100,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: allPlayersStats.length,
                          itemBuilder: (context, index) {
                            final player = allPlayersStats[index];
                            final isSelected =
                                selectedPlayerStats?.name == player.name;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedPlayerStats = player;
                                });
                              },
                              child: Container(
                                width: 80,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        _buildPlayerAvatar(player, radius: 30),
                                        if (isSelected)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: theme
                                                      .scaffoldBackgroundColor,
                                                  width: 2,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      player.name
                                          .split(' ')
                                          .map((s) => s.isNotEmpty ? s[0] : '')
                                          .join(''),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? theme.primaryColor
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Content
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          _tabController.animateTo(index);
                        },
                        children: [
                          // Player stats tab
                          _buildPlayerStats(),

                          // Leaderboard tab
                          ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: allPlayersStats.length,
                            itemBuilder: (context, index) {
                              final player = allPlayersStats[index];
                              final rank = index + 1;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: Text(
                                    '#$rank',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  title: Text(
                                    player.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${player.totalWins} побед • ${player.totalGames} игр • ${player.formattedWinPercentage}% побед',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing:
                                      _buildPlayerAvatar(player, radius: 20),
                                  onTap: () {
                                    setState(() {
                                      selectedPlayerStats = player;
                                      _tabController.animateTo(0);
                                      _pageController.animateToPage(
                                        0,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    });
                                  },
                                ),
                              );
                            },
                          ),

                          // Analytics tab
                          SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildWinPieChart(),
                                _buildWinRateChart(),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

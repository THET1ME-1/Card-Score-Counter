// Модель волейбольного матча: счёт по очкам/сетам считается «реплеем» списка
// событий [events], поэтому отмена хода — это просто удаление последнего
// события. Поддерживает три формата (стандарт/короткий/свободный) с
// настраиваемым числом очков за сет.

/// Формат матча.
enum VbFormat { standard, short, free }

/// Параметры подсчёта.
class VolleyballConfig {
  final VbFormat format;
  final int pointsToWin; // очков в обычном сете (по умолчанию 25)
  final int tiebreakPoints; // очков в решающем сете (по умолчанию 15)
  final int winBy; // разница для победы в сете (2)

  const VolleyballConfig({
    this.format = VbFormat.standard,
    this.pointsToWin = 25,
    this.tiebreakPoints = 15,
    this.winBy = 2,
  });

  bool get isFree => format == VbFormat.free;

  /// Сколько выигранных сетов нужно для победы в матче.
  int get setsToWin => switch (format) {
        VbFormat.standard => 3, // best of 5
        VbFormat.short => 2, // best of 3
        VbFormat.free => 1 << 20, // не авто-завершается
      };

  VolleyballConfig copyWith({
    VbFormat? format,
    int? pointsToWin,
    int? tiebreakPoints,
    int? winBy,
  }) =>
      VolleyballConfig(
        format: format ?? this.format,
        pointsToWin: pointsToWin ?? this.pointsToWin,
        tiebreakPoints: tiebreakPoints ?? this.tiebreakPoints,
        winBy: winBy ?? this.winBy,
      );

  Map<String, dynamic> toJson() => {
        'format': format.name,
        'pointsToWin': pointsToWin,
        'tiebreakPoints': tiebreakPoints,
        'winBy': winBy,
      };

  factory VolleyballConfig.fromJson(Map<String, dynamic> j) => VolleyballConfig(
        format: VbFormat.values.firstWhere(
          (f) => f.name == j['format'],
          orElse: () => VbFormat.standard,
        ),
        pointsToWin: (j['pointsToWin'] as num?)?.toInt() ?? 25,
        tiebreakPoints: (j['tiebreakPoints'] as num?)?.toInt() ?? 15,
        winBy: (j['winBy'] as num?)?.toInt() ?? 2,
      );
}

/// Одно очко в таймлайне: какая команда забила и какой стал счёт у неё.
class VbPoint {
  final int team; // 0/1
  final int score; // счёт команды после этого очка
  const VbPoint(this.team, this.score);
}

/// Снимок состояния матча после реплея событий.
class VbState {
  final int pointsA;
  final int pointsB;
  final int setsA;
  final int setsB;
  final int server; // 0/1 — кто подаёт сейчас
  final bool finished;
  final int? winner; // 0/1 или null
  final List<List<int>> completedSets; // [a,b] завершённых сетов
  final List<List<VbPoint>> setTimelines; // очки по каждому сету (вкл. текущий)

  const VbState({
    required this.pointsA,
    required this.pointsB,
    required this.setsA,
    required this.setsB,
    required this.server,
    required this.finished,
    required this.winner,
    required this.completedSets,
    required this.setTimelines,
  });
}

class VolleyballMatch {
  final String id;
  final DateTime date;
  final List<String> teamNames; // [a, b]
  final List<int> teamColors; // argb [a, b]
  VolleyballConfig config;

  /// События: 0 — очко команде A, 1 — очко команде B, -1 — «завершить сет»
  /// (только в свободном режиме).
  final List<int> events;

  /// Кто подавал первым (0/1).
  int firstServer;

  VolleyballMatch({
    required this.id,
    required this.date,
    required this.teamNames,
    required this.teamColors,
    required this.config,
    List<int>? events,
    this.firstServer = 0,
  }) : events = events ?? <int>[];

  /// Реплей событий → текущее состояние.
  VbState replay() {
    var pa = 0, pb = 0, setsA = 0, setsB = 0;
    var server = firstServer;
    var finished = false;
    int? winner;
    final completed = <List<int>>[];
    final timelines = <List<VbPoint>>[<VbPoint>[]];

    void closeSet() {
      completed.add([pa, pb]);
      if (pa > pb) {
        setsA++;
      } else if (pb > pa) {
        setsB++;
      }
      if (!config.isFree) {
        if (setsA >= config.setsToWin) {
          finished = true;
          winner = 0;
        } else if (setsB >= config.setsToWin) {
          finished = true;
          winner = 1;
        }
      }
      pa = 0;
      pb = 0;
      timelines.add(<VbPoint>[]);
    }

    for (final ev in events) {
      if (finished) break;
      if (ev == -1) {
        // ручное завершение сета (свободный режим)
        if (pa > 0 || pb > 0) closeSet();
        continue;
      }
      if (ev == 0) {
        pa++;
        server = 0;
        timelines.last.add(VbPoint(0, pa));
      } else {
        pb++;
        server = 1;
        timelines.last.add(VbPoint(1, pb));
      }
      if (!config.isFree) {
        final isDecider =
            setsA == config.setsToWin - 1 && setsB == config.setsToWin - 1;
        final target = isDecider ? config.tiebreakPoints : config.pointsToWin;
        final hi = pa > pb ? pa : pb;
        if (hi >= target && (pa - pb).abs() >= config.winBy) {
          closeSet();
        }
      }
    }

    return VbState(
      pointsA: pa,
      pointsB: pb,
      setsA: setsA,
      setsB: setsB,
      server: server,
      finished: finished,
      winner: winner,
      completedSets: completed,
      setTimelines: timelines,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'teamNames': teamNames,
        'teamColors': teamColors,
        'config': config.toJson(),
        'events': events,
        'firstServer': firstServer,
      };

  factory VolleyballMatch.fromJson(Map<String, dynamic> j) => VolleyballMatch(
        id: j['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
        teamNames: (j['teamNames'] as List?)?.map((e) => e.toString()).toList() ??
            ['A', 'B'],
        teamColors: (j['teamColors'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [0xFF3FA34D, 0xFF3B6FE0],
        config: j['config'] is Map
            ? VolleyballConfig.fromJson(
                (j['config'] as Map).cast<String, dynamic>())
            : const VolleyballConfig(),
        events:
            (j['events'] as List?)?.map((e) => (e as num).toInt()).toList() ??
                <int>[],
        firstServer: (j['firstServer'] as num?)?.toInt() ?? 0,
      );
}

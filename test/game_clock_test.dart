import 'package:flutter_test/flutter_test.dart';
import 'package:score_master/utils/game_clock.dart';

void main() {
  // Управляемое «сейчас»: тесты двигают время вручную, без реальных задержек.
  late DateTime now;
  GameClock make({int playerCount = 2, int matchMs = 0, List<int>? playerMs}) =>
      GameClock(
        playerCount: playerCount,
        matchMs: matchMs,
        playerMs: playerMs,
        now: () => now,
      );

  setUp(() => now = DateTime(2026, 7, 25, 12, 0, 0));

  void advance(Duration d) => now = now.add(d);

  test('время партии растёт, пока часы идут', () {
    final clock = make()..start();
    advance(const Duration(minutes: 3));
    expect(clock.liveMatchMs, const Duration(minutes: 3).inMilliseconds);
  });

  test('фиксация отрезка не сбрасывает время хода', () {
    // Так уходит в фон живая партия: время сохраняется, ход продолжается.
    final clock = make()..start();
    advance(const Duration(seconds: 60));
    clock.flush();
    advance(const Duration(seconds: 30));
    expect(clock.liveTurnMs, const Duration(seconds: 90).inMilliseconds);
    expect(clock.liveMatchMs, const Duration(seconds: 90).inMilliseconds);
  });

  test('время идёт и в фоне: свернули на 10 минут — партия и ход выросли', () {
    final clock = make()..start();
    advance(const Duration(seconds: 5));
    clock.onBackground(); // сворачивание — только фиксация, без остановки
    advance(const Duration(minutes: 10));
    clock.onForeground();
    expect(clock.liveMatchMs, const Duration(minutes: 10, seconds: 5).inMilliseconds);
    expect(clock.liveTurnMs, const Duration(minutes: 10, seconds: 5).inMilliseconds);
    expect(clock.running, isTrue);
  });

  test('смена хода обнуляет ход и начисляет время прошлому игроку', () {
    final clock = make()..start();
    advance(const Duration(seconds: 40));
    clock.switchTurn(1);
    advance(const Duration(seconds: 15));
    expect(clock.liveTurnMs, const Duration(seconds: 15).inMilliseconds);
    expect(clock.livePlayerMs(), [
      const Duration(seconds: 40).inMilliseconds,
      const Duration(seconds: 15).inMilliseconds,
    ]);
  });

  test('пауза замораживает счёт, а ход не сбрасывается', () {
    final clock = make()..start();
    advance(const Duration(seconds: 20));
    clock.stop();
    advance(const Duration(minutes: 5));
    expect(clock.liveMatchMs, const Duration(seconds: 20).inMilliseconds);
    expect(clock.liveTurnMs, const Duration(seconds: 20).inMilliseconds);
    clock.start();
    advance(const Duration(seconds: 10));
    expect(clock.liveTurnMs, const Duration(seconds: 30).inMilliseconds);
  });

  test('в режимах без хода время игрокам не начисляется', () {
    final clock = make()..creditsPlayers = false;
    clock.start();
    advance(const Duration(seconds: 30));
    expect(clock.liveMatchMs, const Duration(seconds: 30).inMilliseconds);
    expect(clock.livePlayerMs(), [0, 0]);
  });

  test('сброс обнуляет партию, игроков и ход, часы продолжают идти', () {
    final clock = make()..start();
    advance(const Duration(minutes: 2));
    clock.resetTotals();
    expect(clock.liveMatchMs, 0);
    expect(clock.liveTurnMs, 0);
    expect(clock.livePlayerMs(), [0, 0]);
    advance(const Duration(seconds: 7));
    expect(clock.liveMatchMs, const Duration(seconds: 7).inMilliseconds);
  });

  test('накопленное из сохранённой партии продолжается, а не теряется', () {
    final clock = make(matchMs: 60000, playerMs: [40000, 20000])..start();
    advance(const Duration(seconds: 10));
    expect(clock.liveMatchMs, 70000);
    expect(clock.livePlayerMs(), [50000, 20000]);
  });

  test('переведённые назад системные часы не дают отрицательного времени', () {
    final clock = make()..start();
    now = now.subtract(const Duration(hours: 1));
    expect(clock.liveMatchMs, 0);
    expect(clock.liveTurnMs, 0);
  });

  test('список времени по игрокам подгоняется под число игроков', () {
    final clock = make(playerCount: 3, playerMs: [1000]);
    expect(clock.livePlayerMs(), [1000, 0, 0]);
  });
}

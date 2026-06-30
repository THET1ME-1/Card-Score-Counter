import 'package:flutter_test/flutter_test.dart';
import 'package:score_master/models/volleyball_match.dart';

VolleyballMatch _match(VolleyballConfig c) => VolleyballMatch(
      id: 't',
      date: DateTime(2026, 1, 1),
      teamNames: const ['A', 'B'],
      teamColors: const [0, 1],
      config: c,
    );

void main() {
  test('Сет закрывается при 25 с разницей 2', () {
    final m = _match(const VolleyballConfig());
    // A набирает 25, B — 0.
    for (var i = 0; i < 25; i++) {
      m.events.add(0);
    }
    final st = m.replay();
    expect(st.setsA, 1);
    expect(st.completedSets.first, [25, 0]);
    expect(st.pointsA, 0); // новый сет начался
    expect(st.finished, false);
  });

  test('Нужна разница в 2 очка (24:24 → 26:24)', () {
    final m = _match(const VolleyballConfig());
    for (var i = 0; i < 24; i++) {
      m.events..add(0)..add(1); // 24:24
    }
    m.events..add(0)..add(0); // 26:24
    final st = m.replay();
    expect(st.setsA, 1);
    expect(st.completedSets.first, [26, 24]);
  });

  test('Матч завершается на 3 выигранных сетах, победитель верный', () {
    final m = _match(const VolleyballConfig());
    for (var s = 0; s < 3; s++) {
      for (var i = 0; i < 25; i++) {
        m.events.add(0);
      }
    }
    final st = m.replay();
    expect(st.setsA, 3);
    expect(st.finished, true);
    expect(st.winner, 0);
  });

  test('Решающий сет — до 15 (best of 3)', () {
    final m = _match(const VolleyballConfig(format: VbFormat.short));
    // 1:1 по сетам, затем решающий до 15.
    for (var i = 0; i < 25; i++) {
      m.events.add(0); // сет A
    }
    for (var i = 0; i < 25; i++) {
      m.events.add(1); // сет B
    }
    for (var i = 0; i < 15; i++) {
      m.events.add(0); // решающий до 15 → A
    }
    final st = m.replay();
    expect(st.setsA, 2);
    expect(st.finished, true);
    expect(st.winner, 0);
    expect(st.completedSets.last, [15, 0]);
  });

  test('Отмена убирает последнее очко', () {
    final m = _match(const VolleyballConfig());
    m.events..add(0)..add(0)..add(1);
    var st = m.replay();
    expect(st.pointsA, 2);
    expect(st.pointsB, 1);
    m.events.removeLast();
    st = m.replay();
    expect(st.pointsB, 0);
  });

  test('Свободный режим: сеты только вручную (-1)', () {
    final m = _match(const VolleyballConfig(format: VbFormat.free));
    for (var i = 0; i < 40; i++) {
      m.events.add(0); // 40 очков, авто-сета нет
    }
    var st = m.replay();
    expect(st.pointsA, 40);
    expect(st.setsA, 0);
    expect(st.finished, false);
    m.events.add(-1); // завершить сет вручную
    st = m.replay();
    expect(st.setsA, 1);
    expect(st.completedSets.first, [40, 0]);
  });
}

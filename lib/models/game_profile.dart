import '../l10n/locale_controller.dart';
import '../l10n/strings.dart';

/// Как определяется конец игры и победитель.
enum WinRule {
  /// Набрал >= [GameProfile.target] — выбыл; последний оставшийся побеждает.
  /// Очки — плохо. Пример: 101.
  elimination,

  /// Первый, кто набрал >= [GameProfile.target], побеждает. Очки — хорошо.
  /// Пример: Тысяча, Джин Рамми, Спейдс.
  raceHigh,

  /// Игра идёт, пока кто-то не достигнет порога [GameProfile.target]; тогда
  /// побеждает игрок с НАИМЕНЬШЕЙ суммой. Пример: Червы.
  lowestAtCap,

  /// Без авто-конца — просто считаем очки, победителя отмечают вручную.
  /// Пример: дружеский счёт, Президент по победам.
  manual,

  /// Без очков: каждый кон отмечают проигравшего («дурака»). Считается, сколько
  /// раз каждый проиграл. Меньше всех — лидер, больше всех — «Дурак».
  /// Пример: Дурак.
  fool,

  /// Без чистых очков: каждый кон фиксируют ПОРЯДОК выхода. За место даются
  /// очки (1-й — больше всех), копятся; титулы от Президента до «Говнюка».
  /// Завершение — вручную, победитель = наибольшая сумма. Пример: Президент.
  ranking,

  /// Не очки, а ФАЗЫ 1→10: каждый кон отмечают, кто прошёл свою фазу (тогда
  /// +1 фаза). Кто первым прошёл фазу 10 — победитель. Пример: Phase 10.
  phases,
}

/// Профиль игры — набор правил подсчёта. Бывает встроенный (пресет) или
/// созданный пользователем. Точную механику конкретной игры не воспроизводит —
/// это универсальный счётчик очков по выбранным правилам.
class GameProfile {
  final String id;

  /// Ключ перевода имени для встроенных игр (иначе null).
  final String? nameKey;

  /// Имя для своих игр (для встроенных — запасное, если нет перевода).
  final String name;

  final WinRule winRule;

  /// Порог/цель очков (смысл зависит от [winRule]); null — без порога.
  final int? target;

  /// Ссылки на правила (рус/англ) — обычно Wikipedia/гугл.
  final String? rulesUrlRu;
  final String? rulesUrlEn;

  final bool builtIn;

  const GameProfile({
    required this.id,
    this.nameKey,
    required this.name,
    required this.winRule,
    this.target,
    this.rulesUrlRu,
    this.rulesUrlEn,
    this.builtIn = false,
  });

  String get displayName => nameKey != null ? tr(nameKey!) : name;

  /// Ссылка на правила на текущем языке (с фолбэком).
  String? get rulesUrl {
    final en = LocaleController.instance.code == 'en';
    return (en ? rulesUrlEn : rulesUrlRu) ?? rulesUrlRu ?? rulesUrlEn;
  }

  factory GameProfile.fromJson(Map<String, dynamic> json) => GameProfile(
        id: json['id']?.toString() ??
            DateTime.fromMillisecondsSinceEpoch(0).toString(),
        name: json['name']?.toString() ?? 'Игра',
        winRule: WinRule.values.firstWhere(
          (r) => r.name == json['winRule'],
          orElse: () => WinRule.elimination,
        ),
        target: json['target'] as int?,
        rulesUrlRu: json['rulesUrlRu'] as String?,
        rulesUrlEn: json['rulesUrlEn'] as String?,
        builtIn: false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'winRule': winRule.name,
        'target': target,
        'rulesUrlRu': rulesUrlRu,
        'rulesUrlEn': rulesUrlEn,
      };
}

/// Встроенные пресеты популярных игр. Имена — через ключи перевода
/// (`game_<id>` в [strings]). Ссылки — на Wikipedia (рус/англ).
const List<GameProfile> kBuiltInGames = [
  // ----- СНГ/Россия -----
  GameProfile(
    id: 'g101',
    nameKey: 'game_g101',
    name: '101',
    winRule: WinRule.elimination,
    target: 101,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Кункен',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Conquian',
  ),
  GameProfile(
    id: 'durak',
    nameKey: 'game_durak',
    name: 'Дурак',
    // В Дураке нет очков: проигрывает последний оставшийся с картами.
    // Считаем, кто сколько раз был «дураком».
    winRule: WinRule.fool,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Дурак_(игра)',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Durak',
  ),
  GameProfile(
    id: 'king',
    nameKey: 'game_king',
    name: 'Кинг',
    // Смешанный счёт (минусовые и плюсовые сдачи), фиксированное число сдач,
    // побеждает наибольшая сумма. Авто-порога нет → итог подводится вручную.
    winRule: WinRule.manual,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Кинг_(карточная_игра)',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Barbu',
  ),
  GameProfile(
    id: 'thousand',
    nameKey: 'game_thousand',
    name: 'Тысяча',
    winRule: WinRule.raceHigh,
    target: 1000,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Тысяча_(карточная_игра)',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Thousand_(card_game)',
  ),
  GameProfile(
    id: 'belote',
    nameKey: 'game_belote',
    name: 'Деберц',
    winRule: WinRule.raceHigh,
    target: 501,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Белот',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Belote',
  ),
  // ----- Международные -----
  GameProfile(
    id: 'gin',
    nameKey: 'game_gin',
    name: 'Джин Рамми',
    winRule: WinRule.raceHigh,
    target: 100,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Джин_(карточная_игра)',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Gin_rummy',
  ),
  GameProfile(
    id: 'rummy',
    nameKey: 'game_rummy',
    name: 'Рамми',
    winRule: WinRule.raceHigh,
    target: 100,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Рамми',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Rummy',
  ),
  GameProfile(
    id: 'canasta',
    nameKey: 'game_canasta',
    name: 'Канаста',
    winRule: WinRule.raceHigh,
    target: 5000,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Канаста',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Canasta',
  ),
  GameProfile(
    id: 'hearts',
    nameKey: 'game_hearts',
    name: 'Червы',
    winRule: WinRule.lowestAtCap,
    target: 100,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Черви_(карточная_игра)',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Hearts_(card_game)',
  ),
  GameProfile(
    id: 'spades',
    nameKey: 'game_spades',
    name: 'Спейдс',
    winRule: WinRule.raceHigh,
    target: 500,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Спейдс',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Spades_(card_game)',
  ),
  GameProfile(
    id: 'bridge',
    nameKey: 'game_bridge',
    name: 'Бридж',
    winRule: WinRule.manual,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Бридж',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Contract_bridge',
  ),
  GameProfile(
    id: 'cribbage',
    nameKey: 'game_cribbage',
    name: 'Криббедж',
    winRule: WinRule.raceHigh,
    target: 121,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Криббедж',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Cribbage',
  ),
  GameProfile(
    id: 'phase10',
    nameKey: 'game_phase10',
    name: 'Phase 10',
    // Победа — за прохождение 10 фаз по порядку: режим «фазы».
    winRule: WinRule.phases,
    rulesUrlRu: 'https://en.wikipedia.org/wiki/Phase_10',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Phase_10',
  ),
  GameProfile(
    id: 'president',
    nameKey: 'game_president',
    name: 'Президент',
    // Очков нет — важен ПОРЯДОК выхода каждый кон (1-й = Президент … последний
    // = «Говнюк»). За место даются очки, копятся; победитель — наибольшая сумма.
    winRule: WinRule.ranking,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Президент_(карточная_игра)',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/President_(card_game)',
  ),
  GameProfile(
    id: 'pinochle',
    nameKey: 'game_pinochle',
    name: 'Пинокль',
    winRule: WinRule.raceHigh,
    target: 1000,
    rulesUrlRu: 'https://ru.wikipedia.org/wiki/Пинокль',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Pinochle',
  ),
  GameProfile(
    id: 'euchre',
    nameKey: 'game_euchre',
    name: 'Юкер',
    winRule: WinRule.raceHigh,
    target: 10,
    rulesUrlRu: 'https://en.wikipedia.org/wiki/Euchre',
    rulesUrlEn: 'https://en.wikipedia.org/wiki/Euchre',
  ),
];

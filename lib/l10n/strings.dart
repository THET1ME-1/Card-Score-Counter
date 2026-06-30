import 'locale_controller.dart';
import 'translations.dart';

/// Перевод строки по ключу на текущий язык.
///
/// Базовые ru/en лежат в [_strings]; остальные языки — в [kTranslations]
/// (translations.dart). Если перевода на выбранный язык нет — откатываемся на
/// английский, затем на русский, затем на сам ключ.
String tr(String key) {
  final code = LocaleController.instance.code;
  // Доп. языки (de/fr/es/it/pt…) — отдельные карты.
  final extra = kTranslations[code]?[key];
  if (extra != null && extra.isNotEmpty) return extra;
  final entry = _strings[key];
  if (entry == null) return key;
  return entry[code] ?? entry['en'] ?? entry['ru'] ?? key;
}

/// Перевод с подстановкой `{name}` → значение.
String trf(String key, Map<String, Object> params) {
  var s = tr(key);
  params.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Словарь интерфейсных строк. Растёт по мере локализации экранов.
/// Ключи — латиницей по смыслу; значения на ru/en.
const Map<String, Map<String, String>> _strings = {
  // ----------------------------- Общее -----------------------------
  'cancel': {'ru': 'Отмена', 'en': 'Cancel'},
  'save': {'ru': 'Сохранить', 'en': 'Save'},
  'delete': {'ru': 'Удалить', 'en': 'Delete'},
  'reset': {'ru': 'Сбросить', 'en': 'Reset'},
  'apply': {'ru': 'Применить', 'en': 'Apply'},
  'done': {'ru': 'Готово', 'en': 'Done'},

  // ----------------------------- Настройки -----------------------------
  'settings_title': {'ru': 'Настройки', 'en': 'Settings'},
  'appearance': {'ru': 'Внешний вид', 'en': 'Appearance'},
  'language': {'ru': 'Язык', 'en': 'Language'},
  'language_ru': {'ru': 'Русский', 'en': 'Russian'},
  'language_en': {'ru': 'Английский', 'en': 'English'},
  'dark_theme': {'ru': 'Тёмная тема', 'en': 'Dark theme'},
  'sound': {'ru': 'Звук', 'en': 'Sound'},
  'on': {'ru': 'Включена', 'en': 'On'},
  'off': {'ru': 'Выключена', 'en': 'Off'},
  'dynamic_color': {'ru': 'Material You', 'en': 'Material You'},
  'dynamic_color_sub': {
    'ru': 'Цвет из обоев системы (Android 12+)',
    'en': 'Color from system wallpaper (Android 12+)'
  },
  'theme_color': {'ru': 'Цвет оформления', 'en': 'Theme color'},
  'theme_color_default': {'ru': 'Бирюзовый (стандартный)', 'en': 'Teal (default)'},
  'scoreboard_text_size': {
    'ru': 'Размер текста в табло',
    'en': 'Scoreboard text size'
  },
  'data': {'ru': 'Данные', 'en': 'Data'},
  'create_backup': {'ru': 'Создать резервную копию', 'en': 'Create backup'},
  'create_backup_sub': {
    'ru': 'Игроки и история — в файл',
    'en': 'Players and history to a file'
  },
  'share_backup': {'ru': 'Отправить копию', 'en': 'Send backup'},
  'share_backup_sub': {
    'ru': 'В Google Drive, Dropbox, Mega, Telegram…',
    'en': 'To Google Drive, Dropbox, Mega, Telegram…'
  },
  'restore_backup': {'ru': 'Восстановить из копии', 'en': 'Restore from backup'},
  'restore_backup_sub': {
    'ru': 'Заменить данные данными из файла',
    'en': 'Replace data with the file'
  },
  'danger_zone': {'ru': 'Опасная зона', 'en': 'Danger zone'},
  'reset_wins': {'ru': 'Сбросить счётчики побед', 'en': 'Reset win counters'},
  'reset_wins_sub': {
    'ru': 'Обнулить победы у всех игроков',
    'en': "Zero all players' wins"
  },
  'clear_history': {'ru': 'Очистить историю игр', 'en': 'Clear game history'},
  'clear_history_sub': {
    'ru': 'Удалить все записи из истории',
    'en': 'Delete all history records'
  },
  'help': {'ru': 'Справка', 'en': 'Help'},
  'rules': {'ru': 'Правила игр', 'en': 'Game rules'},
  'app_version': {'ru': 'Версия {v}', 'en': 'Version {v}'},

  // Диалоги/снэкбары настроек
  'restore_q_title': {'ru': 'Восстановить данные?', 'en': 'Restore data?'},
  'restore_q_body': {
    'ru': 'Текущие игроки и история будут заменены данными из файла.',
    'en': 'Current players and history will be replaced with the file.'
  },
  'choose_file': {'ru': 'Выбрать файл', 'en': 'Choose file'},
  'reset_wins_q_title': {
    'ru': 'Сбросить счётчики побед?',
    'en': 'Reset win counters?'
  },
  'reset_wins_q_body': {
    'ru': 'Это действие обнулит все счётчики побед у всех игроков.',
    'en': "This will zero all players' win counters."
  },
  'clear_history_q_title': {
    'ru': 'Очистить историю игр?',
    'en': 'Clear game history?'
  },
  'clear_history_q_body': {
    'ru': 'Это действие удалит все записи из истории игр.',
    'en': 'This will delete all records from the game history.'
  },
  'wins_reset_done': {'ru': 'Счётчики побед сброшены', 'en': 'Win counters reset'},
  'history_cleared_done': {
    'ru': 'История игр очищена',
    'en': 'Game history cleared'
  },
  'export_done': {'ru': 'Резервная копия сохранена', 'en': 'Backup saved'},
  'export_cancelled': {'ru': 'Экспорт отменён', 'en': 'Export cancelled'},
  'export_error': {'ru': 'Ошибка экспорта: {e}', 'en': 'Export error: {e}'},
  'import_done': {
    'ru': 'Данные восстановлены из копии',
    'en': 'Data restored from backup'
  },
  'import_bad_format': {
    'ru': 'Неверный формат файла резервной копии',
    'en': 'Invalid backup file format'
  },
  'import_read_error': {
    'ru': 'Не удалось прочитать файл',
    'en': 'Could not read the file'
  },
  'import_error': {'ru': 'Ошибка импорта: {e}', 'en': 'Import error: {e}'},
  'backup_save_dialog': {
    'ru': 'Сохранить резервную копию',
    'en': 'Save backup'
  },
  'backup_pick_dialog': {
    'ru': 'Выберите резервную копию',
    'en': 'Choose a backup'
  },

  // ----------------------- Колор-пикер -----------------------
  'custom_color': {'ru': 'Свой цвет', 'en': 'Custom color'},

  // ----------------------- Меню/табло -----------------------
  'who_plays': {'ru': 'Кто играет?', 'en': "Who's playing?"},
  'history_title': {'ru': 'История игр', 'en': 'Game history'},
  'finished_short': {'ru': 'завершена', 'en': 'finished'},
  'rounds_n': {'ru': '{n} раунд(ов)', 'en': '{n} round(s)'},
  'scoreboard': {'ru': 'Табло', 'en': 'Scoreboard'},
  'share': {'ru': 'Поделиться', 'en': 'Share'},
  'timer': {'ru': 'Таймер', 'en': 'Timer'},
  'timer_match': {'ru': 'Партия', 'en': 'Game'},
  'timer_turn': {'ru': 'Ход', 'en': 'Turn'},
  'pause': {'ru': 'Пауза', 'en': 'Pause'},
  'turn_order': {'ru': 'Порядок хода', 'en': 'Turn order'},
  'a11y_winrate': {'ru': 'Процент побед: {v}%', 'en': 'Win rate: {v}%'},
  'shuffle': {'ru': 'Перемешать всех', 'en': 'Shuffle all'},
  'shuffle_sub': {
    'ru': 'Случайный порядок для всех игроков',
    'en': 'Randomize the whole order'
  },
  'random_first': {'ru': 'Случайный первый', 'en': 'Random first'},
  'random_first_sub': {
    'ru': 'Меняется только кто ходит первым, остальные на местах',
    'en': 'Only the first player changes, the rest keep their order'
  },
  'winner': {'ru': 'Победитель', 'en': 'Winner'},
  'eliminated': {'ru': 'Выбыл', 'en': 'Out'},
  'to_out': {'ru': 'До вылета: {n}', 'en': 'To bust: {n}'},
  'to_win': {'ru': 'До победы: {n}', 'en': 'To win: {n}'},
  'to_end': {'ru': 'До конца: {n}', 'en': 'To end: {n}'},

  // ----------------------- Игры -----------------------
  'games': {'ru': 'Игры', 'en': 'Games'},
  'choose_game': {'ru': 'Выберите игру', 'en': 'Choose a game'},
  'custom_games': {'ru': 'Свои игры', 'en': 'Custom games'},
  'add_game': {'ru': 'Добавить игру', 'en': 'Add game'},
  'new_game_profile': {'ru': 'Новая игра', 'en': 'New game'},
  'edit_game_profile': {'ru': 'Правка игры', 'en': 'Edit game'},
  'game_name': {'ru': 'Название', 'en': 'Name'},
  'win_rule': {'ru': 'Как определить победителя', 'en': 'How the winner is decided'},
  'target_score': {'ru': 'Порог очков', 'en': 'Target score'},
  'open_rules': {'ru': 'Открыть правила', 'en': 'Open rules'},
  'rule_elimination': {
    'ru': 'Набрал порог — вылетел, последний побеждает',
    'en': 'Reach target — out; last one wins'
  },
  'rule_racehigh': {
    'ru': 'Первый до порога побеждает',
    'en': 'First to target wins'
  },
  'rule_lowestatcap': {
    'ru': 'Доходим до порога — у кого меньше, тот победил',
    'en': 'Play to target — lowest total wins'
  },
  'rule_manual': {
    'ru': 'Просто счёт, победитель вручную',
    'en': 'Just scoring, winner set manually'
  },
  'rule_fool': {
    'ru': 'Без очков: кто проиграл кон — «дурак»',
    'en': 'No points: loser of a hand is the "fool"'
  },
  'rule_ranking': {
    'ru': 'По местам: за порядок выхода (Президент…Бомж)',
    'en': 'By finish order (President…Scum)'
  },
  'rule_phases': {
    'ru': 'Фазы 1→10: кто первым прошёл 10-ю',
    'en': 'Phases 1→10: first to finish phase 10'
  },
  'rule_volleyball': {
    'ru': 'Умное табло: очки и сеты двух команд',
    'en': 'Smart scoreboard: points & sets for two teams'
  },
  'no_target': {'ru': 'без порога', 'en': 'no target'},
  'to_target': {'ru': 'до {n}', 'en': 'to {n}'},
  'game_label': {'ru': 'Игра: {name}', 'en': 'Game: {name}'},
  'all_games': {'ru': 'Все игры', 'en': 'All games'},

  // ----------------------- Навигация -----------------------
  'nav_menu': {'ru': 'Меню', 'en': 'Menu'},
  'nav_history': {'ru': 'История', 'en': 'History'},
  'nav_stats': {'ru': 'Статистика', 'en': 'Stats'},
  'nav_settings': {'ru': 'Настройки', 'en': 'Settings'},

  // ----------------------- Табло -----------------------
  'round_n': {'ru': 'Круг {n}', 'en': 'Round {n}'},
  'add_round_first': {'ru': 'Сначала добавьте раунд', 'en': 'Add a round first'},
  'rounds_history': {'ru': 'История раундов', 'en': 'Round history'},
  'no_rounds_yet': {
    'ru': 'Раундов пока нет — добавьте первый.',
    'en': 'No rounds yet — add the first one.'
  },
  'play_again': {'ru': 'Играть заново', 'en': 'Play again'},
  'add_round': {'ru': 'Добавить раунд', 'en': 'Add round'},
  'undo': {'ru': 'Отменить', 'en': 'Undo'},
  'edit_action': {'ru': 'Изменить', 'en': 'Edit'},
  'finish_game': {'ru': 'Завершить', 'en': 'Finish'},
  'pick_winner': {'ru': 'Кто победил?', 'en': 'Who won?'},
  'clear_winner': {'ru': 'Снять победителя', 'en': 'Clear winner'},
  'change_winner': {'ru': 'Сменить', 'en': 'Change'},
  // «Дурак» (режим без очков)
  'add_kon': {'ru': 'Добавить кон', 'en': 'Add hand'},
  'who_lost_round': {'ru': 'Кто проиграл кон?', 'en': 'Who lost the hand?'},
  'play_round_first': {
    'ru': 'Сыграйте хотя бы один кон',
    'en': 'Play at least one hand'
  },
  'revive_blocked': {
    'ru': '«{name}» уже выбыл, дальше играли без него — вернуть задним числом нельзя',
    'en': '"{name}" is already out and play went on without them — can\'t revive retroactively'
  },
  'times_fool': {'ru': 'в дураках: {n}', 'en': 'fool: {n}'},
  'least_fool': {'ru': 'Меньше всех в дураках', 'en': 'Fewest losses'},
  // «Президент» (режим рангов по порядку выхода)
  'finish_order_title': {'ru': 'Порядок выхода', 'en': 'Finish order'},
  'finish_order_hint': {
    'ru': 'Отметьте по очереди — кто вышел первым, тот выше',
    'en': 'Tap in order — first one out ranks highest'
  },
  'title_president': {'ru': 'Президент', 'en': 'President'},
  'title_vice_president': {'ru': 'Вице-президент', 'en': 'Vice-president'},
  'title_citizen': {'ru': 'Гражданин', 'en': 'Citizen'},
  'title_vice_bum': {'ru': 'Вице-бомж', 'en': 'Vice-scum'},
  'title_bum': {'ru': 'Бомж', 'en': 'Scum'},
  // Phase 10 (режим фаз)
  'who_passed_phase': {'ru': 'Кто прошёл фазу?', 'en': 'Who passed a phase?'},
  'phase_n': {'ru': 'фаза {n}/10', 'en': 'phase {n}/10'},
  'phase_done': {'ru': 'Готово!', 'en': 'Done!'},

  // ----------------------- Ввод очков -----------------------
  'add_scores': {'ru': 'Добавить очки', 'en': 'Add scores'},
  'add_scores_hint_elim': {
    'ru': 'Очки получают проигравшие. Кто закрыл раунд — остаётся с 0.',
    'en': 'Losers get points. Whoever closes the round stays at 0.'
  },
  'add_scores_hint_points': {
    'ru': 'Введите очки за раунд каждому игроку.',
    'en': 'Enter each player\'s points for the round.'
  },
  'save_round': {'ru': 'Сохранить раунд', 'en': 'Save round'},
  'bust': {'ru': 'Вылет', 'en': 'Bust'},

  // ----------------------- История (диалоги/меню) -----------------------
  'game_n': {'ru': 'Игра {n}', 'en': 'Game {n}'},
  'game_name_title': {'ru': 'Название партии', 'en': 'Game name'},
  'name_label': {'ru': 'Имя', 'en': 'Name'},
  'delete_game_q': {'ru': 'Удалить партию?', 'en': 'Delete game?'},
  'delete_game_body': {
    'ru': 'Запись будет удалена из истории безвозвратно.',
    'en': 'The record will be permanently deleted from history.'
  },
  'sort_newest': {'ru': 'Сначала новые', 'en': 'Newest first'},
  'sort_oldest': {'ru': 'Сначала старые', 'en': 'Oldest first'},
  'open': {'ru': 'Открыть', 'en': 'Open'},
  'resume': {'ru': 'Продолжить', 'en': 'Resume'},
  'rename': {'ru': 'Переименовать', 'en': 'Rename'},
  'search_games': {'ru': 'Поиск партий', 'en': 'Search games'},
  'nothing_found': {'ru': 'Ничего не найдено', 'en': 'Nothing found'},
  'history_empty': {'ru': 'История пуста', 'en': 'History is empty'},
  'history_empty_sub': {
    'ru': 'Сыграйте первую партию — она появится здесь.',
    'en': 'Play your first game — it will appear here.'
  },

  // ----------------------- Игроки (меню/редактор) -----------------------
  'wins_n': {'ru': 'Побед: {n}', 'en': 'Wins: {n}'},
  'novice': {'ru': 'Новичок', 'en': 'Newcomer'},
  'create_player': {'ru': 'Создать игрока', 'en': 'Add player'},
  'tap_plus_create': {
    'ru': 'Нажмите «+», чтобы создать игрока',
    'en': 'Tap "+" to add a player'
  },
  'mark_who_plays': {'ru': 'Отметьте, кто играет', 'en': 'Mark who is playing'},
  'players_selected': {'ru': 'Выбрано игроков: {n}', 'en': 'Selected: {n}'},
  'start_game': {'ru': 'Начать игру', 'en': 'Start game'},
  'create_players_first': {
    'ru': 'Сначала создайте игроков',
    'en': 'Add players first'
  },
  'select_min_two': {
    'ru': 'Выберите минимум 2 игроков',
    'en': 'Select at least 2 players'
  },
  'delete_player_q': {'ru': 'Удалить игрока?', 'en': 'Delete player?'},
  'delete_player_body': {
    'ru': '«{name}» будет удалён из списка.',
    'en': '"{name}" will be removed from the list.'
  },
  'edit_player': {'ru': 'Редактировать', 'en': 'Edit'},
  'new_player': {'ru': 'Новый игрок', 'en': 'New player'},
  'color_label': {'ru': 'Цвет', 'en': 'Color'},
  'delete_player': {'ru': 'Удалить игрока', 'en': 'Delete player'},

  // ----------------------- Статистика -----------------------
  'statistics_title': {'ru': 'Статистика', 'en': 'Statistics'},
  'tab_player': {'ru': 'Игрок', 'en': 'Player'},
  'tab_leaders': {'ru': 'Лидеры', 'en': 'Leaders'},
  'tab_analytics': {'ru': 'Аналитика', 'en': 'Analytics'},
  'period_day': {'ru': 'Дни', 'en': 'Days'},
  'period_month': {'ru': 'Месяцы', 'en': 'Months'},
  'period_year': {'ru': 'Годы', 'en': 'Years'},
  'stat_wins': {'ru': 'Побед', 'en': 'Wins'},
  'stat_games': {'ru': 'Игр', 'en': 'Games'},
  'stat_winrate': {'ru': 'Винрейт', 'en': 'Win rate'},
  'stat_best_streak': {'ru': 'Серия побед', 'en': 'Win streak'},
  'stat_losses': {'ru': 'Поражений', 'en': 'Losses'},
  'wins_label': {'ru': 'побед', 'en': 'wins'},
  'games_label': {'ru': 'игр', 'en': 'games'},
  'win_of_total': {'ru': '{w} из {g}', 'en': '{w} of {g}'},
  'wins_distribution': {'ru': 'Доля побед', 'en': 'Share of wins'},
  'wins_dynamics': {'ru': 'Динамика побед', 'en': 'Wins over time'},
  'winrate_dynamics': {'ru': 'Винрейт по периодам', 'en': 'Win rate by period'},
  'no_stats_data': {
    'ru': 'Пока нет данных. Сыграйте партию — здесь появится статистика.',
    'en': 'No data yet. Play a game — stats will appear here.'
  },
  'not_enough_data': {
    'ru': 'Маловато данных для графика',
    'en': 'Not enough data for a chart'
  },
  'total_games': {'ru': 'Всего игр', 'en': 'Total games'},
  'total_wins': {'ru': 'Всего побед', 'en': 'Total wins'},
  'total_rounds': {'ru': 'Всего раундов', 'en': 'Total rounds'},
  'top_player': {'ru': 'Лидер', 'en': 'Top player'},
  'players_count': {'ru': 'Игроков', 'en': 'Players'},
  'others': {'ru': 'Другие', 'en': 'Others'},

  // Названия встроенных игр
  'game_g101': {'ru': '101 (Сто одно)', 'en': '101'},
  'game_durak': {'ru': 'Дурак', 'en': 'Durak'},
  'game_king': {'ru': 'Кинг', 'en': 'King'},
  'game_thousand': {'ru': 'Тысяча', 'en': 'Thousand (1000)'},
  'game_belote': {'ru': 'Деберц (Белот)', 'en': 'Belote'},
  'game_gin': {'ru': 'Джин Рамми', 'en': 'Gin Rummy'},
  'game_rummy': {'ru': 'Рамми', 'en': 'Rummy'},
  'game_canasta': {'ru': 'Канаста', 'en': 'Canasta'},
  'game_hearts': {'ru': 'Червы', 'en': 'Hearts'},
  'game_spades': {'ru': 'Спейдс (Пики)', 'en': 'Spades'},
  'game_bridge': {'ru': 'Бридж', 'en': 'Bridge'},
  'game_cribbage': {'ru': 'Криббедж', 'en': 'Cribbage'},
  'game_phase10': {'ru': 'Phase 10', 'en': 'Phase 10'},
  'game_president': {'ru': 'Президент', 'en': 'President / Scum'},
  'game_pinochle': {'ru': 'Пинокль', 'en': 'Pinochle'},
  'game_euchre': {'ru': 'Юкер', 'en': 'Euchre'},
  'game_volleyball': {'ru': 'Волейбол', 'en': 'Volleyball'},

  // -------------------------- Достижения --------------------------
  'achievements': {'ru': 'Достижения', 'en': 'Achievements'},
  'achievements_sub': {'ru': 'Ваши награды', 'en': 'Your trophies'},
  'achievements_unlocked': {'ru': 'Открыто', 'en': 'Unlocked'},
  'unlocked': {'ru': 'Открыто', 'en': 'Unlocked'},
  'ach_first_game_t': {'ru': 'Первый кон', 'en': 'First deal'},
  'ach_first_game_d': {
    'ru': 'Сыграть первую партию',
    'en': 'Play your first game'
  },
  'ach_first_win_t': {'ru': 'Первая победа', 'en': 'First win'},
  'ach_first_win_d': {
    'ru': 'Завершить партию с победителем',
    'en': 'Finish a game with a winner'
  },
  'ach_games_10_t': {'ru': 'Завсегдатай', 'en': 'Regular'},
  'ach_games_10_d': {'ru': 'Сыграть 10 партий', 'en': 'Play 10 games'},
  'ach_games_50_t': {'ru': 'Картёжник', 'en': 'Card shark'},
  'ach_games_50_d': {'ru': 'Сыграть 50 партий', 'en': 'Play 50 games'},
  'ach_games_100_t': {'ru': 'Легенда стола', 'en': 'Table legend'},
  'ach_games_100_d': {'ru': 'Сыграть 100 партий', 'en': 'Play 100 games'},
  'ach_wins_25_t': {'ru': 'Чемпион', 'en': 'Champion'},
  'ach_wins_25_d': {'ru': '25 побед суммарно', 'en': '25 wins in total'},
  'ach_streak_3_t': {'ru': 'В ударе', 'en': 'On a roll'},
  'ach_streak_3_d': {
    'ru': '3 победы подряд одним игроком',
    'en': '3 wins in a row by one player'
  },
  'ach_streak_5_t': {'ru': 'Неудержимый', 'en': 'Unstoppable'},
  'ach_streak_5_d': {
    'ru': '5 побед подряд одним игроком',
    'en': '5 wins in a row by one player'
  },
  'ach_all_modes_t': {'ru': 'Универсал', 'en': 'All-rounder'},
  'ach_all_modes_d': {
    'ru': 'Опробовать все 7 режимов счёта',
    'en': 'Try all 7 scoring modes'
  },
  'ach_variety_10_t': {'ru': 'Знаток игр', 'en': 'Game buff'},
  'ach_variety_10_d': {
    'ru': 'Сыграть 10 разных игр',
    'en': 'Play 10 different games'
  },
  'ach_full_table_t': {'ru': 'Полный стол', 'en': 'Full table'},
  'ach_full_table_d': {
    'ru': 'Партия на 6 игроков',
    'en': 'A game with 6 players'
  },
  'ach_marathon_t': {'ru': 'Марафон', 'en': 'Marathon'},
  'ach_marathon_d': {
    'ru': 'Партия на 20+ кругов',
    'en': 'A game of 20+ rounds'
  },
  'ach_night_owl_t': {'ru': 'Полуночник', 'en': 'Night owl'},
  'ach_night_owl_d': {
    'ru': 'Партия после полуночи',
    'en': 'A game played after midnight'
  },

  // ----------------------- Таймер / время партии -----------------------
  'timer_setting': {'ru': 'Таймер партии', 'en': 'Game timer'},
  'timer_setting_sub': {
    'ru': 'Показывать время партии на табло',
    'en': 'Show game time on the scoreboard'
  },
  'resume_timer': {'ru': 'Продолжить', 'en': 'Resume'},

  // ----------------------- Аналитика партии -----------------------
  'game_analytics': {'ru': 'Аналитика партии', 'en': 'Game analytics'},
  'duration': {'ru': 'Длительность', 'en': 'Duration'},
  'game_duration': {'ru': 'Партия шла', 'en': 'Game lasted'},
  'avg_per_round': {'ru': 'В среднем на круг', 'en': 'Avg per round'},
  'rounds_played': {'ru': 'Сыграно кругов', 'en': 'Rounds played'},
  'turn_time_by_player': {'ru': 'Время по игрокам', 'en': 'Time by player'},
  'time_share': {'ru': 'Доля времени', 'en': 'Time share'},
  'no_time_data': {
    'ru': 'Время этой партии не записано',
    'en': 'No time recorded for this game'
  },
  'no_time_data_hint': {
    'ru': 'Время считается с обновления. Сыграйте новую партию — здесь появятся графики.',
    'en': 'Timing was added in an update. Play a new game to see charts here.'
  },
  'vs_average': {'ru': 'Сравнение с другими', 'en': 'Compared to others'},
  'vs_average_sub': {
    'ru': 'Длительность относительно других партий «{game}»',
    'en': 'Duration vs other "{game}" games'
  },
  'longer_by': {'ru': 'дольше среднего на {p}%', 'en': '{p}% longer than average'},
  'shorter_by': {'ru': 'короче среднего на {p}%', 'en': '{p}% shorter than average'},
  'about_average': {'ru': 'примерно как в среднем', 'en': 'about average'},
  'avg_duration': {'ru': 'Средняя', 'en': 'Average'},
  'this_game': {'ru': 'Эта партия', 'en': 'This game'},
  'analytics_open': {'ru': 'Открыть', 'en': 'Open'},
  'analytics_resume': {'ru': 'Продолжить партию', 'en': 'Resume game'},
  'fastest_player': {'ru': 'Быстрее всех', 'en': 'Fastest'},
  'slowest_player': {'ru': 'Дольше всех думал', 'en': 'Slowest'},
  'avg_turn_overall': {'ru': 'Средний ход', 'en': 'Avg turn'},
  'players_label': {'ru': 'Игроков', 'en': 'Players'},

  // ----------------------- Календарь -----------------------
  'calendar': {'ru': 'Календарь игр', 'en': 'Games calendar'},
  'cal_week': {'ru': 'Неделя', 'en': 'Week'},
  'cal_month': {'ru': 'Месяц', 'en': 'Month'},
  'cal_year': {'ru': 'Год', 'en': 'Year'},
  'games_per_day': {'ru': 'Игр по дням', 'en': 'Games per day'},
  'games_on': {'ru': 'Игры за {d}', 'en': 'Games on {d}'},
  'no_games_that_day': {'ru': 'В этот день игр не было', 'en': 'No games that day'},
  'games_count_n': {'ru': '{n} игр', 'en': '{n} games'},
  'total_time_played': {'ru': 'Всего за игрой', 'en': 'Total time played'},

  // ----------------------- Волейбол -----------------------
  'vb_home': {'ru': 'Хозяева', 'en': 'Home'},
  'vb_guest': {'ru': 'Гости', 'en': 'Guest'},
  'vb_sets': {'ru': 'Сеты', 'en': 'Sets'},
  'vb_swap': {'ru': 'Сменить стороны', 'en': 'Swap sides'},
  'vb_new_match': {'ru': 'Новый матч', 'en': 'New match'},
  'vb_end_set': {'ru': 'Завершить сет', 'en': 'End set'},
  'vb_finish_match': {'ru': 'Завершить матч', 'en': 'Finish match'},
  'vb_format': {'ru': 'Формат', 'en': 'Format'},
  'vb_format_standard': {'ru': 'Стандарт · до 3 сетов', 'en': 'Standard · best of 5'},
  'vb_format_short': {'ru': 'Короткий · до 2 сетов', 'en': 'Short · best of 3'},
  'vb_format_free': {'ru': 'Свободный', 'en': 'Free'},
  'vb_points': {'ru': 'Очков в сете', 'en': 'Points per set'},
  'vb_tiebreak': {'ru': 'Решающий сет', 'en': 'Deciding set'},
  'vb_set_n': {'ru': 'Сет {n}', 'en': 'Set {n}'},
  'vb_current_set': {'ru': 'Текущий сет', 'en': 'Current set'},
  'vb_timeline': {'ru': 'Таймлайн', 'en': 'Timeline'},
  'vb_config': {'ru': 'Настройки матча', 'en': 'Match settings'},
  'vb_reset_q': {'ru': 'Начать новый матч?', 'en': 'Start a new match?'},
  'vb_reset_body': {
    'ru': 'Текущий счёт будет сброшен.',
    'en': 'The current score will be reset.'
  },
  'vb_match_point': {'ru': 'Матчбол', 'en': 'Match point'},
  'vb_set_point': {'ru': 'Сетбол', 'en': 'Set point'},
  'vb_tap_hint': {'ru': 'Тап по половине — очко команде', 'en': 'Tap a side to add a point'},

  // ----------------------- Очные встречи -----------------------
  'head_to_head': {'ru': 'Очные встречи', 'en': 'Head-to-head'},
  'h2h_shared': {'ru': '{n} совместных', 'en': '{n} together'},
  'h2h_no_rivals': {
    'ru': 'Пока не с кем сравниться — сыграйте партию с другим игроком.',
    'en': 'No rivals yet — play a game with another player.'
  },
  'h2h_no_personal': {'ru': 'без личных побед', 'en': 'no personal wins'},
  'h2h_lead_me': {'ru': 'перевес {name}', 'en': '{name} leads'},
  'h2h_even': {'ru': 'поровну', 'en': 'even'},
  'h2h_other_won': {'ru': 'победил другой', 'en': 'someone else won'},

  // ----------------------- Авто-обновление -----------------------
  'update_available': {'ru': 'Доступно обновление', 'en': 'Update available'},
  'update_new_version': {'ru': 'Новая версия {v}', 'en': 'New version {v}'},
  'update_current_version': {'ru': 'У вас {v}', 'en': 'You have {v}'},
  'update_now': {'ru': 'Обновить', 'en': 'Update'},
  'update_later': {'ru': 'Позже', 'en': 'Later'},
  'update_downloading': {'ru': 'Скачивание… {p}%', 'en': 'Downloading… {p}%'},
  'update_installing': {'ru': 'Запуск установки…', 'en': 'Starting install…'},
  'update_open_github': {'ru': 'Открыть на GitHub', 'en': 'Open on GitHub'},
  'update_failed': {
    'ru': 'Не удалось скачать. Откройте релиз вручную.',
    'en': 'Download failed. Open the release manually.'
  },
  'update_whats_new': {'ru': 'Что нового', 'en': "What's new"},
  'check_updates': {'ru': 'Проверить обновления', 'en': 'Check for updates'},
  'check_updates_sub': {
    'ru': 'Скачать новую версию с GitHub',
    'en': 'Download the latest version from GitHub'
  },
  'up_to_date': {'ru': 'У вас последняя версия', 'en': "You're up to date"},
};

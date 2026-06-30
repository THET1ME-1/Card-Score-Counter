import 'package:flutter/services.dart' show rootBundle;

/// Версия приложения, прочитанная НАПРЯМУЮ из `pubspec.yaml` (он добавлен в
/// assets). Так показываемая в приложении версия всегда совпадает с yaml —
/// без хардкода и без зависимости от платформенных метаданных.
///
/// Возвращает, например, `2.6.5` или `2.6.5 (12)`, если в yaml указан билд
/// (`version: 2.6.5+12`). Пустую строку — если прочитать не удалось.
Future<String> appVersionFromPubspec() async {
  try {
    final yaml = await rootBundle.loadString('pubspec.yaml');
    for (final raw in yaml.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('version:')) continue;
      var v = line.substring('version:'.length).trim();
      // Срезаем возможный комментарий и кавычки.
      final hash = v.indexOf('#');
      if (hash != -1) v = v.substring(0, hash).trim();
      v = v.replaceAll('"', '').replaceAll("'", '').trim();
      if (v.isEmpty) return '';
      // «2.6.5+12» → «2.6.5 (12)»; «2.6.5» → «2.6.5».
      final plus = v.indexOf('+');
      if (plus != -1) {
        final name = v.substring(0, plus);
        final build = v.substring(plus + 1);
        return build.isEmpty ? name : '$name ($build)';
      }
      return v;
    }
  } catch (_) {
    // Падать незачем — вернём пусто, экран покажет запасной вариант.
  }
  return '';
}

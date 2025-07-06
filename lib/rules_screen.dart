import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;

    // Use theme colors for better consistency and null safety
    final Color textColor = isDarkTheme ? Colors.white : Colors.black;
    final Color cardColor = isDarkTheme ? theme.cardColor : Colors.white;
    final Color titleColor =
        isDarkTheme ? Colors.blue[300]! : Colors.blue[700]!;
    final Color subtitleColor =
        isDarkTheme ? Colors.blue[200]! : Colors.blue[600]!;
    final Color dividerColor =
        isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Правила КунКен'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Общие сведения',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'КунКен (Conquian) — карточная игра из семейства Рамми для 2–6 игроков. Используются две колоды по 52 карты плюс джокеры.',
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Правила игры',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRuleItem(
                      context,
                      'Раздача:',
                      'Каждый игрок получает 12 карт. Остальные карты формируют колоду.',
                      subtitleColor,
                      textColor,
                    ),
                    _buildDivider(dividerColor!),
                    _buildRuleItem(
                      context,
                      'Цель:',
                      'Первый игрок, сбросивший все карты в комбинации (сеты из 3+ карт одного ранга или последовательности из 3+ карт одной масти), выигрывает раунд.',
                      subtitleColor,
                      textColor,
                    ),
                    _buildDivider(dividerColor),
                    _buildRuleItem(
                      context,
                      'Ход:',
                      'Игрок тянет карту из колоды или берет сброшенную и сбрасывает одну карту.',
                      subtitleColor,
                      textColor,
                    ),
                    _buildDivider(dividerColor),
                    _buildRuleItem(
                      context,
                      'Очки:',
                      'Раунд завершается, когда кто-то выходит. Очки остальных считаются по оставшимся картам (картинки — 10, остальные — по номиналу).',
                      subtitleColor,
                      textColor,
                    ),
                    _buildDivider(dividerColor),
                    _buildRuleItem(
                      context,
                      'Выбытие:',
                      'Игрок выбывает, если набирает 101 очков за сессию.',
                      subtitleColor,
                      textColor,
                    ),
                    _buildDivider(dividerColor),
                    _buildRuleItem(
                      context,
                      'Конец игры:',
                      'Побеждает игрок с наименьшим общим счётом после всех раундов. Или когда остается один.',
                      subtitleColor,
                      textColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Особенности',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      context,
                      '• Джокеры используются как универсальные карты.',
                      textColor,
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem(
                      context,
                      '• Сессия продолжается до выбытия всех, кроме одного.',
                      textColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, String title, String description,
      Color titleColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 16, color: textColor, height: 1.5),
          children: [
            TextSpan(
              text: '$title\n',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            TextSpan(text: description),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String text, Color textColor) {
    return Text(
      text,
      style: TextStyle(fontSize: 16, color: textColor, height: 1.5),
    );
  }

  Widget _buildDivider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Divider(color: color, height: 1),
    );
  }
}

import 'package:flutter/material.dart';

class AddScoresScreen extends StatefulWidget {
  final List<String> players;
  final Function(List<int>) onAddScores;
  final List<int> initialScores;

  const AddScoresScreen({
    super.key,
    required this.players,
    required this.onAddScores,
    this.initialScores = const [],
  });

  @override
  _AddScoresScreenState createState() => _AddScoresScreenState();
}

class _AddScoresScreenState extends State<AddScoresScreen> {
  late List<TextEditingController> _controllers;
  bool _hasEmptyField = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.players.length,
      (index) => TextEditingController(
        text: widget.initialScores.isNotEmpty && index < widget.initialScores.length
            ? widget.initialScores[index].toString()
            : '',
      ),
    );
  }

  void _submitScores() {
    final List<int> scores = _controllers.map((controller) {
      final text = controller.text;
      if (text.isEmpty || text == '0' || text == '-') return 0;
      return int.tryParse(text) ?? 0;
    }).toList();

    bool hasEmptyField = scores.any((score) => score == 0);

    if (hasEmptyField) {
      widget.onAddScores(scores);
      Navigator.pop(context);
    } else {
      setState(() {
        _hasEmptyField = true;
      });
    }
  }

  void _eliminatePlayer(int index) {
    setState(() {
      _controllers[index].text = '101';
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      textStyle: const TextStyle(fontSize: 14.0), // Уменьшенный размер текста
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить очки'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.players.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2, // Поле для ввода занимает 2/3 ширины
                          child: TextField(
                            controller: _controllers[index],
                            decoration: InputDecoration(
                              labelText: widget.players[index],
                              errorText: _hasEmptyField && _controllers[index].text.isEmpty ? 'Это поле не может быть пустым' : null,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1, // Кнопка занимает 1/3 ширины
                          child: SizedBox(
                            height: 50, // Высота кнопки равна высоте текстового поля
                            child: ElevatedButton(
                              onPressed: () => _eliminatePlayer(index),
                              style: buttonStyle,
                              child: const Text('Проиграл'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitScores,
                style: buttonStyle,
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

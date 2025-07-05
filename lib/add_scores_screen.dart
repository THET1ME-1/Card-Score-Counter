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
  // ignore: library_private_types_in_public_api
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
        text: widget.initialScores.isNotEmpty &&
                index < widget.initialScores.length
            ? widget.initialScores[index].toString()
            : '',
      ),
    );

    for (var controller in _controllers) {
      controller.addListener(_checkIfEmptyFieldExists);
    }
  }

  void _checkIfEmptyFieldExists() {
    bool hasEmptyField = _controllers.any((controller) {
      final text = controller.text;
      return text.isEmpty || text == '0' || text == '-';
    });

    setState(() {
      _hasEmptyField = hasEmptyField;
    });
  }

  void _submitScores() {
    final List<int> scores = _controllers.map((controller) {
      final text = controller.text;
      if (text.isEmpty || text == '0' || text == '-') return 0;
      return int.tryParse(text) ?? 0;
    }).toList();

    widget.onAddScores(scores);
    Navigator.pop(context);
  }

  void _eliminatePlayer(int index) {
    setState(() {
      _controllers[index].text = '101';
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.removeListener(_checkIfEmptyFieldExists);
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

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkTheme ? const Color(0xFFC2B8ED) : Colors.purple;

    final inputDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(16.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: borderColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.red),
      ),
      labelStyle: const TextStyle(fontSize: 14.0),
      errorStyle: const TextStyle(fontSize: 14.0),
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
                            decoration: inputDecoration.copyWith(
                              labelText: widget.players[index],
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1, // Кнопка занимает 1/3 ширины
                          child: SizedBox(
                            height:
                                60, // Высота кнопки равна высоте текстового поля
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
                onPressed: _hasEmptyField ? _submitScores : null,
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

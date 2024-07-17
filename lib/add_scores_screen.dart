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

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.players.length,
      (index) => TextEditingController(
        text: widget.initialScores.isNotEmpty ? widget.initialScores[index].toString() : '',
      ),
    );
  }

  void _submitScores() {
    final List<int> scores = _controllers.map((controller) {
      final text = controller.text;
      if (text.isEmpty) return 0;
      return int.tryParse(text) ?? 0;
    }).toList();

    widget.onAddScores(scores);
    Navigator.pop(context);
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
                    child: TextField(
                      controller: _controllers[index],
                      decoration: InputDecoration(
                        labelText: widget.players[index],
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _submitScores,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

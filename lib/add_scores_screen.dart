import 'package:flutter/material.dart';

class AddScoresScreen extends StatefulWidget {
  final List<String> players;
  final Function(List<int>) onAddScores;

  const AddScoresScreen({
    super.key,
    required this.players,
    required this.onAddScores,
  });

  @override
  // ignore: library_private_types_in_public_api
  _AddScoresScreenState createState() => _AddScoresScreenState();
}

class _AddScoresScreenState extends State<AddScoresScreen> {
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _controllers.addAll(
        List.generate(widget.players.length, (index) => TextEditingController()));
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitScores() {
    final scores = _controllers.map((controller) {
      final text = controller.text;
      if (text.isEmpty) {
        return 0;
      }
      return int.tryParse(text) ?? 0;
    }).toList();

    widget.onAddScores(scores);
    Navigator.pop(context);
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
            ...widget.players.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              return TextField(
                controller: _controllers[index],
                decoration: InputDecoration(
                  labelText: 'Очки игрока $player',
                ),
                keyboardType: TextInputType.number,
              );
            }),
            const SizedBox(height: 20),
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

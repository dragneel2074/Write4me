import 'package:flutter/material.dart';

class OptionChips extends StatelessWidget {
  final Function(String) onSelectExample;

  const OptionChips({super.key,  required this.onSelectExample});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        ActionChip(
          label: const Text('Essay on Rome'),
          onPressed: () => onSelectExample(
              'Write me a 500 words good essay about Rome Civilization'),
        ),
        ActionChip(
          label: const Text('Poem on Trees'),
          onPressed: () =>
              onSelectExample('Write me a poem on Trees'),
        ),
        ActionChip(
          label: const Text('Dad joke on Hotels'),
          onPressed: () => onSelectExample('Tell me a Dad joke about Hotels'),
        ),
      ],
    );
  }
}

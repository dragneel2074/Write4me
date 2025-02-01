import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reminder_provider.dart';

class ReminderDialog extends ConsumerStatefulWidget {
  final String initialText;

  const ReminderDialog({
    super.key,
    required this.initialText,
  });

  @override
  ConsumerState<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends ConsumerState<ReminderDialog> {
  late final TextEditingController _textController;
  late DateTime _selectedDate;
  bool _isAIReminder = false;
  Duration _selectedDuration = const Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _selectedDate = DateTime.now().add(_selectedDuration);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('AI Reminder'),
            subtitle: const Text('Generate content at scheduled time'),
            value: _isAIReminder,
            onChanged: (value) => setState(() => _isAIReminder = value),
          ),
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              labelText: _isAIReminder ? 'AI Prompt' : 'Reminder Text',
              hintText: _isAIReminder ? 'e.g., Tell me a joke' : null,
            ),
            maxLines: null,
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Remind me in'),
            trailing: DropdownButton<Duration>(
              value: _selectedDuration,
              items: [
                const Duration(minutes: 30),
                const Duration(hours: 1),
                const Duration(hours: 3),
                const Duration(hours: 24),
              ].map((duration) {
                String text = duration.inHours >= 1
                    ? '${duration.inHours} hours'
                    : '${duration.inMinutes} minutes';
                return DropdownMenuItem(
                  value: duration,
                  child: Text(text),
                );
              }).toList(),
              onChanged: (duration) {
                if (duration != null) {
                  setState(() {
                    _selectedDuration = duration;
                    _selectedDate = DateTime.now().add(duration);
                  });
                }
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (_textController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter some text')),
              );
              return;
            }

            final reminderNotifier = ref.read(reminderNotifierProvider.notifier);
            try {
              if (_isAIReminder) {
                await reminderNotifier.addAIReminder(
                  _textController.text,
                  _selectedDate,
                );
              } else {
                await reminderNotifier.addReminder(
                  _textController.text,
                  _selectedDate,
                );
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reminder set!')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('Set'),
        ),
      ],
    );
  }
} 
import 'package:flutter/material.dart';
import '../widgets/reminders_list.dart';
import '../widgets/reminder_dialog.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      body: const RemindersList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const ReminderDialog(initialText: ''),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

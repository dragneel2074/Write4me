import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import 'package:intl/intl.dart';

class RemindersList extends ConsumerWidget {
  const RemindersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(reminderNotifierProvider);

    if (reminders.isEmpty) {
      return const Center(
        child: Text('No reminders yet'),
      );
    }

    return ListView.builder(
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return ReminderTile(reminder: reminder);
      },
    );
  }
}

class ReminderTile extends ConsumerWidget {
  final Reminder reminder;

  const ReminderTile({
    super.key,
    required this.reminder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM d, y HH:mm');
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) {
        ref.read(reminderNotifierProvider.notifier).deleteReminder(reminder.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: Icon(
            reminder.hasPrompt ? Icons.auto_awesome : Icons.notifications,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            reminder.hasPrompt ? 'AI Reminder' : reminder.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: reminder.isActive ? null : theme.disabledColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reminder.hasPrompt) ...[
                Text('Prompt: ${reminder.prompt}'),
                if (reminder.generatedContent != null)
                  Text('Response: ${reminder.generatedContent}'),
              ],
              Text(
                'Due: ${dateFormat.format(reminder.dateTime)}',
                style: TextStyle(
                  color: reminder.dateTime.isBefore(DateTime.now())
                      ? theme.colorScheme.error
                      : null,
                ),
              ),
              Text(
                'Frequency: ${reminder.frequency.name}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          trailing: Switch(
            value: reminder.isActive,
            onChanged: (value) {
              ref.read(reminderNotifierProvider.notifier).updateReminder(
                    reminder.copyWith(isActive: value),
                  );
            },
          ),
          onTap: () => _showEditDialog(context, ref, reminder),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Reminder reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(
                text: reminder.hasPrompt ? reminder.prompt : reminder.title,
              ),
              decoration: InputDecoration(
                labelText: reminder.hasPrompt ? 'AI Prompt' : 'Reminder Text',
              ),
              onChanged: (value) {
                if (reminder.hasPrompt) {
                  reminder = reminder.copyWith(prompt: value);
                } else {
                  reminder = reminder.copyWith(title: value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButton<ReminderFrequency>(
              value: reminder.frequency,
              items: ReminderFrequency.values.map((frequency) {
                return DropdownMenuItem(
                  value: frequency,
                  child: Text(frequency.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  reminder = reminder.copyWith(frequency: value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(reminderNotifierProvider.notifier).updateReminder(reminder);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
} 
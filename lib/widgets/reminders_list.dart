import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/reminder.dart';
import 'reminder_dialog.dart';

class RemindersList extends StatelessWidget {
  final List<Reminder> reminders;
  final Function(Reminder) onEdit;
  final Function(String) onDelete;
  final Function(Reminder) onToggle;

  const RemindersList({
    super.key,
    required this.reminders,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return Dismissible(
          key: Key(reminder.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          onDismissed: (_) => onDelete(reminder.id),
          child: ListTile(
            title: Text(
              reminder.title,
              style: TextStyle(
                decoration: reminder.isActive ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Text(
              '${timeago.format(reminder.dateTime)}\n'
              '${reminder.frequency.toString().split('.').last}',
            ),
            isThreeLine: true,
            leading: Switch(
              value: reminder.isActive,
              onChanged: (value) => onToggle(
                Reminder(
                  id: reminder.id,
                  title: reminder.title,
                  dateTime: reminder.dateTime,
                  frequency: reminder.frequency,
                  isActive: value,
                ),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await showDialog<Reminder>(
                  context: context,
                  builder: (context) => ReminderDialog(reminder: reminder),
                );
                if (result != null) {
                  onEdit(result);
                }
              },
            ),
          ),
        );
      },
    );
  }
} 
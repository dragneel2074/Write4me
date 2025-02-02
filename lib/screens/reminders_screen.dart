// import 'package:flutter/material.dart';
// import '../models/reminder.dart';
// import '../services/reminder_service.dart';
// import '../widgets/reminder_dialog.dart';
// import '../widgets/reminders_list.dart';
// import 'package:provider/provider.dart';

// class RemindersScreen extends StatefulWidget {
//   const RemindersScreen({super.key});

//   @override
//   State<RemindersScreen> createState() => _RemindersScreenState();
// }

// class _RemindersScreenState extends State<RemindersScreen> {
//   late final ReminderService _reminderService;
//   List<Reminder> _reminders = [];

//   @override
//   void initState() {
//     super.initState();
//     // Get the already initialized service from provider
//     _reminderService = Provider.of<ReminderService>(context, listen: false);
//     _loadReminders(); // Load reminders immediately since service is already initialized
//   }

//   void _loadReminders() {
//     setState(() {
//       _reminders = _reminderService.getAllReminders();
//     });
//   }

//   Future<void> _addReminder() async {
//     final reminder = await showDialog<Reminder>(
//       context: context,
//       builder: (context) => const ReminderDialog(),
//     );

//     if (reminder != null) {
//       await _reminderService.addReminder(reminder);
//       _loadReminders();
//     }
//   }

//   Future<void> _editReminder(Reminder reminder) async {
//     await _reminderService.updateReminder(reminder);
//     _loadReminders();
//   }

//   Future<void> _deleteReminder(String id) async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete Reminder'),
//         content: const Text('Are you sure you want to delete this reminder?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: const Text('Cancel'),
//           ),
//           FilledButton(
//             onPressed: () => Navigator.of(context).pop(true),
//             style: FilledButton.styleFrom(
//               backgroundColor: Theme.of(context).colorScheme.error,
//             ),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );

//     if (confirmed == true) {
//       await _reminderService.deleteReminder(id);
//       _loadReminders();
//     }
//   }

//   Future<void> _toggleReminder(Reminder reminder) async {
//     await _reminderService.updateReminder(reminder);
//     _loadReminders();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Reminders'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.add),
//             onPressed: _addReminder,
//             tooltip: 'Add Reminder',
//           ),
//         ],
//       ),
//       body: _reminders.isEmpty
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.notifications_none,
//                     size: 64,
//                     color:
//                         Theme.of(context).colorScheme.primary.withValues(alpha:0.5),
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'No reminders yet',
//                     style: Theme.of(context).textTheme.titleLarge,
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Tap + to create a reminder',
//                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                           color: Theme.of(context).textTheme.bodySmall?.color,
//                         ),
//                   ),
//                 ],
//               ),
//             )
//           : RemindersList(
//               reminders: _reminders,
//               onEdit: _editReminder,
//               onDelete: _deleteReminder,
//               onToggle: _toggleReminder,
//             ),
//     );
//   }
// }

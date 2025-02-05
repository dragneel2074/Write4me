// import 'package:flutter/material.dart';
// import '../models/reminder.dart';

// class ReminderDialog extends StatefulWidget {
//   final Reminder? reminder;

//   const ReminderDialog({super.key, this.reminder});

//   @override
//   State<ReminderDialog> createState() => _ReminderDialogState();
// }

// class _ReminderDialogState extends State<ReminderDialog> {
//   late TextEditingController _titleController;
//   late TextEditingController _promptController;
//   late DateTime _selectedDate;
//   late TimeOfDay _selectedTime;
//   late ReminderFrequency _frequency;
//   late bool _isActive;
//   late bool _hasPrompt;

//   @override
//   void initState() {
//     super.initState();
//     _titleController = TextEditingController(text: widget.reminder?.title);
//     _promptController = TextEditingController(text: widget.reminder?.prompt);
//     _selectedDate = widget.reminder?.dateTime ?? DateTime.now();
//     _selectedTime = TimeOfDay.fromDateTime(widget.reminder?.dateTime ?? DateTime.now());
//     _frequency = widget.reminder?.frequency ?? ReminderFrequency.once;
//     _isActive = widget.reminder?.isActive ?? true;
//     _hasPrompt = widget.reminder?.hasPrompt ?? false;
//   }

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _promptController.dispose();
//     super.dispose();
//   }

//   Future<void> _selectDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate.isBefore(DateTime.now()) ? DateTime.now() : _selectedDate,
//       firstDate: DateTime.now(),
//       lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
//     );
//     if (picked != null) {
//       setState(() => _selectedDate = picked);
//     }
//   }

//   Future<void> _selectTime() async {
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: _selectedTime,
//     );
//     if (picked != null) {
//       setState(() => _selectedTime = picked);
//     }
//   }


//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text(widget.reminder == null ? 'Create Reminder' : 'Edit Reminder'),
//       content: SingleChildScrollView(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: _titleController,
//               decoration: const InputDecoration(
//                 labelText: 'Title',
//                 hintText: 'Enter reminder title',
//               ),
//             ),
//             const SizedBox(height: 16),
//             ListTile(
//               title: const Text('Date'),
//               subtitle: Text(
//                 '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}',
//               ),
//               trailing: const Icon(Icons.calendar_today),
//               onTap: _selectDate,
//             ),
//             ListTile(
//               title: const Text('Time'),
//               subtitle: Text(_selectedTime.format(context)),
//               trailing: const Icon(Icons.access_time),
//               onTap: _selectTime,
//             ),
//             DropdownButtonFormField<ReminderFrequency>(
//               value: _frequency,
//               decoration: const InputDecoration(labelText: 'Frequency'),
//               items: ReminderFrequency.values.map((frequency) {
//                 return DropdownMenuItem(
//                   value: frequency,
//                   child: Text(frequency.toString().split('.').last),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 if (value != null) {
//                   setState(() => _frequency = value);
//                 }
//               },
//             ),
//             const SizedBox(height: 8),
//             SwitchListTile(
//               title: const Text('Active'),
//               value: _isActive,
//               onChanged: (value) => setState(() => _isActive = value),
//             ),
//             const SizedBox(height: 8),
//             SwitchListTile(
//               title: const Text('Enable AI Prompt'),
//               subtitle: const Text('Generate content at scheduled time'),
//               value: _hasPrompt,
//               onChanged: (value) => setState(() => _hasPrompt = value),
//             ),
//             if (_hasPrompt) ...[
//               const SizedBox(height: 8),
//               TextField(
//                 controller: _promptController,
//                 decoration: const InputDecoration(
//                   labelText: 'Prompt',
//                   hintText: 'e.g., Tell me a joke',
//                 ),
//                 maxLines: 2,
//               ),
//             ],
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(),
//           child: const Text('Cancel'),
//         ),
//         FilledButton(
//           onPressed: () {
//             if (_titleController.text.isEmpty) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Please enter a title')),
//               );
//               return;
//             }
//             if (_hasPrompt && _promptController.text.isEmpty) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Please enter a prompt')),
//               );
//               return;
//             }

//             final selectedDateTime = DateTime(
//               _selectedDate.year,
//               _selectedDate.month,
//               _selectedDate.day,
//               _selectedTime.hour,
//               _selectedTime.minute,
//             );

//             if (selectedDateTime.isBefore(DateTime.now())) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Please select a future date and time')),
//               );
//               return;
//             }

//             final reminder = Reminder(
//               id: widget.reminder?.id,
//               title: _titleController.text,
//               dateTime: selectedDateTime,
//               frequency: _frequency,
//               isActive: _isActive,
//               hasPrompt: _hasPrompt,
//               prompt: _hasPrompt ? _promptController.text : null,
//             );

//             Navigator.of(context).pop(reminder);
//           },
//           child: Text(widget.reminder == null ? 'Create' : 'Update'),
//         ),
//       ],
//     );
//   }
// } 
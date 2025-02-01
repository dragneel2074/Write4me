import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';
import 'providers.dart';

part 'reminder_provider.g.dart';

@Riverpod(keepAlive: true)
class ReminderNotifier extends _$ReminderNotifier {
  late final ReminderService _service;

  @override
  List<Reminder> build() {
    _service = ref.watch(reminderServiceProvider);
    return _service.getAllReminders();
  }

  Future<void> addReminder(String text, DateTime dateTime) async {
    await _service.addReminder(text, dateTime);
    state = _service.getAllReminders();
  }

  Future<void> addAIReminder(String prompt, DateTime dateTime) async {
    await _service.addAIReminder(prompt, dateTime);
    state = _service.getAllReminders();
  }

  Future<void> updateReminder(Reminder reminder) async {
    await _service.updateReminder(reminder);
    state = _service.getAllReminders();
  }

  Future<void> deleteReminder(String id) async {
    await _service.deleteReminder(id);
    state = _service.getAllReminders();
  }
} 
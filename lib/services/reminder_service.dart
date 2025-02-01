import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/reminder.dart';
import 'notification_service.dart';
import 'text_generation_service.dart';

class ReminderService {
  static const String _boxName = 'reminders';
  late Box<Reminder> _box;
  final NotificationService _notificationService;
  final TextGenerationService _textGenService;

  ReminderService(this._notificationService) 
      : _textGenService = TextGenerationService();

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReminderFrequencyAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ReminderAdapter());
    }
    _box = await Hive.openBox<Reminder>(_boxName);
    _scheduleAllReminders();
  }

  void _scheduleAllReminders() {
    for (final reminder in _box.values) {
      if (reminder.isActive) {
        _scheduleNotification(reminder);
      }
    }
  }

  Future<void> addReminder(String text, DateTime dateTime) async {
    final reminder = Reminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: text,
      dateTime: dateTime,
      frequency: ReminderFrequency.once,
      isActive: true,
      hasPrompt: false,
    );

    await _box.put(reminder.id, reminder);
    await _scheduleNotification(reminder);
  }

  Future<void> addAIReminder(String prompt, DateTime dateTime) async {
    try {
      if (kDebugMode) {
        print('Creating AI reminder with prompt: $prompt');
      }
      
      final content = await _textGenService.generateCloudResponse(prompt);
      
      final reminder = Reminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'AI Response',
        dateTime: dateTime,
        frequency: ReminderFrequency.once,
        isActive: true,
        hasPrompt: true,
        prompt: prompt,
        generatedContent: content,
      );

      await _box.put(reminder.id, reminder);
      await _scheduleNotification(reminder);
    } catch (e) {
      debugPrint('Error creating AI reminder: $e');
      rethrow;
    }
  }

  Future<void> updateReminder(Reminder reminder) async {
    if (reminder.hasPrompt && reminder.prompt != null) {
      try {
        final content = await _textGenService.generateCloudResponse(reminder.prompt!);
        reminder = reminder.copyWith(generatedContent: content);
      } catch (e) {
        debugPrint('Error updating AI reminder: $e');
      }
    }

    await _box.put(reminder.id, reminder);
    await _notificationService.cancelNotification(reminder.id);
    if (reminder.isActive) {
      await _scheduleNotification(reminder);
    }
  }

  Future<void> deleteReminder(String id) async {
    await _box.delete(id);
    await _notificationService.cancelNotification(id);
  }

  List<Reminder> getAllReminders() {
    return _box.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<void> _scheduleNotification(Reminder reminder) async {
    if (!reminder.isActive) return;

    final title = reminder.hasPrompt ? 'AI Response' : reminder.title;
    final body = reminder.hasPrompt 
        ? reminder.generatedContent ?? 'Failed to generate content'
        : reminder.title;

    final now = DateTime.now();
    var nextRunTime = reminder.dateTime;

    // If the scheduled time has passed, calculate next run based on frequency
    if (nextRunTime.isBefore(now)) {
      switch (reminder.frequency) {
        case ReminderFrequency.once:
          return; // Don't schedule if it's a one-time reminder that's passed
        case ReminderFrequency.daily:
          nextRunTime = DateTime(
            now.year,
            now.month,
            now.day,
            reminder.dateTime.hour,
            reminder.dateTime.minute,
          ).add(const Duration(days: 1));
          break;
        case ReminderFrequency.weekly:
          nextRunTime = DateTime(
            now.year,
            now.month,
            now.day,
            reminder.dateTime.hour,
            reminder.dateTime.minute,
          ).add(const Duration(days: 7));
          break;
        case ReminderFrequency.monthly:
          nextRunTime = DateTime(
            now.year,
            now.month + 1,
            reminder.dateTime.day,
            reminder.dateTime.hour,
            reminder.dateTime.minute,
          );
          break;
      }
    }

    await _notificationService.scheduleNotification(
      id: reminder.id,
      title: title,
      body: body,
      scheduledDate: nextRunTime,
    );
  }
} 
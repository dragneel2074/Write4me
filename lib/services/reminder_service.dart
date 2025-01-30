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
  }

  Future<void> addReminder(Reminder reminder) async {
    if (reminder.hasPrompt) {
      // Generate content immediately
      try {
        if (kDebugMode) {
          print(reminder.prompt);
        }
        final content = await _textGenService.generateText(reminder.prompt!);
        if (kDebugMode) {
          print(content);
        }
        reminder = Reminder(
          id: reminder.id,
          title: reminder.title,
          dateTime: reminder.dateTime,
          frequency: reminder.frequency,
          isActive: reminder.isActive,
          hasPrompt: reminder.hasPrompt,
          prompt: reminder.prompt,
          generatedContent: content,
        );
      } catch (e) {
        debugPrint('Error generating content: $e');
      }
    }

    await _box.put(reminder.id, reminder);
    await _scheduleNotification(reminder);
  }

  Future<void> updateReminder(Reminder reminder) async {
    if (reminder.hasPrompt) {
      try {
        if (kDebugMode) {
          print('Updating reminder with prompt: ${reminder.prompt}');
        }
        final content = await _textGenService.generateText(reminder.prompt!);
        if (kDebugMode) {
          print('Generated content: $content');
        }
        reminder = Reminder(
          id: reminder.id,
          title: reminder.title,
          dateTime: reminder.dateTime,
          frequency: reminder.frequency,
          isActive: reminder.isActive,
          hasPrompt: reminder.hasPrompt,
          prompt: reminder.prompt,
          generatedContent: content,
        );
      } catch (e) {
        debugPrint('Error generating content during update: $e');
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

    // Calculate next run time based on frequency
    switch (reminder.frequency) {
      case ReminderFrequency.once:
        if (nextRunTime.isBefore(now)) {
          // Deactivate one-time reminders after they run
          reminder.isActive = false;
          await _box.put(reminder.id, reminder);
          return;
        }
        break;
      case ReminderFrequency.daily:
        while (nextRunTime.isBefore(now)) {
          nextRunTime = nextRunTime.add(const Duration(days: 1));
        }
        break;
      case ReminderFrequency.weekly:
        while (nextRunTime.isBefore(now)) {
          nextRunTime = nextRunTime.add(const Duration(days: 7));
        }
        break;
      case ReminderFrequency.monthly:
        while (nextRunTime.isBefore(now)) {
          nextRunTime = DateTime(
            nextRunTime.year,
            nextRunTime.month + 1,
            nextRunTime.day,
            nextRunTime.hour,
            nextRunTime.minute,
          );
        }
        break;
      case ReminderFrequency.yearly:
        while (nextRunTime.isBefore(now)) {
          nextRunTime = DateTime(
            nextRunTime.year + 1,
            nextRunTime.month,
            nextRunTime.day,
            nextRunTime.hour,
            nextRunTime.minute,
          );
        }
        break;
    }

    // Update reminder with next run time if it changed
    if (nextRunTime != reminder.dateTime) {
      reminder.dateTime = nextRunTime;
      await _box.put(reminder.id, reminder);
    }

    // Schedule the notification
    switch (reminder.frequency) {
      case ReminderFrequency.once:
        await _notificationService.scheduleNotification(
          id: reminder.id,
          title: title,
          body: body,
          scheduledDate: nextRunTime,
        );
        break;
      case ReminderFrequency.daily:
      case ReminderFrequency.weekly:
      case ReminderFrequency.monthly:
      case ReminderFrequency.yearly:
        await _notificationService.scheduleDailyNotification(
          id: reminder.id,
          title: '${reminder.frequency.toString().split('.').last} Reminder',
          body: body,
          scheduledTime: TimeOfDay.fromDateTime(nextRunTime),
        );
        break;
    }
  }
} 
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/reminder.dart';
import 'notification_service.dart';

class ReminderService {
  static const String _boxName = 'reminders';
  late Box<Reminder> _box;
  final NotificationService _notificationService;

  ReminderService(this._notificationService);

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
    await _box.put(reminder.id, reminder);
    await _scheduleNotification(reminder);
  }

  Future<void> updateReminder(Reminder reminder) async {
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

    switch (reminder.frequency) {
      case ReminderFrequency.once:
        await _notificationService.scheduleNotification(
          id: reminder.id,
          title: 'Reminder',
          body: reminder.title,
          scheduledDate: reminder.dateTime,
        );
        break;
      case ReminderFrequency.daily:
        await _notificationService.scheduleDailyNotification(
          id: reminder.id,
          title: 'Daily Reminder',
          body: reminder.title,
          scheduledTime: TimeOfDay.fromDateTime(reminder.dateTime),
        );
        break;
      case ReminderFrequency.weekly:
        await _notificationService.scheduleDailyNotification(
          id: reminder.id,
          title: 'Weekly Reminder',
          body: reminder.title,
          scheduledTime: TimeOfDay.fromDateTime(reminder.dateTime),
        );        break;
      case ReminderFrequency.monthly:
        await _notificationService.scheduleDailyNotification(
          id: reminder.id,
          title: 'Monthly Reminder',
          body: reminder.title,
          scheduledTime: TimeOfDay.fromDateTime(reminder.dateTime),
        );        break;
      case ReminderFrequency.yearly:
        await _notificationService.scheduleDailyNotification(
          id: reminder.id,
          title: 'Yearly Reminder',
          body: reminder.title,
          scheduledTime: TimeOfDay.fromDateTime(reminder.dateTime),
        );        break;
    }
  }
} 
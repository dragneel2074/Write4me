import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'reminder.g.dart';

@HiveType(typeId: 2)
enum ReminderFrequency {
  @HiveField(0)
  once,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
  @HiveField(3)
  monthly,
  @HiveField(4)
  yearly
}

@HiveType(typeId: 3)
class Reminder extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime dateTime;

  @HiveField(3)
  ReminderFrequency frequency;

  @HiveField(4)
  bool isActive;

  Reminder({
    String? id,
    required this.title,
    required this.dateTime,
    required this.frequency,
    this.isActive = true,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateTime': dateTime.toIso8601String(),
    'frequency': frequency.toString(),
    'isActive': isActive,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: json['id'],
    title: json['title'],
    dateTime: DateTime.parse(json['dateTime']),
    frequency: ReminderFrequency.values.firstWhere(
      (e) => e.toString() == json['frequency'],
    ),
    isActive: json['isActive'],
  );
} 
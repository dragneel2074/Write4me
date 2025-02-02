// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  // final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Future<void> init() async {
    // const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // const iosSettings = DarwinInitializationSettings(
    //   requestAlertPermission: true,
    //   requestBadgePermission: true,
    //   requestSoundPermission: true,
    // );
    
    // const initSettings = InitializationSettings(
    //   android: androidSettings,
    //   iOS: iosSettings,
    // );

    // Request permissions for iOS
    // await _notifications.resolvePlatformSpecificImplementation<
    //     IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
    //       alert: true,
    //       badge: true,
    //       sound: true,
    //     );

    // Request permissions for Android
  //   await _notifications.resolvePlatformSpecificImplementation<
  //       AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

  //   await _notifications.initialize(
  //     initSettings,
  //     onDidReceiveNotificationResponse: (details) {
  //       // Handle notification tap
  //       debugPrint('Notification tapped: ${details.payload}');
  //     },
  //   );
  // }

  // Future<void> scheduleNotification({
  //   required String id,
  //   required String title,
  //   required String body,
  //   required DateTime scheduledDate,
  // }) async {
  //   final now = DateTime.now();
  //   if (scheduledDate.isBefore(now)) {
  //     debugPrint('Scheduled date is in the past, skipping notification');
  //     return;
  //   }

  //   final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
    
  //   try {
  //     await _notifications.zonedSchedule(
  //       id.hashCode,
  //       title,
  //       body.length > 1000 ? '${body.substring(0, 997)}...' : body,
  //       tzDateTime,
  //       NotificationDetails(
  //         android: AndroidNotificationDetails(
  //           'reminders_channel',
  //           'Reminders',
  //           channelDescription: 'Channel for scheduled reminders',
  //           importance: Importance.max,
  //           priority: Priority.high,
  //           enableVibration: true,
  //           styleInformation: BigTextStyleInformation(body),
  //         ),
  //         iOS: const DarwinNotificationDetails(
  //           presentAlert: true,
  //           presentBadge: true,
  //           presentSound: true,
  //         ),
  //       ),
  //       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  //       uiLocalNotificationDateInterpretation:
  //           UILocalNotificationDateInterpretation.absoluteTime,
  //       matchDateTimeComponents: DateTimeComponents.time,
  //     );
  //     debugPrint('Notification scheduled for $scheduledDate');
  //   } catch (e) {
  //     debugPrint('Error scheduling notification: $e');
  //     rethrow;
  //   }
  // }

  // Future<void> scheduleDailyNotification({
  //   required String id,
  //   required String title,
  //   required String body,
  //   required TimeOfDay scheduledTime,
  // }) async {
  //   final now = DateTime.now();
  //   var scheduledDate = DateTime(
  //     now.year,
  //     now.month,
  //     now.day,
  //     scheduledTime.hour,
  //     scheduledTime.minute,
  //   );

  //   if (scheduledDate.isBefore(now)) {
  //     scheduledDate = scheduledDate.add(const Duration(days: 1));
  //   }

  //   try {
  //     await _notifications.zonedSchedule(
  //       id.hashCode,
  //       title,
  //       body,
  //       tz.TZDateTime.from(scheduledDate, tz.local),
  //       const NotificationDetails(
  //         android: AndroidNotificationDetails(
  //           'daily_reminders_channel',
  //           'Daily Reminders',
  //           channelDescription: 'Channel for daily reminders',
  //           importance: Importance.max,
  //           priority: Priority.high,
  //           enableVibration: true,
  //         ),
  //         iOS: DarwinNotificationDetails(
  //           presentAlert: true,
  //           presentBadge: true,
  //           presentSound: true,
  //         ),
  //       ),
  //       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  //       uiLocalNotificationDateInterpretation:
  //           UILocalNotificationDateInterpretation.absoluteTime,
  //       matchDateTimeComponents: DateTimeComponents.time,
  //       payload: 'daily_reminder',
  //     );
  //     debugPrint('Daily notification scheduled for $scheduledDate');
  //   } catch (e) {
  //     debugPrint('Error scheduling daily notification: $e');
  //     rethrow;
  //   }
  // }

  // Future<void> cancelNotification(String id) async {
  //   await _notifications.cancel(id.hashCode);
  // }

  // Future<void> cancelAllNotifications() async {
  //   await _notifications.cancelAll();
  // }

  static void showTopNotification(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    OverlayState? overlay = Overlay.of(context);

    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error : Icons.check_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }
}

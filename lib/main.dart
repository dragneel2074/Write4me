import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'homepage.dart';
import 'theme/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/reminder_service.dart';
import 'services/offline_model_service.dart';
import 'services/text_generation_service.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone
  tz.initializeTimeZones();
  
  await Hive.initFlutter();
  
  final notificationService = NotificationService();
  await notificationService.init();
  
  final reminderService = ReminderService(notificationService);
  await reminderService.init();

  final offlineModelService = OfflineModelService();
  await offlineModelService.init();

  final textGenService = TextGenerationService();
  final aiService = AIService(textGenService, offlineModelService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<ReminderService>.value(value: reminderService),
        ChangeNotifierProvider.value(value: offlineModelService),
        Provider<AIService>.value(value: aiService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Write4Me',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const HomePage(),
        );
      },
    );
  }
}

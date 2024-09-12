import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:write4me/components/app_theme.dart';
import 'package:write4me/components/splash_screen.dart';
import 'package:write4me/homepage.dart';
import 'package:write4me/text_detector.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env.production");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppThemes.lightTheme, // Use light theme
      // darkTheme: AppThemes.darkTheme, // Use dark theme
      // themeMode: ThemeMode.system, // Use system theme mode
      home:  const HomePage(),
      // home: TextDetectorPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

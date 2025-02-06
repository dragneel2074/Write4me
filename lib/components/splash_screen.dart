import 'package:flutter/material.dart';
import 'package:write4me/components/static.dart';
import 'package:write4me/homepage.dart';
import 'package:write4me/features/offline_models/offline_feature_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:write4me/providers/offline_mode_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize offline mode
      final offlineModeNotifier = ref.read(offlineModeProvider.notifier);
      await offlineModeNotifier.initialize();
      
      debugPrint('Initialization complete');
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      debugPrint('Error during initialization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing app: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/playstore.png',
              height: ScreenSize.height * 0.25,
              width: ScreenSize.width * 0.56,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

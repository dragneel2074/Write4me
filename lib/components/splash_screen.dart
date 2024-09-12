import 'package:flutter/material.dart';
import 'package:write4me/components/static.dart';
import 'package:write4me/homepage.dart';

class SplashScreen extends StatefulWidget {
  
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
    });
  }

  @override
  Widget build(BuildContext context) {
      ScreenSize.init(context);
      double myWidgetHeight = ScreenSize.height * 0.5; // Half of the screen height
      double myWidgetWidth = ScreenSize.width * 0.8; // 80% of the screen width

    return Scaffold(
      body: Center(
        child: Image.asset('assets/images/playstore.png',
        height: myWidgetHeight * 0.5,
        width: myWidgetWidth * 0.7,
        ),
      ),
    );
  }
}

import 'dart:io' show HttpOverrides;
import 'package:flutter/material.dart';
import 'package:kurs/screens/auth.dart';
import 'package:kurs/theme/app_theme.dart';
import 'package:kurs/utils/fade_page_route.dart';
import 'http_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  HttpOverrides.global = MyHttpOverrides();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Welcome to the ',
              style: TextStyle(fontSize: 60, fontFamily: 'InstrumentSans'),
            ),
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 1500),
              child: const Text(
                'TeamRoom',
                style: TextStyle(fontSize: 70, fontFamily: 'InstrumentSans', fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 60),
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 1000),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    FadePageRoute(child: const LoginScreen()),
                  );
                },
                child: const Text('Let`s explore'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
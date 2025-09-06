import 'package:flutter/material.dart';
import 'package:kurs/screens/auth.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        fontFamily: 'InstrumentSans',
        scaffoldBackgroundColor: const Color(0xffffffff),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: const Color(0xFF7C6BA3),
          displayColor: const Color(0xFFFFFFFF),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB6A5DE),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            fixedSize: const Size(200, 50),
            textStyle: const TextStyle(
              fontSize: 18,
            ),
          ),
        ),
      ),
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
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
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
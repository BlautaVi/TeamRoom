import 'package:flutter/material.dart';

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
        scaffoldBackgroundColor: const Color(0xFFF1F0CC),

        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Color(0xFF7E6B56),
          displayColor: Color(0xFFF1F0CC),
        ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF8D775F),
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
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
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
            const Text(
              'TeamRoom',
              style: TextStyle(fontSize: 70, fontFamily: 'InstrumentSans', fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: () {
                print("Кнопку натиснуто!");
              },
              child: const Text('Let`s explore'),
            ),
          ],
        ),
      ),
    );
  }
}


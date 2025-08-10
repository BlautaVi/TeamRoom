import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color textColor = Colors.white;
    final Color labelColor = Colors.white.withOpacity(0.8);
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF1F0CC),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Let`s \ncomplete an \nauth',
                    style: TextStyle(
                      fontSize: 64,
                      fontFamily: 'InstrumentSans',
                      fontWeight: FontWeight.w200,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    TextField(
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF8D775F),
                          labelText: 'Логін',
                          labelStyle: TextStyle(color: labelColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFF1F0CC))
                          )
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF8D775F),
                          labelText: 'Електронна пошта',
                          labelStyle: TextStyle(color: labelColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFF1F0CC))
                          )
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      obscureText: true,
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF8D775F),
                          labelText: 'Пароль',
                          labelStyle: TextStyle(color: labelColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFF1F0CC))
                          )
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        print('Спроба авторизації');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA71D31),
                        foregroundColor: const Color(0xFFF1F0CC),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Увійти',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

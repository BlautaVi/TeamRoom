import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final String login = _loginController.text.trim();
      final String password = _passwordController.text.trim();

      try {
        final response = await http.post(
          Uri.parse("http://team-room-back.onrender.com/api/auth/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "username": login,
            "password": password,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print("Успішна авторизація: $data");

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Вхід успішний!")),
          );
        } else {
          print("Помилка: ${response.body}");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Невірний логін або пароль")),
          );
        }
      } catch (e) {
        print("Помилка підключення: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Помилка з'єднання")),
        );
      }
    }
  }

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
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    TextFormField(
                      controller: _loginController,
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
                          borderSide:
                          const BorderSide(color: Color(0xFFF1F0CC)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Введіть логін";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
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
                          borderSide:
                          const BorderSide(color: Color(0xFFF1F0CC)),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: labelColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                      ),
    ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Введіть пароль";
                        }
                        if (value.length < 6) {
                          return "Мінімум 6 символів";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _login,
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

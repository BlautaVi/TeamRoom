import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:kurs/screens/Profile.dart';

import 'auth.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String username = _usernameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final url = Uri.parse("http://localhost:8080/api/auth/register");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("Успішна реєстрація: ${response.body}");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Реєстрація успішна! Тепер можете увійти."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
      } else {
        print("Помилка реєстрації (статус ${response.statusCode}): ${response.body}");
        if (mounted) {
          _showErrorSnackBar("Помилка реєстрації. Можливо, такий користувач вже існує.");
        }
      }
    } catch (e) {
      print("Помилка підключення: $e");
      if (mounted) {
        _showErrorSnackBar("Помилка з'єднання з сервером. Перевірте інтернет.");
      }
    }
  }


  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color rightPanelColor = Color(0xFF62567E);
    const Color buttonBackgroundColor = Color(0xFFB6A5DE);
    const Color hintTextColor = Color(0xFF62567E);
    const Color linkTextColor = Color(0xAAFFFFFF);

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Create \nyour \naccount',
                    style: TextStyle(
                      color: Color(0xFF62567E),
                      fontSize: 64,
                      fontFamily: 'InstrumentSans',
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: rightPanelColor,
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Color(0xFF62567E)),
                      decoration: buildInputDecoration('Ім\'я', hintTextColor),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Введіть ім'я";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Color(0xFF62567E)),
                      keyboardType: TextInputType.emailAddress,
                      decoration: buildInputDecoration('Електронна пошта', hintTextColor),
                      validator: (value) {
                        if (value == null || value.isEmpty || !value.contains('@')) {
                          return "Введіть коректну пошту";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      style: const TextStyle(color: Color(0xFF62567E) ),
                      decoration: buildInputDecoration('Пароль', hintTextColor).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: hintTextColor,
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
                          return "Пароль має містити мінімум 6 символів";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBackgroundColor,
                        foregroundColor: hintTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Зареєструватися',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Є акаунт? Авторизуйтесь',
                        style: TextStyle(
                          color: linkTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
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

  InputDecoration buildInputDecoration(String hint, Color hintColor) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: TextStyle(color: hintColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }
}

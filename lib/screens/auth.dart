import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kurs/screens/HomeScreen.dart';
import 'registration.dart';

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
          Uri.parse("https://team-room-back.onrender.com/api/auth/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "username": login,
            "password": password,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final authToken = data['jwt'];
          if (authToken != null && authToken is String) {
            print("Успішна авторизація для користувача: $login");
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(authToken: authToken),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Помилка авторизації: не отримано токен.")),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Невірний логін або пароль")),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Помилка з'єднання")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color rightPanelColor = Color(0xFF62567E);
    const Color buttonBackgroundColor = Color(0xFFB6A5DE);
    const Color hintTextColor = Color(0xFF62567E);
    const Color leftPanelTextColor = Color(0xFF62567E);

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
                    'Let`s\ncomplete an\nauth',
                    style: TextStyle(
                      fontSize: 64,
                      fontFamily: 'InstrumentSans',
                      fontWeight: FontWeight.w400,
                      color: leftPanelTextColor,
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
                      controller: _loginController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Ім\'я',
                        hintStyle: const TextStyle(color: hintTextColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Введіть ім'я";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Пароль',
                        hintStyle: const TextStyle(color: hintTextColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: hintTextColor.withOpacity(0.7),
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
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBackgroundColor,
                        foregroundColor: const Color(0xFFFFFFFF),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Авторизуватись',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RegistrationScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Немає акаунту? Зареєструйтесь',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
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
}
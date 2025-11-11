import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


import 'auth.dart';
import 'package:kurs/utils/fade_page_route.dart';

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
    final url = Uri.parse("https://team-room-jitsi.duckdns.org/api/auth/register");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
        }),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception("Час очікування вичерпаний. Спробуйте ще раз.");
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint("Успішна реєстрація: ${response.body}");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Реєстрація успішна! Тепер можете увійти."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            FadePageRoute(child: const LoginScreen()),
          );
        }
      } else if (response.statusCode == 400) {
        debugPrint("Помилка валідації (статус 400): ${response.body}");
        String errorMessage = "Помилка у вхідних даних.";
        
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['details'] != null && errorData['details'] is List && errorData['details'].isNotEmpty) {
            errorMessage = errorData['details'][0]['message'] ?? errorMessage;
          }
        } catch (e) {
          debugPrint("Помилка парсингу відповіді: $e");
        }
        
        if (mounted) {
          _showErrorSnackBar(errorMessage);
        }
      } else if (response.statusCode == 409) {
        debugPrint("Конфлікт (статус 409): ${response.body}");
        String errorMessage = "Користувач з таким логіном або email уже існує.";
        
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          debugPrint("Помилка парсингу відповіді: $e");
        }
        
        if (mounted) {
          _showErrorSnackBar(errorMessage);
        }
      } else if (response.statusCode == 500) {
        debugPrint("Помилка сервера (статус 500): ${response.body}");
        String errorMessage = "Помилка сервера. Спробуйте пізніше.";
        
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          debugPrint("Помилка парсингу відповіді: $e");
        }
        
        if (mounted) {
          _showErrorSnackBar(errorMessage);
        }
      } else {
        debugPrint("Помилка реєстрації (статус ${response.statusCode}): ${response.body}");
        String errorMessage = "Помилка реєстрації.";
        
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['details'] != null && errorData['details'] is List && errorData['details'].isNotEmpty) {
            errorMessage = errorData['details'][0]['message'] ?? errorMessage;
          }
        } catch (e) {
          debugPrint("Помилка парсингу відповіді: $e");
        }
        
        if (mounted) {
          _showErrorSnackBar(errorMessage);
        }
      }
    } catch (e) {
      debugPrint("Помилка підключення: $e");
      if (mounted) {
        _showErrorSnackBar("Помилка з'єднання: ${e.toString().replaceFirst('Exception: ', '')}");
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // Left pane: white with title text (text stays on the left)
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Create \nyour \naccount',
                    style: TextStyle(
                      color: scheme.primary,
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
          // Right pane: colored with form (panel on the other side of Login)
          Expanded(
            child: Container(
              color: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _usernameController,
                      style: TextStyle(color: scheme.primary),
                      decoration: buildInputDecoration('Ім\'я', scheme.primary),
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
                      style: TextStyle(color: scheme.primary),
                      keyboardType: TextInputType.emailAddress,
                      decoration: buildInputDecoration('Електронна пошта', scheme.primary),
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
                      style: TextStyle(color: scheme.primary),
                      decoration: buildInputDecoration('Пароль', scheme.primary).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white,
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
                      child: const Text(
                        'Зареєструватися',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          FadePageRoute(child: const LoginScreen()),
                        );
                      },
                      child: const Text(
                        'Є акаунт? Авторизуйтесь',
                        style: TextStyle(
                          color: Color(0xAAFFFFFF),
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

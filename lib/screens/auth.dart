import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kurs/screens/HomeScreen.dart';
import 'registration.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:kurs/utils/fade_page_route.dart';

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

      if (login.length < 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ім'я повинно мати мінімум 3 символи")),
          );
        }
        return;
      }

      try {
        final response = await http.post(
          Uri.parse("https://team-room-jitsi.duckdns.org/api/auth/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "username": login,
            "password": password,
          }),
        ).timeout(const Duration(seconds: 15), onTimeout: () {
          throw Exception("Час очікування вичерпаний. Спробуйте ще раз.");
        });

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final authToken = data['jwt'];
          if (authToken != null && authToken is String) {
            debugPrint("Успішна авторизація для користувача: $login");

            final stompConfig = StompConfig(
            url: 'wss://team-room-back.onrender.com/ws/websocket',
            onConnect: (frame) {
            debugPrint("STOMP client connected (from LoginScreen).");
            },
            onWebSocketError: (e) => debugPrint("WebSocket Error: $e"),
            onStompError: (frame) => debugPrint("STOMP Error: ${frame.body}"),
            stompConnectHeaders: {'Authorization': 'Bearer $authToken'},
            webSocketConnectHeaders: {'Authorization': 'Bearer $authToken'},
            reconnectDelay: const Duration(seconds: 5),
            connectionTimeout: const Duration(seconds: 30),
            heartbeatOutgoing: const Duration(seconds: 20),
            heartbeatIncoming: const Duration(seconds: 20),
            );

            final stompClient = StompClient(config: stompConfig);
            stompClient.activate();

            if (mounted) {
              Navigator.of(context).pushReplacement(
                FadePageRoute(
                  child: HomeScreen(
                    authToken: authToken,
                    username: login,
                    stompClient: stompClient,
                  ),
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
        } else if (response.statusCode == 401) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Невірний логін або пароль")),
            );
          }
        } else if (response.statusCode == 400 || response.statusCode == 403 || response.statusCode == 404) {
          String errorMessage = "Помилка запиту.";
          
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        } else if (response.statusCode == 500) {
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        } else {
          String errorMessage = "Помилка авторизації (статус ${response.statusCode}).";
          
          try {
            final errorData = jsonDecode(response.body);
            if (errorData['message'] != null) {
              errorMessage = errorData['message'];
            }
          } catch (e) {
            debugPrint("Помилка парсингу відповіді: $e");
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Помилка з'єднання: ${e.toString().replaceFirst('Exception: ', '')}")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Let`s\ncomplete an\nauth',
                    style: TextStyle(
                      fontSize: 64,
                      fontFamily: 'InstrumentSans',
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF62567E),
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ),
          ),
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
                      controller: _loginController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Ім\'я',
                        hintStyle: TextStyle(color: scheme.primary),
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
                        hintStyle: TextStyle(color: scheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: scheme.primary.withOpacity(0.7),
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
                      child: const Text(
                        'Авторизуватись',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          FadePageRoute(child: const RegistrationScreen()),
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
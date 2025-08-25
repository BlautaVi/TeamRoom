import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.authToken});
  final String authToken;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _biographyController = TextEditingController();

  File? _profileImage;
  String? _currentPhotoUrl;
  bool _isLoading = true;
  bool _profileExists = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final url = Uri.parse("https://team-room-back.onrender.com/api/profile");
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.authToken}',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _biographyController.text = data['biography'] ?? '';
          _currentPhotoUrl = data['photoUrl'];
          _profileExists = true;
        });
      } else if (response.statusCode == 404) {
        setState(() { _profileExists = false; });
        print("Профіль ще не створено.");
      } else {
        _handleErrorResponse(response.body, response.statusCode);
      }
    } catch (e) {
      print("Помилка з'єднання: $e");
      _showErrorSnackBar("Помилка з'єднання з сервером.");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    final url = Uri.parse("https://team-room-back.onrender.com/api/profile");
    final method = _profileExists ? 'PUT' : 'POST';

    try {
      final body = jsonEncode({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'biography': _biographyController.text,
        // 'photoUrl': 'URL_з_хмари_після_завантаження' // Це поле потрібно буде додати пізніше
      });

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.authToken}',
      };

      final response = method == 'PUT'
          ? await http.put(url, headers: headers, body: body)
          : await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar("Профіль успішно збережено!");
        _fetchProfileData();
      } else {
        _handleErrorResponse(response.body, response.statusCode);
      }

    } catch (e) {
      print("Помилка з'єднання: $e");
      _showErrorSnackBar("Помилка з'єднання з сервером.");
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }
  void _handleErrorResponse(String body, int statusCode) {
    print("Помилка від сервера (Статус $statusCode): $body");
    String errorMessage = "Помилка $statusCode";
    try {
      final errorData = jsonDecode(body);
      final message = errorData['message'] ?? errorData['error'] ?? errorData['details'];
      if (message != null) {
        errorMessage = message;
      }
    } catch (e) {
      errorMessage = "Сервер повернув неочікувану відповідь.";
    }
    _showErrorSnackBar(errorMessage);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F0CC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 75,
                    backgroundColor: const Color(0xFF8D775F),
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty
                        ? NetworkImage(_currentPhotoUrl!)
                        : null) as ImageProvider?,
                    child: _profileImage == null && (_currentPhotoUrl == null || _currentPhotoUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 80, color: Color(0xFF3D352E))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFA71D31),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _firstNameController,
                decoration: buildInputDecoration("Ім'я"),
                style: const TextStyle(color: Color(0xFFF1F0CC)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Ім'я є обов'язковим полем";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _lastNameController,
                decoration: buildInputDecoration("Прізвище (необов'язково)"),
                style: const TextStyle(color: Color(0xFFF1F0CC)),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _biographyController,
                decoration: buildInputDecoration("Біографія (необов'язково)"),
                style: const TextStyle(color: Color(0xFFF1F0CC)),
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA71D31),
                  foregroundColor: const Color(0xFFF1F0CC),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _profileExists ? 'Зберегти зміни' : 'Створити профіль',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration buildInputDecoration(String label) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF8D775F),
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF1F0CC)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

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
  String? _currentPublicPhotoUrl;
  String? _displayablePhotoUrl;
  bool _isLoading = true;
  bool _profileExists = false;
  final String _backendBaseUrl = "https://team-room-back.onrender.com";
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
          _currentPublicPhotoUrl = data['photoUrl'];
          _profileExists = true;
        });
        if (_currentPublicPhotoUrl != null && _currentPublicPhotoUrl!.isNotEmpty) {
          _resolveAndSetDisplayableUrl(_currentPublicPhotoUrl!);
        }
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

  Future<void> _saveProfile({String? newPhotoUrl}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    final url = Uri.parse("https://team-room-back.onrender.com/api/profile");
    final method = _profileExists ? 'PUT' : 'POST';

    try {
      final bodyMap = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'biography': _biographyController.text,
      };

      if (newPhotoUrl != null) {
        bodyMap['photoUrl'] = newPhotoUrl;
      }
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.authToken}',
      };

      final response = method == 'PUT'
          ? await http.put(url, headers: headers, body: jsonEncode(bodyMap))
          : await http.post(url, headers: headers, body: jsonEncode(bodyMap));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar("Профіль успішно збережено!");
        setState(() { _profileImage = null; });
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
  Future<void> _handleSave() async {
    if (_profileImage != null) {
      setState(() { _isLoading = true; });
      try {
        final uploadLinkResponse = await _getUploadLink();
        final uploadUrl = uploadLinkResponse['link'];

        final fileId = await _uploadFileToCloud(uploadUrl, _profileImage!);
        if (fileId == null) throw Exception("Не вдалося отримати fileId після завантаження.");

        final publicLink = await _getPublicLink(fileId);
        if (publicLink == null) throw Exception("Не вдалося отримати публічне посилання.");

        await _saveProfile(newPhotoUrl: publicLink);

      } catch (e) {
        _showErrorSnackBar("Помилка завантаження фото: ${e.toString()}");
        if (mounted) setState(() { _isLoading = false; });
      }
    } else {
      await _saveProfile();
    }
  }

  Future<Map<String, dynamic>> _getUploadLink() async {
    final uri = Uri.parse("$_backendBaseUrl/api/cloud-storage/get-upload-link?purpose=profile-photo");
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer ${widget.authToken}',
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Не вдалося отримати посилання для завантаження. Статус: ${response.statusCode}');
    }
  }

  Future<String?> _uploadFileToCloud(String uploadUrl, File imageFile) async {
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
    final mimeType = lookupMimeType(imageFile.path);

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: fileName,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['metadata']['fileid'].toString();
    } else {
      throw Exception('Помилка завантаження файлу на хмару. Статус: ${response.statusCode}');
    }
  }

  Future<String?> _getPublicLink(String fileId) async {
    final uri = Uri.parse("$_backendBaseUrl/api/cloud-storage/get-public-link?fileid=$fileId");
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer ${widget.authToken}',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['link'];
    } else {
      throw Exception('Не вдалося отримати публічне посилання. Статус: ${response.statusCode}');
    }
  }

  Future<void> _resolveAndSetDisplayableUrl(String publicUrl) async {
    try {
      final finalUrl = await _getDisplayableUrl(publicUrl);
      if (mounted) {
        setState(() {
          _displayablePhotoUrl = finalUrl;
        });
      }
    } catch (e) {
      _showErrorSnackBar("Не вдалося завантажити фото профілю.");
      print("Помилка отримання фото для відображення: $e");
    }
  }

  Future<String> _getDisplayableUrl(String publicUrl) async {
    final uri = Uri.parse(publicUrl);
    final code = uri.queryParameters['code'];
    if (code == null) throw Exception("Не знайдено 'code' в URL");

    final pCloudUrl = Uri.parse("https://eapi.pcloud.com/getpublinkdownload?code=$code");
    final response = await http.get(pCloudUrl);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final hosts = data['hosts'] as List;
      final filePath = data['path'] as String;
      if (hosts.isNotEmpty && filePath.isNotEmpty) {
        return "https://${hosts.first}$filePath";
      }
    }
    throw Exception("Помилка отримання прямого посилання з pCloud API. Статус: ${response.statusCode}");
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
      if (message != null) errorMessage = message;
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
                        : (_displayablePhotoUrl != null
                        ? NetworkImage(_displayablePhotoUrl!)
                        : null) as ImageProvider?,
                    child: _profileImage == null && _displayablePhotoUrl == null
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
                onPressed: _isLoading ? null : _handleSave,
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

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:kurs/screens/HomeScreen.dart';
import 'auth.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:kurs/utils/fade_page_route.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.authToken,
    required this.username,
    required this.stompClient,
  });
  final String authToken;
  final String username;
  final StompClient stompClient;

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
  final String _backendBaseUrl = "http://localhost:8080";
  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }
  Future<void> _fetchProfileData() async {
    final url = Uri.parse("$_backendBaseUrl/api/profile");
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.authToken}',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
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
  Future<void> _deleteAccount() async {
    setState(() { _isLoading = true; });
    final url = Uri.parse("$_backendBaseUrl/api/user");
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSuccessSnackBar("Акаунт успішно видалено.");
        if(mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            FadePageRoute(child: const LoginScreen()),
                (route) => false,
          );
        }
      } else {
        _handleErrorResponse(response.body, response.statusCode);
      }
    } catch (e) {
      _showErrorSnackBar("Помилка під час видалення: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      FadePageRoute(child: const LoginScreen()),
          (route) => false,
    );
  }
  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Підтвердження видалення'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Ви впевнені, що хочете видалити свій акаунт?'),
                Text('Цю дію неможливо буде скасувати.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Скасувати'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Видалити'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
            ),
          ],
        );
      },
    );
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
      print("Помилка отримання фото для відображення: $e");
      _showErrorSnackBar("Не вдалося завантажити фото профілю.");
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
      if (data.containsKey('hosts') && data['hosts'] is List && (data['hosts'] as List).isNotEmpty && data.containsKey('path')) {
        final hosts = data['hosts'] as List;
        final filePath = data['path'] as String;
        return "https://${hosts.first}$filePath";
      }
    }
    throw Exception("Помилка отримання прямого посилання з pCloud API.");
  }
  Future<void> _handleSave() async {
    if(!_formKey.currentState!.validate()) return;
    if (_profileImage != null) {
      setState(() { _isLoading = true; });
      try {
        final uploadLinkResponse = await _getUploadLink();
        final uploadUrl = uploadLinkResponse['link'];
        if (uploadUrl == null || uploadUrl is! String) {
          throw Exception("Сервер не повернув посилання для завантаження.");
        }
        final fileId = await _uploadFileToCloud(uploadUrl, _profileImage!);
        if (fileId == null) throw Exception("Не вдалося отримати fileId після завантаження.");
        final publicLink = await _getPublicLink(fileId);
        if (publicLink == null) throw Exception("Не вдалося отримати публічне посилання.");
        await _saveProfile(newPhotoUrl: publicLink);

      } catch (e, stackTrace) {
        print("Повна помилка: ${e.toString()}");
        print("Stack trace: $stackTrace");
        _showErrorSnackBar("Помилка завантаження фото: ${e.toString()}");
        if (mounted) setState(() { _isLoading = false; });
      }
    } else {
      await _saveProfile();
    }
  }
  Future<Map<String, dynamic>> _getUploadLink() async {
    final uri = Uri.parse(
        "$_backendBaseUrl/api/cloud-storage/get-upload-link?purpose=profile-photo");
    final response = await http.get(
        uri, headers: {'Authorization': 'Bearer ${widget.authToken}'});
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Не вдалося отримати посилання для завантаження.');
  }
  Future<String?> _uploadFileToCloud(String uploadUrl, File imageFile) async {
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.containsKey('metadata') && data['metadata'] is List) {
        final metadataList = data['metadata'] as List;
        if (metadataList.isNotEmpty) {
          final firstItem = metadataList[0];
          if (firstItem is Map && firstItem.containsKey('fileid')) {
            return firstItem['fileid'].toString();
          }
        }
      }
      return null;
    } else {
      print("Помилка завантаження на хмару, статус: ${response.statusCode}");
      throw Exception('Помилка завантаження файлу на хмару.');
    }
  }
  Future<String?> _getPublicLink(String fileId) async {
    final uri = Uri.parse(
        "$_backendBaseUrl/api/cloud-storage/get-public-link?fileid=$fileId");
    final response = await http.get(
        uri, headers: {'Authorization': 'Bearer ${widget.authToken}'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['link'];
    }
    throw Exception('Не вдалося отримати публічне посилання.');
  }
  Future<void> _saveProfile({String? newPhotoUrl}) async {
    setState(() { _isLoading = true; });
    final url = Uri.parse("$_backendBaseUrl/api/profile");
    final method = _profileExists ? 'PUT' : 'POST';
    try {
      final Map<String, dynamic> bodyMap = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'biography': _biographyController.text,
      };

      if (method == 'PUT') {
        bodyMap['photoUrl'] = newPhotoUrl ?? _currentPublicPhotoUrl;
      } else if (newPhotoUrl != null) {
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
    } finally {
      if (mounted) setState(() { _isLoading = false; });
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
      final errorData = jsonDecode(utf8.decode(body.codeUnits));
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              FadePageRoute(
                child: HomeScreen(
                  authToken: widget.authToken,
                  username: widget.username,
                  stompClient: widget.stompClient,
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            tooltip: 'Статистика',
            onPressed: () {
              print("Перехід на сторінку статистики");
              _showSuccessSnackBar("Ця функція буде доступна згодом");
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Видалити акаунт',
            onPressed: _showDeleteConfirmationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Вийти з акаунту',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _firstNameController,
                              decoration: buildInputDecoration("Ім'я"),
                              style: const TextStyle(color: Colors.white),
                              validator: (value) => (value == null || value.isEmpty) ? "Введіть ім'я" : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: buildInputDecoration("Прізвище"),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 26),
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: scheme.primary,
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : (_displayablePhotoUrl != null
                                ? NetworkImage(_displayablePhotoUrl!)
                                : null) as ImageProvider?,
                            child: _profileImage == null &&
                                _displayablePhotoUrl == null
                                ? const Icon(Icons.person,
                                size: 50, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: scheme.secondary,
                                child: Icon(Icons.edit,
                                    color: scheme.primary, size: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      TextFormField(
                        controller: _biographyController,
                        decoration: buildInputDecoration("Біографія"),
                        style: TextStyle(color: scheme.onPrimary),
                        maxLines: 5,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                          onTap: _isLoading ? null : _handleSave,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: scheme.secondary,
                            child: Icon(Icons.check, color: scheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration buildInputDecoration(String label) {
    return InputDecoration(
      filled: true,
      fillColor: Theme.of(context).colorScheme.primary,
      hintText: label,
      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.85)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }
}
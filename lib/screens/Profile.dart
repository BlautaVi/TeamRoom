import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:kurs/screens/HomeScreen.dart';
import 'auth.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:kurs/utils/fade_page_route.dart';
import 'package:kurs/screens/CoursesScreen.dart';
import 'package:kurs/classes/course_models.dart';

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
  final String _backendBaseUrl = "https://team-room-jitsi.duckdns.org";
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

  Future<void> _showStatisticsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _StatisticsDialogContent(
            authToken: widget.authToken,
            username: widget.username,
          ),
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
            onPressed: _showStatisticsDialog,
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

class _StatisticsDialogContent extends StatefulWidget {
  final String authToken;
  final String username;

  const _StatisticsDialogContent({
    required this.authToken,
    required this.username,
  });

  @override
  State<_StatisticsDialogContent> createState() => _StatisticsDialogContentState();
}

class _StatisticsDialogContentState extends State<_StatisticsDialogContent> {
  bool _isLoading = true;
  String? _errorMessage;
  
  List<Course> _courses = [];
  Map<int, List<Assignment>> _assignmentsByCourse = {};
  Map<int, List<AssignmentResponse>> _responsesByCourse = {};

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final courseService = CourseService();
      
      final coursesResponse = await http.get(
        Uri.parse('https://team-room-back.onrender.com/api/course'),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );

      if (coursesResponse.statusCode != 200) {
        throw Exception('Не вдалося завантажити курси');
      }

      final coursesData = jsonDecode(utf8.decode(coursesResponse.bodyBytes));
      List<Course> courses;
      
      if (coursesData is List) {
        courses = coursesData.map((c) => Course.fromJson(c)).toList();
      } else if (coursesData is Map && coursesData['courses'] is List) {
        courses = (coursesData['courses'] as List)
            .map((c) => Course.fromJson(c))
            .toList();
      } else {
        courses = [];
      }

      final List<Course> studentCourses = [];
      
      for (var course in courses) {
        try {
          // Отримуємо роль користувача в курсі
          final members = await courseService.getCourseMembers(
            widget.authToken,
            course.id,
          );
          
          final myMembership = members.firstWhere(
            (m) => m.username == widget.username,
            orElse: () => CourseMember(
              username: widget.username,
              role: CourseRole.VIEWER,
            ),
          );
          
          // Фільтруємо - показуємо тільки курси де користувач STUDENT або LEADER
          if (myMembership.role != CourseRole.STUDENT && 
              myMembership.role != CourseRole.LEADER) {
            debugPrint('Skipping course ${course.name} - role: ${myMembership.role}');
            continue;
          }
          
          studentCourses.add(course);
          
          final assignments = await courseService.getAssignments(
            widget.authToken,
            course.id,
          );
          _assignmentsByCourse[course.id] = assignments;

          final responses = await courseService.getAllMyAssignmentResponses(
            widget.authToken,
            course.id,
          );
          _responsesByCourse[course.id] = responses;
          
          // Логування для перевірки даних
          debugPrint('Course: ${course.name}, Role: ${myMembership.role}, '
              'Assignments: ${assignments.length}, Responses: ${responses.length}');
          for (var response in responses) {
            debugPrint('Response: id=${response.id}, assignmentId=${response.assignmentId}, '
                'isGraded=${response.isGraded}, grade=${response.grade}, '
                'isReturned=${response.isReturned}');
          }
        } catch (e) {
          debugPrint('Error loading course ${course.id}: $e');
          _assignmentsByCourse[course.id] = [];
          _responsesByCourse[course.id] = [];
        }
      }
      
      courses = studentCourses;

      if (mounted) {
        setState(() {
          _courses = courses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Помилка завантаження статистики: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 600,
        maxHeight: 700,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Моя статистика',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _courses.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Ви ще не зареєстровані\nв жодному курсі',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildStatisticsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsList() {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(20),
      children: [
        _buildOverallStats(),
        const SizedBox(height: 20),
        const Text(
          'Статистика по курсах:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._courses.map((course) => _buildCourseCard(course)),
      ],
    );
  }

  Widget _buildOverallStats() {
    int totalAssignments = 0;
    int totalResponses = 0;
    double totalGrade = 0;
    int gradedCount = 0;

    for (var course in _courses) {
      final assignments = _assignmentsByCourse[course.id] ?? [];
      final responses = _responsesByCourse[course.id] ?? [];
      
      totalAssignments += assignments.length;
      totalResponses += responses.length;
      
      for (var response in responses) {
        if (response.isGraded && response.grade != null) {
          gradedCount++;
          totalGrade += response.grade!;
        }
      }
    }

    final avgGrade = gradedCount > 0 
        ? (totalGrade / gradedCount).toStringAsFixed(1) 
        : '-';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Загальна статистика',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (gradedCount == 0 && totalResponses > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Tooltip(
                      message: 'Роботи ще не оцінені викладачем',
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.class_outlined,
                  'Курсів',
                  _courses.length.toString(),
                  Colors.blue,
                ),
                _buildStatItem(
                  Icons.assignment_outlined,
                  'Завдань',
                  totalAssignments.toString(),
                  Colors.orange,
                ),
                _buildStatItem(
                  Icons.check_circle_outline,
                  'Здано',
                  totalResponses.toString(),
                  Colors.green,
                ),
                _buildStatItem(
                  Icons.star_outline,
                  gradedCount > 0 ? 'Середній бал' : 'Не оцінено',
                  avgGrade,
                  gradedCount > 0 ? Colors.purple : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCard(Course course) {
    final assignments = _assignmentsByCourse[course.id] ?? [];
    final responses = _responsesByCourse[course.id] ?? [];
    
    int gradedCount = 0;
    double totalGrade = 0;
    
    for (var response in responses) {
      if (response.isGraded && response.grade != null) {
        gradedCount++;
        totalGrade += response.grade!;
      }
    }

    final avgGrade = gradedCount > 0 
        ? (totalGrade / gradedCount).toStringAsFixed(1) 
        : '-';
    
    final completionRate = assignments.isNotEmpty
        ? ((responses.length / assignments.length) * 100).toStringAsFixed(0)
        : '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    course.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${responses.length} / ${assignments.length} завдань здано',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: assignments.isNotEmpty ? responses.length / assignments.length : 0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up, size: 18, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Виконано: $completionRate%',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.grade, size: 18, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      'Середній бал: $avgGrade',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'pcloud_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/src/platform_file.dart';
import 'assignment_screens.dart';
import 'package:intl/date_symbol_data_local.dart';

enum CourseRole { OWNER, PROFESSOR, LEADER, STUDENT, VIEWER }

class Course {
  final int id;
  final String name;
  final String? photoUrl;
  final bool isOpen;
  final int memberCount;

  Course({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.isOpen,
    required this.memberCount,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) {
      print("Error: Course JSON missing 'id': $json");
      throw FormatException("Field 'id' is missing in Course JSON.");
    }
    int count = json['memberCount'] ?? 0;
    return Course(
      id: json['id'],
      name: json['name'] ?? 'Без назви',
      photoUrl: json['photoUrl'],
      isOpen: json['open'] ?? true,
      memberCount: count,
    );
  }
}

class CourseMember {
  final String username;
  final CourseRole role;

  CourseMember({required this.username, required this.role});

  factory CourseMember.fromJson(Map<String, dynamic> json) {
    String roleString = (json['role'] as String?)?.toUpperCase() ?? 'VIEWER';

    CourseRole role = CourseRole.values.firstWhere(
      (e) => e.name.toUpperCase() == roleString,
      orElse: () {
        print(
          "Warning: Unknown role '$roleString' received for user '${json['username']}'. Defaulting to VIEWER.",
        );
        return CourseRole.VIEWER;
      },
    );
    return CourseMember(username: json['username'] ?? 'unknown', role: role);
  }
}

class Tag {
  final String name;

  Tag({required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) =>
      Tag(name: json['name'] ?? '');
}

class MediaFile {
  final int id;
  final String displayName;
  final String fileUrl;

  MediaFile({
    required this.id,
    required this.displayName,
    required this.fileUrl,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) {
      print("Warning: MediaFile JSON missing 'id': $json");
    }
    return MediaFile(
      id: json['id'] ?? 0,
      displayName:
          json['name'] ?? json['fileUrl']?.split('/').last ?? 'unnamed_file',
      fileUrl: json['fileUrl'] ?? '',
    );
  }
}

class CourseMaterial {
  final int id;
  final String topic;
  final String textContent;
  final String authorUsername;
  final List<Tag> tags;
  final List<MediaFile> media;

  CourseMaterial({
    required this.id,
    required this.topic,
    required this.textContent,
    required this.authorUsername,
    this.tags = const [],
    this.media = const [],
  });

  factory CourseMaterial.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) {
      print("Warning: CourseMaterial JSON missing 'id': $json");
    }
    return CourseMaterial(
      id: json['id'] ?? 0,
      topic: json['topic'] ?? 'Без теми',
      textContent: json['textContent'] ?? '',
      authorUsername: json['authorUsername'] ?? 'unknown',
      tags: (json['tags'] as List? ?? [])
          .map((tagJson) => Tag.fromJson(tagJson))
          .toList(),
      media: (json['media'] as List? ?? [])
          .map((fileJson) => MediaFile.fromJson(fileJson))
          .toList(),
    );
  }
}

class Assignment {
  final int id;
  final String title;
  final String description;
  final String authorUsername;
  final DateTime? deadline;
  final int? maxGrade;
  final List<Tag> tags;
  final List<MediaFile> media;

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.authorUsername,
    this.deadline,
    this.maxGrade,
    this.tags = const [],
    this.media = const [],
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        print("Warning: Could not parse date '$dateStr'");
        return null;
      }
    }

    if (json['id'] == null) {
      print("Warning: Assignment JSON missing 'id': $json");
    }
    return Assignment(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Без теми',
      description: json['description'] ?? '',
      authorUsername: json['authorUsername'] ?? 'unknown',
      deadline: parseDate(json['deadline']),
      maxGrade: json['maxGrade'],
      tags: (json['tags'] as List? ?? [])
          .map((tagJson) => Tag.fromJson(tagJson))
          .toList(),
      media: (json['media'] as List? ?? [])
          .map((fileJson) => MediaFile.fromJson(fileJson))
          .toList(),
    );
  }
}

class CourseService {
  final String _apiBaseUrl = "https://team-room-back.onrender.com/api";

  Exception _handleErrorResponse(http.Response response, String context) {
    String errorMessage = 'Невідома помилка';
    try {
      final error = jsonDecode(response.body);
      if (error is Map && error.containsKey('message')) {
        errorMessage = error['message'];
      } else {
        errorMessage = response.body;
      }
    } catch (_) {
      errorMessage = response.body.isEmpty
          ? 'Порожня відповідь'
          : response.body;
    }
    print(
      "Error in $context: Status ${response.statusCode}, Message: $errorMessage",
    );
    return Exception(
      '$context: $errorMessage (Статус: ${response.statusCode})',
    );
  }

  Future<String?> getDirectImageUrl(String publicUrl) async {
    try {
      final uri = Uri.parse(publicUrl);
      final code = uri.queryParameters['code'];
      if (code == null) {
        print("Warning: Could not find 'code' in image URL: $publicUrl");
        return null;
      }

      String apiHost = (uri.host == 'e.pcloud.link')
          ? 'eapi.pcloud.com'
          : 'api.pcloud.com';
      final apiUrl = Uri.https(apiHost, '/getpublinkdownload', {'code': code});
      final apiResponse = await http.get(apiUrl);

      if (apiResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(apiResponse.body);
        if (jsonResponse['result'] == 0) {
          final path = jsonResponse['path'] as String?;
          final hosts = (jsonResponse['hosts'] as List?) ?? [];
          if (hosts.isNotEmpty && path != null) {
            return 'https://${hosts.first}$path';
          }
        } else {
          print(
            "pCloud API error for image code $code: ${jsonResponse['error']}",
          );
        }
      } else {
        print(
          "Error fetching direct image link from pCloud API: ${apiResponse.statusCode}",
        );
      }
    } catch (e) {
      print("Error processing image URL $publicUrl: $e");
    }
    return null;
  }

  Future<List<Course>> getCourses(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/course'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map &&
            decoded.containsKey('courses') &&
            decoded['courses'] is List) {
          print("Fetched ${decoded['courses'].length} courses.");
          return (decoded['courses'] as List)
              .map((c) => Course.fromJson(c))
              .toList();
        } else {
          print("Error: Invalid course list format: $decoded");
          throw Exception(
            'Неправильний формат відповіді від API: відсутнє поле "courses" або воно не є списком.',
          );
        }
      } else {
        throw _handleErrorResponse(response, 'Не вдалося завантажити курси');
      }
    } catch (e) {
      print("Error fetching courses: $e");
      rethrow;
    }
  }

  Future<void> createCourse(
    String token,
    String name, {
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'photoUrl': photoUrl}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _handleErrorResponse(response, 'Не вдалося створити курс');
    }
  }

  Future<void> updateCourse(
    String token,
    int courseId,
    String name, {
    String? photoUrl,
    bool? isOpen,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (photoUrl != null) {
      body['photoUrl'] = photoUrl;
    }
    if (isOpen != null) {
      body['open'] = isOpen;
    }

    final response = await http.put(
      Uri.parse('$_apiBaseUrl/course/$courseId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(response, 'Не вдалося оновити курс');
    }
  }

  Future<void> deleteCourse(String token, int courseId) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/course/$courseId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося видалити курс');
    }
  }

  Future<void> joinCourse(String token, int courseId) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course/$courseId/members'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(response, 'Не вдалося приєднатися до курсу');
    }
  }

  Future<List<CourseMember>> getCourseMembers(
    String token,
    int courseId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/course/$courseId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map &&
            decoded.containsKey('members') &&
            decoded['members'] is List) {
          print(
            "Fetched ${decoded['members'].length} members for course $courseId.",
          );
          return (decoded['members'] as List)
              .map((m) => CourseMember.fromJson(m))
              .toList();
        } else if (decoded is List) {
          print(
            "Fetched ${decoded.length} members for course $courseId (direct list).",
          );
          return decoded.map((m) => CourseMember.fromJson(m)).toList();
        } else {
          print(
            "Error: Invalid members list format for course $courseId: $decoded",
          );
          throw Exception(
            'Неправильний формат відповіді від API: відсутнє поле "members" або воно не є списком.',
          );
        }
      } else {
        throw _handleErrorResponse(
          response,
          'Не вдалося завантажити учасників',
        );
      }
    } catch (e) {
      print("Error fetching members for course $courseId: $e");
      rethrow;
    }
  }

  Future<void> addMember(
    String token,
    int courseId,
    String username,
    CourseRole role,
  ) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course/$courseId/members'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'username': username, 'role': role.name.toUpperCase()}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _handleErrorResponse(response, 'Не вдалося додати учасника');
    }
  }

  Future<void> updateMemberRole(
    String token,
    int courseId,
    String username,
    CourseRole newRole,
  ) async {
    final response = await http.put(
      Uri.parse('$_apiBaseUrl/course/$courseId/members'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'role': newRole.name.toUpperCase(),
      }),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(response, 'Не вдалося змінити роль');
    }
  }

  Future<void> deleteMember(String token, int courseId, String username) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/course/$courseId/members/$username'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося видалити учасника');
    }
  }

  Future<List<CourseMaterial>> getCourseMaterials(
    String token,
    int courseId,
  ) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/course/$courseId/materials'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map &&
          decoded.containsKey('materials') &&
          decoded['materials'] is List) {
        print(
          "Fetched ${decoded['materials'].length} materials for course $courseId.",
        );
        return (decoded['materials'] as List)
            .map((m) => CourseMaterial.fromJson(m))
            .toList();
      } else if (decoded is List) {
        print(
          "Fetched ${decoded.length} materials for course $courseId (direct list).",
        );
        return decoded.map((m) => CourseMaterial.fromJson(m)).toList();
      } else {
        print(
          "Error: Invalid materials list format for course $courseId: $decoded",
        );
        throw Exception(
          'Неправильний формат відповіді від API: відсутнє поле "materials" або воно не є списком.',
        );
      }
    } else {
      throw _handleErrorResponse(response, 'Не вдалося завантажити матеріали');
    }
  }

  Future<CourseMaterial> getMaterialDetails(
    String token,
    int courseId,
    int materialId,
  ) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/course/$courseId/materials/$materialId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print('--- Raw Material Details Response ---');
    print(response.body);
    if (response.statusCode == 200) {
      try {
        return CourseMaterial.fromJson(jsonDecode(response.body));
      } catch (e) {
        print("Error parsing material details JSON: $e");
        throw Exception('Помилка обробки даних матеріалу.');
      }
    } else {
      throw _handleErrorResponse(
        response,
        'Не вдалося завантажити деталі матеріалу',
      );
    }
  }

  Future<int> createMaterial(
    String token,
    int courseId,
    String topic,
    String textContent,
    List<String> tags,
  ) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course/$courseId/materials'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'topic': topic,
        'textContent': textContent,
        'tags': tags.map((name) => {'name': name}).toList(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('id') && body['id'] is int) {
        return body['id'];
      } else {
        print(
          "Error: Material creation response missing or invalid 'id': $body",
        );
        throw Exception('API не повернуло ID для створеного матеріалу.');
      }
    } else {
      throw _handleErrorResponse(response, 'Не вдалося створити матеріал');
    }
  }

  Future<void> patchMaterial(
    String token,
    int courseId,
    int materialId,
    String topic,
    String textContent,
    List<String> tags,
  ) async {
    final response = await http.patch(
      Uri.parse('$_apiBaseUrl/course/$courseId/materials/$materialId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'topic': topic,
        'textContent': textContent,
        'tags': tags.map((name) => {'name': name}).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(
        response,
        'Не вдалося частково оновити матеріал',
      );
    }
  }

  Future<void> addMediaToMaterial(
    String token,
    int courseId,
    int materialId,
    String fileUrl,
    String fileName,
  ) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course/$courseId/materials/$materialId/media'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': fileName, 'fileUrl': fileUrl}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _handleErrorResponse(response, 'Не вдалося додати медіафайл');
    }
  }

  Future<void> deleteMaterialFile(
    String token,
    int courseId,
    int materialId,
    int mediaId,
  ) async {
    final response = await http.delete(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/materials/$materialId/media/$mediaId',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося видалити файл');
    }
  }

  Future<void> deleteMaterial(
    String token,
    int courseId,
    int materialId,
  ) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/course/$courseId/materials/$materialId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося видалити матеріал');
    }
  }

  Future<List<Assignment>> getAssignments(String token, int courseId) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/course/$courseId/assignments'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map &&
          decoded.containsKey('assignments') &&
          decoded['assignments'] is List) {
        print(
          "Fetched ${decoded['assignments'].length} assignments for course $courseId.",
        );
        return (decoded['assignments'] as List)
            .map((m) => Assignment.fromJson(m))
            .toList();
      } else if (decoded is List) {
        print(
          "Fetched ${decoded.length} assignments for course $courseId (direct list).",
        );
        return decoded.map((m) => Assignment.fromJson(m)).toList();
      } else {
        print(
          "Error: Invalid assignments list format for course $courseId: $decoded",
        );
        throw Exception(
          'Неправильний формат відповіді від API: відсутнє поле "assignments" або воно не є списком.',
        );
      }
    } else {
      throw _handleErrorResponse(response, 'Не вдалося завантажити завдання');
    }
  }

  Future<Assignment> getAssignmentDetails(
    String token,
    int courseId,
    int assignmentId,
  ) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/course/$courseId/assignments/$assignmentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      try {
        return Assignment.fromJson(jsonDecode(response.body));
      } catch (e) {
        print("Error parsing assignment details JSON: $e");
        throw Exception('Помилка обробки даних завдання.');
      }
    } else {
      throw _handleErrorResponse(
        response,
        'Не вдалося завантажити деталі завдання',
      );
    }
  }

  Future<int> createAssignment(
      String token,
      int courseId,
      String title,
      String description,
      List<String> tags,
      DateTime? deadline,
      int? maxGrade,
      ) async {
    final body = {
      'title': title,
      'description': description,
      'tags': tags,
      'deadline': deadline?.toIso8601String(),
      'maxGrade': maxGrade,
    };

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course/$courseId/assignments'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('id') && body['id'] is int) {
        return body['id'];
      } else {
        print(
          "Error: Assignment creation response missing or invalid 'id': $body",
        );
        throw Exception('API не повернуло ID для створеного завдання.');
      }
    } else {
      throw _handleErrorResponse(response, 'Не вдалося створити завдання');
    }
  }

  Future<void> patchAssignment(
      String token,
      int courseId,
      int assignmentId,
      String title,
      String description,
      List<String> tags,
      DateTime? deadline,
      int? maxGrade,
      ) async {
    final patchBody = {
      'title': title,
      'description': description,
      'tags': tags,
      'deadline': deadline?.toIso8601String(),
      'maxGrade': maxGrade,
    };
    final response = await http.patch(
      Uri.parse('$_apiBaseUrl/course/$courseId/assignments/$assignmentId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(patchBody),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(
        response,
        'Не вдалося частково оновити завдання',
      );
    }
  }

  Future<void> addMediaToAssignment(
    String token,
    int courseId,
    int assignmentId,
    String fileUrl,
    String fileName,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/media',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': fileName, 'fileUrl': fileUrl}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _handleErrorResponse(
        response,
        'Не вдалося додати медіафайл до завдання',
      );
    }
  }

  Future<void> deleteAssignmentFile(
    String token,
    int courseId,
    int assignmentId,
    int mediaId,
  ) async {
    final response = await http.delete(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/media/$mediaId',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося видалити файл завдання');
    }
  }

  Future<void> deleteAssignment(
    String token,
    int courseId,
    int assignmentId,
  ) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/course/$courseId/assignments/$assignmentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося видалити завдання');
    }
  }
}

class CoursesScreen extends StatefulWidget {
  final String authToken;

  const CoursesScreen({super.key, required this.authToken});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final CourseService _courseService = CourseService();
  late Future<List<Course>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() {
    if (mounted) {
      setState(() {
        _coursesFuture = _courseService.getCourses(widget.authToken).catchError(
          (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Помилка завантаження курсів: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }

            throw e;
          },
        );
      });
    }
  }

  Future<String?> getDirectImageUrl(String publicUrl) async {
    try {
      final uri = Uri.parse(publicUrl);
      final code = uri.queryParameters['code'];
      if (code == null) {
        print("Warning: Could not find 'code' in image URL: $publicUrl");
        return null;
      }

      String apiHost = (uri.host == 'e.pcloud.link')
          ? 'eapi.pcloud.com'
          : 'api.pcloud.com';
      final apiUrl = Uri.https(apiHost, '/getpublinkdownload', {'code': code});
      final apiResponse = await http.get(apiUrl);

      if (apiResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(apiResponse.body);
        if (jsonResponse['result'] == 0) {
          final path = jsonResponse['path'] as String?;
          final hosts = (jsonResponse['hosts'] as List?) ?? [];
          if (hosts.isNotEmpty && path != null) {
            return 'https://${hosts.first}$path';
          }
        } else {
          print(
            "pCloud API error for image code $code: ${jsonResponse['error']}",
          );
        }
      } else {
        print(
          "Error fetching direct image link from pCloud API: ${apiResponse.statusCode}",
        );
      }
    } catch (e) {
      print("Error processing image URL $publicUrl: $e");
    }
    return null;
  }

  Future<void> _showJoinCourseDialog() async {
    final courseIdController = TextEditingController();

    final currentContext = context;

    await showDialog(
      context: currentContext,
      builder: (dialogContext) {
        bool isJoining = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Приєднатись до курсу'),
              content: TextField(
                controller: courseIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ID або код курсу',
                ),
                enabled: !isJoining,
              ),
              actions: [
                TextButton(
                  onPressed: isJoining
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: isJoining
                      ? null
                      : () async {
                          final idText = courseIdController.text.trim();
                          final id = int.tryParse(idText);
                          if (id != null) {
                            setDialogState(() => isJoining = true);
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              currentContext,
                            );
                            try {
                              await _courseService.joinCourse(
                                widget.authToken,
                                id,
                              );
                              if (mounted) {
                                Navigator.pop(dialogContext);
                                _loadCourses();
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Ви успішно приєднались!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Помилка приєднання: ${e.toString().replaceFirst("Exception: ", "")}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setDialogState(() => isJoining = false);
                              }
                            }
                          } else {
                            if (mounted)
                              ScaffoldMessenger.of(currentContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Введіть коректний ID курсу.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                          }
                        },
                  child: isJoining
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Приєднатись'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C6BA3);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.group_add_outlined),
                  onPressed: _showJoinCourseDialog,
                  label: const Text('Приєднатись'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreateCourseScreen(authToken: widget.authToken),
                      ),
                    );
                    if (result == true) {
                      _loadCourses();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<Course>>(
                future: _coursesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(
                      child: Text(
                        'Помилка завантаження: ${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                      ),
                    );
                  if (!snapshot.hasData || snapshot.data!.isEmpty)
                    return const Center(
                      child: Text('Ви не є учасником жодного курсу.'),
                    );

                  final courses = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: () async => _loadCourses(),
                    child: GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            childAspectRatio: 3 / 2.3,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        return _CourseCard(
                          course: courses[index],
                          authToken: widget.authToken,
                          onCourseAction: _loadCourses,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatefulWidget {
  // Змінено на StatefulWidget
  final Course course;
  final String authToken;
  final VoidCallback onCourseAction;

  const _CourseCard({
    required this.course,
    required this.authToken,
    required this.onCourseAction,
    super.key,
  });

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  String? _directPhotoUrl;
  bool _isLoadingPhoto = false;
  int? _actualMemberCount;
  bool _isLoadingCount = false;

  @override
  void initState() {
    super.initState();
    _resolvePhotoUrl();
    _fetchMemberCount();
  }

  Future<void> _resolvePhotoUrl() async {
    if (widget.course.photoUrl != null && widget.course.photoUrl!.isNotEmpty) {
      if (!mounted) return;
      setState(() => _isLoadingPhoto = true);
      try {
        final directUrl = await CourseService().getDirectImageUrl(
          widget.course.photoUrl!,
        );
        if (mounted) {
          setState(() {
            _directPhotoUrl = directUrl;
            _isLoadingPhoto = false;
          });
        }
      } catch (e) {
        print("Error resolving photo URL for course ${widget.course.id}: $e");
        if (mounted) {
          setState(() => _isLoadingPhoto = false);
        }
      }
    }
  }

  Future<void> _fetchMemberCount() async {
    if (widget.course.memberCount > 0) {
      if (mounted)
        setState(() => _actualMemberCount = widget.course.memberCount);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoadingCount = true);
    try {
      final members = await CourseService().getCourseMembers(
        widget.authToken,
        widget.course.id,
      );
      if (mounted) {
        setState(() {
          _actualMemberCount = members.length;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      print("Error fetching member count for course ${widget.course.id}: $e");
      if (mounted) {
        setState(() {
          _isLoadingCount = false;
          _actualMemberCount = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color cardColor = Color(0xFF8B80B1);
    const Color textColor = Colors.white;

    return InkWell(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailScreen(
              course: widget.course,
              authToken: widget.authToken,
            ),
          ),
        );

        if (result == true && context.mounted) {
          print("Course action detected, reloading courses...");
          widget.onCourseAction();
          _fetchMemberCount();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.course.name,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white.withOpacity(0.8),
                  backgroundImage:
                      _directPhotoUrl != null && _directPhotoUrl!.isNotEmpty
                      ? NetworkImage(_directPhotoUrl!)
                      : null,
                  onBackgroundImageError:
                      _directPhotoUrl != null && _directPhotoUrl!.isNotEmpty
                      ? (_, __) {
                          print(
                            "Error loading direct image in Card: $_directPhotoUrl",
                          );
                          if (mounted) {
                            // Скидаємо URL при помилці, щоб показалась іконка
                            // Перевіряємо ще раз, чи URL справді той самий, що викликав помилку
                            if (_directPhotoUrl == _directPhotoUrl) {
                              setState(() {
                                _directPhotoUrl = null;
                                _isLoadingPhoto = false;
                              });
                            }
                          }
                        }
                      : null,
                  child: _isLoadingPhoto
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cardColor,
                          ),
                        )
                      : (_directPhotoUrl == null || _directPhotoUrl!.isEmpty
                            ? Icon(
                                Icons.school_outlined,
                                color: cardColor.withOpacity(0.9),
                                size: 30,
                              )
                            : null),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: textColor.withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 4),
                _isLoadingCount
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white70,
                        ),
                      )
                    : Text(
                        '${_actualMemberCount ?? 0} учасників',
                        style: const TextStyle(color: textColor, fontSize: 12),
                      ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  widget.course.isOpen
                      ? Icons.lock_open_outlined
                      : Icons.lock_outline,
                  color: textColor.withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.course.isOpen ? 'Відкритий' : 'Закритий',
                  style: const TextStyle(color: textColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  final String authToken;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.authToken,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CourseRole _currentUserRole = CourseRole.VIEWER;
  bool _isLoadingRole = true;
  late String _courseName;
  String? _coursePhotoUrl;
  late bool _courseIsOpen;
  File? _newCourseImageFile;
  final ImagePicker _picker = ImagePicker();
  final String _currentUsername = "test_user";

  @override
  void initState() {
    super.initState();
    _courseName = widget.course.name;
    _coursePhotoUrl = widget.course.photoUrl;
    _courseIsOpen = widget.course.isOpen;
    initializeDateFormatting('uk_UA', null);
    _tabController = TabController(length: 6, vsync: this);
    _determineCurrentUserRole();
  }

  Future<void> _determineCurrentUserRole() async {
    if (!mounted) return;
    setState(() => _isLoadingRole = true);
    try {
      final members = await CourseService().getCourseMembers(
        widget.authToken,
        widget.course.id,
      );

      final currentUserMember = members.firstWhere(
        (m) => m.username == _currentUsername,

        orElse: () =>
            CourseMember(username: _currentUsername, role: CourseRole.VIEWER),
      );
      if (mounted) {
        setState(() {
          _currentUserRole = currentUserMember.role;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      print("Error determining user role: $e");
      if (mounted) {
        setState(() => _isLoadingRole = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Помилка визначення ролі: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editCourse() async {
    final newNameController = TextEditingController(text: _courseName);
    String? currentEditPhotoUrl = _coursePhotoUrl;
    File? newSelectedImageFile;

    final updatedData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Редагувати курс'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: newSelectedImageFile != null
                              ? FileImage(newSelectedImageFile!)
                              : (currentEditPhotoUrl != null &&
                                            currentEditPhotoUrl!.isNotEmpty
                                        ? NetworkImage(currentEditPhotoUrl!)
                                        : null)
                                    as ImageProvider?,
                          child:
                              newSelectedImageFile == null &&
                                  (currentEditPhotoUrl == null ||
                                      currentEditPhotoUrl!.isEmpty)
                              ? Icon(
                                  Icons.school_outlined,
                                  size: 50,
                                  color: Colors.grey.shade600,
                                )
                              : null,
                        ),
                        IconButton(
                          icon: CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColorLight.withOpacity(0.9),
                            child: Icon(
                              Icons.edit,
                              color: Theme.of(context).primaryColorDark,
                              size: 18,
                            ),
                          ),
                          tooltip: 'Змінити фото курсу',
                          onPressed: isSaving
                              ? null
                              : () async {
                                  try {
                                    final XFile? pickedFile = await _picker
                                        .pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 85,
                                          maxWidth: 1024,
                                          maxHeight: 1024,
                                        );
                                    if (pickedFile != null) {
                                      setDialogState(() {
                                        newSelectedImageFile = File(
                                          pickedFile.path,
                                        );
                                        currentEditPhotoUrl = null;
                                      });
                                    }
                                  } catch (e) {
                                    if (mounted)
                                      ScaffoldMessenger.of(
                                        dialogContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Помилка вибору: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                  }
                                },
                        ),
                        if (newSelectedImageFile != null ||
                            (currentEditPhotoUrl != null &&
                                currentEditPhotoUrl!.isNotEmpty))
                          Positioned(
                            top: -5,
                            right: -5,
                            child: IconButton(
                              icon: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.red.withOpacity(0.8),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                              tooltip: 'Видалити фото',
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        newSelectedImageFile = null;
                                        currentEditPhotoUrl = null;
                                      });
                                    },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: newNameController,
                      decoration: InputDecoration(labelText: 'Назва курсу'),
                      maxLength: 100,
                      enabled: !isSaving,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          if (newNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Назва курсу не може бути порожньою.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(dialogContext, {
                            'name': newNameController.text.trim(),
                            'newImageFile': newSelectedImageFile,
                            'removeCurrentImage':
                                currentEditPhotoUrl == null &&
                                widget.course.photoUrl != null,
                          });
                        },
                  child: isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Зберегти'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updatedData != null && mounted) {
      final newName = updatedData['name'] as String?;
      final File? newlyPickedImageFile = updatedData['newImageFile'] as File?;
      final bool removeCurrentImage =
          updatedData['removeCurrentImage'] as bool? ?? false;

      if (newName != null && newName.isNotEmpty) {
        bool nameChanged = newName != _courseName;
        bool imageChanged = newlyPickedImageFile != null || removeCurrentImage;
        bool hasChanges = nameChanged || imageChanged;

        if (!hasChanges) {
          print("No changes detected in course edit.");
          return;
        }

        final scaffoldMessenger = ScaffoldMessenger.of(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(child: CircularProgressIndicator()),
        );

        String? finalPhotoUrl = _coursePhotoUrl;

        try {
          if (newlyPickedImageFile != null) {
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Завантаження нового фото...'),
                duration: Duration(minutes: 1),
              ),
            );

            final pCloudService = PCloudService();
            final platformFile = PlatformFile(
              name: newlyPickedImageFile.path.split('/').last,
              path: newlyPickedImageFile.path,
              size: await newlyPickedImageFile.length(),
            );
            finalPhotoUrl = await pCloudService.uploadFileAndGetPublicLink(
              file: platformFile,
              authToken: widget.authToken,
              purpose: 'course-photo',
            );
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Нове фото завантажено!'),
                duration: Duration(seconds: 2),
              ),
            );
          } else if (removeCurrentImage) {
            finalPhotoUrl = null;
          }

          await CourseService().updateCourse(
            widget.authToken,
            widget.course.id,
            newName,
            photoUrl: finalPhotoUrl,
          );

          Navigator.pop(context);
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('Курс оновлено!')),
            );
            setState(() {
              _courseName = newName;
              _coursePhotoUrl = finalPhotoUrl;
            });
          }
        } catch (e) {
          Navigator.pop(context);
          if (mounted)
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Помилка оновлення: ${e.toString().replaceFirst("Exception: ", "")}',
                ),
                backgroundColor: Colors.red,
              ),
            );
        }
      }
    }
  }

  Future<void> _deleteCourse() async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Підтвердити видалення курсу'),
            content: Text(
              'Ви ВПЕВНЕНІ, що хочете видалити курс "$_courseName"?\n\n'
              'ВСІ матеріали та дані учасників курсу будуть втрачені НАЗАВЖДИ!',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Скасувати'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'ВИДАЛИТИ',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(child: CircularProgressIndicator()),
      );
      try {
        await CourseService().deleteCourse(widget.authToken, widget.course.id);
        Navigator.pop(context);
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Курс "$_courseName" видалено.')),
          );

          Navigator.pop(context, true);
        }
      } catch (e) {
        Navigator.pop(context);
        if (mounted)
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Помилка видалення: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C6BA3);
    return Scaffold(
      appBar: AppBar(
        title: Text(_courseName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoadingRole && _currentUserRole == CourseRole.OWNER)
            IconButton(
              icon: Icon(Icons.edit_outlined),
              tooltip: 'Редагувати курс',
              onPressed: _editCourse,
            ),
          if (!_isLoadingRole && _currentUserRole == CourseRole.OWNER)
            IconButton(
              icon: Icon(Icons.delete_forever_outlined),
              tooltip: 'Видалити курс',
              onPressed: _deleteCourse,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,

          tabs: const [
            Tab(icon: Icon(Icons.dynamic_feed_outlined), text: 'Стрічка'),
            Tab(icon: Icon(Icons.assignment_outlined), text: 'Завдання'),
            Tab(icon: Icon(Icons.folder_copy_outlined), text: 'Матеріали'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'Учасники'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Чати'),
            Tab(icon: Icon(Icons.video_call_outlined), text: 'Конференції'),
          ],
        ),
      ),
      body: _isLoadingRole
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                const Center(child: Text("Вкладка 'Стрічка' в розробці.")),
                AssignmentsTabView(
                  authToken: widget.authToken,
                  courseId: widget.course.id,
                  currentUserRole: _currentUserRole,
                ),
                MaterialsTabView(
                  authToken: widget.authToken,
                  courseId: widget.course.id,
                  currentUserRole: _currentUserRole,
                ),
                MembersTabView(
                  authToken: widget.authToken,
                  courseId: widget.course.id,
                  currentUserRole: _currentUserRole,
                ),
                const Center(child: Text("Вкладка 'Чати' в розробці.")),
                const Center(child: Text("Вкладка 'Конференції' в розробці.")),
              ],
            ),
    );
  }
}

class MembersTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;

  const MembersTabView({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.currentUserRole,
  });

  @override
  State<MembersTabView> createState() => _MembersTabViewState();
}

class _MembersTabViewState extends State<MembersTabView> {
  final CourseService _courseService = CourseService();
  late Future<List<CourseMember>> _membersFuture;

  final String _currentUsername = "test_user";

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() {
    if (mounted) {
      setState(() {
        _membersFuture = _courseService
            .getCourseMembers(widget.authToken, widget.courseId)
            .catchError((e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Помилка завантаження учасників: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }

              throw e;
            });
      });
    }
  }

  Future<void> _showAddMemberDialog() async {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    CourseRole selectedRole = CourseRole.STUDENT;
    final currentContext = context;

    await showDialog(
      context: currentContext,
      builder: (dialogContext) {
        bool isAdding = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Додати учасника'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      enabled: !isAdding,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Введіть username'
                          : null,
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<CourseRole>(
                      value: selectedRole,
                      items: CourseRole.values
                          .where((role) => role != CourseRole.OWNER)
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role.name),
                            ),
                          )
                          .toList(),
                      onChanged: isAdding
                          ? null
                          : (value) {
                              if (value != null) selectedRole = value;
                            },
                      decoration: InputDecoration(labelText: 'Роль'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isAdding
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            final username = usernameController.text.trim();
                            setDialogState(() => isAdding = true);
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              currentContext,
                            );
                            try {
                              await _courseService.addMember(
                                widget.authToken,
                                widget.courseId,
                                username,
                                selectedRole,
                              );
                              if (mounted) {
                                Navigator.pop(dialogContext);
                                _loadMembers();
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Учасника додано!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted)
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Помилка додавання: ${e.toString().replaceFirst("Exception: ", "")}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                            } finally {
                              if (mounted) {
                                setDialogState(() => isAdding = false);
                              }
                            }
                          }
                        },
                  child: isAdding
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Додати'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeMemberRole(CourseMember member) async {
    CourseRole selectedRole = member.role;
    final currentContext = context;

    final newRole = await showDialog<CourseRole>(
      context: currentContext,
      builder: (dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Змінити роль для ${member.username}'),
              content: DropdownButtonFormField<CourseRole>(
                value: selectedRole,
                items: CourseRole.values
                    .where((role) => role != CourseRole.OWNER)
                    .map(
                      (role) =>
                          DropdownMenuItem(value: role, child: Text(role.name)),
                    )
                    .toList(),
                onChanged: isSaving
                    ? null
                    : (value) {
                        if (value != null) {
                          setDialogState(() => selectedRole = value);
                        }
                      },
                decoration: InputDecoration(labelText: 'Нова роль'),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: (selectedRole == member.role || isSaving)
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            currentContext,
                          );
                          try {
                            await _courseService.updateMemberRole(
                              widget.authToken,
                              widget.courseId,
                              member.username,
                              selectedRole,
                            );
                            if (mounted) {
                              Navigator.pop(dialogContext, selectedRole);
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Роль для ${member.username} оновлено!',
                                  ),
                                ),
                              );
                              _loadMembers();
                            }
                          } catch (e) {
                            if (mounted)
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Помилка зміни ролі: ${e.toString().replaceFirst("Exception: ", "")}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );

                            if (mounted) setDialogState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Зберегти'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMember(CourseMember member) async {
    final currentContext = context;
    final confirm =
        await showDialog<bool>(
          context: currentContext,
          builder: (context) => AlertDialog(
            title: Text('Видалити учасника'),
            content: Text(
              'Ви впевнені, що хочете видалити ${member.username} з курсу?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Скасувати'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Видалити', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(currentContext);

      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (_) => Center(child: CircularProgressIndicator()),
      );
      try {
        await _courseService.deleteMember(
          widget.authToken,
          widget.courseId,
          member.username,
        );
        Navigator.pop(currentContext);
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Учасника ${member.username} видалено.')),
          );
          _loadMembers();
        }
      } catch (e) {
        Navigator.pop(currentContext);
        if (mounted)
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Помилка видалення: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canManageMembers = widget.currentUserRole == CourseRole.OWNER;

    final bool canAddMembers =
        widget.currentUserRole == CourseRole.OWNER ||
        widget.currentUserRole == CourseRole.PROFESSOR ||
        widget.currentUserRole == CourseRole.LEADER;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadMembers(),
        child: FutureBuilder<List<CourseMember>>(
          future: _membersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());

            if (snapshot.hasError)
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Помилка завантаження учасників:\n${snapshot.error.toString().replaceFirst("Exception: ", "")}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              );
            final members = snapshot.data ?? [];
            if (members.isEmpty)
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Учасників ще немає.'),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text('Оновити'),
                      onPressed: _loadMembers,
                    ),
                  ],
                ),
              );

            members.sort((a, b) {
              if (a.role == CourseRole.OWNER) return -1;
              if (b.role == CourseRole.OWNER) return 1;

              int roleComparison = a.role.index.compareTo(b.role.index);
              if (roleComparison != 0) return roleComparison;
              return a.username.toLowerCase().compareTo(
                b.username.toLowerCase(),
              );
            });

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];

                final bool canManageThisMember =
                    canManageMembers &&
                    member.username != _currentUsername &&
                    member.role != CourseRole.OWNER;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors
                        .accents[index % Colors.accents.length]
                        .withOpacity(0.2),
                    child: Text(
                      member.username.isNotEmpty
                          ? member.username[0].toUpperCase()
                          : '?',
                    ),
                    foregroundColor:
                        Colors.accents[index % Colors.accents.length].shade700,
                  ),
                  title: Text(member.username),
                  subtitle: Text(
                    member.role.name,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  trailing: canManageThisMember
                      ? PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.grey.shade700,
                          ),
                          tooltip: 'Опції для ${member.username}',
                          onSelected: (value) {
                            if (value == 'change_role') {
                              _changeMemberRole(member);
                            } else if (value == 'delete') {
                              _deleteMember(member);
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'change_role',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.manage_accounts_outlined,
                                    ),
                                    title: Text('Змінити роль'),
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.person_remove_outlined,
                                      color: Colors.red,
                                    ),
                                    title: Text(
                                      'Видалити',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ),
                              ],
                        )
                      : null,
                );
              },
            );
          },
        ),
      ),

      floatingActionButton: canAddMembers
          ? FloatingActionButton(
              onPressed: _showAddMemberDialog,
              tooltip: 'Додати учасника',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class MaterialsTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;

  const MaterialsTabView({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.currentUserRole,
  });

  @override
  State<MaterialsTabView> createState() => _MaterialsTabViewState();
}

class _MaterialsTabViewState extends State<MaterialsTabView> {
  final CourseService _courseService = CourseService();
  late Future<List<CourseMaterial>> _materialsFuture;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  void _loadMaterials() {
    if (mounted) {
      setState(() {
        _materialsFuture = _courseService
            .getCourseMaterials(widget.authToken, widget.courseId)
            .catchError((e) {
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Помилка завантаження матеріалів: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              throw e;
            });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage =
        widget.currentUserRole == CourseRole.OWNER ||
        widget.currentUserRole == CourseRole.PROFESSOR;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadMaterials(),
        child: FutureBuilder<List<CourseMaterial>>(
          future: _materialsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Center(
                child: Text(
                  "Помилка: ${snapshot.error.toString().replaceFirst("Exception: ", "")}",
                  style: TextStyle(color: Colors.red),
                ),
              );
            final materials = snapshot.data ?? [];
            if (materials.isEmpty)
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Матеріалів ще немає.'),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text('Оновити'),
                      onPressed: _loadMaterials,
                    ),
                  ],
                ),
              );

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final material = materials[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      Icons.article_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      material.topic,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      material.textContent.isNotEmpty
                          ? material.textContent
                          : 'Без опису',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: material.textContent.isNotEmpty
                            ? null
                            : Colors.grey,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                    ),
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MaterialDetailScreen(
                            authToken: widget.authToken,
                            courseId: widget.courseId,
                            materialId: material.id,
                            canManage: canManage,
                          ),
                        ),
                      );
                      if (result == true && mounted) _loadMaterials();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateMaterialScreen(
                      authToken: widget.authToken,
                      courseId: widget.courseId,
                    ),
                  ),
                );
                if (result == true && mounted) _loadMaterials();
              },
              tooltip: 'Додати матеріал',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class MaterialDetailScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final int materialId;
  final bool canManage;

  const MaterialDetailScreen({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.materialId,
    required this.canManage,
  });

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  late Future<CourseMaterial> _materialFuture;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadMaterialDetails();
  }

  void _loadMaterialDetails() {
    if (mounted) {
      setState(() {
        _materialFuture = CourseService()
            .getMaterialDetails(
              widget.authToken,
              widget.courseId,
              widget.materialId,
            )
            .catchError((e) {
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Помилка завантаження деталей: $e'),
                    backgroundColor: Colors.red,
                  ),
                );

              throw e;
            });
      });
    }
  }

  Future<void> _downloadAndOpenFile(String publicUrl, String fileName) async {
    if (_isDownloading || !mounted) return;
    setState(() => _isDownloading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Обробка файлу: $fileName...'),
        duration: Duration(minutes: 5),
      ),
    );
    try {
      String directDownloadUrl;
      final uri = Uri.parse(publicUrl);
      final code = uri.queryParameters['code'];
      if (code == null)
        throw Exception("Не вдалося знайти 'code' у посиланні '$publicUrl'.");
      String apiHost = (uri.host == 'e.pcloud.link')
          ? 'eapi.pcloud.com'
          : 'api.pcloud.com';
      final apiUrl = Uri.https(apiHost, '/getpublinkdownload', {'code': code});
      final apiResponse = await http.get(apiUrl);
      if (!mounted) return;
      if (apiResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(apiResponse.body);
        if (jsonResponse['result'] != 0)
          throw Exception("API pCloud помилка: ${jsonResponse['error']}");
        final path = jsonResponse['path'] as String?;
        final hosts = (jsonResponse['hosts'] as List?) ?? [];
        if (hosts.isEmpty || path == null)
          throw Exception("API pCloud не повернуло дані для завантаження.");
        directDownloadUrl = 'https://${hosts.first}$path';
      } else {
        throw Exception(
          "API pCloud помилка. Статус: ${apiResponse.statusCode}",
        );
      }
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Завантаження: $fileName...'),
          duration: Duration(minutes: 5),
        ),
      );
      final response = await http.get(Uri.parse(directDownloadUrl));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/${fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        if (!mounted) return;
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Відкриття файлу...')),
        );
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done)
          throw Exception('Не вдалося відкрити: ${result.message}');
      } else {
        throw Exception(
          'Помилка завантаження файлу. Статус: ${response.statusCode}',
        );
      }
    } catch (e) {
      print("File download/open error: $e");
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Помилка: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);

        Future.delayed(Duration(seconds: 2), () {
          if (mounted) scaffoldMessenger.hideCurrentSnackBar();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Деталі матеріалу'),
        actions: [
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редагувати матеріал',
              onPressed: () async {
                try {
                  final materialToEdit = await _materialFuture;
                  if (!mounted) return;
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditMaterialScreen(
                        authToken: widget.authToken,
                        courseId: widget.courseId,
                        material: materialToEdit,
                      ),
                    ),
                  );
                  if (result == true) _loadMaterialDetails();
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Не вдалося завантажити дані для редагування: $e',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                }
              },
            ),
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Видалити матеріал',
              onPressed: () async {
                final confirm =
                    await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Підтвердити видалення'),
                        content: const Text(
                          'Ви впевнені, що хочете видалити цей матеріал?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Скасувати'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Видалити',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (confirm && mounted) {
                  final currentContext = context;
                  showDialog(
                    context: currentContext,
                    barrierDismissible: false,
                    builder: (_) => Center(child: CircularProgressIndicator()),
                  );
                  try {
                    await CourseService().deleteMaterial(
                      widget.authToken,
                      widget.courseId,
                      widget.materialId,
                    );
                    if (mounted) {
                      Navigator.pop(currentContext);
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(content: Text('Матеріал видалено.')),
                      );
                      Navigator.pop(currentContext, true);
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(currentContext);
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Помилка видалення: ${e.toString().replaceFirst("Exception: ", "")}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<CourseMaterial>(
        future: _materialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Text(
                'Помилка завантаження матеріалу: ${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                style: TextStyle(color: Colors.red),
              ),
            );

          final material = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadMaterialDetails(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SelectableText(
                  material.topic,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Автор: ${material.authorUsername}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const Divider(height: 32),
                SelectableText(
                  material.textContent.isNotEmpty
                      ? material.textContent
                      : 'Опис відсутній.',
                  style: TextStyle(
                    color: material.textContent.isNotEmpty ? null : Colors.grey,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                if (material.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: material.tags
                          .map(
                            (t) => Chip(
                              label: Text(t.name),
                              backgroundColor: Colors.blueGrey.shade50,
                              labelStyle: TextStyle(
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (material.media.isNotEmpty) ...[
                  Text(
                    'Прикріплені файли:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  Column(
                    children: material.media
                        .map(
                          (file) => Card(
                            elevation: 1,
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                Icons.attach_file,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(
                                file.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: _isDownloading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.download_for_offline_outlined,
                                      color: Colors.grey.shade600,
                                    ),
                              onTap: _isDownloading
                                  ? null
                                  : () => _downloadAndOpenFile(
                                      file.fileUrl,
                                      file.displayName,
                                    ),
                              dense: true,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else ...[
                  const Text(
                    'Прикріплені файли відсутні.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class CreateMaterialScreen extends StatefulWidget {
  final String authToken;
  final int courseId;

  const CreateMaterialScreen({
    super.key,
    required this.authToken,
    required this.courseId,
  });

  @override
  State<CreateMaterialScreen> createState() => _CreateMaterialScreenState();
}

class _CreateMaterialScreenState extends State<CreateMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final List<PlatformFile> _pickedFiles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _topicController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_isLoading) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && mounted) {
        setState(() => _pickedFiles.addAll(result.files));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка вибору файлів: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _submitForm() async {
    if (_isLoading || !mounted) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      FocusScope.of(context).unfocus();
      try {
        final topic = _topicController.text.trim();
        final content = _contentController.text.trim();
        final tags = _tagsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Створення матеріалу...'),
            duration: Duration(minutes: 1),
          ),
        );
        final materialId = await CourseService().createMaterial(
          widget.authToken,
          widget.courseId,
          topic,
          content,
          tags,
        );

        if (_pickedFiles.isNotEmpty) {
          final pCloudService = PCloudService();
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Завантаження файлів (0/${_pickedFiles.length})...',
              ),
              duration: Duration(minutes: 5),
            ),
          );
          for (int i = 0; i < _pickedFiles.length; i++) {
            if (!mounted) break;
            final file = _pickedFiles[i];
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Файл ${i + 1}/${_pickedFiles.length}: ${file.name}...',
                ),
                duration: Duration(minutes: 5),
              ),
            );
            final fileUrl = await pCloudService.uploadFileAndGetPublicLink(
              file: file,
              authToken: widget.authToken,
              purpose: 'material-file',
            );
            await CourseService().addMediaToMaterial(
              widget.authToken,
              widget.courseId,
              materialId,
              fileUrl,
              file.name,
            );
          }
        }
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Матеріал створено!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Помилка: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новий матеріал')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Тема *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Введіть тему' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Зміст (необов\'язково)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              minLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Теги (через кому, необов\'язково)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Додати файли'),
              onPressed: _isLoading ? null : _pickFiles,
            ),
            const SizedBox(height: 8),
            if (_pickedFiles.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pickedFiles.length,
                itemBuilder: (context, index) {
                  final file = _pickedFiles[index];
                  String fileSize;
                  if (file.size > 1024 * 1024)
                    fileSize =
                        '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB';
                  else if (file.size > 1024)
                    fileSize = '${(file.size / 1024).toStringAsFixed(2)} KB';
                  else
                    fileSize = '${file.size} B';
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.insert_drive_file_outlined),
                      title: Text(file.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(fileSize),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Видалити файл',
                        onPressed: _isLoading
                            ? null
                            : () =>
                                  setState(() => _pickedFiles.removeAt(index)),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Зберегти матеріал'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditMaterialScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseMaterial material;

  const EditMaterialScreen({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.material,
  });

  @override
  State<EditMaterialScreen> createState() => _EditMaterialScreenState();
}

class _EditMaterialScreenState extends State<EditMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _topicController;
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  late List<MediaFile> _existingFiles;
  final List<PlatformFile> _newFiles = [];
  final List<MediaFile> _filesToDelete = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.material.topic);
    _contentController = TextEditingController(
      text: widget.material.textContent,
    );
    _tagsController = TextEditingController(
      text: widget.material.tags.map((t) => t.name).join(', '),
    );
    _existingFiles = List.from(widget.material.media);
  }

  @override
  void dispose() {
    _topicController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_isLoading) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && mounted) {
        setState(() => _newFiles.addAll(result.files));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка вибору файлів: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_isLoading || !mounted) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      FocusScope.of(context).unfocus();
      try {
        final topic = _topicController.text.trim();
        final content = _contentController.text.trim();
        final tags = _tagsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Оновлення тексту та тегів...'),
            duration: Duration(minutes: 1),
          ),
        );

        await CourseService().patchMaterial(
          widget.authToken,
          widget.courseId,
          widget.material.id,
          topic,
          content,
          tags,
        );
        if (_filesToDelete.isNotEmpty) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Видалення файлів (0/${_filesToDelete.length})...'),
              duration: Duration(minutes: 5),
            ),
          );
          for (int i = 0; i < _filesToDelete.length; i++) {
            if (!mounted) break;
            final fileToDelete = _filesToDelete[i];
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Видалення ${i + 1}/${_filesToDelete.length}: ${fileToDelete.displayName}...',
                ),
                duration: Duration(minutes: 5),
              ),
            );
            await CourseService().deleteMaterialFile(
              widget.authToken,
              widget.courseId,
              widget.material.id,
              fileToDelete.id,
            );
          }
        }

        if (_newFiles.isNotEmpty) {
          final pCloudService = PCloudService();
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Завантаження нових файлів (0/${_newFiles.length})...',
              ),
              duration: Duration(minutes: 5),
            ),
          );
          for (int i = 0; i < _newFiles.length; i++) {
            if (!mounted) break;
            final file = _newFiles[i];
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Завантаження ${i + 1}/${_newFiles.length}: ${file.name}...',
                ),
                duration: Duration(minutes: 5),
              ),
            );
            final fileUrl = await pCloudService.uploadFileAndGetPublicLink(
              file: file,
              authToken: widget.authToken,
              purpose: 'material-file',
            );
            await CourseService().addMediaToMaterial(
              widget.authToken,
              widget.courseId,
              widget.material.id,
              fileUrl,
              file.name,
            );
          }
        }

        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Матеріал оновлено!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Помилка: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редагувати матеріал')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Тема *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Введіть тему' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Зміст',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              minLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Теги (через кому)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Прикріплені файли',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_existingFiles.isEmpty &&
                _newFiles.isEmpty &&
                _filesToDelete.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Файлів немає.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            if (_existingFiles.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _existingFiles.length,
                itemBuilder: (context, index) {
                  final file = _existingFiles[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(file.displayName),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: 'Позначити для видалення',
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                _filesToDelete.add(file);
                                _existingFiles.removeAt(index);
                              }),
                      ),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: const Text('Додати нові файли'),
                onPressed: _isLoading ? null : _pickFiles,
              ),
            ),
            if (_newFiles.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _newFiles.length,
                itemBuilder: (context, index) {
                  final file = _newFiles[index];
                  String fileSize;
                  if (file.size > 1024 * 1024)
                    fileSize =
                        '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB';
                  else if (file.size > 1024)
                    fileSize = '${(file.size / 1024).toStringAsFixed(2)} KB';
                  else
                    fileSize = '${file.size} B';
                  return Card(
                    color: Colors.green.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.upload_file,
                        color: Colors.green,
                      ),
                      title: Text(file.name),
                      subtitle: Text(fileSize),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Скасувати додавання',
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _newFiles.removeAt(index)),
                      ),
                    ),
                  );
                },
              ),
            if (_filesToDelete.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Файли для видалення:',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filesToDelete.length,
                itemBuilder: (context, index) {
                  final file = _filesToDelete[index];
                  return Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.red,
                      ),
                      title: Text(
                        file.displayName,
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.undo, color: Colors.orange),
                        tooltip: 'Повернути',
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                _existingFiles.add(file);
                                _filesToDelete.removeAt(index);
                              }),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Зберегти зміни'),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateCourseScreen extends StatefulWidget {
  final String authToken;

  const CreateCourseScreen({super.key, required this.authToken});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final CourseService _courseService = CourseService();
  bool _isCreating = false;
  File? _courseImageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isCreating) return;
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _courseImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка вибору зображення: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_isCreating || !mounted) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isCreating = true);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      FocusScope.of(context).unfocus();

      String? finalPhotoUrl;

      try {
        if (_courseImageFile != null) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Завантаження фото курсу...'),
              duration: Duration(minutes: 1),
            ),
          );

          final pCloudService = PCloudService();
          final platformFile = PlatformFile(
            name: _courseImageFile!.path.split('/').last,
            path: _courseImageFile!.path,
            size: await _courseImageFile!.length(),
          );

          finalPhotoUrl = await pCloudService.uploadFileAndGetPublicLink(
            file: platformFile,
            authToken: widget.authToken,
            purpose: 'course-photo',
          );

          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Фото завантажено! Створення курсу...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        await _courseService.createCourse(
          widget.authToken,
          _nameController.text.trim(),
          photoUrl: finalPhotoUrl,
        );

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Курс успішно створено!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Помилка створення: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C6BA3);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Створення нового курсу'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _courseImageFile != null
                        ? FileImage(_courseImageFile!)
                        : null,
                    child: _courseImageFile == null
                        ? Icon(
                            Icons.school_outlined,
                            size: 60,
                            color: Colors.grey.shade600,
                          )
                        : null,
                  ),
                  IconButton(
                    icon: CircleAvatar(
                      radius: 20,
                      backgroundColor: primaryColor,
                      child: Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                    tooltip: 'Обрати фото курсу',
                    onPressed: _pickImage,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Назва курсу *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Будь ласка, введіть назву курсу';
                  if (value.length > 100)
                    return 'Назва не може перевищувати 100 символів';
                  return null;
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: _isCreating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isCreating ? 'Створення...' : 'Створити курс'),
                onPressed: _isCreating ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

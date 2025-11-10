import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'pcloud_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import 'assignment_screens.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../classes/course_models.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:io' show Platform;
import 'package:kurs/utils/animated_tap_wrapper.dart';
import 'ChatsMain.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'grades_tab.dart';

class CourseService {
  final String _apiBaseUrl = "http://localhost:8080/api";

  Exception _handleErrorResponse(http.Response response, String context) {
    String errorMessage = 'Невідома помилка';
    try {
      final error = jsonDecode(response.body);
      errorMessage = (error is Map && error.containsKey('message'))
          ? error['message']
          : response.body;
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
      if (code == null) return null;
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
        }
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
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map &&
            decoded.containsKey('courses') &&
            decoded['courses'] is List) {
          return (decoded['courses'] as List)
              .map((c) => Course.fromJson(c))
              .toList();
        } else {
          throw Exception('Неправильний формат відповіді.');
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
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'photoUrl': photoUrl,
        'description': description,
      }),
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
    String? description,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (photoUrl != null) body['photoUrl'] = photoUrl;
    if (isOpen != null) body['open'] = isOpen;
    if (description != null) body['description'] = description;
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
    if (response.statusCode != 200 && response.statusCode != 201) {
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
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map &&
            decoded.containsKey('members') &&
            decoded['members'] is List) {
          return (decoded['members'] as List)
              .map((m) => CourseMember.fromJson(m))
              .toList();
        } else {
          throw Exception('Неправильний формат відповіді для учасників.');
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
    final uri = Uri.parse(
      '$_apiBaseUrl/course/$courseId/members',
    ).replace(queryParameters: {'username': username});
    final response = await http.delete(
      uri,
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
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map &&
          decoded.containsKey('materials') &&
          decoded['materials'] is List) {
        return (decoded['materials'] as List)
            .map((m) => CourseMaterial.fromJson(m))
            .toList();
      } else if (decoded is List) {
        return decoded.map((m) => CourseMaterial.fromJson(m)).toList();
      } else {
        throw Exception('Неправильний формат відповіді.');
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
    if (response.statusCode == 200) {
      try {
        return CourseMaterial.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      } catch (e) {
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
        'tags': tags,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body.containsKey('id') && body['id'] is int) {
        return body['id'];
      } else {
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
    String? topic,
    String? textContent,
    List<String>? tags,
  ) async {
    final body = <String, dynamic>{};
    if (topic != null) body['topic'] = topic;
    if (textContent != null) body['textContent'] = textContent;
    if (tags != null) body['tags'] = tags;

    if (body.isEmpty) return;

    final response = await http.patch(
      Uri.parse('$_apiBaseUrl/course/$courseId/materials/$materialId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
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
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map &&
          decoded.containsKey('assignments') &&
          decoded['assignments'] is List) {
        return (decoded['assignments'] as List)
            .map((m) => Assignment.fromJson(m))
            .toList();
      } else if (decoded is List) {
        return decoded.map((m) => Assignment.fromJson(m)).toList();
      } else {
        throw Exception('Неправильний формат відповіді.');
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
        return Assignment.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } catch (e) {
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
    body.removeWhere((key, value) => value == null);

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course/$courseId/assignments'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final respBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (respBody is Map &&
          respBody.containsKey('id') &&
          respBody['id'] is int) {
        return respBody['id'];
      } else {
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
    String? title,
    String? description,
    List<String>? tags,
    DateTime? deadline,
    int? maxGrade,
  ) async {
    final patchBody = <String, dynamic>{};
    if (title != null) patchBody['title'] = title;
    if (description != null) patchBody['description'] = description;
    if (tags != null) patchBody['tags'] = tags;
    if (deadline != null) patchBody['deadline'] = deadline.toIso8601String();
    if (maxGrade != null) patchBody['maxGrade'] = maxGrade;

    if (patchBody.isEmpty) return;

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

  Future<int> submitAssignmentResponse(
    String token,
    int courseId,
    int assignmentId,
    List<Map<String, String>> mediaList,
  ) async {
    final uri = Uri.parse(
      '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/responses',
    );

    Future<AssignmentResponse?> findExistingWithRetries() async {
      AssignmentResponse? existing;
      int delayMs = 200;
      for (int attempt = 0; attempt < 8 && existing == null; attempt++) {
        if (attempt > 0) await Future.delayed(Duration(milliseconds: delayMs));
        delayMs = (delayMs * 2).clamp(200, 2000);
        try {
          existing = await getMyAssignmentResponse(
            token,
            courseId,
            assignmentId,
          );
        } catch (_) {
          existing = null;
        }
        if (existing == null) {
          try {
            final myAll = await getAllMyAssignmentResponses(token, courseId);
            existing = myAll.firstWhere(
              (r) => r.assignmentId == assignmentId,
              orElse: () => AssignmentResponse(
                id: 0,
                assignmentId: -1,
                authorUsername: '',
                isReturned: false,
                isGraded: false,
                media: const [],
              ),
            );
            if (existing.assignmentId == -1) existing = null;
          } catch (_) {
            existing = null;
          }
        }
      }
      return existing;
    }

    Future<int> create() async {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'media': mediaList}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map &&
              decoded.containsKey('id') &&
              decoded['id'] is num) {
            return (decoded['id'] as num).toInt();
          } else {
            print(
              "Warning: Assignment response created (status ${response.statusCode}) but no ID found in response body: ${response.body}",
            );
            return 0;
          }
        } catch (e) {
          throw Exception('Failed to parse response ID after submitting: $e');
        }
      } else {
        throw _handleErrorResponse(response, 'Не вдалося надіслати відповідь');
      }
    }

    try {
      final existingPre = await findExistingWithRetries();
      if (existingPre != null) {
        if (existingPre.isGraded == true) {
          throw Exception('Відповідь вже оцінена — перездача неможлива.');
        }
        await deleteAssignmentResponse(
          token,
          courseId,
          assignmentId,
          existingPre.id,
        );
      }
    } catch (_) {}

    try {
      return await create();
    } catch (e) {
      final message = e.toString();
      final looksLikeDuplicate =
          message.contains('already exists') ||
          message.contains('(Статус: 409)') ||
          message.contains('(Статус: 400)');

      if (!looksLikeDuplicate) rethrow;

      final existing = await findExistingWithRetries();
      if (existing == null) {
        rethrow;
      }
      if (existing.isGraded == true) {
        throw Exception('Відповідь вже оцінена — перездача неможлива.');
      }
      await deleteAssignmentResponse(
        token,
        courseId,
        assignmentId,
        existing.id,
      );
      return await create();
    }
  }

  Future<List<AssignmentResponse>> getAllMyAssignmentResponses(
    String token,
    int courseId,
  ) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/course/$courseId/assignments/my-responses'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded.map((r) => AssignmentResponse.fromJson(r)).toList();
      } else if (decoded is Map && decoded['responses'] is List) {
        return (decoded['responses'] as List)
            .map((r) => AssignmentResponse.fromJson(r))
            .toList();
      } else {
        throw Exception('Неправильний формат списку моїх відповідей.');
      }
    } else {
      throw _handleErrorResponse(
        response,
        'Не вдалося завантажити мої відповіді в курсі',
      );
    }
  }

  Future<List<AssignmentResponse>> getAssignmentResponses(
    String token,
    int courseId,
    int assignmentId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/responses',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded.map((r) => AssignmentResponse.fromJson(r)).toList();
      } else if (decoded is Map &&
          decoded.containsKey('responses') &&
          decoded['responses'] is List) {
        return (decoded['responses'] as List)
            .map((r) => AssignmentResponse.fromJson(r))
            .toList();
      } else {
        throw Exception('Неправильний формат списку відповідей від API.');
      }
    } else {
      throw _handleErrorResponse(
        response,
        'Не вдалося завантажити відповіді на завдання',
      );
    }
  }

  Future<AssignmentResponse> getAssignmentResponseDetails(
    String token,
    int courseId,
    int assignmentId,
    int responseId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/responses/$responseId',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      try {
        return AssignmentResponse.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      } catch (e) {
        throw Exception('Помилка обробки даних відповіді.');
      }
    } else {
      throw _handleErrorResponse(
        response,
        'Не вдалося завантажити деталі відповіді',
      );
    }
  }

  Future<AssignmentResponse?> getMyAssignmentResponse(
    String token,
    int courseId,
    int assignmentId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/responses/my',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      try {
        return AssignmentResponse.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );
      } catch (e) {
        throw Exception('Помилка обробки даних "моєї" відповіді.');
      }
    } else if (response.statusCode == 404) {
      print("getMyAssignmentResponse: No response found (404)");
      return null;
    } else {
      throw _handleErrorResponse(
        response,
        'Не вдалося завантажити "мою" відповідь на завдання',
      );
    }
  }

  Future<void> deleteAssignmentResponse(
    String token,
    int courseId,
    int assignmentId,
    int responseId,
  ) async {
    final response = await http.delete(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/responses/$responseId',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося видалити відповідь');
    }
  }

  Future<void> returnAssignmentResponse(
    String token,
    int courseId,
    int assignmentId,
    int responseId,
    String? comment,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/responses/$responseId/return',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'comment': comment ?? ''}),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(
        response,
        'Не вдалося повернути відповідь на доопрацювання',
      );
    }
  }

  Future<void> cancelReturnAssignmentResponse(
    String token,
    int courseId,
    int assignmentId,
    int responseId,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/responses/$responseId/return-cancel',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(
        response,
        'Не вдалося скасувати повернення відповіді',
      );
    }
  }

  Future<void> gradeAssignmentResponse(
    String token,
    int courseId,
    int assignmentId,
    int responseId,
    int grade,
    String? comment,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/responses/$responseId/grade',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'grade': grade, 'comment': comment ?? ''}),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(response, 'Не вдалося оцінити відповідь');
    }
  }

  Future<void> cancelGradeAssignmentResponse(
    String token,
    int courseId,
    int assignmentId,
    int responseId,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$_apiBaseUrl/course/$courseId/assignments/$assignmentId/responses/$responseId/grade-cancel',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(response, 'Не вдалося скасувати оцінку');
    }
  }
}

class CoursesScreen extends StatefulWidget {
  final String authToken;
  final String currentUsername;
  final StompClient stompClient;

  const CoursesScreen({
    super.key,
    required this.authToken,
    required this.currentUsername,
    required this.stompClient,
  });

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
            return <Course>[];
          },
        );
      });
    }
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
                            if (mounted) {
                              ScaffoldMessenger.of(currentContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Введіть коректний ID курсу.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        },
                  child: isJoining
                      ? const SizedBox(
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
                    side: const BorderSide(color: primaryColor),
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
                    if (result == true) _loadCourses();
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Помилка завантаження: ${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('Ви не є учасником жодного курсу.'),
                    );
                  }
                  final courses = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: () async => _loadCourses(),
                    child: GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            childAspectRatio: 3 / 2.5,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        return _CourseCard(
                          course: courses[index],
                          authToken: widget.authToken,
                          onCourseAction: _loadCourses,
                          currentUsername: widget.currentUsername,
                          stompClient: widget.stompClient,
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
  final Course course;
  final String authToken;
  final VoidCallback onCourseAction;
  final String currentUsername;
  final StompClient stompClient;

  const _CourseCard({
    required this.course,
    required this.authToken,
    required this.onCourseAction,
    required this.currentUsername,
    required this.stompClient,
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
        if (mounted) setState(() => _isLoadingPhoto = false);
      }
    }
  }

  Future<void> _fetchMemberCount() async {
    if (widget.course.memberCount > 0) {
      if (mounted) {
        setState(() => _actualMemberCount = widget.course.memberCount);
      }
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

    return AnimatedTapWrapper(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailScreen(
              course: widget.course,
              authToken: widget.authToken,
              currentUsername: widget.currentUsername,
              stompClient: widget.stompClient,
            ),
          ),
        );
        if (result == true && context.mounted) {
          widget.onCourseAction();
          _fetchMemberCount();
        }
      },
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
              offset: const Offset(0, 3),
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
                          if (mounted) {
                            setState(() {
                              _directPhotoUrl = null;
                              _isLoadingPhoto = false;
                            });
                          }
                        }
                      : null,
                  child: _isLoadingPhoto
                      ? const SizedBox(
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
                    ? const SizedBox(
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
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.tag_outlined,
                  color: textColor.withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'ID: ${widget.course.id}',
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
  final String currentUsername;
  final StompClient stompClient;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.authToken,
    required this.currentUsername,
    required this.stompClient,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CourseRole _currentUserRole = CourseRole.VIEWER;
  bool _isLoadingRole = true;
  bool _tabControllerInitialized = false;
  late String _courseName;
  String? _coursePhotoUrl;
  String? _courseDescription;
  final ImagePicker _picker = ImagePicker();
  String? _directPhotoUrl;

  @override
  void initState() {
    super.initState();
    _courseName = widget.course.name;
    _coursePhotoUrl = widget.course.photoUrl;
    _courseDescription = widget.course.description;
    initializeDateFormatting('uk_UA', null);
    _determineCurrentUserRole();
    _resolvePhotoUrl();
    _initializeTabController();
  }

  void _initializeTabController() {
    if (!_tabControllerInitialized) {
      _tabController = TabController(length: _getTabCount(), vsync: this);
      _tabControllerInitialized = true;
    }
  }

  int _getTabCount() {
    int count = 6; // Стрічка, Завдання, Матеріали, Учасники, Чати, Конференції
    if (_currentUserRole == CourseRole.PROFESSOR ||
        _currentUserRole == CourseRole.OWNER) {
      count++; // Додаємо вкладку Оцінки
    }
    return count;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _resolvePhotoUrl() async {
    if (_coursePhotoUrl != null && _coursePhotoUrl!.isNotEmpty) {
      final directUrl = await CourseService().getDirectImageUrl(
        _coursePhotoUrl!,
      );
      if (mounted) setState(() => _directPhotoUrl = directUrl);
    } else {
      if (mounted) setState(() => _directPhotoUrl = null);
    }
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
        (m) => m.username == widget.currentUsername,
        orElse: () => CourseMember(
          username: widget.currentUsername,
          role: CourseRole.VIEWER,
        ),
      );
      if (mounted) {
        setState(() {
          _currentUserRole = currentUserMember.role;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
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
    final newDescriptionController = TextEditingController(
      text: _courseDescription ?? '',
    );
    String? currentEditPhotoUrl = _directPhotoUrl;
    File? newSelectedImageFile;

    final updatedData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Редагувати курс'),
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
                                    as ImageProvider?
                              : (currentEditPhotoUrl != null &&
                                        currentEditPhotoUrl!.isNotEmpty
                                    ? NetworkImage(currentEditPhotoUrl!)
                                    : null),
                          onBackgroundImageError: (_, __) {
                            setDialogState(() => currentEditPhotoUrl = null);
                          },
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
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        dialogContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Помилка вибору: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
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
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                              tooltip: 'Видалити фото',
                              onPressed: isSaving
                                  ? null
                                  : () => setDialogState(() {
                                      newSelectedImageFile = null;
                                      currentEditPhotoUrl = null;
                                    }),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: newNameController,
                      decoration: const InputDecoration(
                        labelText: 'Назва курсу',
                      ),
                      maxLength: 100,
                      enabled: !isSaving,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Опис (необов\'язково)',
                      ),
                      maxLines: 3,
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
                  child: const Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          if (newNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
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
                            'description': newDescriptionController.text.trim(),
                            'newImageFile': newSelectedImageFile,
                            'removeCurrentImage':
                                newSelectedImageFile == null &&
                                currentEditPhotoUrl == null &&
                                _coursePhotoUrl != null,
                          });
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Зберегти'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updatedData != null && mounted) {
      final newName = updatedData['name'] as String?;
      final newDescription = updatedData['description'] as String?;
      final File? newlyPickedImageFile = updatedData['newImageFile'] as File?;
      final bool removeCurrentImage =
          updatedData['removeCurrentImage'] as bool? ?? false;

      if (newName != null && newName.isNotEmpty) {
        bool hasChanges =
            (newName != _courseName) ||
            (newDescription != (_courseDescription ?? '')) ||
            (newlyPickedImageFile != null) ||
            removeCurrentImage;

        if (!hasChanges) return;

        final scaffoldMessenger = ScaffoldMessenger.of(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
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
            description: newDescription,
          );

          Navigator.pop(context);
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Курс оновлено!')),
            );
            setState(() {
              _courseName = newName;
              _coursePhotoUrl = finalPhotoUrl;
              _courseDescription = newDescription;
              _resolvePhotoUrl();
            });
            Navigator.pop(context, true);
          }
        } catch (e) {
          Navigator.pop(context);
          if (mounted) {
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
  }

  Future<void> _deleteCourse() async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Підтвердити видалення курсу'),
            content: Text(
              'Ви ВПЕВНЕНІ, що хочете видалити курс "$_courseName"?\n\nВСІ матеріали та дані учасників курсу будуть втрачені НАЗАВЖДИ!',
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Скасувати'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
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
        builder: (_) => const Center(child: CircularProgressIndicator()),
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
        if (mounted) {
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
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редагувати курс',
              onPressed: _editCourse,
            ),
          if (!_isLoadingRole && _currentUserRole == CourseRole.OWNER)
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined),
              tooltip: 'Видалити курс',
              onPressed: _deleteCourse,
            ),
        ],
        bottom: _tabControllerInitialized
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  const Tab(icon: Icon(Icons.dynamic_feed_outlined), text: 'Стрічка'),
                  const Tab(icon: Icon(Icons.assignment_outlined), text: 'Завдання'),
                  const Tab(
                    icon: Icon(Icons.folder_copy_outlined),
                    text: 'Матеріали',
                  ),
                  const Tab(icon: Icon(Icons.groups_outlined), text: 'Учасники'),
                  if (_currentUserRole == CourseRole.PROFESSOR ||
                      _currentUserRole == CourseRole.OWNER)
                    const Tab(icon: Icon(Icons.grade_outlined), text: 'Оцінки'),
                  const Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Чати'),
                  const Tab(
                    icon: Icon(Icons.video_call_outlined),
                    text: 'Конференції',
                  ),
                ],
              )
            : null,
      ),
      body: _isLoadingRole
          ? const Center(child: CircularProgressIndicator())
          : _tabControllerInitialized
          ? TabBarView(
              controller: _tabController,
              children: [
                FeedTabView(
                  authToken: widget.authToken,
                  courseId: widget.course.id,
                  currentUserRole: _currentUserRole,
                  currentUsername: widget.currentUsername,
                ),
                AssignmentsTabView(
                  authToken: widget.authToken,
                  courseId: widget.course.id,
                  currentUserRole: _currentUserRole,
                  currentUsername: widget.currentUsername,
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
                  currentUsername: widget.currentUsername,
                ),
                if (_currentUserRole == CourseRole.PROFESSOR ||
                    _currentUserRole == CourseRole.OWNER)
                  GradesTabView(
                    authToken: widget.authToken,
                    courseId: widget.course.id,
                    currentUserRole: _currentUserRole,
                    currentUsername: widget.currentUsername,
                  ),
                CourseChatsTabView(
                  authToken: widget.authToken,
                  courseId: widget.course.id,
                  currentUsername: widget.currentUsername,
                  stompClient: widget.stompClient,
                ),
                VideoConferencingTabView(
                  authToken: widget.authToken,
                  courseId: widget.course.id,
                  courseName: _courseName,
                  currentUsername: widget.currentUsername,
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class CourseChatsTabView extends StatelessWidget {
  final String authToken;
  final int courseId;
  final String currentUsername;
  final StompClient stompClient;

  const CourseChatsTabView({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.currentUsername,
    required this.stompClient,
  });

  @override
  Widget build(BuildContext context) {
    return ChatsMain(
      authToken: authToken,
      currentUsername: currentUsername,
      stompClient: stompClient,
      filterByCourseId: courseId,
    );
  }
}

class MembersTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;
  final String currentUsername;

  const MembersTabView({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.currentUserRole,
    required this.currentUsername,
  });

  @override
  State<MembersTabView> createState() => _MembersTabViewState();
}

class _MembersTabViewState extends State<MembersTabView> {
  final CourseService _courseService = CourseService();
  late Future<List<CourseMember>> _membersFuture;

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
              return <CourseMember>[];
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
                    const SizedBox(height: 16),
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
                              if (value != null) {
                                selectedRole = value;
                              }
                            },
                      decoration: const InputDecoration(labelText: 'Роль'),
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
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Помилка додавання: ${e.toString().replaceFirst("Exception: ", "")}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setDialogState(() => isAdding = false);
                              }
                            }
                          }
                        },
                  child: isAdding
                      ? const SizedBox(
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

    await showDialog<void>(
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
                decoration: const InputDecoration(labelText: 'Нова роль'),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Скасувати'),
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
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Помилка зміни ролі: ${e.toString().replaceFirst("Exception: ", "")}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            if (mounted) setDialogState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Зберегти'),
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
            title: const Text('Видалити учасника'),
            content: Text(
              'Ви впевнені, що хочете видалити ${member.username} з курсу?',
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
      final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
      showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
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
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            final members = snapshot.data ?? [];
            if (members.isEmpty)
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Учасників ще немає.'),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Оновити'),
                      onPressed: _loadMembers,
                    ),
                  ],
                ),
              );
            members.sort((a, b) {
              if (a.role == CourseRole.OWNER) return -1;
              if (b.role == CourseRole.OWNER) return 1;
              int roleComparison = a.role.index.compareTo(b.role.index);
              return (roleComparison != 0)
                  ? roleComparison
                  : a.username.toLowerCase().compareTo(
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
                    member.username != widget.currentUsername &&
                    member.role != CourseRole.OWNER;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors
                        .accents[index % Colors.accents.length]
                        .withOpacity(0.2),
                    foregroundColor:
                        Colors.accents[index % Colors.accents.length].shade700,
                    child: Text(
                      member.username.isNotEmpty
                          ? member.username[0].toUpperCase()
                          : '?',
                    ),
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
                            if (value == 'change_role')
                              _changeMemberRole(member);
                            else if (value == 'delete')
                              _deleteMember(member);
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
    if (mounted)
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
              return <CourseMaterial>[];
            });
      });
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
                  style: const TextStyle(color: Colors.red),
                ),
              );
            final materials = snapshot.data ?? [];
            if (materials.isEmpty)
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Матеріалів ще немає.'),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Оновити'),
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
                          : 'Показати більше',
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
    if (mounted)
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

  Future<void> _downloadAndOpenFile(String publicUrl, String fileName) async {
    if (_isDownloading || !mounted) return;
    setState(() => _isDownloading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Обробка файлу: $fileName...'),
        duration: const Duration(minutes: 5),
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
          duration: const Duration(minutes: 5),
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
          const SnackBar(content: Text('Відкриття файлу...')),
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
        Future.delayed(const Duration(seconds: 2), () {
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
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
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
                        const SnackBar(content: Text('Матеріал видалено.')),
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
                style: const TextStyle(color: Colors.red),
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
                            margin: const EdgeInsets.symmetric(vertical: 4),
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
                                  ? const SizedBox(
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
      if (result != null && mounted)
        setState(() => _pickedFiles.addAll(result.files));
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
          const SnackBar(
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
              duration: const Duration(minutes: 5),
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
                duration: const Duration(minutes: 5),
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
            const SnackBar(content: Text('Матеріал створено!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted)
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Помилка: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: Colors.red,
            ),
          );
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
                  String fileSize = file.size > 1048576
                      ? '${(file.size / 1048576).toStringAsFixed(2)} MB'
                      : file.size > 1024
                      ? '${(file.size / 1024).toStringAsFixed(2)} KB'
                      : '${file.size} B';
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
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
                  ? const SizedBox(
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
      if (result != null && mounted)
        setState(() => _newFiles.addAll(result.files));
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
        bool textOrTagsChanged =
            topic != widget.material.topic ||
            content != widget.material.textContent ||
            !_listEquals(
              tags,
              widget.material.tags.map((t) => t.name).toList(),
            );

        scaffoldMessenger.hideCurrentSnackBar();

        if (textOrTagsChanged) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Оновлення тексту та тегів...'),
              duration: Duration(minutes: 1),
            ),
          );
          await CourseService().patchMaterial(
            widget.authToken,
            widget.courseId,
            widget.material.id,
            textOrTagsChanged ? topic : null,
            textOrTagsChanged ? content : null,
            textOrTagsChanged ? tags : null,
          );
        }

        if (_filesToDelete.isNotEmpty) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Видалення файлів (0/${_filesToDelete.length})...'),
              duration: const Duration(minutes: 5),
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
                duration: const Duration(minutes: 5),
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
              duration: const Duration(minutes: 5),
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
                duration: const Duration(minutes: 5),
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
            const SnackBar(content: Text('Матеріал оновлено!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted)
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Помилка: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: Colors.red,
            ),
          );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    a.sort();
    b.sort();
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
              const Padding(
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
                  String fileSize = file.size > 1048576
                      ? '${(file.size / 1048576).toStringAsFixed(2)} MB'
                      : file.size > 1024
                      ? '${(file.size / 1024).toStringAsFixed(2)} KB'
                      : '${file.size} B';
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
              const SizedBox(height: 16),
              const Text(
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
                        style: const TextStyle(
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
                  ? const SizedBox(
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
  final _descriptionController = TextEditingController();
  final CourseService _courseService = CourseService();
  bool _isCreating = false;
  File? _courseImageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
      if (pickedFile != null && mounted)
        setState(() => _courseImageFile = File(pickedFile.path));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка вибору зображення: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
          description: _descriptionController.text.trim(),
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
                    icon: const CircleAvatar(
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Опис (необов\'язково)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                minLines: 2,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: _isCreating
                    ? const SizedBox(
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
                  textStyle: const TextStyle(fontSize: 16),
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

class VideoConferencingTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final String courseName;
  final String currentUsername;

  const VideoConferencingTabView({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.courseName,
    required this.currentUsername,
  });

  @override
  State<VideoConferencingTabView> createState() =>
      _VideoConferencingTabViewState();
}

class _VideoConferencingTabViewState extends State<VideoConferencingTabView> {
  final _controller = WebviewController();
  final TextEditingController _roomController = TextEditingController();

  bool _isWebViewInitialized = false;
  bool _isLoading = false;
  String? _currentRoomUrl;

  @override
  void initState() {
    super.initState();
    _roomController.text = 'General';
    initPlatformState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _roomController.dispose();
    super.dispose();
  }

  String _generateRoomName(String input) {
    String safeInput = input
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
    if (safeInput.isEmpty) {
      safeInput = 'room';
    }
    return 'teamroom-course-${widget.courseId}-$safeInput';
  }

  Future<void> initPlatformState() async {
    if (!Platform.isWindows) {
      setState(() {});
      return;
    }

    try {
      await _controller.initialize();
      _controller.loadingState.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = (state == LoadingState.loading);
          });
        }
      });

      if (mounted) {
        setState(() {
          _isWebViewInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не вдалося ініціалізувати WebView: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinMeeting() async {
    if (!_isWebViewInitialized) return;
    if (_roomController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введіть назву кімнати'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final String roomName = _generateRoomName(_roomController.text.trim());

    final String newUrl =
        'https://nek1tarch.local:8443/$roomName'
        '#config.prejoinPageEnabled=false'
        '&config.startWithAudioMuted=false'
        '&config.startWithVideoMuted=false'
        '&userInfo.displayName=${Uri.encodeComponent(widget.currentUsername)}'
        '&config.toolbarButtons=["microphone","camera","closedcaptions","desktop","fullscreen","fodeviceselection","hangup","profile","chat","recording","livestreaming","etherpad","sharedvideo","settings","raisehand","videoquality","filmstrip","invite","feedback","stats","shortcuts","tileview","videobackgroundblur","download","help","mute-everyone"]';

    if (newUrl != _currentRoomUrl) {
      await _controller.loadUrl(newUrl);
      setState(() {
        _currentRoomUrl = newUrl;
      });
    }
  }

  Widget buildContent() {
    if (!Platform.isWindows) {
      return const Center(
        child: Text(
          'Відеоконференції не підтримуються на цій десктопній платформі.',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_isWebViewInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Ініціалізація WebView...'),
          ],
        ),
      );
    }

    if (_currentRoomUrl == null) {
      return const Center(
        child: Text(
          'Натисніть "Приєднатися", щоб розпочати відеоконференцію',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Stack(
      children: [
        Webview(_controller),
        if (_isLoading)
          Container(
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomController,
                  decoration: const InputDecoration(
                    labelText: 'Назва кімнати',
                    hintText: 'Наприклад, "General" або "Lecture 1"',
                    border: OutlineInputBorder(),
                  ),
                  enabled: _isWebViewInitialized && !_isLoading,
                  onSubmitted: (_) => _joinMeeting(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_isWebViewInitialized && !_isLoading)
                      ? _joinMeeting
                      : null,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.video_call_outlined),
                  label: Text(_isLoading ? 'Завантаження...' : 'Приєднатися'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum FeedItemType { assignment, material }

class FeedItem {
  final FeedItemType type;
  final DateTime sortDate;
  final Assignment? assignment;
  final CourseMaterial? material;

  FeedItem({
    required this.type,
    required this.sortDate,
    this.assignment,
    this.material,
  });
}

class FeedTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;
  final String currentUsername;

  const FeedTabView({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.currentUserRole,
    required this.currentUsername,
  });

  @override
  State<FeedTabView> createState() => _FeedTabViewState();
}

class _FeedTabViewState extends State<FeedTabView> {
  late Future<List<FeedItem>> _feedFuture;
  final CourseService _courseService = CourseService();

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  void _loadFeed() {
    if (mounted) {
      setState(() {
        _feedFuture = _fetchAndCombineFeed();
      });
    }
  }

  Future<List<FeedItem>> _fetchAndCombineFeed() async {
    try {
      final results = await Future.wait([
        _courseService.getAssignments(widget.authToken, widget.courseId),
        _courseService.getCourseMaterials(widget.authToken, widget.courseId),
      ]);

      final List<FeedItem> combinedList = [];

      final List<Assignment> assignments = results[0] as List<Assignment>;
      for (var a in assignments) {
        combinedList.add(
          FeedItem(
            type: FeedItemType.assignment,
            sortDate:
                a.deadline ?? DateTime.fromMillisecondsSinceEpoch(a.id * 1000),
            assignment: a,
          ),
        );
      }

      final List<CourseMaterial> materials = results[1] as List<CourseMaterial>;
      for (var m in materials) {
        combinedList.add(
          FeedItem(
            type: FeedItemType.material,
            sortDate: DateTime.fromMillisecondsSinceEpoch(m.id * 1000),
            material: m,
          ),
        );
      }

      combinedList.sort((a, b) => b.sortDate.compareTo(a.sortDate));

      return combinedList;
    } catch (e) {
      print("Помилка завантаження стрічки: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не вдалося завантажити стрічку: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return [];
    }
  }

  Future<void> _refreshFeed() async {
    _loadFeed();
    await _feedFuture;
  }

  void _handleAction() {
    _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<FeedItem>>(
        future: _feedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Помилка завантаження стрічки: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('У стрічці курсу поки що нічого немає.'),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Оновити'),
                    onPressed: _refreshFeed,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshFeed,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                switch (item.type) {
                  case FeedItemType.assignment:
                    return _AssignmentFeedTile(
                      assignment: item.assignment!,
                      authToken: widget.authToken,
                      courseId: widget.courseId,
                      currentUserRole: widget.currentUserRole,
                      currentUsername: widget.currentUsername,
                      onAction: _handleAction,
                    );
                  case FeedItemType.material:
                    return _MaterialFeedTile(
                      material: item.material!,
                      authToken: widget.authToken,
                      courseId: widget.courseId,
                      canManage:
                          widget.currentUserRole == CourseRole.OWNER ||
                          widget.currentUserRole == CourseRole.PROFESSOR,
                      onAction: _handleAction,
                    );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _MaterialFeedTile extends StatelessWidget {
  final CourseMaterial material;
  final String authToken;
  final int courseId;
  final bool canManage;
  final VoidCallback onAction;

  const _MaterialFeedTile({
    required this.material,
    required this.authToken,
    required this.courseId,
    required this.canManage,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          foregroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.article_outlined, size: 22),
        ),
        title: Text(
          material.topic,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Новий матеріал",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => MaterialDetailScreen(
                authToken: authToken,
                courseId: courseId,
                materialId: material.id,
                canManage: canManage,
              ),
            ),
          );
          if (result == true) {
            onAction();
          }
        },
      ),
    );
  }
}

class _AssignmentFeedTile extends StatelessWidget {
  final Assignment assignment;
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;
  final String currentUsername;
  final VoidCallback onAction;

  const _AssignmentFeedTile({
    required this.assignment,
    required this.authToken,
    required this.courseId,
    required this.currentUserRole,
    required this.currentUsername,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPastDue =
        assignment.deadline != null &&
        assignment.deadline!.isBefore(DateTime.now());

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPastDue
              ? Colors.grey.shade200
              : Colors.teal.withOpacity(0.1),
          foregroundColor: isPastDue
              ? Colors.grey.shade700
              : Colors.teal.shade700,
          child: const Icon(Icons.assignment_outlined, size: 22),
        ),
        title: Text(
          assignment.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          assignment.deadline != null
              ? "Нове завдання · Дедлайн: ${DateFormat('dd.MM.yyyy \'o\' HH:mm', 'uk_UA').format(assignment.deadline!)}"
              : "Нове завдання · Без дедлайну",
          style: TextStyle(
            fontSize: 12,
            color: isPastDue ? Colors.red.shade700 : Colors.grey.shade600,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AssignmentDetailScreen(
                authToken: authToken,
                courseId: courseId,
                assignmentId: assignment.id,
                currentUserRole: currentUserRole,
                currentUsername: currentUsername,
              ),
            ),
          );
          if (result == true) {
            onAction();
          }
        },
      ),
    );
  }
}

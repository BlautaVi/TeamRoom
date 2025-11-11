import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'chat_models.dart';

class ChatService {
  final String _apiBaseUrl = "https://team-room-jitsi.duckdns.org/api";

  Exception _handleErrorResponse(
    http.Response response,
    String context, {
    String? customContext,
  }) {
    String errorMessage = 'Невідома помилка';
    final statusCode = response.statusCode;

    try {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      if (error is Map && error.containsKey('message')) {
        final serverMessage = error['message'] as String?;

        // Translate common English error messages to Ukrainian
        if (serverMessage != null) {
          errorMessage = _translateErrorMessage(
            serverMessage,
            statusCode,
            customContext,
          );
        } else {
          errorMessage = _getDefaultErrorMessage(statusCode, customContext);
        }
      } else {
        errorMessage = _getDefaultErrorMessage(statusCode, customContext);
      }
    } catch (_) {
      errorMessage = _getDefaultErrorMessage(statusCode, customContext);
    }

    debugPrint("Error in $context: Status $statusCode, Message: $errorMessage");

    return Exception(errorMessage);
  }

  String _translateErrorMessage(
    String serverMessage,
    int statusCode,
    String? customContext,
  ) {
    // Handle permission errors (403)
    if (statusCode == 403) {
      if (serverMessage.contains('Access Denied') ||
          serverMessage.contains('required permissions') ||
          serverMessage.contains('permission')) {
        if (customContext == 'pin') {
          return 'У вас немає прав для закріплення повідомлень у цьому чаті. Для закріплення повідомлень потрібна роль модератора або вище.';
        } else if (customContext == 'unpin') {
          return 'У вас немає прав для відкріплення повідомлень у цьому чаті. Для відкріплення повідомлень потрібна роль модератора або вище.';
        }
        return 'У вас немає достатніх прав для виконання цієї дії.';
      }
      return 'Доступ заборонено. У вас немає прав для виконання цієї дії.';
    }

    // Handle not found errors (404)
    if (statusCode == 404) {
      if (serverMessage.contains('Not Found') ||
          serverMessage.contains('не знайдено')) {
        if (customContext == 'pin') {
          return 'Не вдалося знайти повідомлення або чат для закріплення.';
        } else if (customContext == 'unpin') {
          return 'Не вдалося знайти закріплене повідомлення.';
        }
        return 'Запитуваний ресурс не знайдено.';
      }
      return serverMessage;
    }

    // Handle bad request errors (400)
    if (statusCode == 400) {
      if (serverMessage.contains('already pinned') ||
          serverMessage.contains('вже прикріплене')) {
        return 'Це повідомлення вже закріплене.';
      }
      if (serverMessage.contains('not pinned') ||
          serverMessage.contains('не прикріплене')) {
        return 'Це повідомлення не закріплене.';
      }
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'Невірний запит. Перевірте введені дані.';
    }

    // Return server message as is if it's already in Ukrainian or if we don't have a translation
    return serverMessage;
  }

  String _getDefaultErrorMessage(int statusCode, String? customContext) {
    switch (statusCode) {
      case 403:
        if (customContext == 'pin') {
          return 'У вас немає прав для закріплення повідомлень у цьому чаті. Для закріплення повідомлень потрібна роль модератора або вище.';
        } else if (customContext == 'unpin') {
          return 'У вас немає прав для відкріплення повідомлень у цьому чаті. Для відкріплення повідомлень потрібна роль модератора або вище.';
        }
        return 'Доступ заборонено. У вас немає прав для виконання цієї дії.';
      case 404:
        if (customContext == 'pin' || customContext == 'unpin') {
          return 'Не вдалося знайти повідомлення або чат.';
        }
        return 'Запитуваний ресурс не знайдено.';
      case 400:
        return 'Невірний запит. Перевірте введені дані.';
      case 401:
        return 'Необхідна авторизація. Увійдіть у систему.';
      case 500:
        return 'Помилка сервера. Спробуйте пізніше.';
      default:
        return 'Сталася помилка. Спробуйте ще раз.';
    }
  }

  Future<Chat> createGroupChat(
    String token,
    String name,
    List<String> memberUsernames, {
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/chats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        'name': name,
        'photoUrl': photoUrl,
        'memberUsernames': memberUsernames,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      final int? newChatId = data['chatId'] ?? data['id'];

      if (newChatId == null) {
        throw Exception(
          'Сервер не повернув ID створеного групового чату у відповіді.',
        );
      }

      print(
        "Group chat created with temp ID $newChatId. Fetching full details...",
      );
      return await getChatDetails(token, newChatId);
    } else {
      throw _handleErrorResponse(response, 'Не вдалося створити груповий чат');
    }
  }

  Future<Chat> createPrivateChat(String token, String otherUsername) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/chats/private'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({'username': otherUsername}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      final int? newChatId = data['chatId'] ?? data['id'];

      if (newChatId == null) {
        throw Exception(
          'Сервер не повернув ID створеного приватного чату у відповіді.',
        );
      }
      print(
        "Private chat created with ID $newChatId. Fetching full details...",
      );
      return await getChatDetails(token, newChatId);
    } else {
      throw _handleErrorResponse(response, 'Не вдалося створити приватний чат');
    }
  }

  Future<Chat> createCourseChat(
    String token,
    int courseId,
    String name, {
    String? photoUrl,
    List<String>? memberUsernames,
  }) async {
    final body = <String, dynamic>{
      'name': name,
    };
    if (photoUrl != null) body['photoUrl'] = photoUrl;

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course/$courseId/chats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      final int? newChatId = data['chatId'] ?? data['id'];

      if (newChatId == null) {
        throw Exception(
          'Сервер не повернув ID створеного курсового чату у відповіді.',
        );
      }
      print("Course chat created with ID $newChatId. Fetching full details...");
      return await getChatDetails(token, newChatId);
    } else {
      throw _handleErrorResponse(response, 'Не вдалося створити курсовий чат');
    }
  }

  Future<void> clearPrivateChat(
    String token,
    int chatId, {
    bool clearForBoth = false,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '$_apiBaseUrl/chats/private/$chatId/clear?clearForBoth=$clearForBoth',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося очистити приватний чат');
    }
  }

  Future<List<Chat>> getMyChats(String token) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/chats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Chat.fromJson(json)).toList();
    } else {
      throw _handleErrorResponse(response, 'Не вдалося завантажити чати');
    }
  }

  Future<Chat> getChatDetails(String token, int chatId) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/chats/$chatId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return Chat.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw _handleErrorResponse(
        response,
        'Не вдалося завантажити деталі чату',
      );
    }
  }

  Future<List<ChatMessage>> getMessages(
    String token,
    int chatId,
    int limitBefore, {
    int? messageId,
    int? limitAfter,
  }) async {
    final queryParameters = {
      'limitBefore': limitBefore.toString(),
      if (messageId != null) 'messageId': messageId.toString(),
      if (limitAfter != null) 'limitAfter': limitAfter.toString(),
    };

    final uri = Uri.parse(
      '$_apiBaseUrl/chats/$chatId/messages',
    ).replace(queryParameters: queryParameters);

    print("ChatService: Fetching messages: $uri");

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      throw _handleErrorResponse(
        response,
        'Не вдалося завантажити повідомлення',
      );
    }
  }

  Future<List<ChatMember>> getChatMembers(String token, int chatId) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/chats/$chatId/members'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => ChatMember.fromJson(json)).toList();
    } else {
      throw _handleErrorResponse(
        response,
        'Не вдалося завантажити учасників чату',
      );
    }
  }

  Future<ChatMember> getMyChatMembership(
    String token,
    int chatId,
    String currentUsername,
  ) async {
    final members = await getChatMembers(token, chatId);
    try {
      final myMembership = members.firstWhere(
        (member) => member.username == currentUsername,
      );
      return myMembership;
    } catch (e) {
      throw Exception(
        'Поточного користувача не знайдено серед учасників чату.',
      );
    }
  }

  Future<void> addChatMember(String token, int chatId, String username) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/chats/$chatId/members'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({'username': username, 'role': 'MEMBER'}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _handleErrorResponse(response, 'Не вдалося додати учасника');
    }
  }

  Future<void> removeChatMember(
    String token,
    int chatId,
    String username,
  ) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/chats/$chatId/members/$username'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося видалити учасника');
    }
  }

  Future<void> deleteChat(String token, int chatId) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/chats/$chatId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося видалити чат');
    }
  }

  Future<void> leaveChat(String token, int chatId) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/chats/$chatId/members/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося покинути чат');
    }
  }

  Future<void> patchChat(
    String token,
    int chatId, {
    String? name,
    String? photoUrl,
  }) async {
    if (name == null && photoUrl == null) return;

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (photoUrl != null) body['photoUrl'] = photoUrl;

    final response = await http.patch(
      Uri.parse('$_apiBaseUrl/chats/$chatId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(response, 'Не вдалося оновити чат');
    }
  }

  Future<void> updateChatMemberRole(
    String token,
    int chatId,
    String username,
    ChatRole newRole,
  ) async {
    final response = await http.put(
      Uri.parse('$_apiBaseUrl/chats/$chatId/members/$username'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({'role': newRole.name}),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(response, 'Не вдалося змінити роль учасника');
    }
  }

  Future<void> transferOwnership(
    String token,
    int chatId,
    String newOwnerUsername,
  ) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/chats/$chatId/transfer-ownership'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({'newOwnerUsername': newOwnerUsername}),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(
        response,
        'Не вдалося передати права власності',
      );
    }
  }

  Future<List<ChatMessage>> getPinnedMessages(String token, int chatId) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/chats/$chatId/pinned'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      List<dynamic> messagesList = [];

      if (decoded is List) {
        messagesList = decoded;
      } else if (decoded is Map && decoded['messages'] is List) {
        messagesList = decoded['messages'];
      }
      return messagesList.map((json) {
        if (json is Map<String, dynamic>) {
          final normalizedJson = {
            'id': json['messageId'] ?? json['id'] ?? 0,

            'content': json['messageContent'] ?? json['content'] ?? '',

            'username': json['username'],
            'type': json['messageType'] ?? json['type'] ?? 'USER_MESSAGE',
            'isDeleted': json['isDeleted'] ?? false,
            'chatId': json['chatId'] ?? chatId,
            'replyToMessageId': json['replyToMessageId'],
            'sentAt': json['sentAt'] ?? DateTime.now().toIso8601String(),
            'editedAt': json['editedAt'],
            'relatedEntities': json['relatedEntities'] ?? [],
            'media': json['media'] ?? [],
            'reactions': json['reactions'] ?? [],
          };
          return ChatMessage.fromJson(normalizedJson);
        }
        return ChatMessage.fromJson({});
      }).toList();
    } else if (response.statusCode == 403) {
      debugPrint("Access denied to pinned messages, returning empty list");
      return [];
    } else {
      throw _handleErrorResponse(
        response,
        'Завантаження закріплених повідомлень',
      );
    }
  }

  Future<void> pinMessage(String token, int chatId, int messageId) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/chats/$chatId/pinned'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({'messageId': messageId}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _handleErrorResponse(
        response,
        'Закріплення повідомлення',
        customContext: 'pin',
      );
    }
  }

  Future<void> unpinMessage(String token, int chatId, int messageId) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/chats/$chatId/pinned/$messageId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(
        response,
        'Відкріплення повідомлення',
        customContext: 'unpin',
      );
    }
  }

  // Conference methods
  Future<List<Conference>> getConferences(String token, int courseId) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/course/$courseId/conferences'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Conference.fromJson(json)).toList();
    } else {
      throw _handleErrorResponse(response, 'Завантаження конференцій');
    }
  }

  Future<Conference> getConferenceDetails(
    String token,
    int courseId,
    int conferenceId,
  ) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/course/$courseId/conferences/$conferenceId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return Conference.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw _handleErrorResponse(response, 'Завантаження деталей конференції');
    }
  }

  Future<ConferenceJoinData> createConference(
    String token,
    int courseId,
    String subject,
  ) async {
    try {
      final requestBody = jsonEncode({'subject': subject});
      final url = '$_apiBaseUrl/course/$courseId/conferences';

      debugPrint('=== Conference Creation Debug ===');
      debugPrint('URL: $url');
      debugPrint('CourseId: $courseId');
      debugPrint('Subject: "$subject"');
      debugPrint('Request body: $requestBody');
      debugPrint('Token length: ${token.length}');
      debugPrint(
        'Token (first 20 chars): ${token.substring(0, (token.length > 20 ? 20 : token.length))}...',
      );
      debugPrint('Token is empty: ${token.isEmpty}');
      debugPrint(
        'Authorization header: Bearer ${token.substring(0, (token.length > 20 ? 20 : token.length))}...',
      );

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('Conference creation response: $jsonData');
        return ConferenceJoinData.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Неавторизований. Будь ласка, перейдіть заново.');
      } else if (response.statusCode == 403) {
        String serverMessage = 'Доступ заборонено';
        String responseBody = utf8.decode(response.bodyBytes);
        debugPrint('403 Forbidden Response: $responseBody');
        try {
          final error = jsonDecode(responseBody);
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {}
        throw Exception('Доступ заборонено: $serverMessage');
      } else if (response.statusCode == 400) {
        String serverMessage = 'Невірний запит';
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          }
        } catch (_) {}
        throw Exception('Помилка: $serverMessage');
      } else if (response.statusCode == 500) {
        String serverMessage = 'Помилка сервера';
        String responseBody = utf8.decode(response.bodyBytes);
        debugPrint('500 Error Response Body: $responseBody');
        try {
          final error = jsonDecode(responseBody);
          if (error is Map && error.containsKey('message')) {
            serverMessage = error['message'];
          } else if (error is String) {
            serverMessage = error;
          }
        } catch (_) {
          // Якщо це не JSON, використовуємо сам текст відповіді
          if (responseBody.isNotEmpty) {
            serverMessage = responseBody;
          }
        }
        throw Exception('Помилка сервера (500): $serverMessage');
      } else {
        throw _handleErrorResponse(response, 'Створення конференції');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Помилка підключення до сервера: $e');
    }
  }

  Future<ConferenceJoinData> joinConference(
    String token,
    int courseId,
    int conferenceId,
  ) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/course/$courseId/conferences/$conferenceId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ConferenceJoinData.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    } else {
      throw _handleErrorResponse(response, 'Приєднання до конференції');
    }
  }
}

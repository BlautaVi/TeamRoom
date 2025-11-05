import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_models.dart';

class ChatService {
  final String _apiBaseUrl = "http://localhost:8080/api";

  Exception _handleErrorResponse(http.Response response, String context) {
    String errorMessage = 'Невідома помилка';
    try {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      errorMessage = (error is Map && error.containsKey('message'))
          ? error['message']
          : utf8.decode(response.bodyBytes);
    } catch (_) {
      errorMessage = response.body.isEmpty ? 'Порожня відповідь' : response.body;
    }
    print(
      "Error in $context: Status ${response.statusCode}, Message: $errorMessage",
    );
    return Exception(
      '$context: $errorMessage (Статус: ${response.statusCode})',
    );
  }

  Future<Chat> createGroupChat(String token,
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
        throw Exception('Сервер не повернув ID створеного групового чату у відповіді.');
      }

      print("Group chat created with temp ID $newChatId. Fetching full details...");
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
      body: jsonEncode({
        'username': otherUsername,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      final int? newChatId = data['chatId'] ?? data['id'];

      if (newChatId == null) {
        throw Exception('Сервер не повернув ID створеного приватного чату у відповіді.');
      }
      print("Private chat created with ID $newChatId. Fetching full details...");
      return await getChatDetails(token, newChatId);

    } else {
      throw _handleErrorResponse(response, 'Не вдалося створити приватний чат');
    }
  }

  Future<void> clearPrivateChat(String token, int chatId, {bool clearForBoth = false}) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/chats/private/$chatId/clear?clearForBoth=$clearForBoth'),
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
      throw _handleErrorResponse(response, 'Не вдалося завантажити деталі чату');
    }
  }

  Future<List<ChatMessage>> getMessages(
      String token,
      int chatId,
      int limitBefore,
      {int? messageId,
        int? limitAfter}
      ) async {

    final queryParameters = {
      'limitBefore': limitBefore.toString(),
      if (messageId != null) 'messageId': messageId.toString(),
      if (limitAfter != null) 'limitAfter': limitAfter.toString(),
    };

    final uri = Uri.parse('$_apiBaseUrl/chats/$chatId/messages').replace(
      queryParameters: queryParameters,
    );

    print("ChatService: Fetching messages: $uri");

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      throw _handleErrorResponse(response, 'Не вдалося завантажити повідомлення');
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
      throw _handleErrorResponse(response, 'Не вдалося завантажити учасників чату');
    }
  }

  Future<ChatMember> getMyChatMembership(String token, int chatId, String currentUsername) async {
    final members = await getChatMembers(token, chatId);
    try {
      final myMembership = members.firstWhere(
            (member) => member.username == currentUsername,
      );
      return myMembership;
    } catch (e) {
      throw Exception('Поточного користувача не знайдено серед учасників чату.');
    }
  }

  Future<void> addChatMember(String token, int chatId, String username) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/chats/$chatId/members'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        'username': username,
        'role': 'MEMBER',
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _handleErrorResponse(response, 'Не вдалося додати учасника');
    }
  }

  Future<void> removeChatMember(String token, int chatId, String username) async {
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

  Future<void> patchChat(String token, int chatId, {String? name, String? photoUrl}) async {
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

  Future<void> updateChatMemberRole(String token, int chatId, String username, ChatRole newRole) async {
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

  Future<void> transferOwnership(String token, int chatId, String newOwnerUsername) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/chats/$chatId/transfer-ownership'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({'newOwnerUsername': newOwnerUsername}),
    );
    if (response.statusCode != 200) {
      throw _handleErrorResponse(response, 'Не вдалося передати права власності');
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
            'reactions': json['reactions'] ?? []
          };
          return ChatMessage.fromJson(normalizedJson);
        }
        return ChatMessage.fromJson({});
      }).toList();

    } else {
      throw _handleErrorResponse(response, 'Не вдалося завантажити закріплені повідомлення');
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
      throw _handleErrorResponse(response, 'Не вдалося закріпити повідомлення');
    }
  }

  Future<void> unpinMessage(String token, int chatId, int messageId) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/chats/$chatId/pinned/$messageId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _handleErrorResponse(response, 'Не вдалося відкріпити повідомлення');
    }
  }
}
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_models.dart';

class ChatService {
  final String _apiBaseUrl = "http://localhost:8080/api";

  Exception _handleErrorResponse(http.Response response, String context) {
    String errorMessage = 'Невідома помилка';
    try {
      final error = jsonDecode(response.body);
      errorMessage = (error is Map && error.containsKey('message'))
          ? error['message']
          : response.body;
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

  // --- 💡 ПОВЕРНУЛИ МЕТОДИ ДЛЯ REST API ---

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

  Future<List<Chat>> getCourseChats(String token, int courseId) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/course/$courseId/chats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Chat.fromJson(json)).toList();
    } else {
      throw _handleErrorResponse(response, 'Не вдалося завантажити чати курсу');
    }
  }

  Future<List<ChatMessage>> getMessages(
      String token,
      int chatId,
      int page,
      ) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/chats/$chatId/messages?page=$page'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      throw _handleErrorResponse(response, 'Не вдалося завантажити повідомлення');
    }
  }

  // --- 💡 ---

  Future<ChatMember> getMyChatMembership(String token, int chatId) async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/chats/$chatId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return ChatMember.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw _handleErrorResponse(response, 'Не вдалося завантажити дані чату');
    }
  }
}
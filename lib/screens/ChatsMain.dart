import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:kurs/classes/chat_models.dart';
import 'package:kurs/classes/chat_service.dart';
import 'chat_screen.dart';

class ChatsMain extends StatefulWidget {
  final String authToken;
  final String currentUsername;

  const ChatsMain({
    super.key,
    required this.authToken,
    required this.currentUsername,
  });

  @override
  State<ChatsMain> createState() => _ChatsMainState();
}

class _ChatsMainState extends State<ChatsMain> {
  final ChatService _chatService = ChatService();
  late Future<List<Chat>> _chatsFuture;

  // 💡 Додаємо StompClient ТІЛЬКИ для створення
  StompClient? _stompClient;

  @override
  void initState() {
    super.initState();
    _loadChats(); // Повертаємо завантаження списку
    _connectToStomp(); // Підключаємось до WS
  }

  @override
  void dispose() {
    _stompClient?.deactivate();
    super.dispose();
  }

  void _loadChats() {
    if (mounted) {
      setState(() {
        // Повертаємо завантаження через REST API
        _chatsFuture = _chatService.getMyChats(widget.authToken);
      });
    }
  }

  // --- 💡 ЛОГІКА WEBSOCKET ДЛЯ СТВОРЕННЯ ---

  void _connectToStomp() {
    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://localhost:8080/ws/websocket',
        onConnect: _onStompConnect,
        onWebSocketError: (e) => print("WebSocket Error: $e"),
        stompConnectHeaders: {'Authorization': 'Bearer ${widget.authToken}'},
        webSocketConnectHeaders: {'Authorization': 'Bearer ${widget.authToken}'},
      ),
    );
    _stompClient!.activate();
  }

  void _onStompConnect(StompFrame frame) {
    print("STOMP client connected (ChatsMain).");
    // Підписуємось на нашу чергу, щоб отримати відповідь про СТВОРЕНИЙ чат
    _stompClient!.subscribe(
      destination: '/user/queue/notifications',
      callback: (frame) {
        if (frame.body == null) return;
        final broadcast = jsonDecode(frame.body!);
        final type = broadcast['type'];

        // Як у JS-прикладі, чекаємо на 'ROOM_CREATED'
        if (type == 'ROOM_CREATED') {
          // Оновлюємо список чатів, коли прийшла відповідь
          print("Chat created via WebSocket! Refreshing list...");
          if (mounted) {
            _loadChats();
          }
        }
      },
    );
  }

  Future<void> _showCreateChatDialog() async {
    if (_stompClient?.connected != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Не вдалося підключитися до сервісу чатів. Спробуйте пізніше.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Створити новий груповий чат'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Назва чату'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(context, nameController.text.trim());
                }
              },
              child: const Text('Створити'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // 💡 Надсилаємо запит на СТВОРЕННЯ через WebSocket
      _stompClient!.send(
        destination: '/app/room.create', // Згідно JS-прикладу
        body: jsonEncode({
          'roomName': result,
          'photoUrl': "", // TODO: Додати вибір фото
        }),
      );
    }
  }

  // --- 💡 ---

  Future<void> _openChat(Chat chat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          authToken: widget.authToken,
          chatId: chat.id,
          chatName: chat.name,
          currentUsername: widget.currentUsername,
        ),
      ),
    );
    // Оновлюємо список, щоб оновити 'lastMessage'
    if (mounted) {
      _loadChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мої чати'),
        backgroundColor: const Color(0xFF62567E),
        foregroundColor: Colors.white,
        leading: const SizedBox.shrink(), // Прибираємо кнопку "Назад"
        flexibleSpace: Container(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Створити чат',
            // Кнопка активна, тільки якщо WS підключено
            onPressed: _stompClient?.connected == true ? _showCreateChatDialog : null,
          ),
        ],
      ),
      // Повертаємо FutureBuilder
      body: RefreshIndicator(
        onRefresh: () async => _loadChats(),
        child: FutureBuilder<List<Chat>>(
          future: _chatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Помилка завантаження чатів:\n${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }
            final chats = snapshot.data ?? [];
            if (chats.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('У вас ще немає чатів.'),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Оновити'),
                      onPressed: _loadChats,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ListTile(
                  leading: CircleAvatar(
                    // TODO: Використовувати chat.photoUrl
                    child: Text(chat.name.isNotEmpty ? chat.name[0] : '?'),
                  ),
                  title: Text(chat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    chat.lastMessage?.content ?? 'Немає повідомлень',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: chat.unreadCount > 0
                      ? CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.red,
                    child: Text(
                      chat.unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                      : null,
                  onTap: () => _openChat(chat),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
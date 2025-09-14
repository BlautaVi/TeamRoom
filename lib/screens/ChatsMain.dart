import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class Message {
  final String text;
  final String senderUsername;
  final String roomId;

  Message({required this.text, required this.senderUsername, required this.roomId});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      text: json['content'] ?? '',
      senderUsername: json['sender'] ?? 'unknown',
      roomId: json['roomId'] ?? '',
    );
  }
}

class Room {
  final String id;
  final String name;
  String lastMessage;

  Room({required this.id, required this.name, this.lastMessage = ''});
  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['roomId'] ?? json['id'] ?? '',
      name: json['roomName'] ?? 'Unnamed Room',
      lastMessage: json['lastMessage']?['content'] ?? 'Немає повідомлень',
    );
  }
}

class SearchedUser {
  final String id;
  final String username;
  SearchedUser({required this.id, required this.username});
  factory SearchedUser.fromJson(Map<String, dynamic> json) {
    return SearchedUser(id: json['_id'], username: json['username']);
  }
}

class ChatsMain extends StatefulWidget {
  final String authToken;
  final Function(int? index) onChatSelected;

  const ChatsMain({
    super.key,
    required this.authToken,
    required this.onChatSelected,
  });

  @override
  State<ChatsMain> createState() => _ChatsMainState();
}

class _ChatsMainState extends State<ChatsMain> {
  final String _hostname = "team-room-back.onrender.com";
  final String _searchUsersEndpoint = "/users/search";

  StompClient? _stompClient;
  List<Room> _rooms = [];
  bool _isLoading = true;
  Room? _selectedRoom;
  String _error = '';

  List<Message> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  StreamSubscription<StompFrame>? _topicSubscription;

  String _currentUserId = '';
  String _currentUsername = '';


  @override
  void initState() {
    super.initState();
    _initializeUserAndConnection();
  }

  void _initializeUserAndConnection() {
    _currentUserId = _parseJwt(widget.authToken, ['id', 'userId', '_id', 'sub']);
    _currentUsername = _parseJwt(widget.authToken, ['username', 'user_name', 'name', 'sub']);

    if (_currentUserId.isNotEmpty && _currentUsername.isNotEmpty) {
      _connectToStomp();
    } else {
      setState(() {
        _isLoading = false;
        _error = "Помилка конфігурації акаунту: не вдалося ідентифікувати користувача. Функціонал чату обмежено.";
      });
    }
  }

  String _parseJwt(String token, List<String> keys) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return '';
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is Map) {
        for (var key in keys) {
          if (payload.containsKey(key) && payload[key] != null) {
            return payload[key].toString();
          }
        }
      }
      print("ПОПЕРЕДЖЕННЯ: Жодне з полів '${keys.join(', ')}' не знайдено у токені: $payload");
      return '';
    } catch (e) {
      print("Критична помилка декодування токена: $e");
      return '';
    }
  }

  void _connectToStomp() {
    _stompClient = StompClient(
      config: StompConfig(
        url: 'wss://team-room-back.onrender.com/ws/websocket',
        onConnect: _onStompConnect,
        onWebSocketError: (dynamic error) {
          print("WebSocket Error: $error");
          if (mounted) setState(() => _error = 'Помилка підключення до чату.');
        },
        onStompError: (StompFrame frame) {
          print("STOMP Error: ${frame.body}");
          if (mounted) setState(() => _error = 'Помилка протоколу чату.');
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer ${widget.authToken}',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer ${widget.authToken}',
        },
      ),
    );
    _stompClient!.activate();
  }

  void _onStompConnect(StompFrame frame) {
    print("STOMP client connected.");
    _stompClient!.subscribe(
      destination: '/user/queue/notifications',
      callback: _onUserBroadcastReceived,
    );

    _stompClient!.send(destination: '/app/get-initial-data');
  }

  void _onUserBroadcastReceived(StompFrame frame) {
    if (frame.body == null) return;
    final broadcast = jsonDecode(frame.body!);
    final type = broadcast['type'];
    final payload = broadcast['payload'];

    print("Received broadcast of type '$type'");

    switch (type) {
      case 'INITIAL_DATA':
        final List<dynamic> roomData = payload ?? [];
        setState(() {
          _rooms = roomData.map((data) => Room.fromJson(data)).toList();
          _isLoading = false;
          _error = '';
        });
        break;
      case 'ROOM_MESSAGES_RESPONSE':
        final List<dynamic> messageData = payload ?? [];
        setState(() {
          _messages = messageData.map((data) => Message.fromJson(data)).toList().reversed.toList();
          _isLoading = false;
        });
        break;
      case 'ROOM_CREATED':
        final newRoom = Room.fromJson(payload);
        if(!_rooms.any((room) => room.id == newRoom.id)) {
          setState(() => _rooms.insert(0, newRoom));
        }
        break;
      case 'CHAT_MESSAGE':
        final message = Message.fromJson(payload);
        final roomIndex = _rooms.indexWhere((room) => room.id == message.roomId);
        if (roomIndex != -1) {
          setState(() {
            _rooms[roomIndex].lastMessage = message.text;
            final updatedRoom = _rooms.removeAt(roomIndex);
            _rooms.insert(0, updatedRoom);
          });
        }
        break;
      default:
        print("Unhandled broadcast type: $type");
    }
  }

  void _onTopicBroadcastReceived(StompFrame frame) {
    if (frame.body == null) return;
    final broadcast = jsonDecode(frame.body!);

    if (broadcast['type'] == 'CHAT_MESSAGE') {
      setState(() {
        _messages.insert(0, Message.fromJson(broadcast['payload']));
      });
    }
  }

  Future<void> _openRoom(Room room) async {
    setState(() {
      _isLoading = true;
      _selectedRoom = room;
      _messages.clear();
    });

    _topicSubscription?.cancel();

    _topicSubscription = _stompClient?.subscribe(
      destination: '/topic/rooms/${room.id}',
      callback: _onTopicBroadcastReceived,
    ) as StreamSubscription<StompFrame>?;

    _stompClient?.send(
      destination: '/app/get-room-messages',
      body: jsonEncode({'roomId': room.id}),
    );
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty && _stompClient != null && _selectedRoom != null) {
      _stompClient!.send(
        destination: '/app/chat.sendMessage',
        body: jsonEncode({
          'roomId': _selectedRoom!.id,
          'sender': _currentUsername,
          'content': _messageController.text,
          'type': 'CHAT',
        }),
      );
      _messageController.clear();
    }
  }

  Future<void> _showSearchUserDialog() async {
    final searchController = TextEditingController();
    List<SearchedUser> searchResults = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> searchUsers() async {
              if (searchController.text.isEmpty) return;
              try {
                final response = await http.get(
                  Uri.parse("https://$_hostname$_searchUsersEndpoint?username=${searchController.text}"),
                  headers: {'Authorization': 'Bearer ${widget.authToken}'},
                );
                if (response.statusCode == 200) {
                  final List<dynamic> data = jsonDecode(response.body);
                  setDialogState(() {
                    searchResults = data.map((d) => SearchedUser.fromJson(d)).toList();
                  });
                }
              } catch (e) {
                print("Помилка пошуку: $e");
              }
            }

            void createRoom(SearchedUser user) {
              _stompClient?.send(
                  destination: '/app/room.create',
                  body: jsonEncode({
                    'roomName': user.username,
                    'participantIds': [user.id]
                  })
              );
              Navigator.of(context).pop();
            }

            return AlertDialog(
              title: const Text('Створити новий чат'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Пошук за username',
                        suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: searchUsers),
                      ),
                      onSubmitted: (_) => searchUsers(),
                    ),
                    const SizedBox(height: 16),
                    if (searchResults.isNotEmpty)
                      SizedBox(
                        height: 200,
                        child: ListView(
                          shrinkWrap: true,
                          children: searchResults
                              .map((user) => ListTile(
                            title: Text(user.username),
                            onTap: () => createRoom(user),
                          ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Скасувати'),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _selectedRoom == null ? _buildChatListPanel() : _buildChatConversationPanel(),
        if (_selectedRoom == null)
          const Expanded(
            child: Center(
              child: Text(
                'Оберіть чат для початку спілкування',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatListPanel() {
    const Color primaryColor = Color(0xFF62567E);
    const Color dividerColor = Color(0xFF7A6C9B);
    return Container(
      width: 300,
      color: primaryColor,
      child: Column(
        children: [
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
          else if (_error.isNotEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Re-request initial data on pull-to-refresh
                  _stompClient?.send(destination: '/app/get-initial-data');
                },
                child: _rooms.isEmpty
                    ? const Center(child: Text("У вас ще немає чатів.", style: TextStyle(color: Colors.white70)))
                    : ListView.separated(
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: primaryColor)),
                      title: Text(room.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(room.lastMessage, style: TextStyle(color: Colors.white.withOpacity(0.7)), overflow: TextOverflow.ellipsis),
                      onTap: () => _openRoom(room),
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(color: dividerColor, height: 1, thickness: 1),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                onPressed: _error.isEmpty ? _showSearchUserDialog : null,
                backgroundColor: _error.isEmpty ? Colors.white : Colors.grey,
                child: Icon(Icons.add, color: _error.isEmpty ? primaryColor : Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatConversationPanel() {
    const Color primaryColor = Color(0xFF62567E);
    return Expanded(
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: primaryColor),
              onPressed: () {
                // Unsubscribe from topic when leaving room
                _topicSubscription?.cancel();
                _topicSubscription = null;
                setState(() => _selectedRoom = null);
              },
            ),
            title: Text(_selectedRoom!.name, style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              reverse: true, // Keep new messages at the bottom
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                // The `isMe` check now compares usernames.
                final isMe = message.senderUsername == _currentUsername;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? primaryColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(message.text, style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Введіть повідомлення...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: primaryColor), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _topicSubscription?.cancel();
    _stompClient?.deactivate();
    _messageController.dispose();
    super.dispose();
  }
}

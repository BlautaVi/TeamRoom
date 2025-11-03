import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:kurs/classes/chat_models.dart';
import 'package:kurs/classes/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String authToken;
  final int chatId;
  final String chatName;
  final String currentUsername;

  const ChatScreen({
    super.key,
    required this.authToken,
    required this.chatId,
    required this.chatName,
    required this.currentUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  StompClient? _stompClient;
  void Function()? _topicUnsubscribe;

  bool _isLoading = true;
  String _error = '';
  bool _isLoadingMore = false;
  int _currentPage = 1;
  final List<ChatMessage> _messages = [];
  late ChatMember _myMembership;
  final List<String> _typingUsers = [];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _myMembership = ChatMember(
      username: widget.currentUsername,
      role: ChatRole.MEMBER,
      lastReadMessageId: 0,
    );
    _loadInitialData();
    _connectToStomp();
    _messageController.addListener(_onTyping);
  }

  @override
  void dispose() {
    _topicUnsubscribe?.call();
    _stompClient?.deactivate();
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }


  void _onTyping() {
    if (_stompClient?.connected != true) return;

    if (_typingTimer == null && _messageController.text.isNotEmpty) {
      _stompClient?.send(
        destination: '/app/chat/${widget.chatId}/typing/start',
        body: jsonEncode({}),
      );
      _typingTimer = Timer(const Duration(seconds: 4), () {
        _sendStopTyping();
      });
    } else if (_typingTimer != null && _messageController.text.isEmpty) {
      _sendStopTyping();
    }
  }

  void _sendStopTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;
    if (_stompClient?.connected == true) {
      _stompClient?.send(
        destination: '/app/chat/${widget.chatId}/typing/stop',
        body: jsonEncode({}),
      );
    }
  }
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    try {
      _myMembership =
      await _chatService.getMyChatMembership(widget.authToken, widget.chatId);

      final messages =
      await _chatService.getMessages(widget.authToken, widget.chatId, 1);

      if (mounted) {
        setState(() {
          _messages.addAll(messages.reversed);
          _isLoading = false;
          _currentPage = 1;
        });
        _markAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Помилка завантаження чату: $e';
        });
      }
    }
  }


  void _connectToStomp() {
    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://localhost:8080/ws/websocket',
        onConnect: _onStompConnect,
        onWebSocketError: (dynamic error) {
          print("WebSocket Error: $error");
          if (mounted) setState(() => _error = 'Помилка підключення до чату.');
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
    print("STOMP client connected to chat ${widget.chatId}.");
    _topicUnsubscribe = _stompClient!.subscribe(
      destination: '/topic/chats/${widget.chatId}',
      callback: _onBroadcastReceived,
    );
  }

  void _onBroadcastReceived(StompFrame frame) {
    if (frame.body == null) return;
    final data = jsonDecode(frame.body!);
    final type = data['type'];
    final payload = data['payload'];

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        switch (type) {
          case 'USER_MESSAGE':
            _handleNewMessage(ChatMessage.fromJson(payload));
            break;
          case 'REACTION_UPDATE':
            _handleReactionUpdate(payload);
            break;
          case 'MESSAGE_UPDATE':
            _handleMessageUpdate(payload);
            break;
          case 'MESSAGE_DELETED':
            _handleMessageDelete(payload);
            break;
          case 'START_TYPING':
            if (payload['username'] != widget.currentUsername) {
              _typingUsers.add(payload['username']);
              _typingUsers.toSet().toList();
            }
            break;
          case 'STOP_TYPING':
            _typingUsers.remove(payload['username']);
            break;
          case 'READ_LAST_MESSAGE':
            print(
                "User ${payload['username']} read up to ${payload['lastReadMessageId']}");
            break;
          default:
            if (type != null && type != 'USER_MESSAGE') {
              _handleNewMessage(ChatMessage.fromJson(payload));
            }
        }
      });
    });
  }

  void _handleNewMessage(ChatMessage message) {
    _messages.add(message);
    if (message.username == widget.currentUsername) {
      Timer(
        const Duration(milliseconds: 50),
            () => _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    }
    _markAsRead();
  }

  void _handleReactionUpdate(Map<String, dynamic> payload) {
    final int messageId = payload['messageId'];
    final String username = payload['username'];
    final String emoji = payload['emoji'];

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final message = _messages[index];
      if (!message.reactions.containsKey(emoji)) {
        message.reactions[emoji] = [];
      }

      if (message.reactions[emoji]!.contains(username)) {
        message.reactions[emoji]!.remove(username);
      } else {
        message.reactions[emoji]!.add(username);
      }
    }
  }

  void _handleMessageUpdate(Map<String, dynamic> payload) {
    final int messageId = payload['id'];
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final oldReactions = _messages[index].reactions;
      _messages[index] = ChatMessage.fromJson(payload);
      _messages[index].reactions = oldReactions;
    }
  }

  void _handleMessageDelete(Map<String, dynamic> payload) {
    final int messageId = payload['messageId'];
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index].isDeleted = true;
      _messages[index].content = "Повідомлення видалено";
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty || _stompClient?.connected != true) return;

    _sendStopTyping();
    _stompClient!.send(
      destination: '/app/chat/${widget.chatId}/send',
      body: jsonEncode({
        'content': content,
        'replyToMessageId': null,
        'relatedEntities': [],
        'media': [],
      }),
    );
    _messageController.clear();
  }

  void _sendReaction(int messageId, String emoji) {
    if (_stompClient?.connected != true) return;
    _stompClient!.send(
      destination: '/app/chat/${widget.chatId}/react',
      body: jsonEncode({
        'messageId': messageId,
        'emoji': emoji,
      }),
    );
  }

  void _sendDelete(int messageId) {
    if (_stompClient?.connected != true) return;
    _stompClient!.send(
      destination: '/app/chat/${widget.chatId}/delete',
      body: jsonEncode({
        'messageId': messageId,
      }),
    );
  }

  void _markAsRead() {
    if (_messages.isEmpty || _stompClient?.connected != true) return;

    final int lastMessageId = _messages.last.id;
    if (_myMembership.lastReadMessageId < lastMessageId) {
      _stompClient!.send(
        destination: '/app/chat/${widget.chatId}/read',
        body: jsonEncode({
          'lastReadMessageId': lastMessageId,
        }),
      );
      _myMembership = ChatMember(
        username: _myMembership.username,
        role: _myMembership.role,
        lastReadMessageId: lastMessageId,
        lastReadAt: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF62567E);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty && _messages.isEmpty
                  ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ))
                  : ListView.builder(
                controller: _scrollController,
                reverse: true, // 💡 ПОВЕРНУЛИ
                padding: const EdgeInsets.all(8.0),
                itemCount: _messages.length + 1, // 💡 ПОВЕРНУЛИ +1
                itemBuilder: (context, index) {
                  if (index == _messages.length) { // 💡 ПОВЕРНУЛИ
                    return _isLoadingMore
                        ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                        : const SizedBox.shrink();
                  } // 💡 ПОВЕРНУЛИ
                  final message = _messages[index]; // 💡 ПОВЕРНУЛИ
                  final isMe = message.username == widget.currentUsername;
                  if (message.type != MessageType.USER_MESSAGE) {
                    return _SystemMessageTile(message: message);
                  }
                  return _MessageBubble(
                    message: message,
                    isMe: isMe,
                    primaryColor: primaryColor,
                    onReact: (emoji) =>
                        _sendReaction(message.id, emoji),
                    onDelete: () => _sendDelete(message.id),
                    canDelete: _myMembership.role != ChatRole.VIEWER,
                  );
                },
              ),
            ),
          ),
          if (_typingUsers.isNotEmpty)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                '${_typingUsers.toSet().join(', ')} друкує...',
                style: TextStyle(
                    color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: primaryColor),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.primaryColor,
    required this.onReact,
    required this.onDelete,
    required this.canDelete,
  });

  final ChatMessage message;
  final bool isMe;
  final Color primaryColor;
  final Function(String emoji) onReact;
  final Function() onDelete;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: () {

            if (isMe && canDelete) onDelete();
          },
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: isMe ? primaryColor : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      message.username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                SelectableText(
                  message.isDeleted ? 'Повідомлення видалено' : message.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontStyle:
                    message.isDeleted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    message.formattedTime +
                        (message.editedAt != null ? ' (ред.)' : ''),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SystemMessageTile extends StatelessWidget {
  final ChatMessage message;
  const _SystemMessageTile({required this.message});

  String _getSystemMessageText() {
    switch (message.type) {
      case MessageType.USER_JOINED_TO_CHAT:
        return '${message.username} приєднався до чату.';
      case MessageType.USER_LEFT_FROM_CHAT:
        return '${message.username} покинув чат.';
      case MessageType.ASSIGNMENT_CREATED:
        return 'Створено нове завдання: ${message.content}';
      case MessageType.COURSE_OPENED:
        return 'Курс відкрито.';
      case MessageType.COURSE_CLOSED:
        return 'Курс закрито.';
      case MessageType.MATERIAL_CREATED:
        return 'Створено новий матеріал: ${message.content}';
      case MessageType.ASSIGNMENT_DEADLINE_ENDED:
        return 'Дедлайн для завдання ${message.content} закінчився.';
      default:
        return message.content.isEmpty ? 'Системна подія' : message.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      alignment: Alignment.center,
      child: Text(
        _getSystemMessageText(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
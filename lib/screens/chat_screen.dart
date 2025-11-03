import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:kurs/classes/chat_models.dart';
import 'package:kurs/classes/chat_service.dart';
import 'chat_members_screen.dart';
import 'package:kurs/screens/CoursesScreen.dart';
import 'package:kurs/classes/course_models.dart';
import 'package:kurs/screens/assignment_screens.dart';


class ChatScreen extends StatefulWidget {
  final String authToken;
  final int chatId;
  final String chatName;
  final String currentUsername;
  final StompClient stompClient;
  final int? courseId;

  const ChatScreen({
    super.key,
    required this.authToken,
    required this.chatId,
    required this.chatName,
    required this.currentUsername,
    required this.stompClient,
    this.courseId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  void Function()? _topicUnsubscribe;

  bool _isLoading = true;
  String _error = '';
  bool _isLoadingMore = false;
  final int _messagePageSize = 20;
  bool _hasMoreMessages = true;
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
    _setupStompListener();
    _messageController.addListener(_onTyping);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _topicUnsubscribe?.call();
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    try {
      _myMembership =
      await _chatService.getMyChatMembership(widget.authToken, widget.chatId, widget.currentUsername);

      final messages =
      await _chatService.getMessages(
        widget.authToken,
        widget.chatId,
        _messagePageSize,
        messageId: null,
        limitAfter: 0,
      );

      if (mounted) {
        _messages.clear();
        _messages.addAll(messages.reversed);
        if (messages.length < _messagePageSize) {
          _hasMoreMessages = false;
        } else {
          _hasMoreMessages = true;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _markAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Помилка завантаження чату: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_messages.isEmpty) {
      setState(() {
        _isLoadingMore = false;
        _hasMoreMessages = false;
      });
      return;
    }

    final int oldestMessageId = _messages.first.id;

    print("Loading more messages, before ID $oldestMessageId");
    setState(() => _isLoadingMore = true);
    try {
      final newMessages = await _chatService.getMessages(
        widget.authToken,
        widget.chatId,
        _messagePageSize,
        messageId: oldestMessageId,
        limitAfter: 0,
      );

      if (!mounted) return;

      if (newMessages.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _messages.insertAll(0, newMessages.reversed);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка завантаження старих повідомлень: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _showDeleteChatDialog() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити чат?'),
        content: Text('Ви впевнені, що хочете НАЗАВЖДИ видалити чат "${widget.chatName}"? Цю дію неможливо скасувати.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Видалити', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _chatService.deleteChat(widget.authToken, widget.chatId);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка видалення: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showLeaveChatDialog() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Покинути чат?'),
        content: Text('Ви впевнені, що хочете покинути чат "${widget.chatName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Покинути', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _chatService.leaveChat(widget.authToken, widget.chatId);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _openManageMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatMembersScreen(
          authToken: widget.authToken,
          chatId: widget.chatId,
          myRole: _myMembership.role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF62567E);
    final bool canManageMembers = _myMembership.role == ChatRole.OWNER || _myMembership.role == ChatRole.ADMIN;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'manage_members') {
                _openManageMembers();
              } else if (value == 'delete_chat') {
                _showDeleteChatDialog();
              } else if (value == 'leave_chat') {
                _showLeaveChatDialog();
              }
            },
            itemBuilder: (BuildContext context) {
              final List<PopupMenuEntry<String>> items = [];

              if (canManageMembers) {
                items.add(
                  const PopupMenuItem<String>(
                    value: 'manage_members',
                    child: ListTile(
                      leading: Icon(Icons.group),
                      title: Text('Учасники'),
                    ),
                  ),
                );
              }
              if (_myMembership.role == ChatRole.OWNER) {
                items.add(
                  const PopupMenuItem<String>(
                    value: 'delete_chat',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever, color: Colors.red),
                      title: Text('Видалити чат', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                );
              }

              if (_myMembership.role != ChatRole.OWNER) {
                items.add(
                  const PopupMenuItem<String>(
                    value: 'leave_chat',
                    child: ListTile(
                      leading: Icon(Icons.exit_to_app, color: Colors.red),
                      title: Text('Покинути чат', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                );
              }
              return items;
            },
          ),
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
                reverse: true,
                padding: const EdgeInsets.all(8.0),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _isLoadingMore
                        ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                        : (_hasMoreMessages ? const SizedBox.shrink() : const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text("Кінець історії чату", style: TextStyle(color: Colors.grey))),
                    ));
                  }

                  final message = _messages[_messages.length - 1 - index];
                  final isMe = message.username == widget.currentUsername;

                  if (message.relatedEntities.isNotEmpty && widget.courseId != null) {
                    return _RelatedEntityCard(
                      entity: message.relatedEntities.first,
                      authToken: widget.authToken,
                      courseId: widget.courseId!,
                      message: message,
                      currentUserRole: _myMembership.role,
                      currentUsername: widget.currentUsername,
                    );
                  }

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
                    canDelete: isMe || canManageMembers,
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

  void _onTyping() {
    if (widget.stompClient.connected != true) return;

    if (_typingTimer == null && _messageController.text.isNotEmpty) {
      widget.stompClient.send(
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
    if (widget.stompClient.connected == true) {
      widget.stompClient.send(
        destination: '/app/chat/${widget.chatId}/typing/stop',
        body: jsonEncode({}),
      );
    }
  }

  void _setupStompListener() {
    if (widget.stompClient.connected) {
      _onStompConnect(null);
    }
  }

  void _onStompConnect(StompFrame? frame) {
    print("STOMP client connected to chat ${widget.chatId}.");
    _topicUnsubscribe?.call();

    _topicUnsubscribe = widget.stompClient.subscribe(
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
          case 'ASSIGNMENT_CREATED':
          case 'MATERIAL_CREATED':
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
              if (!_typingUsers.contains(payload['username'])) {
                _typingUsers.add(payload['username']);
              }
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
            try {
              _handleNewMessage(ChatMessage.fromJson(payload));
            } catch (e) {
              print("Unknown message type received: $type");
            }
        }
      });
    });
  }

  void _handleNewMessage(ChatMessage message) {
    if (_messages.any((m) => m.id == message.id)) return;

    if (message.username == widget.currentUsername) {
      _messages.removeWhere((m) =>
      m.isSending &&
          m.content == message.content &&
          m.username == message.username);
    }

    _messages.add(message);
    _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

    if (message.username == widget.currentUsername) {
      Timer(
        const Duration(milliseconds: 50),
            () {
          if(_scrollController.hasClients) {
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
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
    if (content.isEmpty || widget.stompClient.connected != true) return;

    _sendStopTyping();

    final tempMessage = ChatMessage(
      id: 0 - DateTime.now().millisecondsSinceEpoch,
      chatId: widget.chatId,
      username: widget.currentUsername,
      content: content,
      type: MessageType.USER_MESSAGE,
      sentAt: DateTime.now(),
      isSending: true,
    );

    setState(() {
      _messages.add(tempMessage);
    });
    Timer(
      const Duration(milliseconds: 50),
          () {
        if(_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
    );

    widget.stompClient.send(
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
    if (widget.stompClient.connected != true) return;
    widget.stompClient.send(
      destination: '/app/chat/${widget.chatId}/react',
      body: jsonEncode({
        'messageId': messageId,
        'emoji': emoji,
      }),
    );
  }

  void _sendDelete(int messageId) {
    if (widget.stompClient.connected != true) return;
    widget.stompClient.send(
      destination: '/app/chat/${widget.chatId}/delete',
      body: jsonEncode({
        'messageId': messageId,
      }),
    );
  }

  void _markAsRead() {
    if (_messages.isEmpty || widget.stompClient.connected != true) return;

    final int lastMessageId = _messages.last.id;
    if (lastMessageId <= 0) return; // Не відправляти для оптимістичних повідомлень

    if (_myMembership.lastReadMessageId < lastMessageId) {
      widget.stompClient.send(
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
            if (canDelete && !message.isSending) onDelete();
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
                    message.isSending ? "Відправка..." : message.formattedTime +
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

class _RelatedEntityCard extends StatefulWidget {
  final RelatedEntity entity;
  final String authToken;
  final int courseId;
  final ChatMessage message;
  final ChatRole currentUserRole;
  final String currentUsername;

  const _RelatedEntityCard({
    required this.entity,
    required this.authToken,
    required this.courseId,
    required this.message,
    required this.currentUserRole,
    required this.currentUsername,
  });

  @override
  State<_RelatedEntityCard> createState() => _RelatedEntityCardState();
}

class _RelatedEntityCardState extends State<_RelatedEntityCard> {
  late Future<Assignment> _assignmentFuture;
  CourseRole? _courseRole;

  @override
  void initState() {
    super.initState();
    if (widget.entity.relatedEntityType == RelatedEntityType.ASSIGNMENT) {
      _loadAssignmentAndRole();
    }
  }

  void _loadAssignmentAndRole() {
    _assignmentFuture = Future(() async {
      try {
        final members = await CourseService().getCourseMembers(widget.authToken, widget.courseId);
        final myMember = members.firstWhere((m) => m.username == widget.currentUsername, orElse: () => CourseMember(username: '', role: CourseRole.VIEWER));
        if (mounted) {
          setState(() {
            _courseRole = myMember.role;
          });
        }
      } catch (e) {
        print("Error fetching course role in chat: $e");
        if(mounted) {
          setState(() {
            _courseRole = CourseRole.VIEWER;
          });
        }
      }
      return CourseService().getAssignmentDetails(
        widget.authToken,
        widget.courseId,
        widget.entity.relatedEntityId,
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    if (widget.entity.relatedEntityType != RelatedEntityType.ASSIGNMENT) {
      return _SystemMessageTile(message: widget.message);
    }

    return FutureBuilder<Assignment>(
      future: _assignmentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 40),
            elevation: 1,
            child: ListTile(
              leading: const CircularProgressIndicator(strokeWidth: 2),
              title: Text(widget.message.content),
              subtitle: const Text("Завантаження деталей..."),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _SystemMessageTile(message: widget.message);
        }

        final assignment = snapshot.data!;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withOpacity(0.1),
              foregroundColor: Colors.teal.shade700,
              child: const Icon(Icons.assignment_outlined),
            ),
            title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Створено нове завдання"),
                if (assignment.deadline != null)
                  Text(
                    "Дедлайн: ${DateFormat('dd.MM.yyyy, HH:mm').format(assignment.deadline!.toLocal())}",
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
              ],
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
            onTap: _courseRole == null ? null : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignmentDetailScreen(
                    authToken: widget.authToken,
                    courseId: widget.courseId,
                    assignmentId: assignment.id,
                    currentUserRole: _courseRole!,
                    currentUsername: widget.currentUsername,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
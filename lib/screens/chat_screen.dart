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

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'pcloud_service.dart';


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
  Chat? _chat;
  final List<String> _typingUsers = [];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;

  late String _currentChatName;
  String? _currentChatPhotoUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentChatName = widget.chatName;
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
      final results = await Future.wait([
        _chatService.getMyChatMembership(widget.authToken, widget.chatId, widget.currentUsername),
        _chatService.getChatDetails(widget.authToken, widget.chatId),
        _chatService.getMessages(
          widget.authToken,
          widget.chatId,
          _messagePageSize,
          messageId: null,
          limitAfter: 0,
        ),
      ]);

      if (mounted) {
        _myMembership = results[0] as ChatMember;
        _chat = results[1] as Chat;
        final messages = results[2] as List<ChatMessage>;

        _messages.clear();
        _messages.addAll(messages.reversed);

        if (messages.length < _messagePageSize) {
          _hasMoreMessages = false;
        } else {
          _hasMoreMessages = true;
        }

        setState(() {
          _isLoading = false;
          _currentChatName = _chat?.name ?? widget.chatName;
          _currentChatPhotoUrl = _chat?.photoUrl;
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
        content: Text('Ви впевнені, що хочете НАЗАВЖДИ видалити чат "$_currentChatName"? Цю дію неможливо скасувати.'),
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
        content: Text('Ви впевнені, що хочете покинути чат "$_currentChatName"?'),
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

  Future<void> _showClearChatDialog() async {
    final bool? clearForBoth = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистити історію чату?'),
        content: const Text('Ця дія видалить повідомлення з чату.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Скасувати')),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Тільки для мене'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Для мене та співрозмовника', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (clearForBoth != null && mounted) {
      try {
        await _chatService.clearPrivateChat(widget.authToken, widget.chatId, clearForBoth: clearForBoth);
        if (mounted) {
          _loadInitialData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка очищення: $e'), backgroundColor: Colors.red),
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
          currentUsername: widget.currentUsername,
        ),
      ),
    );
  }

  Future<void> _showEditChatDialog() async {
    final nameController = TextEditingController(text: _currentChatName);
    File? newImageFile;
    String? tempPhotoUrl = _currentChatPhotoUrl;

    final bool? success = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Редагувати чат'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: newImageFile != null
                              ? FileImage(newImageFile!)
                              : (tempPhotoUrl != null
                              ? NetworkImage(tempPhotoUrl!)
                              : null) as ImageProvider?,
                          child: newImageFile == null && tempPhotoUrl == null
                              ? const Icon(Icons.group, size: 50, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: isSaving ? null : () async {
                              final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                              if (pickedFile != null) {
                                setDialogState(() {
                                  newImageFile = File(pickedFile.path);
                                });
                              }
                            },
                            child: const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFFBFB8D1),
                              child: Icon(Icons.edit, color: Color(0xFF62567E), size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Назва чату'),
                      autofocus: true,
                      enabled: !isSaving,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) return;

                    setDialogState(() => isSaving = true);
                    final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);

                    try {
                      String? finalPhotoUrl = _currentChatPhotoUrl;

                      if (newImageFile != null) {
                        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Завантаження фото...')));

                        final platformFile = PlatformFile(
                          name: newImageFile!.path.split(Platform.pathSeparator).last,
                          path: newImageFile!.path,
                          size: await newImageFile!.length(),
                        );

                        finalPhotoUrl = await PCloudService().uploadFileAndGetPublicLink(
                          file: platformFile,
                          authToken: widget.authToken,
                          purpose: 'chat-photo',
                        );
                      }
                      await _chatService.patchChat(
                        widget.authToken,
                        widget.chatId,
                        name: newName,
                        photoUrl: finalPhotoUrl,
                      );

                      if (mounted) {
                        setState(() {
                          _currentChatName = newName;
                          _currentChatPhotoUrl = finalPhotoUrl;
                        });
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Помилка: ${e.toString().replaceFirst("Exception: ", "")}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setDialogState(() => isSaving = false);
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Зберегти'),
                ),
              ],
            );
          },
        );
      },
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чат оновлено!')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF62567E);
    final bool canManageMembers = _myMembership.role == ChatRole.OWNER || _myMembership.role == ChatRole.ADMIN;
    final bool isViewer = _myMembership.role == ChatRole.VIEWER;
    final bool canEditChat = (_myMembership.role == ChatRole.OWNER || _myMembership.role == ChatRole.ADMIN) &&
        (_chat?.type == ChatType.GROUP);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: (_currentChatPhotoUrl != null && _currentChatPhotoUrl!.isNotEmpty)
                ? NetworkImage(_currentChatPhotoUrl!)
                : null,
            child: (_currentChatPhotoUrl == null || _currentChatPhotoUrl!.isEmpty)
                ? Text(_currentChatName.isNotEmpty ? _currentChatName[0].toUpperCase() : '?')
                : null,
          ),
        ),
        title: Text(_currentChatName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (canEditChat)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редагувати чат',
              onPressed: _showEditChatDialog,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'manage_members') {
                _openManageMembers();
              } else if (value == 'delete_chat') {
                _showDeleteChatDialog();
              } else if (value == 'leave_chat') {
                _showLeaveChatDialog();
              } else if (value == 'clear_chat') {
                _showClearChatDialog();
              }
            },
            itemBuilder: (BuildContext context) {
              final List<PopupMenuEntry<String>> items = [];

              if (_chat?.type == ChatType.PRIVATE) {
                items.add(
                  const PopupMenuItem<String>(
                    value: 'clear_chat',
                    child: ListTile(
                      leading: Icon(Icons.cleaning_services_outlined),
                      title: Text('Очистити історію'),
                    ),
                  ),
                );
              }

              if (_chat?.type == ChatType.GROUP) {
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
                    myRole: _myMembership.role,
                    onLongPress: () => _showMessageOptions(context, message),
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

          if (!isViewer)
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
            )
          else
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey.shade100,
              child: const Center(
                child: Text(
                  "Ви у режимі перегляду. Надсилання повідомлень вимкнено.",
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    if (message.isSending || message.isDeleted) return;

    final bool isMe = message.username == widget.currentUsername;
    final bool canEdit = isMe && message.type == MessageType.USER_MESSAGE;

    final bool canDelete = isMe ||
        _myMembership.role == ChatRole.MODERATOR ||
        _myMembership.role == ChatRole.ADMIN ||
        _myMembership.role == ChatRole.OWNER;

    showModalBottomSheet(
      context: context,
      builder: (builderContext) {
        return SafeArea(
          child: Wrap(
            children: [
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Редагувати'),
                  onTap: () {
                    Navigator.pop(builderContext);
                    _showEditMessageDialog(message);
                  },
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Видалити', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(builderContext);
                    _sendDelete(message.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditMessageDialog(ChatMessage message) async {
    final editController = TextEditingController(text: message.content);
    final String? newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Редагувати повідомлення'),
          content: TextField(
            controller: editController,
            autofocus: true,
            maxLines: null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = editController.text.trim();
                if (text.isNotEmpty && text != message.content) {
                  Navigator.pop(dialogContext, text);
                } else {
                  Navigator.pop(dialogContext, null);
                }
              },
              child: const Text('Зберегти'),
            ),
          ],
        );
      },
    );

    if (newContent != null) {
      _sendEdit(message.id, newContent);
    }
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
    if (_messages.any((m) => m.id == message.id && m.id != 0)) return;

    if (message.username == widget.currentUsername) {
      _messages.removeWhere((m) =>
      m.isSending &&
          m.content == message.content &&
          m.username == message.username);
    }

    if (!_messages.any((m) => m.id == message.id)) {
      _messages.add(message);
    }

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

  void _sendEdit(int messageId, String newContent) {
    if (widget.stompClient.connected != true) return;

    widget.stompClient.send(
      destination: '/app/chat/${widget.chatId}/edit',
      body: jsonEncode({
        'messageId': messageId,
        'content': newContent,
        'relatedEntities': [],
        'media': [],
      }),
    );
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
    if (lastMessageId <= 0) return;

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
    required this.myRole,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool isMe;
  final Color primaryColor;
  final ChatRole myRole;
  final VoidCallback onLongPress;


  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: onLongPress,
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
                Text(widget.message.content.isNotEmpty ? widget.message.content : "Створено нове завдання"),
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
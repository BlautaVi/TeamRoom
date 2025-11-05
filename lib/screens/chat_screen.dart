import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kurs/screens/pcloud_service.dart';
import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:kurs/classes/chat_models.dart';
import 'package:kurs/classes/chat_service.dart';
import 'chat_members_screen.dart';
import 'package:kurs/screens/CoursesScreen.dart';
import 'package:kurs/classes/course_models.dart';
import 'package:kurs/screens/assignment_screens.dart';
import 'package:kurs/screens/CoursesScreen.dart'
    show MaterialDetailScreen, CourseService;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kurs/theme/app_theme.dart';
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
  String? _directChatPhotoUrl;
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> _pinnedMessages = [];
  bool _isLoadingPinned = true;

  final List<Media> _mediaToSend = [];
  bool _isUploadingFile = false;
  ChatMessage? _replyingToMessage;

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
    _messageController.removeListener(_onTyping);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _sendReaction(int messageId, String emoji) {
    if (widget.stompClient.connected != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Не вдалося надіслати реакцію. Немає з\'єднання.')),
      );
      return;
    }

    widget.stompClient.send(
      destination: '/app/chat/${widget.chatId}/react',
      body: jsonEncode({
        'messageId': messageId,
        'emoji': emoji,
      }),
    );
    setState(() {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messages[index];

        if (message.reactions[emoji] == null) {
          message.reactions[emoji] = [];
        }

        if (message.reactions[emoji]!.contains(widget.currentUsername)) {
          message.reactions[emoji]!.remove(widget.currentUsername);
          if (message.reactions[emoji]!.isEmpty) {
            message.reactions.remove(emoji);
          }
        } else {
          message.reactions[emoji]!.add(widget.currentUsername);
        }
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _resolvePhotoUrl(String? publicUrl) async {
    if (publicUrl == null || publicUrl.isEmpty) {
      if (mounted) setState(() => _directChatPhotoUrl = null);
      return;
    }

    try {
      final directUrl = await PCloudService().getDirectImageUrl(publicUrl);
      if (mounted) {
        setState(() {
          _directChatPhotoUrl = directUrl;
        });
      }
    } catch (e) {
      print("Failed to resolve chat photo URL: $e");
      if (mounted) setState(() => _directChatPhotoUrl = null);
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    try {
      _loadPinnedMessages();

      final chat =
      await _chatService.getChatDetails(widget.authToken, widget.chatId);

      ChatMember myMembership;
      if (chat.type == ChatType.PRIVATE) {
        myMembership = ChatMember(
          username: widget.currentUsername,
          role: ChatRole.MEMBER,
          lastReadMessageId: 0,
        );
      } else {
        myMembership = await _chatService.getMyChatMembership(
          widget.authToken,
          widget.chatId,
          widget.currentUsername,
        );
      }

      final messages = await _chatService.getMessages(
        widget.authToken,
        widget.chatId,
        _messagePageSize,
        messageId: null,
        limitAfter: 0,
      );

      if (mounted) {
        _myMembership = myMembership;
        _chat = chat;

        _messages.clear();
        _messages.addAll(messages.reversed);

        _hasMoreMessages = messages.length >= _messagePageSize;

        setState(() {
          _isLoading = false;
          _currentChatName = _chat?.name ?? widget.chatName;
          _currentChatPhotoUrl = _chat?.photoUrl;
        });

        _resolvePhotoUrl(_currentChatPhotoUrl);
        _markAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
          'Помилка завантаження чату: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    }
  }

  Future<void> _loadPinnedMessages() async {
    if (!mounted) return;
    setState(() => _isLoadingPinned = true);
    try {
      final pinned =
      await _chatService.getPinnedMessages(widget.authToken, widget.chatId);
      if (mounted) {
        setState(() {
          _pinnedMessages = pinned;
          _isLoadingPinned = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPinned = false);
        print("Помилка завантаження закріплених: $e");
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
            content: Text(
                'Помилка завантаження старих повідомлень: ${e.toString().replaceFirst("Exception: ", "")}'),
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
        content: Text(
            'Ви впевнені, що хочете НАЗАВЖДИ видалити чат "$_currentChatName"? Цю дію неможливо скасувати.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати')),
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
            SnackBar(
                content: Text('Помилка видалення: $e'),
                backgroundColor: Colors.red),
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
        content:
        Text('Ви впевнені, що хочете покинути чат "$_currentChatName"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати')),
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
            SnackBar(
                content: Text('Помилка: $e'), backgroundColor: Colors.red),
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
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Скасувати')),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Тільки для мене'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Для мене та співрозмовника',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (clearForBoth != null && mounted) {
      try {
        await _chatService.clearPrivateChat(widget.authToken, widget.chatId,
            clearForBoth: clearForBoth);
        if (mounted) {
          _loadInitialData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Помилка очищення: $e'),
                backgroundColor: Colors.red),
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
    String? tempPhotoUrl = _directChatPhotoUrl;

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
                              : (tempPhotoUrl != null &&
                              tempPhotoUrl!.isNotEmpty
                              ? NetworkImage(tempPhotoUrl!)
                              : null) as ImageProvider?,
                          child: newImageFile == null &&
                              (tempPhotoUrl == null ||
                                  tempPhotoUrl!.isEmpty)
                              ? const Icon(Icons.group,
                              size: 50, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: isSaving
                                ? null
                                : () async {
                              final XFile? pickedFile =
                              await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80);
                              if (pickedFile != null) {
                                setDialogState(() {
                                  newImageFile = File(pickedFile.path);
                                  tempPhotoUrl = null;
                                });
                              }
                            },
                            child: const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFFBFB8D1),
                              child: Icon(Icons.edit,
                                  color: Color(0xFF62567E), size: 18),
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
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) return;

                    setDialogState(() => isSaving = true);
                    final scaffoldMessenger =
                    ScaffoldMessenger.of(dialogContext);

                    try {
                      String? finalPhotoUrl = _currentChatPhotoUrl;

                      if (newImageFile != null) {
                        scaffoldMessenger.showSnackBar(const SnackBar(
                            content: Text('Завантаження фото...')));

                        final platformFile = PlatformFile(
                          name: newImageFile!.path
                              .split(Platform.pathSeparator)
                              .last,
                          path: newImageFile!.path,
                          size: await newImageFile!.length(),
                        );

                        finalPhotoUrl = await PCloudService()
                            .uploadFileAndGetPublicLink(
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
                        _resolvePhotoUrl(finalPhotoUrl);
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                'Помилка: ${e.toString().replaceFirst("Exception: ", "")}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setDialogState(() => isSaving = false);
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
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

    final bool canManageMembers =
        (_myMembership.role == ChatRole.OWNER ||
            _myMembership.role == ChatRole.ADMIN) &&
            (_chat?.type == ChatType.GROUP);

    final bool isViewer = _myMembership.role == ChatRole.VIEWER;

    final bool canEditChat = (_myMembership.role == ChatRole.OWNER ||
        _myMembership.role == ChatRole.ADMIN) &&
        (_chat?.type == ChatType.GROUP || _chat?.type == ChatType.COURSE_CHAT);

    final bool canPin = (_myMembership.role == ChatRole.OWNER ||
        _myMembership.role == ChatRole.ADMIN ||
        _myMembership.role == ChatRole.MODERATOR) &&
        (_chat?.type != ChatType.PRIVATE);

    final bool canLeave = _myMembership.role != ChatRole.OWNER &&
        (_chat?.type == ChatType.GROUP);

    final bool canDelete = _myMembership.role == ChatRole.OWNER &&
        (_chat?.type == ChatType.GROUP);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: (_directChatPhotoUrl != null &&
                    _directChatPhotoUrl!.isNotEmpty)
                    ? NetworkImage(_directChatPhotoUrl!)
                    : null,
                onBackgroundImageError: (_directChatPhotoUrl != null && _directChatPhotoUrl!.isNotEmpty)
                    ? (_, __) {
                  if (mounted) setState(() => _directChatPhotoUrl = null);
                }
                    : null,
                child:
                (_directChatPhotoUrl == null || _directChatPhotoUrl!.isEmpty)
                    ? Text(_currentChatName.isNotEmpty
                    ? _currentChatName[0].toUpperCase()
                    : '?')
                    : null,
              ),
              const SizedBox(width: 12),
              Text(_currentChatName),
            ],
          ),
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
                  if (canDelete) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'delete_chat',
                        child: ListTile(
                          leading:
                          Icon(Icons.delete_forever, color: Colors.red),
                          title: Text('Видалити чат',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    );
                  }
                  if (canLeave) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'leave_chat',
                        child: ListTile(
                          leading: Icon(Icons.exit_to_app, color: Colors.red),
                          title: Text('Покинути чат',
                              style: TextStyle(color: Colors.red)),
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
            _PinnedMessageBar(
              isLoading: _isLoadingPinned,
              messages: _pinnedMessages,
              onUnpin: (messageId) {
                if (canPin) _sendUnpin(messageId);
              },
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFF6F4FA),
                      const Color(0xFFF2EFF7),
                    ],
                  ),
                ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                  itemCount: _messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _isLoadingMore
                          ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                            child: CircularProgressIndicator()),
                      )
                          : (_hasMoreMessages
                          ? const SizedBox.shrink()
                          : const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                            child: Text(
                                "Кінець історії чату",
                                style: TextStyle(
                                    color: Colors.grey))),
                      ));
                    }

                    final message =
                    _messages[_messages.length - 1 - index];
                    final isMe =
                        message.username == widget.currentUsername;

                    Widget messageWidget;
                    if (message.relatedEntities.isNotEmpty &&
                        widget.courseId != null &&
                        (message.type == MessageType.ASSIGNMENT_CREATED ||
                            message.type == MessageType.MATERIAL_CREATED ||
                            message.type == MessageType.USER_MESSAGE)) {
                      messageWidget = _RelatedEntityCard(
                        entity: message.relatedEntities.first,
                        authToken: widget.authToken,
                        courseId: widget.courseId!,
                        message: message,
                        currentUsername: widget.currentUsername,
                      );
                    } else if (message.username == null ||
                        message.type != MessageType.USER_MESSAGE) {
                      messageWidget = _SystemMessageTile(message: message);
                    } else {
                      messageWidget = _MessageBubble(
                        message: message,
                        isMe: isMe,
                        primaryColor: primaryColor,
                        myRole: _myMembership.role,
                        onLongPress: () => _showMessageOptions(
                            context, message,
                            canPin: canPin),
                      );
                    }

                    return Column(
                      children: [
                        if (message.replyToMessageId != null)
                          _buildReplyPreview(message.replyToMessageId!),
                        messageWidget,
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_typingUsers.isNotEmpty)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_typingUsers.toSet().join(', ')} друкує...',
                      style: TextStyle(
                          color: AppColors.onSurface.withOpacity(0.7),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),

            _buildStagingArea(),

            if (!isViewer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.outline.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.outline.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.attach_file_rounded, color: primaryColor),
                        tooltip: 'Прикріпити файл',
                        onPressed: _isUploadingFile ? null : _pickAndUploadFiles,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F4FA),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.outline.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Повідомлення',
                            hintStyle: TextStyle(
                              color: AppColors.onSurface.withOpacity(0.5),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.onSurface,
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted:
                          _isUploadingFile ? null : (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                        onPressed: _isUploadingFile ? null : _sendMessage,
                        tooltip: 'Надіслати',
                      ),
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
                    style: TextStyle(
                        color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStagingArea() {
    if (_replyingToMessage == null &&
        _mediaToSend.isEmpty &&
        !_isUploadingFile) {
      return const SizedBox.shrink();
    }

    return Container(
      color: const Color(0xFFF6F4FA),
      child: Column(
        children: [
          if (_isUploadingFile) const LinearProgressIndicator(),
          if (_replyingToMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primary,
                      width: 3,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _replyingToMessage!.username ?? 'Система',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _replyingToMessage!.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.onSurface.withOpacity(0.8), 
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded, 
                        size: 18, 
                        color: AppColors.onSurface.withOpacity(0.6),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _replyingToMessage = null;
                        });
                      },
                    )
                  ],
                ),
              ),
            ),
          if (_mediaToSend.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: _mediaToSend.length,
                itemBuilder: (context, index) {
                  final media = _mediaToSend[index];
                  final isImage = media.fileName != null &&
                      (media.fileName!.toLowerCase().endsWith('.png') ||
                          media.fileName!.toLowerCase().endsWith('.jpg') ||
                          media.fileName!.toLowerCase().endsWith('.jpeg'));
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: isImage
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),

                            child: _OptimizedImagePreview(
                                publicUrl: media.fileUrl),
                          )
                              : Icon(Icons.insert_drive_file_outlined,
                              color: Colors.grey.shade700),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _mediaToSend.removeAt(index);
                              });
                            },
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black.withOpacity(0.6),
                              child:
                              const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            )
        ],
      ),
    );
  }

  Widget _buildReplyPreview(int repliedMessageId) {
    final originalMessage = _messages.firstWhere(
          (m) => m.id == repliedMessageId,
      orElse: () => ChatMessage(
          id: 0,
          chatId: widget.chatId,
          content: 'Повідомлення не знайдено',
          sentAt: DateTime.now(),
          type: MessageType.UNKNOWN
      ),
    );

    return Container(
      margin: const EdgeInsets.only(left: 48, right: 16, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        border: Border(
          left: BorderSide(
            color: AppColors.primary,
            width: 3,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  originalMessage.username ?? 'Система',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  originalMessage.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.onSurface.withOpacity(0.8), 
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFiles() async {
    if (_isUploadingFile) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          _uploadFile(file);
        }
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

  Future<void> _uploadFile(PlatformFile file) async {
    if (!mounted) return;
    setState(() => _isUploadingFile = true);

    try {
      final pCloudService = PCloudService();

      final fileUrl = await pCloudService.uploadFileAndGetPublicLink(
        file: file,
        authToken: widget.authToken,
        purpose: 'message-file',
      );

      final newMedia = Media(
        fileUrl: fileUrl,
        fileName: file.name,
        fileType: file.extension,
        fileSizeBytes: file.size,
      );

      if (mounted) {
        setState(() {
          _mediaToSend.add(newMedia);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка завантаження ${file.name}: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingFile = false);
      }
    }
  }

  void _showMessageOptions(BuildContext context, ChatMessage message,
      {required bool canPin}) {
    if (message.isSending || message.isDeleted) return;
    final bool isMe = message.username == widget.currentUsername;
    final bool canEdit = isMe && message.type == MessageType.USER_MESSAGE;

    final bool canDelete = isMe ||
        _myMembership.role == ChatRole.MODERATOR ||
        _myMembership.role == ChatRole.ADMIN ||
        _myMembership.role == ChatRole.OWNER;

    final bool isAlreadyPinned =
    _pinnedMessages.any((m) => m.id == message.id);
    final bool canPinThis =
        canPin && message.type == MessageType.USER_MESSAGE && message.id > 0;

    showModalBottomSheet(
      context: context,
      builder: (builderContext) {
        return SafeArea(
          child: Wrap(
            children: [
              _buildReactionPicker(builderContext, message),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Відповісти'),
                onTap: () {
                  Navigator.pop(builderContext);
                  setState(() => _replyingToMessage = message);
                },
              ),

              if (canPinThis)
                ListTile(
                  leading: Icon(isAlreadyPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined),
                  title: Text(isAlreadyPinned ? 'Відкріпити' : 'Закріпити'),
                  onTap: () {
                    Navigator.pop(builderContext);
                    if (isAlreadyPinned) {
                      _sendUnpin(message.id);
                    } else {
                      _sendPin(message.id);
                    }
                  },
                ),
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
                  title: const Text('Видалити',
                      style: TextStyle(color: Colors.red)),
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

  Widget _buildReactionPicker(BuildContext modalContext, ChatMessage message) {
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: emojis.map((emoji) {
          final bool isSelected =
              message.reactions[emoji]?.contains(widget.currentUsername) ??
                  false;

          return InkWell(
            onTap: () {
              Navigator.pop(modalContext);
              _sendReaction(message.id, emoji);
            },
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Theme.of(context).primaryColorLight.withOpacity(0.2)
                    : Colors.transparent,
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        }).toList(),
      ),
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
    if (frame.body == null || !mounted) return;
    final data = jsonDecode(frame.body!);
    final type = data['type'];
    final payload = data['payload'];

    print("Received broadcast: $type");

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        switch (type) {
          case 'USER_MESSAGE':
          case 'USER_JOINED_TO_CHAT':
          case 'USER_LEFT_FROM_CHAT':
          case 'COURSE_OPENED':
          case 'COURSE_CLOSED':
          case 'MATERIAL_CREATED':
          case 'MATERIAL_UPDATED':
          case 'MATERIAL_DELETED':
          case 'ASSIGNMENT_CREATED':
          case 'ASSIGNMENT_UPDATED':
          case 'ASSIGNMENT_DELETED':
          case 'ASSIGNMENT_DEADLINE_IN_24HR':
          case 'ASSIGNMENT_DEADLINE_ENDED':
          case 'CONFERENCE_STARTED':
          case 'CONFERENCE_ENDED':
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

          case 'PIN_UPDATE':
            _loadPinnedMessages();
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
            print("Unknown broadcast type received: $type");
        }
      });
    });
  }

  void _handleNewMessage(ChatMessage message) {
    if (_messages.any((m) => m.id == message.id && m.id != 0)) return;

    if (message.username == widget.currentUsername && !message.isSending) {
      final index = _messages.indexWhere((m) =>
      m.isSending &&
          m.content == message.content &&
          m.replyToMessageId == message.replyToMessageId);

      if (index != -1) {
        _messages[index] = message;
        _markAsRead();
        return;
      }
    }

    if (!_messages.any((m) => m.id == message.id)) {
      _messages.add(message);
    }

    _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

    if (message.username == widget.currentUsername) {
      Timer(
        const Duration(milliseconds: 50),
            () {
          if (_scrollController.hasClients) {
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
    final String? username = payload['username'] as String?;
    final String? emoji = payload['emoji'] as String?;

    if (username == null || emoji == null) {
      print("Reaction update received with null username or emoji. Ignoring.");
      return;
    }

    if (username == widget.currentUsername) {
      print("Ignoring optimistic reaction update for self.");
      return;
    }
    setState(() {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messages[index];

        if (message.reactions[emoji] == null) {
          message.reactions[emoji] = [];
        }

        if (message.reactions[emoji]!.contains(username)) {
          message.reactions[emoji]!.remove(username);
          if (message.reactions[emoji]!.isEmpty) {
            message.reactions.remove(emoji);
          }
        } else {
          message.reactions[emoji]!.add(username);
        }
      }
    });
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
    if (content.isEmpty && _mediaToSend.isEmpty) return;
    if (_isUploadingFile) return;

    if (widget.stompClient.connected != true) return;

    _sendStopTyping();

    final tempId = 0 - DateTime.now().millisecondsSinceEpoch;
    final tempMessage = ChatMessage(
      id: tempId,
      chatId: widget.chatId,
      username: widget.currentUsername,
      content: content,
      type: MessageType.USER_MESSAGE,
      sentAt: DateTime.now(),
      isSending: true,
      media: _mediaToSend,
      replyToMessageId: _replyingToMessage?.id,
    );

    setState(() {
      _messages.add(tempMessage);
    });

    Timer(
      const Duration(milliseconds: 50),
          () {
        if (_scrollController.hasClients) {
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
        'replyToMessageId': _replyingToMessage?.id,
        'relatedEntities': [],
        'media': _mediaToSend.map((m) => m.toJson()).toList(),
      }),
    );

    _messageController.clear();
    setState(() {
      _mediaToSend.clear();
      _replyingToMessage = null;
    });
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

  void _sendDelete(int messageId) {
    if (widget.stompClient.connected != true) return;
    widget.stompClient.send(
      destination: '/app/chat/${widget.chatId}/delete',
      body: jsonEncode({
        'messageId': messageId,
      }),
    );
  }

  void _sendPin(int messageId) async {
    if (messageId <= 0) return;
    try {
      await _chatService.pinMessage(
          widget.authToken, widget.chatId, messageId);
      _loadPinnedMessages();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Помилка закріплення: $e'),
            backgroundColor: Colors.red));
    }
  }

  void _sendUnpin(int messageId) async {
    try {
      await _chatService.unpinMessage(
          widget.authToken, widget.chatId, messageId);
      _loadPinnedMessages();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Помилка відкріплення: $e'),
            backgroundColor: Colors.red));
    }
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
        joinedAt: _myMembership.joinedAt,
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
    final List<Media> images = message.media
        .where((m) =>
    m.fileName?.toLowerCase().endsWith('.png') == true ||
        m.fileName?.toLowerCase().endsWith('.jpg') == true ||
        m.fileName?.toLowerCase().endsWith('.jpeg') == true ||
        m.fileName?.toLowerCase().endsWith('.gif') == true)
        .toList();

    final List<Media> files = message.media
        .where((m) => !images.contains(m))
        .toList();

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe && message.username != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, right: 4),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: primaryColor.withOpacity(0.2),
              child: Text(
                message.username![0].toUpperCase(),
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        Flexible(
          child: GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              margin: EdgeInsets.only(
                bottom: 2,
                left: isMe ? 48 : 4,
                right: isMe ? 4 : 48,
                top: 2,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: isMe 
                    ? primaryColor
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe 
                        ? primaryColor.withOpacity(0.2)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe && message.username != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        message.username!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isMe 
                              ? Colors.white.withOpacity(0.95) 
                              : primaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  if (images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _OptimizedImagePreview(publicUrl: images.first.fileUrl),
                        ),
                      ),
                    ),
                  if (files.isNotEmpty)
                    ...files.map((file) => _FileAttachment(file: file, isMe: isMe)),

                  if (message.content.isNotEmpty || message.isDeleted)
                    SelectableText(
                      message.isDeleted ? 'Повідомлення видалено' : message.content,
                      style: TextStyle(
                        color: isMe 
                            ? Colors.white 
                            : AppColors.onSurface,
                        fontSize: 15,
                        height: 1.5,
                        fontStyle: message.isDeleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),

                  if (message.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Wrap(
                        spacing: 4.0,
                        runSpacing: 4.0,
                        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
                        children: message.reactions.entries.map((entry) {
                          final String emoji = entry.key;
                          final List<String> users = entry.value;
                          if (users.isEmpty) return const SizedBox.shrink();

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withOpacity(0.3)
                                  : AppColors.outline.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(14.0),
                            ),
                            child: Text(
                              '$emoji ${users.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isMe 
                                    ? Colors.white 
                                    : AppColors.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.isSending
                              ? "Відправка..."
                              : message.formattedTime,
                          style: TextStyle(
                            color: isMe 
                                ? Colors.white.withOpacity(0.85) 
                                : AppColors.onSurface.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (message.editedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              'ред.',
                              style: TextStyle(
                                color: isMe 
                                    ? Colors.white.withOpacity(0.85) 
                                    : AppColors.onSurface.withOpacity(0.6),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptimizedImagePreview extends StatefulWidget {
  final String publicUrl;
  const _OptimizedImagePreview({required this.publicUrl});

  @override
  State<_OptimizedImagePreview> createState() => _OptimizedImagePreviewState();
}

class _OptimizedImagePreviewState extends State<_OptimizedImagePreview> {
  String? _directUrl;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  Future<void> _resolveUrl() async {

    if (widget.publicUrl.startsWith('http')) {
      try {
        final url = await PCloudService().getDirectImageUrl(widget.publicUrl);
        if (mounted) {
          setState(() {
            _directUrl = url;
          });
        }
      } catch (e) {
        print("Failed to resolve image preview: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_directUrl == null) {
      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Image.network(
      _directUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.broken_image, color: Colors.grey);
      },
    );
  }
}
class _FileAttachment extends StatelessWidget {
  final Media file;
  final bool isMe;
  const _FileAttachment({required this.file, required this.isMe});

  Future<void> _launchFileUrl() async {
    try {
      final directUrl = await PCloudService().getDirectImageUrl(file.fileUrl);
      if (directUrl != null) {
        if (!await launchUrl(Uri.parse(directUrl), mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch $directUrl');
        }
      }
    } catch (e) {
      print("Error launching file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = isMe ? Colors.white : AppColors.onSurface;
    return InkWell(
      onTap: _launchFileUrl,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe 
              ? Colors.white.withOpacity(0.2) 
              : AppColors.outline.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: isMe 
              ? null 
              : Border.all(
                  color: AppColors.outline.withOpacity(0.5), 
                  width: 1,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_rounded, 
              color: color, 
              size: 28,
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                file.fileName ?? 'Файл',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SystemMessageTile extends StatelessWidget {
  final ChatMessage message;
  const _SystemMessageTile({required this.message});

  Map<String, dynamic> _parseContentJson(String content) {
    try {
      if (content.isNotEmpty) {
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Failed to parse system message content: $e");
    }
    return {};
  }

  String _getSystemMessageText() {
    final contentData = _parseContentJson(message.content);

    final String username = contentData['username'] ?? 'Хтось';

    final String materialTopic = contentData['materialTopic'] ?? 'матеріал';
    final String assignmentTitle = contentData['assignmentTitle'] ?? 'завдання';

    switch (message.type) {
      case MessageType.USER_JOINED_TO_CHAT:
        return '$username приєднався до чату.';
      case MessageType.USER_LEFT_FROM_CHAT:
        return '$username покинув чат.';

      case MessageType.COURSE_OPENED:
        return 'Курс відкрито для приєднання.';
      case MessageType.COURSE_CLOSED:
        return 'Курс закрито.';

      case MessageType.MATERIAL_CREATED:
        return 'Створено новий матеріал: "$materialTopic"';
      case MessageType.MATERIAL_UPDATED:
        return 'Оновлено матеріал: "$materialTopic"';
      case MessageType.MATERIAL_DELETED:
        return 'Видалено матеріал: "$materialTopic"';

      case MessageType.ASSIGNMENT_CREATED:
        return 'Створено нове завдання: "$assignmentTitle"';
      case MessageType.ASSIGNMENT_UPDATED:
        return 'Оновлено завдання: "$assignmentTitle"';
      case MessageType.ASSIGNMENT_DELETED:
        return 'Видалено завдання: "$assignmentTitle"';
      case MessageType.ASSIGNMENT_DEADLINE_IN_24HR:
        return 'Дедлайн для завдання "$assignmentTitle" закінчується через 24 години.';
      case MessageType.ASSIGNMENT_DEADLINE_ENDED:
        return 'Дедлайн для завдання "$assignmentTitle" закінчився.';

      case MessageType.CONFERENCE_STARTED:
        return 'Конференція розпочалась.';
      case MessageType.CONFERENCE_ENDED:
        return 'Конференція завершилась.';

      case MessageType.USER_MESSAGE:
        return message.content;
      case MessageType.UNKNOWN:
        return 'Невідома системна подія.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.outline.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _getSystemMessageText(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onSurface.withOpacity(0.7),
            fontSize: 12,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
          ),
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
  final String currentUsername;

  const _RelatedEntityCard({
    required this.entity,
    required this.authToken,
    required this.courseId,
    required this.message,
    required this.currentUsername,
  });

  @override
  State<_RelatedEntityCard> createState() => _RelatedEntityCardState();
}

class _RelatedEntityCardState extends State<_RelatedEntityCard> {
  Future<dynamic>? _entityFuture;
  CourseRole? _courseRole;

  @override
  void initState() {
    super.initState();
    _loadEntityAndRole();
  }

  void _loadEntityAndRole() {
    _entityFuture = Future(() async {
      try {
        final members = await CourseService()
            .getCourseMembers(widget.authToken, widget.courseId);
        final myMember = members.firstWhere(
              (m) => m.username == widget.currentUsername,
          orElse: () => CourseMember(username: '', role: CourseRole.VIEWER),
        );
        if (mounted) {
          setState(() {
            _courseRole = myMember.role;
          });
        }
      } catch (e) {
        print("Error fetching course role in chat: $e");
        if (mounted) {
          setState(() {
            _courseRole = CourseRole.VIEWER;
          });
        }
      }

      if (widget.entity.relatedEntityType == RelatedEntityType.ASSIGNMENT) {
        return CourseService().getAssignmentDetails(
          widget.authToken,
          widget.courseId,
          widget.entity.relatedEntityId,
        );
      } else if (widget.entity.relatedEntityType == RelatedEntityType.MATERIAL) {
        return CourseService().getMaterialDetails(
          widget.authToken,
          widget.courseId,
          widget.entity.relatedEntityId,
        );
      } else if (widget.entity.relatedEntityType ==
          RelatedEntityType.CONFERENCE) {
        return null;
      }
      return null;
    });
  }

  Map<String, dynamic> _parseContentJson(String content) {
    try {
      if (content.isNotEmpty) {
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {}
    return {};
  }

  @override
  Widget build(BuildContext context) {
    Widget loadingCard = Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 32),
      elevation: 1,
      child: ListTile(
        leading: const CircularProgressIndicator(strokeWidth: 2),
        title: Text(widget.message.content.isNotEmpty
            ? widget.message.content
            : "Завантаження..."),
        subtitle: const Text("Завантаження деталей..."),
      ),
    );

    return FutureBuilder<dynamic>(
      future: _entityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingCard;
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _SystemMessageTile(message: widget.message);
        }

        final entityData = snapshot.data;

        if (entityData is Assignment) {
          final assignment = entityData;
          final contentData = _parseContentJson(widget.message.content);
          final title = contentData['assignmentTitle'] ?? assignment.title;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.withOpacity(0.1),
                foregroundColor: Colors.teal.shade700,
                child: const Icon(Icons.assignment_outlined),
              ),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.message.type == MessageType.ASSIGNMENT_CREATED
                      ? "Створено нове завдання"
                      : (widget.message.type == MessageType.USER_MESSAGE
                      ? widget.message.content
                      : "Завдання оновлено")),
                  if (assignment.deadline != null)
                    Text(
                      "Дедлайн: ${DateFormat('dd.MM.yyyy, HH:mm').format(assignment.deadline!.toLocal())}",
                      style:
                      TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                ],
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
              onTap: _courseRole == null
                  ? null
                  : () {
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
        }

        if (entityData is CourseMaterial) {
          final material = entityData;
          final contentData = _parseContentJson(widget.message.content);
          final topic = contentData['materialTopic'] ?? material.topic;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                foregroundColor: Colors.blue.shade700,
                child: const Icon(Icons.article_outlined),
              ),
              title:
              Text(topic, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(widget.message.type == MessageType.MATERIAL_CREATED
                  ? "Створено новий матеріал"
                  : (widget.message.type == MessageType.USER_MESSAGE
                  ? widget.message.content
                  : "Матеріал оновлено")),
              trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
              onTap: _courseRole == null
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaterialDetailScreen(
                      authToken: widget.authToken,
                      courseId: widget.courseId,
                      materialId: material.id,
                      canManage: _courseRole == CourseRole.OWNER ||
                          _courseRole == CourseRole.PROFESSOR,
                    ),
                  ),
                );
              },
            ),
          );
        }

        if (widget.entity.relatedEntityType == RelatedEntityType.CONFERENCE) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.withOpacity(0.1),
                foregroundColor: Colors.purple.shade700,
                child: const Icon(Icons.video_call_outlined),
              ),
              title: Text(
                  widget.message.type == MessageType.CONFERENCE_STARTED
                      ? "Конференція розпочалась"
                      : "Конференція завершилась",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }

        return _SystemMessageTile(message: widget.message);
      },
    );
  }
}

class _PinnedMessageBar extends StatelessWidget {
  final bool isLoading;
  final List<ChatMessage> messages;
  final Function(int messageId) onUnpin;

  const _PinnedMessageBar({
    required this.isLoading,
    required this.messages,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(10.0),
        color: const Color(0xFFF6F4FA),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }
    final message = messages.first;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.15),
        border: Border(
          bottom: BorderSide(
            color: AppColors.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.push_pin_rounded,
          color: AppColors.primary,
          size: 22,
        ),
        title: Text(
          message.isDeleted ? "(Видалене повідомлення)" : message.content,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onSurface,
            fontWeight: FontWeight.w500,
            fontStyle:
            message.isDeleted ? FontStyle.italic : FontStyle.normal),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.close_rounded, 
            size: 20, 
            color: AppColors.onSurface.withOpacity(0.7),
          ),
          onPressed: () => onUnpin(message.id),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:kurs/classes/chat_models.dart';
import 'package:kurs/classes/chat_service.dart';
import 'chat_screen.dart';
import 'package:kurs/screens/pcloud_service.dart';


class ChatsMain extends StatefulWidget {
  final String authToken;
  final String currentUsername;
  final StompClient stompClient;
  final int? filterByCourseId;

  const ChatsMain({
    super.key,
    required this.authToken,
    required this.currentUsername,
    required this.stompClient,
    this.filterByCourseId,
  });

  @override
  State<ChatsMain> createState() => _ChatsMainState();
}

class _ChatsMainState extends State<ChatsMain> {
  final ChatService _chatService = ChatService();

  List<Chat> _chats = [];
  bool _isLoading = true;
  String _error = '';

  final Map<int, void Function()> _chatSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _setupStompListener();
    _loadChats();
  }

  @override
  void dispose() {
    _unsubscribeFromAllChats();
    super.dispose();
  }

  void _setupStompListener() {
    if (widget.stompClient.connected) {
      _onStompConnect(null);
    }
  }


  Future<void> _loadChats() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      final chats = await _chatService.getMyChats(widget.authToken);
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
        final filteredChats = _getFilteredChats(chats);
        _subscribeToChatTopics(filteredChats);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Помилка завантаження чатів:\n${e.toString().replaceFirst(
              "Exception: ", "")}';
        });
      }
    }
  }

  List<Chat> _getFilteredChats(List<Chat> allChats) {
    if (widget.filterByCourseId == null) {
      return allChats.where((chat) =>
      chat.type == ChatType.GROUP || chat.type == ChatType.PRIVATE
      ).toList();
    } else {
      return allChats.where((chat) =>
      chat.courseId == widget.filterByCourseId
      ).toList();
    }
  }


  void _onStompConnect(StompFrame? frame) {
    print("STOMP client connected (ChatsMain).");
    _loadChats();
  }

  void _unsubscribeFromAllChats() {
    print("Unsubscribing from all chat topics...");
    for (var unsubscribe in _chatSubscriptions.values) {
      unsubscribe();
    }
    _chatSubscriptions.clear();
  }

  void _subscribeToChatTopics(List<Chat> chats) {
    _unsubscribeFromAllChats();

    print("Subscribing to ${chats.length} chat topics...");
    for (final chat in chats) {
      final unsubscribe = widget.stompClient.subscribe(
        destination: '/topic/chats/${chat.id}',
        callback: (frame) => _onChatListUpdate(frame, chat.id),
      );
      _chatSubscriptions[chat.id] = unsubscribe;
    }
  }

  void _onChatListUpdate(StompFrame frame, int chatId) {
    if (frame.body == null || !mounted) return;

    try {
      final data = jsonDecode(frame.body!);
      final type = data['type'];
      final payload = data['payload'];

      if (type == 'USER_MESSAGE' ||
          type.startsWith('ASSIGNMENT_') ||
          type.startsWith('MATERIAL_') ||
          type.startsWith('COURSE_') ||
          type == 'USER_JOINED_TO_CHAT' ||
          type == 'USER_LEFT_FROM_CHAT'
      ) {
        final message = ChatMessage.fromJson(payload);

        setState(() {
          final index = _chats.indexWhere((c) => c.id == chatId);
          if (index != -1) {
            final oldChat = _chats[index];
            final updatedChat = oldChat.copyWith(
              lastMessage: message,
              unreadCount: (message.username != widget.currentUsername)
                  ? oldChat.unreadCount + 1
                  : oldChat.unreadCount,
            );
            _chats[index] = updatedChat;
            _chats.sort((a, b) {
              final aTime = a.lastMessage?.sentAt ?? DateTime(1970);
              final bTime = b.lastMessage?.sentAt ?? DateTime(1970);
              return bTime.compareTo(aTime);
            });
          }
        });
      } else if (type == 'READ_LAST_MESSAGE') {
        if (payload['username'] == widget.currentUsername) {
          setState(() {
            final index = _chats.indexWhere((c) => c.id == chatId);
            if (index != -1) {
              _chats[index] = _chats[index].copyWith(unreadCount: 0);
            }
          });
        }
      }
    } catch (e) {
      print("Error processing chat list update: $e");
    }
  }

  Future<void> _showCreateGroupChatDialog() async {
    final nameController = TextEditingController();
    final Chat? newChat = await showDialog<Chat>(
      context: context,
      builder: (dialogContext) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Створити новий груповий чат'),
              content: TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Назва чату'),
                autofocus: true,
                enabled: !isCreating,
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () => Navigator.pop(dialogContext, null),
                  child: const Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                    final chatName = nameController.text.trim();
                    if (chatName.isEmpty) return;

                    setDialogState(() => isCreating = true);

                    try {
                      final createdChat = await _chatService.createGroupChat(
                        widget.authToken,
                        chatName,
                        [widget.currentUsername],
                        photoUrl: null,
                      );

                      if (mounted) {
                        Navigator.pop(dialogContext, createdChat);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Помилка: ${e.toString().replaceFirst(
                                    "Exception: ", "")}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setDialogState(() => isCreating = false);
                      }
                    }
                  },
                  child: isCreating
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Text('Створити'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newChat != null) {
      _handleNewChatCreated(newChat);
    }
  }

  Future<void> _showCreatePrivateChatDialog() async {
    final usernameController = TextEditingController();
    final Chat? newChat = await showDialog<Chat>(
      context: context,
      builder: (dialogContext) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Створити приватний чат'),
              content: TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                    labelText: 'Username співрозмовника'),
                autofocus: true,
                enabled: !isCreating,
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () => Navigator.pop(dialogContext, null),
                  child: const Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                    final username = usernameController.text.trim();
                    if (username.isEmpty) return;
                    if (username == widget.currentUsername) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Ви не можете створити чат з собою.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    setDialogState(() => isCreating = true);

                    try {
                      final createdChat = await _chatService.createPrivateChat(
                        widget.authToken,
                        username,
                      );

                      if (mounted) {
                        Navigator.pop(dialogContext, createdChat);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Помилка: ${e.toString().replaceFirst(
                                    "Exception: ", "")}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setDialogState(() => isCreating = false);
                      }
                    }
                  },
                  child: isCreating
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Text('Почати чат'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newChat != null) {
      _handleNewChatCreated(newChat);
    }
  }

  void _handleNewChatCreated(Chat newChat) {
    _loadChats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чат успішно створено!')),
      );
      _openChat(newChat);
    }
  }

  Future<void> _openChat(Chat chat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatScreen(
              authToken: widget.authToken,
              chatId: chat.id,
              chatName: chat.name,
              currentUsername: widget.currentUsername,
              stompClient: widget.stompClient,
              courseId: chat.courseId,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmbedded = widget.filterByCourseId != null;

    final appBar = AppBar(
      title: const Text('Мої чати'),
      backgroundColor: const Color(0xFF62567E),
      foregroundColor: Colors.white,
      leading: const SizedBox.shrink(),
      flexibleSpace: Container(),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.add_comment_outlined),
          tooltip: 'Створити чат',
          onSelected: (value) {
            if (value == 'group') {
              _showCreateGroupChatDialog();
            } else if (value == 'private') {
              _showCreatePrivateChatDialog();
            }
          },
          itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'private',
              child: ListTile(
                leading: Icon(Icons.person_add_alt_1_outlined),
                title: Text('Приватний чат'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'group',
              child: ListTile(
                leading: Icon(Icons.group_add_outlined),
                title: Text('Груповий чат'),
              ),
            ),
          ],
        ),
      ],
    );

    final body = RefreshIndicator(
      onRefresh: _loadChats,
      child: _buildChatList(),
    );

    if (isEmbedded) {
      return body;
    }

    return Scaffold(
      appBar: appBar,
      body: body,
    );
  }

  Widget _buildChatList() {
    if (_isLoading && _chats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty && _chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Спробувати ще'),
                onPressed: _loadChats,
              ),
            ],
          ),
        ),
      );
    }

    final filteredChats = _getFilteredChats(_chats);

    if (filteredChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.filterByCourseId != null
                ? 'Для цього курсу ще немає чатів.'
                : 'У вас ще немає чатів.'
            ),
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

    filteredChats.sort((a, b) {
      final aTime = a.lastMessage?.sentAt ?? DateTime(1970);
      final bTime = b.lastMessage?.sentAt ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    final visibleChats = filteredChats;

    if (visibleChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.filterByCourseId != null
                ? 'Немає активних чатів у курсі.'
                : 'У вас немає активних чатів.'
            ),
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

    return AnimationLimiter(
      child: ListView.builder(
        itemCount: visibleChats.length,
        itemBuilder: (context, index) {
          final chat = visibleChats[index];

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _ChatListTile(
                  chat: chat,
                  onTap: () => _openChat(chat),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
class _ChatListTile extends StatefulWidget {
  final Chat chat;
  final VoidCallback onTap;

  const _ChatListTile({required this.chat, required this.onTap});

  @override
  State<_ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends State<_ChatListTile> {
  String? _directPhotoUrl;
  bool _isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _resolvePhotoUrl();
  }

  // 💡 Логіка, яка була в CoursesScreen
  Future<void> _resolvePhotoUrl() async {
    if (widget.chat.photoUrl != null && widget.chat.photoUrl!.isNotEmpty) {
      if (!mounted) return;
      setState(() => _isLoadingPhoto = true);
      try {
        final directUrl = await PCloudService().getDirectImageUrl(
          widget.chat.photoUrl!,
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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (_directPhotoUrl != null && _directPhotoUrl!.isNotEmpty)
            ? NetworkImage(_directPhotoUrl!)
            : null,
        child: _isLoadingPhoto
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : (_directPhotoUrl == null || _directPhotoUrl!.isEmpty)
            ? Text(widget.chat.name.isNotEmpty ? widget.chat.name[0].toUpperCase() : '?')
            : null,
      ),
      title: Text(widget.chat.name,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        widget.chat.lastMessage?.content ?? (widget.chat.courseId != null ? 'Немає повідомлень' : 'Переглянути'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: widget.chat.unreadCount > 0
          ? CircleAvatar(
        radius: 12,
        backgroundColor: Colors.red,
        child: Text(
          widget.chat.unreadCount.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      )
          : null,
      onTap: widget.onTap,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:kurs/classes/chat_models.dart';
import 'package:kurs/classes/chat_service.dart';

class ChatMembersScreen extends StatefulWidget {
  final String authToken;
  final int chatId;
  final ChatRole myRole;

  const ChatMembersScreen({
    super.key,
    required this.authToken,
    required this.chatId,
    required this.myRole,
  });

  @override
  State<ChatMembersScreen> createState() => _ChatMembersScreenState();
}

class _ChatMembersScreenState extends State<ChatMembersScreen> {
  final ChatService _chatService = ChatService();
  late Future<List<ChatMember>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() {
    if (mounted) {
      setState(() {
        _membersFuture = _chatService.getChatMembers(widget.authToken, widget.chatId);
      });
    }
  }

  Future<void> _showAddMemberDialog() async {
    final usernameController = TextEditingController();
    final bool? added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Додати учасника'),
            content: TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              enabled: !isLoading,
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Скасувати'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                  final username = usernameController.text.trim();
                  if (username.isEmpty) return;
                  setDialogState(() => isLoading = true);
                  try {
                    await _chatService.addChatMember(
                      widget.authToken,
                      widget.chatId,
                      username,
                    );
                    if (mounted) Navigator.pop(dialogContext, true);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Помилка: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    setDialogState(() => isLoading = false);
                  }
                },
                child: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Додати'),
              ),
            ],
          );
        });
      },
    );

    if (added == true) {
      _loadMembers();
    }
  }

  Future<void> _removeMember(ChatMember member) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити учасника?'),
        content: Text('Ви впевнені, що хочете видалити ${member.username} з чату?'),
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
        await _chatService.removeChatMember(
          widget.authToken,
          widget.chatId,
          member.username,
        );
        _loadMembers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка видалення: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = widget.myRole == ChatRole.OWNER || widget.myRole == ChatRole.ADMIN;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Учасники чату'),
      ),
      body: FutureBuilder<List<ChatMember>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Помилка: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          final members = snapshot.data ?? [];

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final bool canManageThisMember = canManage &&
                  member.role != ChatRole.OWNER &&
                  (widget.myRole == ChatRole.OWNER || member.role != ChatRole.ADMIN);

              return ListTile(
                leading: CircleAvatar(child: Text(member.username[0].toUpperCase())),
                title: Text(member.username),
                subtitle: Text(member.role.name),
                trailing: canManageThisMember
                    ? IconButton(
                  icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                  tooltip: 'Видалити з чату',
                  onPressed: () => _removeMember(member),
                )
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
        onPressed: _showAddMemberDialog,
        tooltip: 'Додати учасника',
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
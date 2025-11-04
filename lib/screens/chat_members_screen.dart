import 'package:flutter/material.dart';
import 'package:kurs/classes/chat_models.dart';
import 'package:kurs/classes/chat_service.dart';

class ChatMembersScreen extends StatefulWidget {
  final String authToken;
  final int chatId;
  final ChatRole myRole;
  final String currentUsername;

  const ChatMembersScreen({
    super.key,
    required this.authToken,
    required this.chatId,
    required this.myRole,
    required this.currentUsername,
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
                          content: Text('Помилка: ${e.toString().replaceFirst("Exception: ", "")}'),
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

  Future<void> _showChangeRoleDialog(ChatMember member) async {
    ChatRole selectedRole = member.role;
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Змінити роль для ${member.username}'),
              content: DropdownButtonFormField<ChatRole>(
                value: selectedRole,
                items: [
                  if (widget.myRole == ChatRole.OWNER)
                    const DropdownMenuItem(value: ChatRole.ADMIN, child: Text('ADMIN')),
                  if (widget.myRole == ChatRole.OWNER || widget.myRole == ChatRole.ADMIN)
                    const DropdownMenuItem(value: ChatRole.MODERATOR, child: Text('MODERATOR')),
                  const DropdownMenuItem(value: ChatRole.MEMBER, child: Text('MEMBER')),
                  const DropdownMenuItem(value: ChatRole.VIEWER, child: Text('VIEWER')),
                ],
                onChanged: isSaving ? null : (value) {
                  if (value != null) {
                    setDialogState(() => selectedRole = value);
                  }
                },
                decoration: const InputDecoration(labelText: 'Нова роль'),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: (selectedRole == member.role || isSaving) ? null : () async {
                    setDialogState(() => isSaving = true);
                    try {
                      await _chatService.updateChatMemberRole(
                        widget.authToken,
                        widget.chatId,
                        member.username,
                        selectedRole,
                      );
                      if (mounted) Navigator.pop(dialogContext, true);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Помилка: ${e.toString().replaceFirst("Exception: ", "")}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      setDialogState(() => isSaving = false);
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

    if (changed == true) {
      _loadMembers();
    }
  }

  Future<void> _showTransferOwnershipDialog(ChatMember member) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Передати права власності?', style: TextStyle(color: Colors.red)),
        content: Text('Ви впевнені, що хочете зробити ${member.username} НОВИМ ВЛАСНИКОМ чату?\n\nВи втратите всі права власника і станете ADMIN. Цю дію НЕМОЖЛИВО скасувати.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Передати права', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _chatService.transferOwnership(
          widget.authToken,
          widget.chatId,
          member.username,
        );
        _loadMembers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Помилка: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red),
          );
        }
      }
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
          members.sort((a, b) => a.role.index.compareTo(b.role.index));


          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final bool isMe = member.username == widget.currentUsername;

              bool amIOwner = widget.myRole == ChatRole.OWNER;
              bool amIAdmin = widget.myRole == ChatRole.ADMIN;
              bool canManageThisMember = !isMe && (
                  amIOwner ||
                      (amIAdmin && member.role != ChatRole.OWNER && member.role != ChatRole.ADMIN)
              );

              return ListTile(
                leading: CircleAvatar(child: Text(member.username[0].toUpperCase())),
                title: Text(member.username + (isMe ? ' (Ви)' : '')),
                subtitle: Text(member.role.name),
                trailing: canManageThisMember
                    ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'role') {
                      _showChangeRoleDialog(member);
                    } else if (value == 'transfer') {
                      _showTransferOwnershipDialog(member);
                    } else if (value == 'remove') {
                      _removeMember(member);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'role',
                      child: ListTile(
                        leading: Icon(Icons.manage_accounts_outlined),
                        title: Text('Змінити роль'),
                      ),
                    ),

                    if (amIOwner)
                      const PopupMenuItem<String>(
                        value: 'transfer',
                        child: ListTile(
                          leading: Icon(Icons.vpn_key_outlined, color: Colors.orange),
                          title: Text('Передати власність', style: TextStyle(color: Colors.orange)),
                        ),
                      ),

                    const PopupMenuDivider(),

                    const PopupMenuItem<String>(
                      value: 'remove',
                      child: ListTile(
                        leading: Icon(Icons.person_remove_outlined, color: Colors.red),
                        title: Text('Видалити з чату', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
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
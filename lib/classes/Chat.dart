class Chat {
  final String name;
  final String lastMessage;
  final String? avatarUrl;

  const Chat({
    required this.name,
    required this.lastMessage,
    this.avatarUrl,
  });
}

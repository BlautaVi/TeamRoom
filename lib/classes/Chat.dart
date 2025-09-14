class Chat {
  final String id;
  final String name;
  String lastMessage;

  Chat({required this.id, required this.name, this.lastMessage = ''});

  factory Chat.fromJson(Map<String, dynamic> json, String currentUserId) {
    var otherParticipant = (json['participants'] as List).firstWhere(
          (p) => p['_id'] != currentUserId,
      orElse: () => {'username': 'Невідомий'},
    );

    return Chat(
      id: json['_id'],
      name: otherParticipant['username'],
      lastMessage: json['lastMessage']?['content'] ?? 'Немає повідомлень',
    );
  }
}
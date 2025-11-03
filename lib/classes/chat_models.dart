import 'package:intl/intl.dart';
enum ChatType {
  PRIVATE,
  GROUP,
  COURSE_CHAT,
  MAIN_COURSE_CHAT,
  UNKNOWN
}

enum MessageType {
  USER_MESSAGE,
  USER_JOINED_TO_CHAT,
  USER_LEFT_FROM_CHAT,
  COURSE_OPENED,
  COURSE_CLOSED,
  MATERIAL_CREATED,
  MATERIAL_UPDATED,
  MATERIAL_DELETED,
  ASSIGNMENT_CREATED,
  ASSIGNMENT_UPDATED,
  ASSIGNMENT_DELETED,
  ASSIGNMENT_DEADLINE_IN_24HR,
  ASSIGNMENT_DEADLINE_ENDED,
  CONFERENCE_STARTED,
  CONFERENCE_ENDED,
  UNKNOWN
}

enum RelatedEntityType { ASSIGNMENT, MATERIAL, CONFERENCE, UNKNOWN }

enum ChatRole { OWNER, ADMIN, MODERATOR, MEMBER, VIEWER, UNKNOWN }


class Chat {
  final int id;
  final String name;
  final String? photoUrl;
  final ChatType type;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final int courseId;

  Chat({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.type,
    this.lastMessage,
    this.unreadCount = 0,
    this.courseId = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Невідомий чат',
      photoUrl: json['photoUrl'],
      type: _parseChatType(json['type']),
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      courseId: json['courseId'] ?? 0,
    );
  }

  static ChatType _parseChatType(String? typeStr) {
    switch (typeStr) {
      case 'PRIVATE':
        return ChatType.PRIVATE;
      case 'GROUP':
        return ChatType.GROUP;
      case 'COURSE_CHAT':
        return ChatType.COURSE_CHAT;
      case 'MAIN_COURSE_CHAT':
        return ChatType.MAIN_COURSE_CHAT;
      default:
        return ChatType.UNKNOWN;
    }
  }
}

class ChatMember {
  final String username;
  final ChatRole role;
  final int lastReadMessageId;
  final DateTime? lastReadAt;

  ChatMember({
    required this.username,
    required this.role,
    this.lastReadMessageId = 0,
    this.lastReadAt,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      username: json['username'] ?? 'unknown',
      role: _parseChatRole(json['role']),
      lastReadMessageId: json['lastReadMessageId'] ?? 0,
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.tryParse(json['lastReadAt'])
          : null,
    );
  }

  static ChatRole _parseChatRole(String? roleStr) {
    switch (roleStr) {
      case 'OWNER':
        return ChatRole.OWNER;
      case 'ADMIN':
        return ChatRole.ADMIN;
      case 'MODERATOR':
        return ChatRole.MODERATOR;
      case 'MEMBER':
        return ChatRole.MEMBER;
      case 'VIEWER':
        return ChatRole.VIEWER;
      default:
        return ChatRole.UNKNOWN;
    }
  }
}

class ChatMessage {
  final int id;
  final int chatId;
  final String username;
  late final String content;
  final MessageType type;
  final int? replyToMessageId;
  final DateTime sentAt;
  final DateTime? editedAt;
  bool isDeleted;
  final List<RelatedEntity> relatedEntities;
  final List<Media> media;

  Map<String, List<String>> reactions;
  bool isSending;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.username,
    required this.content,
    required this.type,
    this.replyToMessageId,
    required this.sentAt,
    this.editedAt,
    this.isDeleted = false,
    this.relatedEntities = const [],
    this.media = const [],
    this.reactions = const {},
    this.isSending = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      chatId: json['chatId'] ?? 0,
      username: json['username'] ?? 'system',
      content: json['content'] ?? '',
      type: _parseMessageType(json['type']),
      replyToMessageId: json['replyToMessageId'],
      sentAt: DateTime.tryParse(json['sentAt'] ?? '') ?? DateTime.now(),
      editedAt: json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'])
          : null,
      isDeleted: json['isDeleted'] ?? false,
      relatedEntities: (json['relatedEntities'] as List? ?? [])
          .map((e) => RelatedEntity.fromJson(e))
          .toList(),
      media: (json['media'] as List? ?? [])
          .map((e) => Media.fromJson(e))
          .toList(),
      reactions: {},
    );
  }

  String get formattedTime {
    return DateFormat('HH:mm').format(sentAt.toLocal());
  }

  static MessageType _parseMessageType(String? typeStr) {
    switch (typeStr) {
      case 'USER_MESSAGE':
        return MessageType.USER_MESSAGE;
      case 'USER_JOINED_TO_CHAT':
        return MessageType.USER_JOINED_TO_CHAT;
      case 'USER_LEFT_FROM_CHAT':
        return MessageType.USER_LEFT_FROM_CHAT;
      case 'ASSIGNMENT_CREATED':
        return MessageType.ASSIGNMENT_CREATED;
      default:
        if (typeStr != null && typeStr != 'USER_MESSAGE') {
          return MessageType.UNKNOWN;
        }
        return MessageType.USER_MESSAGE;
    }
  }
}

class RelatedEntity {
  final RelatedEntityType relatedEntityType;
  final int relatedEntityId;

  RelatedEntity({required this.relatedEntityType, required this.relatedEntityId});

  factory RelatedEntity.fromJson(Map<String, dynamic> json) {
    return RelatedEntity(
      relatedEntityType: _parseRelatedEntityType(json['relatedEntityType']),
      relatedEntityId: json['relatedEntityId'] ?? 0,
    );
  }

  static RelatedEntityType _parseRelatedEntityType(String? typeStr) {
    switch (typeStr) {
      case 'ASSIGNMENT':
        return RelatedEntityType.ASSIGNMENT;
      case 'MATERIAL':
        return RelatedEntityType.MATERIAL;
      case 'CONFERENCE':
        return RelatedEntityType.CONFERENCE;
      default:
        return RelatedEntityType.UNKNOWN;
    }
  }
}

class Media {
  final String fileUrl;
  final String? fileName;
  final String? fileType;
  final int? fileSizeBytes;

  Media({
    required this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSizeBytes,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      fileUrl: json['fileUrl'] ?? '',
      fileName: json['fileName'],
      fileType: json['fileType'],
      fileSizeBytes: json['fileSizeBytes'],
    );
  }
}
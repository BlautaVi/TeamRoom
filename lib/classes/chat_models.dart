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

enum ConferenceStatus { ACTIVE, ENDED, UNKNOWN }

enum ConferenceRole { MODERATOR, MEMBER, VIEWER, UNKNOWN }


class Conference {
  final int id;
  final int courseId;
  final String subject;
  final String roomName;
  final ConferenceStatus status;
  final DateTime createdAt;
  final DateTime? endedAt;
  final List<ConferenceParticipant> participants;

  Conference({
    required this.id,
    required this.courseId,
    required this.subject,
    required this.roomName,
    required this.status,
    required this.createdAt,
    this.endedAt,
    this.participants = const [],
  });

  factory Conference.fromJson(Map<String, dynamic> json) {
    return Conference(
      id: json['id'] ?? 0,
      courseId: json['courseId'] ?? 0,
      subject: json['subject'] ?? '',
      roomName: json['roomName'] ?? '',
      status: _parseConferenceStatus(json['status']),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt']) : null,
      participants: (json['participants'] as List? ?? [])
          .map((e) => ConferenceParticipant.fromJson(e))
          .toList(),
    );
  }

  int get participantCount => participants.length;

  static ConferenceStatus _parseConferenceStatus(String? statusStr) {
    switch (statusStr) {
      case 'ACTIVE':
        return ConferenceStatus.ACTIVE;
      case 'ENDED':
        return ConferenceStatus.ENDED;
      default:
        return ConferenceStatus.UNKNOWN;
    }
  }
}

class ConferenceParticipant {
  final String username;
  final ConferenceRole role;
  final DateTime joinedAt;
  final DateTime? leftAt;

  ConferenceParticipant({
    required this.username,
    required this.role,
    required this.joinedAt,
    this.leftAt,
  });

  factory ConferenceParticipant.fromJson(Map<String, dynamic> json) {
    return ConferenceParticipant(
      username: json['username'] ?? 'unknown',
      role: _parseConferenceRole(json['role']),
      joinedAt: DateTime.tryParse(json['joinedAt'] ?? '') ?? DateTime.now(),
      leftAt: json['leftAt'] != null ? DateTime.tryParse(json['leftAt']) : null,
    );
  }

  static ConferenceRole _parseConferenceRole(String? roleStr) {
    switch (roleStr) {
      case 'MODERATOR':
        return ConferenceRole.MODERATOR;
      case 'MEMBER':
        return ConferenceRole.MEMBER;
      case 'VIEWER':
        return ConferenceRole.VIEWER;
      default:
        return ConferenceRole.UNKNOWN;
    }
  }
}

class ConferenceJoinData {
  final String jwt;
  final String roomName;
  final ConferenceRole role;
  final String jitsiServerUrl;

  ConferenceJoinData({
    required this.jwt,
    required this.roomName,
    required this.role,
    this.jitsiServerUrl = 'https://team-room-jitsi.duckdns.org',
  });

  factory ConferenceJoinData.fromJson(Map<String, dynamic> json) {
    final jwt = json['jwt'] as String?;
    final roomName = json['roomName'] as String?;
    final role = json['role'] as String?;
    
    if (jwt == null || jwt.isEmpty) {
      throw Exception('JWT токен не отримано від сервера');
    }
    if (roomName == null || roomName.isEmpty) {
      throw Exception('Назва кімнати не отримана від сервера');
    }
    if (role == null || role.isEmpty) {
      throw Exception('Роль користувача не визначена');
    }
    
    return ConferenceJoinData(
      jwt: jwt,
      roomName: roomName,
      role: _parseConferenceRole(role),
      jitsiServerUrl: json['jitsiServerUrl'] ?? 'https://team-room-jitsi.duckdns.org',
    );
  }

  static ConferenceRole _parseConferenceRole(String? roleStr) {
    switch (roleStr) {
      case 'MODERATOR':
        return ConferenceRole.MODERATOR;
      case 'MEMBER':
        return ConferenceRole.MEMBER;
      case 'VIEWER':
        return ConferenceRole.VIEWER;
      default:
        return ConferenceRole.UNKNOWN;
    }
  }
}


class Chat {
  final int id;
  final String name;
  final String? photoUrl;
  final ChatType type;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final int? courseId;

  Chat({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.type,
    this.lastMessage,
    this.unreadCount = 0,
    this.courseId,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    final parsedType = _parseChatType(json['type']);
    final rawName = (json['name'] as String?)?.trim();

    final resolvedName = (rawName == null || rawName.isEmpty)
        ? (
        parsedType == ChatType.COURSE_CHAT || parsedType == ChatType.MAIN_COURSE_CHAT
            ? 'Чат курсу'
            : parsedType == ChatType.PRIVATE
            ? 'Приватний чат'
            : 'Невідомий чат'
    )
        : rawName;

    return Chat(
      id: json['id'] ?? 0,
      name: resolvedName,
      photoUrl: json['photoUrl'],
      type: parsedType,
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      courseId: json['courseId'],
    );
  }

  Chat copyWith({
    int? id,
    String? name,
    String? photoUrl,
    ChatType? type,
    ChatMessage? lastMessage,
    int? unreadCount,
    int? courseId,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      type: type ?? this.type,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      courseId: courseId ?? this.courseId,
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
  final DateTime? joinedAt;

  ChatMember({
    required this.username,
    required this.role,
    this.lastReadMessageId = 0,
    this.lastReadAt,
    this.joinedAt,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      username: json['username'] ?? 'unknown',
      role: _parseChatRole(json['role']),
      lastReadMessageId: json['lastReadMessageId'] ?? 0,
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.tryParse(json['lastReadAt'])
          : null,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'])
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
  final String? username;
  late final String content;
  final MessageType type;
  final int? replyToMessageId;
  final DateTime sentAt;
  final DateTime? editedAt;
  bool isDeleted;
  bool isPinned;
  final List<RelatedEntity> relatedEntities;
  final List<Media> media;

  Map<String, List<String>> reactions;
  bool isSending;

  ChatMessage({
    required this.id,
    required this.chatId,
    this.username,
    required this.content,
    required this.type,
    this.replyToMessageId,
    required this.sentAt,
    this.editedAt,
    this.isDeleted = false,
    this.isPinned = false,
    this.relatedEntities = const [],
    this.media = const [],
    this.reactions = const {},
    this.isSending = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      chatId: json['chatId'] ?? 0,
      username: json['username'],
      content: json['content'] ?? '',
      type: _parseMessageType(json['type']),
      replyToMessageId: json['replyToMessageId'],
      sentAt: DateTime.tryParse(json['sentAt'] ?? '') ?? DateTime.now(),
      editedAt: json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'])
          : null,
      isDeleted: json['isDeleted'] ?? false,
      isPinned: json['isPinned'] ?? false,
      relatedEntities: (json['relatedEntities'] as List? ?? [])
          .map((e) => RelatedEntity.fromJson(e))
          .toList(),
      media: (json['media'] as List? ?? [])
          .map((e) => Media.fromJson(e))
          .toList(),

      reactions: _parseReactions(json['reactions']),

      isSending: false,
    );
  }

  static Map<String, List<String>> _parseReactions(dynamic reactionsJson) {
    if (reactionsJson == null || reactionsJson is! List) {
      return {};
    }

    final Map<String, List<String>> reactionsMap = {};
    try {
      for (var reactionObject in reactionsJson) {
        if (reactionObject is Map) {
          final String? emoji = reactionObject['emoji'] as String?;
          final String? username = reactionObject['username'] as String?;

          if (emoji != null && username != null) {
            if (reactionsMap[emoji] == null) {
              reactionsMap[emoji] = [];
            }
            if (!reactionsMap[emoji]!.contains(username)) {
              reactionsMap[emoji]!.add(username);
            }
          }
        }
      }
    } catch (e) {
      print("Error parsing reactions list: $e");
      return {};
    }
    return reactionsMap;
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
      case 'COURSE_OPENED':
        return MessageType.COURSE_OPENED;
      case 'COURSE_CLOSED':
        return MessageType.COURSE_CLOSED;
      case 'MATERIAL_CREATED':
        return MessageType.MATERIAL_CREATED;
      case 'MATERIAL_UPDATED':
        return MessageType.MATERIAL_UPDATED;
      case 'MATERIAL_DELETED':
        return MessageType.MATERIAL_DELETED;
      case 'ASSIGNMENT_CREATED':
        return MessageType.ASSIGNMENT_CREATED;
      case 'ASSIGNMENT_UPDATED':
        return MessageType.ASSIGNMENT_UPDATED;
      case 'ASSIGNMENT_DELETED':
        return MessageType.ASSIGNMENT_DELETED;
      case 'ASSIGNMENT_DEADLINE_IN_24HR':
        return MessageType.ASSIGNMENT_DEADLINE_IN_24HR;
      case 'ASSIGNMENT_DEADLINE_ENDED':
        return MessageType.ASSIGNMENT_DEADLINE_ENDED;
      case 'CONFERENCE_STARTED':
        return MessageType.CONFERENCE_STARTED;
      case 'CONFERENCE_ENDED':
        return MessageType.CONFERENCE_ENDED;
      default:
        if (typeStr != null && typeStr != 'USER_MESSAGE') {
          print("Warning: Unknown MessageType received: $typeStr");
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
  Map<String, dynamic> toJson() {
    return {
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'fileSizeBytes': fileSizeBytes,
    };
  }
}
enum WebSocketMessageType {
  JOINED_TO_COURSE,
  REMOVED_FROM_COURSE,
  ROLE_CHANGED_IN_COURSE,
  COURSE_UPDATED,
  COURSE_DELETED,
  MATERIAL_CREATED,
  MATERIAL_UPDATED,
  MATERIAL_DELETED,
  ASSIGNMENT_CREATED,
  ASSIGNMENT_UPDATED,
  ASSIGNMENT_DELETED,
  ASSIGNMENT_RESPONSE_CREATED,
  ASSIGNMENT_RESPONSE_UPDATED,
  ASSIGNMENT_RESPONSE_DELETED,
  UNKNOWN,
}

WebSocketMessageType parseMessageType(String type) {
  return WebSocketMessageType.values.firstWhere(
    (e) => e.name == type,
    orElse: () => WebSocketMessageType.UNKNOWN,
  );
}

abstract class WebSocketPayload {
  factory WebSocketPayload.fromJson(
      WebSocketMessageType type, Map<String, dynamic> json) {
    switch (type) {
      case WebSocketMessageType.JOINED_TO_COURSE:
        return JoinedToCoursePayload.fromJson(json);
      case WebSocketMessageType.REMOVED_FROM_COURSE:
        return RemovedFromCoursePayload.fromJson(json);
      case WebSocketMessageType.ROLE_CHANGED_IN_COURSE:
        return RoleChangedInCoursePayload.fromJson(json);
      case WebSocketMessageType.COURSE_UPDATED:
        return CourseUpdatedPayload.fromJson(json);
      case WebSocketMessageType.COURSE_DELETED:
        return CourseDeletedPayload.fromJson(json);
      case WebSocketMessageType.MATERIAL_CREATED:
        return MaterialCreatedPayload.fromJson(json);
      case WebSocketMessageType.MATERIAL_UPDATED:
        return MaterialUpdatedPayload.fromJson(json);
      case WebSocketMessageType.MATERIAL_DELETED:
        return MaterialDeletedPayload.fromJson(json);
      case WebSocketMessageType.ASSIGNMENT_CREATED:
        return AssignmentCreatedPayload.fromJson(json);
      case WebSocketMessageType.ASSIGNMENT_UPDATED:
        return AssignmentUpdatedPayload.fromJson(json);
      case WebSocketMessageType.ASSIGNMENT_DELETED:
        return AssignmentDeletedPayload.fromJson(json);
      case WebSocketMessageType.ASSIGNMENT_RESPONSE_CREATED:
        return AssignmentResponseCreatedPayload.fromJson(json);
      case WebSocketMessageType.ASSIGNMENT_RESPONSE_UPDATED:
        return AssignmentResponseUpdatedPayload.fromJson(json);
      case WebSocketMessageType.ASSIGNMENT_RESPONSE_DELETED:
        return AssignmentResponseDeletedPayload.fromJson(json);
      default:
        return UnknownPayload(json);
    }
  }
}

class WebSocketBroadcast {
  final WebSocketMessageType type;
  final WebSocketPayload payload;

  WebSocketBroadcast({
    required this.type,
    required this.payload,
  });

  factory WebSocketBroadcast.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'UNKNOWN';
    final type = parseMessageType(typeStr);
    final payloadData = (json['payload'] as Map<String, dynamic>?) ?? {};

    return WebSocketBroadcast(
      type: type,
      payload: WebSocketPayload.fromJson(type, payloadData),
    );
  }
}

// Payload Classes

class JoinedToCoursePayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final String role;
  final String joinedAt;

  JoinedToCoursePayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.role,
    required this.joinedAt,
  });

  factory JoinedToCoursePayload.fromJson(Map<String, dynamic> json) {
    return JoinedToCoursePayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      role: json['role'] ?? '',
      joinedAt: json['joined_at'] ?? '',
    );
  }
}

class RemovedFromCoursePayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;

  RemovedFromCoursePayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
  });

  factory RemovedFromCoursePayload.fromJson(Map<String, dynamic> json) {
    return RemovedFromCoursePayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
    );
  }
}

class RoleChangedInCoursePayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final String oldRole;
  final String newRole;

  RoleChangedInCoursePayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.oldRole,
    required this.newRole,
  });

  factory RoleChangedInCoursePayload.fromJson(Map<String, dynamic> json) {
    return RoleChangedInCoursePayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      oldRole: json['old_role'] ?? '',
      newRole: json['new_role'] ?? '',
    );
  }
}

class CourseUpdatedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;

  CourseUpdatedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
  });

  factory CourseUpdatedPayload.fromJson(Map<String, dynamic> json) {
    return CourseUpdatedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
    );
  }
}

class CourseDeletedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;

  CourseDeletedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
  });

  factory CourseDeletedPayload.fromJson(Map<String, dynamic> json) {
    return CourseDeletedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
    );
  }
}

class MaterialCreatedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final int materialId;
  final String materialTopic;
  final String authorUsername;
  final String authorFirstName;
  final String authorLastName;
  final String? authorPhotoUrl;

  MaterialCreatedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.materialId,
    required this.materialTopic,
    required this.authorUsername,
    required this.authorFirstName,
    required this.authorLastName,
    this.authorPhotoUrl,
  });

  factory MaterialCreatedPayload.fromJson(Map<String, dynamic> json) {
    return MaterialCreatedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      materialId: json['material_id'] ?? 0,
      materialTopic: json['material_topic'] ?? '',
      authorUsername: json['author_username'] ?? '',
      authorFirstName: json['author_first_name'] ?? '',
      authorLastName: json['author_last_name'] ?? '',
      authorPhotoUrl: json['author_photo_url'],
    );
  }
}

class MaterialUpdatedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final int materialId;
  final String materialTopic;

  MaterialUpdatedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.materialId,
    required this.materialTopic,
  });

  factory MaterialUpdatedPayload.fromJson(Map<String, dynamic> json) {
    return MaterialUpdatedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      materialId: json['material_id'] ?? 0,
      materialTopic: json['material_topic'] ?? '',
    );
  }
}

class MaterialDeletedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final int materialId;
  final String materialTopic;

  MaterialDeletedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.materialId,
    required this.materialTopic,
  });

  factory MaterialDeletedPayload.fromJson(Map<String, dynamic> json) {
    return MaterialDeletedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      materialId: json['material_id'] ?? 0,
      materialTopic: json['material_topic'] ?? '',
    );
  }
}

class AssignmentCreatedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final int assignmentId;
  final String assignmentTitle;
  final String authorUsername;
  final String authorFirstName;
  final String authorLastName;
  final String? authorPhotoUrl;

  AssignmentCreatedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.authorUsername,
    required this.authorFirstName,
    required this.authorLastName,
    this.authorPhotoUrl,
  });

  factory AssignmentCreatedPayload.fromJson(Map<String, dynamic> json) {
    return AssignmentCreatedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      assignmentId: json['assignment_id'] ?? 0,
      assignmentTitle: json['assignment_title'] ?? '',
      authorUsername: json['author_username'] ?? '',
      authorFirstName: json['author_first_name'] ?? '',
      authorLastName: json['author_last_name'] ?? '',
      authorPhotoUrl: json['author_photo_url'],
    );
  }
}

class AssignmentUpdatedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final int assignmentId;
  final String assignmentTitle;

  AssignmentUpdatedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  factory AssignmentUpdatedPayload.fromJson(Map<String, dynamic> json) {
    return AssignmentUpdatedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      assignmentId: json['assignment_id'] ?? 0,
      assignmentTitle: json['assignment_title'] ?? '',
    );
  }
}

class AssignmentDeletedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final int assignmentId;
  final String assignmentTitle;

  AssignmentDeletedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  factory AssignmentDeletedPayload.fromJson(Map<String, dynamic> json) {
    return AssignmentDeletedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      assignmentId: json['assignment_id'] ?? 0,
      assignmentTitle: json['assignment_title'] ?? '',
    );
  }
}

class AssignmentResponseCreatedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final int assignmentId;
  final String assignmentTitle;
  final int responseAssignmentId;
  final String responseAuthorUsername;
  final String responseAuthorFirstName;
  final String responseAuthorLastName;
  final String? responseAuthorPhotoUrl;

  AssignmentResponseCreatedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.responseAssignmentId,
    required this.responseAuthorUsername,
    required this.responseAuthorFirstName,
    required this.responseAuthorLastName,
    this.responseAuthorPhotoUrl,
  });

  factory AssignmentResponseCreatedPayload.fromJson(
      Map<String, dynamic> json) {
    return AssignmentResponseCreatedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      assignmentId: json['assignment_id'] ?? 0,
      assignmentTitle: json['assignment_title'] ?? '',
      responseAssignmentId: json['response_assignment_id'] ?? 0,
      responseAuthorUsername: json['response_author_username'] ?? '',
      responseAuthorFirstName: json['response_author_first_name'] ?? '',
      responseAuthorLastName: json['response_author_last_name'] ?? '',
      responseAuthorPhotoUrl: json['response_author_photo_url'],
    );
  }
}

class AssignmentResponseUpdatedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final int assignmentId;
  final String assignmentTitle;
  final int responseAssignmentId;

  AssignmentResponseUpdatedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.responseAssignmentId,
  });

  factory AssignmentResponseUpdatedPayload.fromJson(
      Map<String, dynamic> json) {
    return AssignmentResponseUpdatedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      assignmentId: json['assignment_id'] ?? 0,
      assignmentTitle: json['assignment_title'] ?? '',
      responseAssignmentId: json['response_assignment_id'] ?? 0,
    );
  }
}

class AssignmentResponseDeletedPayload implements WebSocketPayload {
  final int courseId;
  final String courseName;
  final String? coursePhotoUrl;
  final int assignmentId;
  final String assignmentTitle;
  final int responseAssignmentId;
  final String responseAuthorUsername;
  final String responseAuthorFirstName;
  final String responseAuthorLastName;
  final String? responseAuthorPhotoUrl;

  AssignmentResponseDeletedPayload({
    required this.courseId,
    required this.courseName,
    this.coursePhotoUrl,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.responseAssignmentId,
    required this.responseAuthorUsername,
    required this.responseAuthorFirstName,
    required this.responseAuthorLastName,
    this.responseAuthorPhotoUrl,
  });

  factory AssignmentResponseDeletedPayload.fromJson(
      Map<String, dynamic> json) {
    return AssignmentResponseDeletedPayload(
      courseId: json['course_id'] ?? 0,
      courseName: json['course_name'] ?? '',
      coursePhotoUrl: json['course_photoUrl'],
      assignmentId: json['assignment_id'] ?? 0,
      assignmentTitle: json['assignment_title'] ?? '',
      responseAssignmentId: json['response_assignment_id'] ?? 0,
      responseAuthorUsername: json['response_author_username'] ?? '',
      responseAuthorFirstName: json['response_author_first_name'] ?? '',
      responseAuthorLastName: json['response_author_last_name'] ?? '',
      responseAuthorPhotoUrl: json['response_author_photo_url'],
    );
  }
}

class UnknownPayload implements WebSocketPayload {
  final Map<String, dynamic> data;

  UnknownPayload(this.data);
}

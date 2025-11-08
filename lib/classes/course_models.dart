
enum CourseRole { OWNER, PROFESSOR, LEADER, STUDENT, VIEWER }

class Course {
  final int id;
  final String name;
  final String? photoUrl;
  final bool isOpen;
  final int memberCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? description;

  Course({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.isOpen,
    required this.memberCount,
    this.createdAt,
    this.updatedAt,
    this.description,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    int count = json['membersCount'] ?? (json['members'] as List?)?.length ?? 0;
    return Course(
      id: json['id'],
      name: json['name'] ?? 'Без назви',
      photoUrl: json['photoUrl'],
      isOpen: json['isOpen'] ?? json['open'] ?? true,
      memberCount: count,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      description: json['description'],
    );
  }
}

class CourseMember {
  final String username;
  final CourseRole role;

  CourseMember({required this.username, required this.role});

  factory CourseMember.fromJson(Map<String, dynamic> json) {
    String roleString = (json['role'] as String?)?.toUpperCase() ?? 'VIEWER';
    CourseRole role = CourseRole.values.firstWhere(
          (e) => e.name.toUpperCase() == roleString,
      orElse: () => CourseRole.VIEWER,
    );
    return CourseMember(username: json['username'] ?? 'unknown', role: role);
  }
}

class Tag {
  final String name;

  Tag({required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) =>
      Tag(name: json['name'] ?? '');
}

class MediaFile {
  final int id;
  final String displayName;
  final String fileUrl;

  MediaFile({
    required this.id,
    required this.displayName,
    required this.fileUrl,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      id: json['id'] ?? 0,
      displayName:
      json['name'] ?? json['fileUrl']?.split('/').last ?? 'unnamed_file',
      fileUrl: json['fileUrl'] ?? '',
    );
  }
}

class CourseMaterial {
  final int id;
  final String topic;
  final String textContent;
  final String authorUsername;
  final List<Tag> tags;
  final List<MediaFile> media;

  CourseMaterial({
    required this.id,
    required this.topic,
    required this.textContent,
    required this.authorUsername,
    this.tags = const [],
    this.media = const [],
  });

  factory CourseMaterial.fromJson(Map<String, dynamic> json) {
    return CourseMaterial(
      id: json['id'] ?? 0,
      topic: json['topic'] ?? 'Без теми',
      textContent: json['textContent'] ?? '',
      authorUsername: json['authorUsername'] ?? 'unknown',
      tags: (json['tags'] as List? ?? [])
          .map((tagJson) => Tag.fromJson(tagJson))
          .toList(),
      media: (json['media'] as List? ?? [])
          .map((fileJson) => MediaFile.fromJson(fileJson))
          .toList(),
    );
  }
}

class Assignment {
  final int id;
  final String title;
  final String description;
  final String authorUsername;
  final DateTime? deadline;
  final int? maxGrade;
  final List<Tag> tags;
  final List<MediaFile> media;

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.authorUsername,
    this.deadline,
    this.maxGrade,
    this.tags = const [],
    this.media = const [],
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return Assignment(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Без теми',
      description: json['description'] ?? '',
      authorUsername: json['authorUsername'] ?? 'unknown',
      deadline: parseDate(json['deadline']),
      maxGrade: json['maxGrade'],
      tags: (json['tags'] as List? ?? [])
          .map((tagJson) => Tag.fromJson(tagJson))
          .toList(),
      media: (json['media'] as List? ?? [])
          .map((fileJson) => MediaFile.fromJson(fileJson))
          .toList(),
    );
  }
}

class AssignmentResponse {
  final int id;
  final int assignmentId;
  final String authorUsername;
  final bool isReturned;
  final String? returnComment;
  final bool isGraded;
  final int? grade;
  final String? gradeComment;
  final List<MediaFile> media;

  AssignmentResponse({
    required this.id,
    required this.assignmentId,
    required this.authorUsername,
    required this.isReturned,
    this.returnComment,
    required this.isGraded,
    this.grade,
    this.gradeComment,
    this.media = const [],
  });

  factory AssignmentResponse.fromJson(Map<String, dynamic> json) {
    String author =
        json['authorUsername'] ?? json['author_username'] ?? 'unknown_author';
    return AssignmentResponse(
      id: json['id'] ?? json['responseId'] ?? 0,
      assignmentId: json['assignment_id'] ?? json['assignmentId'] ?? 0,
      authorUsername: author,
      isReturned: json['is_returned'] ?? json['isReturned'] ?? false,
      returnComment: json['return_comment'] ?? json['returnComment'],
      isGraded: json['is_graded'] ?? json['isGraded'] ?? false,
      grade: json['grade'],
      gradeComment: json['grade_comment'] ?? json['gradeComment'],
      media: (json['media'] as List? ?? [])
          .map((fileJson) => MediaFile.fromJson(fileJson))
          .toList(),
    );
  }
}

class GradebookData {
  final List<CourseMember> students;
  final List<Assignment> assignments;
  final Map<String, Map<int, AssignmentResponse>> studentResponses;

  GradebookData({
    required this.students,
    required this.assignments,
    required this.studentResponses,
  });
}
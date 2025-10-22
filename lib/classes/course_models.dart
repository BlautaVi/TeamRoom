import 'dart:convert';

enum CourseRole { OWNER, PROFESSOR, LEADER, STUDENT, VIEWER }

class Course {
  final int id;
  final String name;
  final String? photoUrl;
  final bool isOpen;
  final int memberCount;

  Course({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.isOpen,
    required this.memberCount,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) {
      print("Error: Course JSON missing 'id': $json");
      throw FormatException("Field 'id' is missing in Course JSON.");
    }
    int count = json['memberCount'] ?? 0;
    return Course(
      id: json['id'],
      name: json['name'] ?? 'Без назви',
      photoUrl: json['photoUrl'],
      isOpen: json['open'] ?? true,
      memberCount: count,
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
      orElse: () {
        print(
          "Warning: Unknown role '$roleString' received for user '${json['username']}'. Defaulting to VIEWER.",
        );
        return CourseRole.VIEWER;
      },
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
    if (json['id'] == null) {
      print("Warning: MediaFile JSON missing 'id': $json");
    }
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
    if (json['id'] == null) {
      print("Warning: CourseMaterial JSON missing 'id': $json");
    }
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
  final String? description;
  final String authorUsername;
  final DateTime? dueDate;
  final double? maxGrade;
  final List<MediaFile> media;

  Assignment({
    required this.id,
    required this.title,
    this.description,
    required this.authorUsername,
    this.dueDate,
    this.maxGrade,
    this.media = const [],
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Без назви',
      description: json['description'],
      authorUsername: json['authorUsername'] ?? 'unknown',
      dueDate:
      json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      maxGrade: (json['maxGrade'] as num?)?.toDouble(),
      media: (json['media'] as List? ?? [])
          .map((fileJson) => MediaFile.fromJson(fileJson))
          .toList(),
    );
  }
}

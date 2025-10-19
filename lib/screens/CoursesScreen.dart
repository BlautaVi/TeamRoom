import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    if (json['id'] == null) throw FormatException("Field 'id' is missing in Course JSON.");
    return Course(
      id: json['id'],
      name: json['name'] ?? 'Без назви',
      photoUrl: json['photoUrl'],
      isOpen: json['open'] ?? true,
      memberCount: json['memberCount'] ?? (json['members'] as List?)?.length ?? 0,
    );
  }
}

class CourseMember {
  final String username;
  final CourseRole role;
  CourseMember({required this.username, required this.role});

  factory CourseMember.fromJson(Map<String, dynamic> json) {
    return CourseMember(
      username: json['username'] ?? 'unknown',
      role: CourseRole.values.firstWhere(
            (e) => e.name.toUpperCase() == (json['role'] as String?)?.toUpperCase(),
        orElse: () => CourseRole.VIEWER,
      ),
    );
  }
}

class Tag {
  final String name;
  Tag({required this.name});
  factory Tag.fromJson(Map<String, dynamic> json) => Tag(name: json['name'] ?? '');
}

class MediaFile {
  final int id;
  final String displayName;
  final String fileUrl;
  MediaFile({required this.id, required this.displayName, required this.fileUrl});

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      id: json['id'],
      displayName: json['name'] ?? json['fileUrl']?.split('_*file*_')?.first ?? 'unnamed_file',
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
      id: json['id'],
      topic: json['topic'] ?? 'Без теми',
      textContent: json['textContent'] ?? '',
      authorUsername: json['authorUsername'] ?? 'unknown',
      tags: (json['tags'] as List? ?? []).map((tagJson) => Tag.fromJson(tagJson)).toList(),
      media: (json['media'] as List? ?? []).map((fileJson) => MediaFile.fromJson(fileJson)).toList(),
    );
  }
}

class CourseService {
  final String _baseUrl = "https://team-room-back.onrender.com/api/course";

  Future<List<Course>> getCourses(String token) async {
    final response = await http.get(Uri.parse(_baseUrl), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['courses'] as List).map((c) => Course.fromJson(c)).toList();
    } else {
      throw Exception('Не вдалося завантажити курси. Статус: ${response.statusCode}');
    }
  }

  Future<void> createCourse(String token, String name, {String? photoUrl}) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'photoUrl': photoUrl}),
    );
    if (response.statusCode != 200) {
      throw Exception('Не вдалося створити курс. Статус: ${response.statusCode}');
    }
  }

  Future<void> joinCourse(String token, int courseId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/$courseId/members'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Не вдалося приєднатися до курсу. Статус: ${response.statusCode}');
    }
  }

  Future<List<CourseMember>> getCourseMembers(String token, int courseId) async {
    final response = await http.get(Uri.parse('$_baseUrl/$courseId'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['members'] as List).map((m) => CourseMember.fromJson(m)).toList();
    } else {
      throw Exception('Не вдалося завантажити учасників. Статус: ${response.statusCode}');
    }
  }

  Future<List<CourseMaterial>> getCourseMaterials(String token, int courseId) async {
    final response = await http.get(Uri.parse('$_baseUrl/$courseId/materials'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['materials'] as List).map((m) => CourseMaterial.fromJson(m)).toList();
    } else {
      throw Exception('Не вдалося завантажити матеріали. Статус: ${response.statusCode}');
    }
  }

  Future<CourseMaterial> getMaterialDetails(String token, int courseId, int materialId) async {
    final response = await http.get(Uri.parse('$_baseUrl/$courseId/materials/$materialId'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return CourseMaterial.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Не вдалося завантажити деталі матеріалу. Статус: ${response.statusCode}');
    }
  }

  Future<int> createMaterial(String token, int courseId, String topic, String textContent, List<String> tags) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/$courseId/materials'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'topic': topic,
        'textContent': textContent,
        'tags': tags.map((name) => {'name': name}).toList(),
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['id'];
    } else {
      throw Exception('Не вдалося створити матеріал. Статус: ${response.statusCode}');
    }
  }

  Future<void> updateMaterial(String token, int courseId, int materialId, String topic, String textContent, List<String> tags) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/$courseId/materials/$materialId'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'topic': topic,
        'textContent': textContent,
        'tags': tags.map((name) => {'name': name}).toList(),
        'media': [],
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Не вдалося оновити матеріал. Статус: ${response.statusCode}');
    }
  }

  Future<void> uploadMaterialFile(String token, int courseId, int materialId, PlatformFile file) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/$courseId/materials/$materialId/media'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    var response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Не вдалося завантажити файл. Статус: ${response.statusCode}');
    }
  }

  Future<void> deleteMaterial(String token, int courseId, int materialId) async {
    final response = await http.delete(Uri.parse('$_baseUrl/$courseId/materials/$materialId'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) {
      throw Exception('Не вдалося видалити матеріал. Статус: ${response.statusCode}');
    }
  }

  Future<void> addMember(String token, int courseId, String username, CourseRole role) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/$courseId/members'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'role': role.name}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception('Не вдалося додати учасника: ${error['message'] ?? 'Невідома помилка'}');
    }
  }
}

class CoursesScreen extends StatefulWidget {
  final String authToken;
  const CoursesScreen({super.key, required this.authToken});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final CourseService _courseService = CourseService();
  late Future<List<Course>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() {
    setState(() {
      _coursesFuture = _courseService.getCourses(widget.authToken);
    });
  }

  Future<void> _showJoinCourseDialog() async {
    final courseIdController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Приєднатись до курсу'),
          content: TextField(
            controller: courseIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ID або код курсу'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Скасувати')),
            ElevatedButton(
              onPressed: () async {
                final id = int.tryParse(courseIdController.text);
                if (id != null) {
                  try {
                    await _courseService.joinCourse(widget.authToken, id);
                    Navigator.pop(dialogContext);
                    _loadCourses();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ви успішно приєднались!')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
                  }
                }
              },
              child: const Text('Приєднатись'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C6BA3);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.group_add_outlined),
                  onPressed: _showJoinCourseDialog,
                  label: const Text('Приєднатись'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (context) => CreateCourseScreen(authToken: widget.authToken)),
                    );
                    if (result == true) {
                      _loadCourses();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<Course>>(
                future: _coursesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text('Помилка завантаження: ${snapshot.error}'));
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Ви не є учасником жодного курсу.'));
                  final courses = snapshot.data!;
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      childAspectRatio: 3 / 2.3,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      return _CourseCard(course: courses[index], authToken: widget.authToken);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ВІДЖЕТ КАРТКИ КУРСУ ---
class _CourseCard extends StatelessWidget {
  final Course course;
  final String authToken;
  const _CourseCard({required this.course, required this.authToken});

  @override
  Widget build(BuildContext context) {
    const Color cardColor = Color(0xFF8B80B1);
    const Color textColor = Colors.white;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CourseDetailScreen(course: course, authToken: authToken)),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    course.name,
                    style: const TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CircleAvatar(
                  radius: 25,
                  backgroundImage: course.photoUrl != null && course.photoUrl!.isNotEmpty ? NetworkImage(course.photoUrl!) : null,
                  child: course.photoUrl == null || course.photoUrl!.isEmpty ? const Icon(Icons.school_outlined) : null,
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.people_outline, color: textColor.withOpacity(0.8), size: 16),
                const SizedBox(width: 4),
                Text('${course.memberCount} учасників', style: const TextStyle(color: textColor, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(course.isOpen ? Icons.lock_open_outlined : Icons.lock_outline, color: textColor.withOpacity(0.8), size: 16),
                const SizedBox(width: 4),
                Text(course.isOpen ? 'Відкритий' : 'Закритий', style: const TextStyle(color: textColor, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- ЕКРАН ДЕТАЛЕЙ КУРСУ ---
class CourseDetailScreen extends StatefulWidget {
  final Course course;
  final String authToken;
  const CourseDetailScreen({super.key, required this.course, required this.authToken});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CourseRole _currentUserRole = CourseRole.VIEWER;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _determineCurrentUserRole();
  }

  Future<void> _determineCurrentUserRole() async {
    const currentUsername = "test_user";
    try {
      final members = await CourseService().getCourseMembers(widget.authToken, widget.course.id);
      final currentUserMember = members.firstWhere((m) => m.username == currentUsername, orElse: () => CourseMember(username: '', role: CourseRole.VIEWER));
      if (mounted) {
        setState(() {
          _currentUserRole = currentUserMember.role;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C6BA3);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Стрічка'), Tab(text: 'Завдання'), Tab(text: 'Матеріали'),
            Tab(text: 'Учасники'), Tab(text: 'Чати'), Tab(text: 'Конференції'),
          ],
        ),
      ),
      body: _isLoadingRole
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          const Center(child: Text("Вкладка 'Стрічка' в розробці.")),
          const Center(child: Text("Вкладка 'Завдання' в розробці.")),
          MaterialsTabView(authToken: widget.authToken, courseId: widget.course.id, currentUserRole: _currentUserRole),
          MembersTabView(authToken: widget.authToken, courseId: widget.course.id, currentUserRole: _currentUserRole),
          const Center(child: Text("Вкладка 'Чати' в розробці.")),
          const Center(child: Text("Вкладка 'Конференції' в розробці.")),
        ],
      ),
    );
  }
}

class MembersTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;
  const MembersTabView({super.key, required this.authToken, required this.courseId, required this.currentUserRole});

  @override
  State<MembersTabView> createState() => _MembersTabViewState();
}

class _MembersTabViewState extends State<MembersTabView> {
  final CourseService _courseService = CourseService();
  late Future<List<CourseMember>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() {
    setState(() {
      _membersFuture = _courseService.getCourseMembers(widget.authToken, widget.courseId);
    });
  }

  Future<void> _showAddMemberDialog() async {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    CourseRole selectedRole = CourseRole.STUDENT;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Додати учасника'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) => value!.isEmpty ? 'Введіть username' : null,
                ),
                DropdownButtonFormField<CourseRole>(
                  value: selectedRole,
                  items: CourseRole.values.map((role) {
                    return DropdownMenuItem(value: role, child: Text(role.name));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) selectedRole = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Скасувати')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _courseService.addMember(widget.authToken, widget.courseId, usernameController.text, selectedRole);
                    Navigator.pop(dialogContext);
                    _loadMembers();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Учасника додано!')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
                  }
                }
              },
              child: const Text('Додати'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = widget.currentUserRole == CourseRole.OWNER || widget.currentUserRole == CourseRole.PROFESSOR || widget.currentUserRole == CourseRole.LEADER;
    return Scaffold(
      body: FutureBuilder<List<CourseMember>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Помилка: ${snapshot.error}"));
          final members = snapshot.data ?? [];
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(child: Text(member.username.isNotEmpty ? member.username[0].toUpperCase() : '?')),
                title: Text(member.username),
                trailing: Text(member.role.name, style: const TextStyle(color: Colors.grey)),
              );
            },
          );
        },
      ),
      floatingActionButton: canManage ? FloatingActionButton(onPressed: _showAddMemberDialog, child: const Icon(Icons.add)) : null,
    );
  }
}

class MaterialsTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;
  const MaterialsTabView({super.key, required this.authToken, required this.courseId, required this.currentUserRole});

  @override
  State<MaterialsTabView> createState() => _MaterialsTabViewState();
}

class _MaterialsTabViewState extends State<MaterialsTabView> {
  final CourseService _courseService = CourseService();
  late Future<List<CourseMaterial>> _materialsFuture;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  void _loadMaterials() {
    setState(() {
      _materialsFuture = _courseService.getCourseMaterials(widget.authToken, widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = widget.currentUserRole == CourseRole.OWNER || widget.currentUserRole == CourseRole.PROFESSOR;
    return Scaffold(
      body: FutureBuilder<List<CourseMaterial>>(
        future: _materialsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Помилка: ${snapshot.error}"));
          final materials = snapshot.data ?? [];
          if (materials.isEmpty) return const Center(child: Text('Матеріалів ще немає.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final material = materials[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(material.topic, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(material.textContent, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) =>
                        MaterialDetailScreen(
                          authToken: widget.authToken,
                          courseId: widget.courseId,
                          materialId: material.id,
                          canManage: canManage,
                        )
                    ));
                    if (result == true) _loadMaterials();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canManage ? FloatingActionButton(onPressed: () async {
        final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) =>
            CreateOrEditMaterialScreen(
              authToken: widget.authToken,
              courseId: widget.courseId,
            )
        ));
        if (result == true) _loadMaterials();
      }, child: const Icon(Icons.add)) : null,
    );
  }
}

class MaterialDetailScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final int materialId;
  final bool canManage;
  const MaterialDetailScreen({super.key, required this.authToken, required this.courseId, required this.materialId, required this.canManage});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  late Future<CourseMaterial> _materialFuture;

  @override
  void initState() {
    super.initState();
    _loadMaterialDetails();
  }

  void _loadMaterialDetails() {
    setState(() {
      _materialFuture = CourseService().getMaterialDetails(widget.authToken, widget.courseId, widget.materialId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Деталі матеріалу'),
        actions: [
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final materialToEdit = await _materialFuture;
                final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) =>
                    CreateOrEditMaterialScreen(
                      authToken: widget.authToken,
                      courseId: widget.courseId,
                      material: materialToEdit,
                    )
                ));
                if (result == true) {
                  _loadMaterialDetails();
                }
              },
            ),
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Підтвердити видалення'),
                      content: const Text('Ви впевнені, що хочете видалити цей матеріал?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Видалити', style: TextStyle(color: Colors.red))),
                      ],
                    )
                ) ?? false;

                if (confirm) {
                  try {
                    await CourseService().deleteMaterial(widget.authToken, widget.courseId, widget.materialId);
                    Navigator.pop(context, true);
                  } catch(e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка видалення: $e')));
                  }
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<CourseMaterial>(
        future: _materialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Помилка: ${snapshot.error}'));
          final material = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(material.topic, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Автор: ${material.authorUsername}', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              const Divider(height: 32),
              Text(material.textContent),
              const SizedBox(height: 24),
              if (material.tags.isNotEmpty) Wrap(spacing: 8, children: material.tags.map((t) => Chip(label: Text(t.name))).toList()),
              const SizedBox(height: 24),
              ...material.media.map((file) => ListTile(
                leading: const Icon(Icons.attach_file),
                title: Text(file.displayName),
                onTap: () {},
              )),
            ],
          );
        },
      ),
    );
  }
}

class CreateOrEditMaterialScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseMaterial? material;
  const CreateOrEditMaterialScreen({super.key, required this.authToken, required this.courseId, this.material});

  @override
  State<CreateOrEditMaterialScreen> createState() => _CreateOrEditMaterialScreenState();
}

class _CreateOrEditMaterialScreenState extends State<CreateOrEditMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _topicController;
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  final List<PlatformFile> _pickedFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.material?.topic);
    _contentController = TextEditingController(text: widget.material?.textContent);
    _tagsController = TextEditingController(text: widget.material?.tags.map((t) => t.name).join(', '));
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
    );
    if (result != null) {
      setState(() {
        _pickedFiles.addAll(result.files);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final tags = _tagsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

        if (widget.material == null) {
          // Створення нового матеріалу
          final materialId = await CourseService().createMaterial(widget.authToken, widget.courseId, _topicController.text, _contentController.text, tags);
          for (final file in _pickedFiles) {
            await CourseService().uploadMaterialFile(widget.authToken, widget.courseId, materialId, file);
          }
        } else {
          // Оновлення існуючого
          await CourseService().updateMaterial(widget.authToken, widget.courseId, widget.material!.id, _topicController.text, _contentController.text, tags);
        }

        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.material == null ? 'Новий матеріал' : 'Редагувати матеріал')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(labelText: 'Тема', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Введіть тему' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Зміст', border: OutlineInputBorder()),
              maxLines: 8,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(labelText: 'Теги (через кому)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Додати файли'),
              onPressed: _pickFiles,
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pickedFiles.length,
              itemBuilder: (context, index) {
                final file = _pickedFiles[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(file.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${(file.size / 1024).toStringAsFixed(2)} KB'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _pickedFiles.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Зберегти'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ЕКРАН СТВОРЕННЯ КУРСУ ---
class CreateCourseScreen extends StatefulWidget {
  final String authToken;
  const CreateCourseScreen({super.key, required this.authToken});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final CourseService _courseService = CourseService();
  bool _isCreating = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isCreating = true);
      try {
        await _courseService.createCourse(widget.authToken, _nameController.text);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Курс успішно створено!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка створення: $e')));
        }
      } finally {
        if (mounted) setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C6BA3);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Створення нового курсу'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Назва курсу',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Будь ласка, введіть назву курсу';
                  if (value.length > 100) return 'Назва не може перевищувати 100 символів';
                  return null;
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: _isCreating ? const SizedBox.shrink() : const Icon(Icons.check),
                label: _isCreating
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Створити курс'),
                onPressed: _isCreating ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
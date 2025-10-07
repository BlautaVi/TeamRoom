import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- МОДЕЛІ ДАНИХ ---

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
      throw FormatException("Поле 'id' відсутнє у відповіді сервера.");
    }
    return Course(
      id: json['id'],
      name: json['name'] ?? 'Без назви',
      photoUrl: json['photoUrl'],
      isOpen: json['open'] ?? true,
      memberCount: (json['members'] as List?)?.length ?? 0,
    );
  }
}

// Моделі для екрану деталей курсу
class CourseMember {
  final String name;
  final CourseRole role;
  final String avatarUrl;
  CourseMember({required this.name, required this.role, required this.avatarUrl});
}

class CourseMaterial {
  final String title;
  final String description;
  final int fileCount;
  final List<String> tags;
  CourseMaterial({required this.title, required this.description, required this.fileCount, required this.tags});
}

class Assignment {
  final String title;
  final String dueDate;
  final String status;
  Assignment({required this.title, required this.dueDate, required this.status});
}

class FeedEvent {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  FeedEvent({required this.icon, required this.title, required this.subtitle, required this.time});
}

class CourseService {
  final String _baseUrl = "https://team-room-back.onrender.com/api";

  Future<List<Course>> getCourses(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/course'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> courseList = data['courses'];
      return courseList.map((json) => Course.fromJson(json)).toList();
    } else {
      throw Exception('Не вдалося завантажити курси. Статус: ${response.statusCode}');
    }
  }

  Future<void> createCourse(String token, String name, {String? photoUrl}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/course'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name, 'photoUrl': photoUrl}),
    );
    if (response.statusCode != 200) {
      throw Exception('Не вдалося створити курс. Статус: ${response.statusCode}');
    }
  }

  Future<void> joinCourse(String token, int courseId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/course/$courseId/members'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Не вдалося приєднатися до курсу. Статус: ${response.statusCode}');
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ви успішно приєднались до курсу!')));
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Помилка завантаження курсів: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Ви ще не приєднались до жодного курсу.'));
                  }

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
                      return _CourseCard(course: courses[index]);
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

class _CourseCard extends StatelessWidget {
  final Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    const Color cardColor = Color(0xFF8B80B1);
    const Color textColor = Colors.white;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CourseDetailScreen(course: course)),
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

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Симуляція ролі поточного користувача в цьому курсі
  final CourseRole _currentUserRole = CourseRole.OWNER; // Спробуйте змінити на .STUDENT

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7C6BA3);
    final bool canManage = _currentUserRole == CourseRole.OWNER || _currentUserRole == CourseRole.PROFESSOR;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Стрічка', icon: Icon(Icons.dynamic_feed)),
            Tab(text: 'Завдання', icon: Icon(Icons.assignment)),
            Tab(text: 'Матеріали', icon: Icon(Icons.folder_open)),
            Tab(text: 'Учасники', icon: Icon(Icons.people_outline)),
            Tab(text: 'Чати', icon: Icon(Icons.chat_bubble_outline)),
            Tab(text: 'Конференції', icon: Icon(Icons.video_call_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedPage(),
          _buildAssignmentsPage(canManage),
          _buildMaterialsPage(canManage),
          _buildMembersPage(canManage),
          const Center(child: Text("Сторінка чатів курсу")),
          const Center(child: Text("Сторінка конференцій")),
        ],
      ),
    );
  }

  Widget _buildFeedPage() {
    final List<FeedEvent> events = [
      FeedEvent(icon: Icons.assignment_turned_in, title: 'Нове завдання', subtitle: 'Лабораторна робота №5', time: '2 год. тому'),
      FeedEvent(icon: Icons.folder, title: 'Додано матеріал', subtitle: 'Лекція 6: Асинхронність', time: 'вчора'),
      FeedEvent(icon: Icons.announcement, title: 'Оголошення від OWNER', subtitle: 'Консультація переноситься на 15:00', time: '2 дні тому'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(events[index].icon, color: const Color(0xFF7C6BA3)),
          title: Text(events[index].title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(events[index].subtitle),
          trailing: Text(events[index].time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildAssignmentsPage(bool canManage) {
    final List<Assignment> assignments = [
      Assignment(title: 'Лабораторна робота №5', dueDate: 'Термін здачі: 25.10.2025', status: 'Не здано'),
      Assignment(title: 'Лабораторна робота №4', dueDate: 'Термін здачі: 18.10.2025', status: 'Здано'),
    ];
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: assignments.length,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.assignment, color: Color(0xFF7C6BA3)),
            title: Text(assignments[index].title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(assignments[index].dueDate),
            trailing: Text(assignments[index].status, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  Widget _buildMaterialsPage(bool canManage) {
    final List<CourseMaterial> materials = [
      CourseMaterial(title: 'Лекція 6: Асинхронність', description: 'Огляд Future, async, await.', fileCount: 2, tags: ['Лекція']),
      CourseMaterial(title: 'Додаткові матеріали до ЛР-4', description: 'Приклади коду та корисні посилання.', fileCount: 5, tags: ['Довідкові матеріали']),
    ];
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: materials.length,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(materials[index].title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(materials[index].description, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 16),
                    const SizedBox(width: 4),
                    Text('Файлів: ${materials[index].fileCount}'),
                    const Spacer(),
                    ...materials[index].tags.map((tag) => Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Chip(label: Text(tag)),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  Widget _buildMembersPage(bool canManage) {
    final List<CourseMember> members = [
      CourseMember(name: 'Петренко Петро', role: CourseRole.OWNER, avatarUrl: '...'),
      CourseMember(name: 'Іванов Іван', role: CourseRole.LEADER, avatarUrl: '...'),
      CourseMember(name: 'Сидорова Анна', role: CourseRole.STUDENT, avatarUrl: '...'),
    ];
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: members.length,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(members[index].name),
            trailing: Text(members[index].role.name, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.person_add_alt_1),
      )
          : null,
    );
  }
}

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
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'CoursesScreen.dart';
import 'pcloud_service.dart';

class AssignmentsTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;

  const AssignmentsTabView({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.currentUserRole,
  });

  @override
  State<AssignmentsTabView> createState() => _AssignmentsTabViewState();
}

class _AssignmentsTabViewState extends State<AssignmentsTabView> {
  final CourseService _courseService = CourseService();
  late Future<List<Assignment>> _assignmentsFuture;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  void _loadAssignments() {
    if (mounted) {
      setState(() {
        _assignmentsFuture = _courseService
            .getAssignments(widget.authToken, widget.courseId)
            .catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Помилка завантаження завдань: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          throw e;
        });
      });
    }
  }

  String _formatDueDate(DateTime? date) {
    if (date == null) return 'Без дедлайну';
    return 'Дедлайн: ${DateFormat('dd.MM.yyyy, HH:mm').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = widget.currentUserRole == CourseRole.OWNER ||
        widget.currentUserRole == CourseRole.PROFESSOR;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadAssignments(),
        child: FutureBuilder<List<Assignment>>(
          future: _assignmentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Помилка: ${snapshot.error.toString().replaceFirst("Exception: ", "")}",
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            final assignments = snapshot.data ?? [];
            if (assignments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Завдань ще немає.'),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Оновити'),
                      onPressed: _loadAssignments,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      Icons.assignment_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      assignment.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _formatDueDate(assignment.deadline),
                      style: TextStyle(
                        color: assignment.deadline != null &&
                            assignment.deadline!.isBefore(DateTime.now())
                            ? Colors.red.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                    trailing: assignment.maxGrade != null
                        ? Chip(
                      label: Text('${assignment.maxGrade} балів'),
                      backgroundColor: Colors.blueGrey.shade50,
                      padding: EdgeInsets.zero,
                    )
                        : const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssignmentDetailScreen(
                            authToken: widget.authToken,
                            courseId: widget.courseId,
                            assignmentId: assignment.id,
                            canManage: canManage,
                          ),
                        ),
                      );
                      if (result == true && mounted) _loadAssignments();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreateAssignmentScreen(
                authToken: widget.authToken,
                courseId: widget.courseId,
              ),
            ),
          );
          if (result == true && mounted) _loadAssignments();
        },
        tooltip: 'Додати завдання',
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}

class AssignmentDetailScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final int assignmentId;
  final bool canManage;

  const AssignmentDetailScreen({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.assignmentId,
    required this.canManage,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  late Future<Assignment> _assignmentFuture;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadAssignmentDetails();
  }

  void _loadAssignmentDetails() {
    if (mounted) {
      setState(() {
        _assignmentFuture = CourseService()
            .getAssignmentDetails(
          widget.authToken,
          widget.courseId,
          widget.assignmentId,
        )
            .catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Помилка завантаження деталей: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          throw e;
        });
      });
    }
  }

  Future<void> _downloadAndOpenFile(String publicUrl, String fileName) async {
    if (_isDownloading || !mounted) return;
    setState(() => _isDownloading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Обробка файлу: $fileName...'),
        duration: const Duration(minutes: 5),
      ),
    );
    try {
      String directDownloadUrl;
      final uri = Uri.parse(publicUrl);
      final code = uri.queryParameters['code'];
      if (code == null) {
        throw Exception("Не вдалося знайти 'code' у посиланні '$publicUrl'.");
      }
      String apiHost = (uri.host == 'e.pcloud.link')
          ? 'eapi.pcloud.com'
          : 'api.pcloud.com';
      final apiUrl = Uri.https(apiHost, '/getpublinkdownload', {'code': code});
      final apiResponse = await http.get(apiUrl);
      if (!mounted) return;
      if (apiResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(apiResponse.body);
        if (jsonResponse['result'] != 0) {
          throw Exception("API pCloud помилка: ${jsonResponse['error']}");
        }
        final path = jsonResponse['path'] as String?;
        final hosts = (jsonResponse['hosts'] as List?) ?? [];
        if (hosts.isEmpty || path == null) {
          throw Exception("API pCloud не повернуло дані для завантаження.");
        }
        directDownloadUrl = 'https://'
            '${hosts.first}$path';
      } else {
        throw Exception(
          "API pCloud помилка. Статус: ${apiResponse.statusCode}",
        );
      }
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Завантаження: $fileName...'),
          duration: const Duration(minutes: 5),
        ),
      );
      final response = await http.get(Uri.parse(directDownloadUrl));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/${fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        if (!mounted) return;
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Відкриття файлу...')),
        );
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          throw Exception('Не вдалося відкрити: ${result.message}');
        }
      } else {
        throw Exception(
          'Помилка завантаження файлу. Статус: ${response.statusCode}',
        );
      }
    } catch (e) {
      print("File download/open error: $e");
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Помилка: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) scaffoldMessenger.hideCurrentSnackBar();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Деталі завдання'),
        actions: [
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редагувати завдання',
              onPressed: () async {
                try {
                  final assignmentToEdit = await _assignmentFuture;
                  if (!mounted) return;
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditAssignmentScreen(
                        authToken: widget.authToken,
                        courseId: widget.courseId,
                        assignment: assignmentToEdit,
                      ),
                    ),
                  );
                  if (result == true) _loadAssignmentDetails();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Не вдалося завантажити дані для редагування: $e',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Видалити завдання',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Підтвердити видалення'),
                    content: const Text(
                      'Ви впевнені, що хочете видалити це завдання?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Скасувати'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Видалити',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ) ??
                    false;
                if (confirm && mounted) {
                  final currentContext = context;
                  showDialog(
                    context: currentContext,
                    barrierDismissible: false,
                    builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                  );
                  try {
                    await CourseService().deleteAssignment(
                      widget.authToken,
                      widget.courseId,
                      widget.assignmentId,
                    );
                    if (mounted) {
                      Navigator.pop(currentContext);
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        const SnackBar(content: Text('Завдання видалено.')),
                      );
                      Navigator.pop(currentContext, true);
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(currentContext);
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Помилка видалення: ${e.toString().replaceFirst("Exception: ", "")}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<Assignment>(
        future: _assignmentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Помилка завантаження завдання: ${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final assignment = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadAssignmentDetails(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SelectableText(
                  assignment.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Автор: ${assignment.authorUsername}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                if (assignment.deadline != null)
                  InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: 'Дедлайн',
                    value: DateFormat('dd MMMM yyyy, HH:mm')
                        .format(assignment.deadline!),
                    color: assignment.deadline!.isBefore(DateTime.now())
                        ? Colors.red
                        : Colors.green,
                  ),
                if (assignment.maxGrade != null)
                  InfoChip(
                    icon: Icons.star_border_outlined,
                    label: 'Максимум',
                    value: '${assignment.maxGrade} балів',
                    color: Colors.blueGrey,
                  ),
                const Divider(height: 32),
                SelectableText(
                  assignment.description.isNotEmpty
                      ? assignment.description
                      : 'Опис відсутній.',
                  style: TextStyle(
                    color:
                    assignment.description.isNotEmpty ? null : Colors.grey,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                if (assignment.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: assignment.tags
                          .map(
                            (t) => Chip(
                          label: Text(t.name),
                          backgroundColor: Colors.blueGrey.shade50,
                          labelStyle: TextStyle(
                            color: Colors.blueGrey.shade800,
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ),

                if (assignment.media.isNotEmpty) ...[
                  Text(
                    'Прикріплені файли:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: assignment.media
                        .map(
                          (file) => Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            Icons.attach_file,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(
                            file.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: _isDownloading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : Icon(
                            Icons.download_for_offline_outlined,
                            color: Colors.grey.shade600,
                          ),
                          onTap: _isDownloading
                              ? null
                              : () => _downloadAndOpenFile(
                            file.fileUrl,
                            file.displayName,
                          ),
                          dense: true,
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ] else ...[
                  const Text(
                    'Прикріплені файли відсутні.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
                const Divider(height: 32),
                Text(
                  'Відповіді студентів',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Розділ відповідей в розробці.\n(Потрібне API: .../responses)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final MaterialColor color;

  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              '$label: ',
              style:
              TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(color: color.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateAssignmentScreen extends StatefulWidget {
  final String authToken;
  final int courseId;

  const CreateAssignmentScreen({
    super.key,
    required this.authToken,
    required this.courseId,
  });

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _maxGradeController = TextEditingController();
  DateTime? _selectedDueDate;

  final List<PlatformFile> _pickedFiles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _topicController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _maxGradeController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_isLoading) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && mounted) {
        setState(() => _pickedFiles.addAll(result.files));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка вибору файлів: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickDueDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _selectedDueDate ?? DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (_isLoading || !mounted) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      FocusScope.of(context).unfocus();
      try {
        final topic = _topicController.text.trim();
        final content = _contentController.text.trim();
        final tags = _tagsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final maxGrade = int.tryParse(_maxGradeController.text.trim());

        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Створення завдання...'),
            duration: Duration(minutes: 1),
          ),
        );
        final assignmentId = await CourseService().createAssignment(
          widget.authToken,
          widget.courseId,
          topic,
          content,
          tags,
          _selectedDueDate,
          maxGrade,
        );

        if (_pickedFiles.isNotEmpty) {
          final pCloudService = PCloudService();
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Завантаження файлів (0/${_pickedFiles.length})...',
              ),
              duration: const Duration(minutes: 5),
            ),
          );
          for (int i = 0; i < _pickedFiles.length; i++) {
            if (!mounted) break;
            final file = _pickedFiles[i];
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Файл ${i + 1}/${_pickedFiles.length}: ${file.name}...',
                ),
                duration: const Duration(minutes: 5),
              ),
            );
            final fileUrl = await pCloudService.uploadFileAndGetPublicLink(
              file: file,
              authToken: widget.authToken,
              purpose: 'assignment-file',
            );
            await CourseService().addMediaToAssignment(
              widget.authToken,
              widget.courseId,
              assignmentId,
              fileUrl,
              file.name,
            );
          }
        }
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Завдання створено!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Помилка: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нове завдання')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Тема *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Введіть тему' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Опис (необов\'язково)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              minLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxGradeController,
              decoration: const InputDecoration(
                labelText: 'Макс. бал (необов\'язково)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (int.tryParse(v) == null) return 'Введіть число';
                if (int.parse(v) <= 0) return 'Бал має бути > 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(_selectedDueDate == null
                    ? 'Дедлайн (необов\'язково)'
                    : 'Дедлайн: ${DateFormat('dd.MM.yyyy, HH:mm').format(_selectedDueDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _isLoading ? null : _pickDueDate,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Теги (через кому, необов\'язково)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Додати файли'),
              onPressed: _isLoading ? null : _pickFiles,
            ),
            const SizedBox(height: 8),
            if (_pickedFiles.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pickedFiles.length,
                itemBuilder: (context, index) {
                  final file = _pickedFiles[index];
                  String fileSize;
                  if (file.size > 1024 * 1024) {
                    fileSize =
                    '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB';
                  } else if (file.size > 1024) {
                    fileSize = '${(file.size / 1024).toStringAsFixed(2)} KB';
                  } else {
                    fileSize = '${file.size} B';
                  }
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(file.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(fileSize),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Видалити файл',
                        onPressed: _isLoading
                            ? null
                            : () =>
                            setState(() => _pickedFiles.removeAt(index)),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Зберегти завдання'),
            ),
          ],
        ),
      ),
    );
  }
}


class EditAssignmentScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final Assignment assignment;

  const EditAssignmentScreen({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.assignment,
  });

  @override
  State<EditAssignmentScreen> createState() => _EditAssignmentScreenState();
}

class _EditAssignmentScreenState extends State<EditAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _topicController;
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  late TextEditingController _maxGradeController;
  DateTime? _selectedDueDate;

  late List<MediaFile> _existingFiles;
  final List<PlatformFile> _newFiles = [];
  final List<MediaFile> _filesToDelete = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.assignment.title);
    _contentController =
        TextEditingController(text: widget.assignment.description);
    _tagsController = TextEditingController(
      text: widget.assignment.tags.map((t) => t.name).join(', '),
    );
    _maxGradeController = TextEditingController(
      text: widget.assignment.maxGrade?.toString() ?? '',
    );
    _selectedDueDate = widget.assignment.deadline;
    _existingFiles = List.from(widget.assignment.media);
  }

  @override
  void dispose() {
    _topicController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _maxGradeController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_isLoading) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && mounted) {
        setState(() => _newFiles.addAll(result.files));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка вибору файлів: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickDueDate() async {
    // ... (Скопіюй сюди _pickDueDate з CreateAssignmentScreen) ...
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime(2020), // Можна редагувати на минулу дату
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _selectedDueDate ?? DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (_isLoading || !mounted) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      FocusScope.of(context).unfocus();
      try {
        final topic = _topicController.text.trim();
        final content = _contentController.text.trim();
        final tags = _tagsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final maxGrade = int.tryParse(_maxGradeController.text.trim());

        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Оновлення тексту та тегів...'),
            duration: Duration(minutes: 1),
          ),
        );

        await CourseService().patchAssignment(
          widget.authToken,
          widget.courseId,
          widget.assignment.id,
          topic,
          content,
          tags,
          _selectedDueDate,
          maxGrade,
        );

        if (_filesToDelete.isNotEmpty) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Видалення файлів (0/${_filesToDelete.length})...'),
              duration: const Duration(minutes: 5),
            ),
          );
          for (int i = 0; i < _filesToDelete.length; i++) {
            if (!mounted) break;
            final fileToDelete = _filesToDelete[i];
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Видалення ${i + 1}/${_filesToDelete.length}: ${fileToDelete.displayName}...',
                ),
                duration: const Duration(minutes: 5),
              ),
            );
            await CourseService().deleteAssignmentFile(
              widget.authToken,
              widget.courseId,
              widget.assignment.id,
              fileToDelete.id,
            );
          }
        }

        if (_newFiles.isNotEmpty) {
          final pCloudService = PCloudService();
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Завантаження нових файлів (0/${_newFiles.length})...',
              ),
              duration: const Duration(minutes: 5),
            ),
          );
          for (int i = 0; i < _newFiles.length; i++) {
            if (!mounted) break;
            final file = _newFiles[i];
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Завантаження ${i + 1}/${_newFiles.length}: ${file.name}...',
                ),
                duration: const Duration(minutes: 5),
              ),
            );
            final fileUrl = await pCloudService.uploadFileAndGetPublicLink(
              file: file,
              authToken: widget.authToken,
              purpose: 'assignment-file',
            );
            await CourseService().addMediaToAssignment(
              widget.authToken,
              widget.courseId,
              widget.assignment.id,
              fileUrl,
              file.name,
            );
          }
        }

        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Завдання оновлено!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Помилка: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редагувати завдання')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Тема *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Введіть тему' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Зміст',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              minLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxGradeController,
              decoration: const InputDecoration(
                labelText: 'Макс. бал (необов\'язково)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (int.tryParse(v) == null) return 'Введіть число';
                if (int.parse(v) <= 0) return 'Бал має бути > 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(_selectedDueDate == null
                    ? 'Дедлайн (необов\'язково)'
                    : 'Дедлайн: ${DateFormat('dd.MM.yyyy, HH:mm').format(_selectedDueDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _isLoading ? null : _pickDueDate,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Теги (через кому)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Прикріплені файли',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_existingFiles.isEmpty &&
                _newFiles.isEmpty &&
                _filesToDelete.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Файлів немає.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            if (_existingFiles.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _existingFiles.length,
                itemBuilder: (context, index) {
                  final file = _existingFiles[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(file.displayName),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: 'Позначити для видалення',
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                          _filesToDelete.add(file);
                          _existingFiles.removeAt(index);
                        }),
                      ),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: const Text('Додати нові файли'),
                onPressed: _isLoading ? null : _pickFiles,
              ),
            ),
            if (_newFiles.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _newFiles.length,
                itemBuilder: (context, index) {
                  final file = _newFiles[index];
                  String fileSize;
                  if (file.size > 1024 * 1024) {
                    fileSize =
                    '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB';
                  } else if (file.size > 1024) {
                    fileSize = '${(file.size / 1024).toStringAsFixed(2)} KB';
                  } else {
                    fileSize = '${file.size} B';
                  }
                  return Card(
                    color: Colors.green.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.upload_file,
                        color: Colors.green,
                      ),
                      title: Text(file.name),
                      subtitle: Text(fileSize),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Скасувати додавання',
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _newFiles.removeAt(index)),
                      ),
                    ),
                  );
                },
              ),
            if (_filesToDelete.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Файли для видалення:',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filesToDelete.length,
                itemBuilder: (context, index) {
                  final file = _filesToDelete[index];
                  return Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.red,
                      ),
                      title: Text(
                        file.displayName,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.undo, color: Colors.orange),
                        tooltip: 'Повернути',
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                          _existingFiles.add(file);
                          _filesToDelete.removeAt(index);
                        }),
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Зберегти зміни'),
            ),
          ],
        ),
      ),
    );
  }
}
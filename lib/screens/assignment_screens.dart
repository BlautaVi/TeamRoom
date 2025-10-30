import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../classes/course_models.dart';
import 'CoursesScreen.dart';
import 'pcloud_service.dart';

class AssignmentsTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;
  final String currentUsername;

  const AssignmentsTabView({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.currentUserRole,
    required this.currentUsername,
  });

  @override
  State<AssignmentsTabView> createState() => _AssignmentsTabViewState();
}

class _AssignmentsTabViewState extends State<AssignmentsTabView> {
  late Future<List<Assignment>> _assignmentsFuture;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  void _loadAssignments() {
    if (mounted) {
      setState(() {
        _assignmentsFuture = CourseService()
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
          return <Assignment>[];
        });
      });
    }
  }

  Future<void> _openCreate() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final bool canCreate =
        widget.currentUserRole == CourseRole.PROFESSOR ||
            widget.currentUserRole == CourseRole.OWNER;

    return Scaffold(
      body: FutureBuilder<List<Assignment>>(
        future: _assignmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Помилка завантаження завдань:\n${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('В цьому курсі ще немає завдань.'),
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
          items.sort((a, b) {
            if (a.deadline == null && b.deadline == null) {
              return b.id.compareTo(a.id);
            }
            if (a.deadline == null) return 1;
            if (b.deadline == null) return -1;
            return b.deadline!.compareTo(a.deadline!);
          });

          return RefreshIndicator(
            onRefresh: () async => _loadAssignments(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, i) {
                final a = items[i];
                final bool isPastDue =
                    a.deadline != null && a.deadline!.isBefore(DateTime.now());
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 1.5,
                  child: ListTile(
                    leading: Icon(
                      Icons.assignment_turned_in_outlined,
                      color: isPastDue
                          ? Colors.grey
                          : Theme.of(context).primaryColor,
                    ),
                    title: Text(
                      a.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isPastDue ? Colors.grey.shade700 : null,
                      ),
                    ),
                    subtitle: Text(
                      a.description.isNotEmpty ? a.description : 'Побачити більше..',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: a.description.isNotEmpty
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          a.deadline != null
                              ? DateFormat('dd.MM HH:mm').format(a.deadline!)
                              : 'Без дедлайну',
                          style: TextStyle(
                            fontSize: 12,
                            color: isPastDue
                                ? Colors.red.shade700
                                : Colors.grey.shade600,
                            fontWeight: isPastDue
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Макс: ${a.maxGrade ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssignmentDetailScreen(
                            authToken: widget.authToken,
                            courseId: widget.courseId,
                            assignmentId: a.id,
                            currentUserRole: widget.currentUserRole,
                            currentUsername: widget.currentUsername,
                          ),
                        ),
                      );
                      if (result == true && mounted) _loadAssignments();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
        onPressed: _openCreate,
        tooltip: 'Створити завдання',
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
  final CourseRole currentUserRole;
  final String currentUsername;

  const AssignmentDetailScreen({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.assignmentId,
    required this.currentUserRole,
    required this.currentUsername,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  late Future<Assignment> _assignmentFuture;
  AssignmentResponse? _studentResponse;
  bool _isLoadingStudentResponse = false;
  bool _isDownloading = false;
  final GlobalKey<_AssignmentResponsesSectionState> _responsesSectionKey =
  GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _loadStudentResponseData();
  }

  Future<void> _loadStudentResponseData() async {
    if (widget.currentUserRole != CourseRole.STUDENT || !mounted) return;
    setState(() => _isLoadingStudentResponse = true);

    try {
      final response = await CourseService().getMyAssignmentResponse(
        widget.authToken,
        widget.courseId,
        widget.assignmentId,
      );

      if (mounted) {
        _studentResponse = response;
      }
    } catch (e) {
      print("Error loading my assignment response: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Не вдалося завантажити вашу відповідь: $e'),
            backgroundColor: Colors.red));
      }
      _studentResponse = null;
    } finally {
      if (mounted) {
        setState(() => _isLoadingStudentResponse = false);
        _responsesSectionKey.currentState
            ?.updateStudentResponse(_studentResponse);
      }
    }
  }

  void _loadDetails({bool forceReloadResponses = false}) {
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
                content: Text(
                  'Помилка завантаження деталей завдання: ${e.toString().replaceFirst("Exception: ", "")}',
                ),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.maybePop(context);
          }
          throw e;
        });
      });
      if (forceReloadResponses) {
        if (widget.currentUserRole == CourseRole.STUDENT) {
          _loadStudentResponseData();
        } else {
          _responsesSectionKey.currentState?.forceReload();
        }
      }
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

        directDownloadUrl = 'https://${hosts.first}$path';
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
        final safeFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final filePath = '${tempDir.path}/$safeFileName';
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
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) scaffoldMessenger.hideCurrentSnackBar();
        });
      } else {
        throw Exception(
          'Помилка завантаження файлу. Статус: ${response.statusCode}',
        );
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
      if (mounted) {
        setState(() => _isDownloading = false);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) scaffoldMessenger.hideCurrentSnackBar();
        });
      }
    }
  }

  bool get _canSubmit => widget.currentUserRole == CourseRole.STUDENT;

  bool get _canManage =>
      widget.currentUserRole == CourseRole.PROFESSOR ||
          widget.currentUserRole == CourseRole.OWNER;

  Future<void> _editAssignment(Assignment assignment) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditAssignmentScreen(
          authToken: widget.authToken,
          courseId: widget.courseId,
          assignment: assignment,
        ),
      ),
    );
    if (result == true && mounted) {
      _loadDetails();
    }
  }

  Future<void> _deleteAssignment(Assignment assignment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити завдання?'),
        content: Text(
          'Ви впевнені, що хочете видалити завдання "${assignment.title}"? Це видалить також ВСІ відповіді студентів.',
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
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await CourseService().deleteAssignment(
          widget.authToken,
          widget.courseId,
          assignment.id,
        );
        Navigator.pop(context);
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Завдання видалено')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        Navigator.pop(context);
        if (mounted) {
          scaffoldMessenger.showSnackBar(
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Деталі завдання'),
        actions: [
          FutureBuilder<Assignment>(
            future: _assignmentFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData && _canManage) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Редагувати завдання',
                      onPressed: () => _editAssignment(snapshot.data!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Видалити завдання',
                      onPressed: () => _deleteAssignment(snapshot.data!),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Помилка завантаження завдання:\n${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          final assignment = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadDetails(forceReloadResponses: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
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
                const Divider(height: 24),
                SelectableText(
                  assignment.description.isNotEmpty
                      ? assignment.description
                      : 'Опис відсутній.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: assignment.description.isNotEmpty
                        ? null
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    InfoChip(
                      label: 'Дедлайн',
                      value: assignment.deadline != null
                          ? DateFormat(
                        'dd.MM.yyyy HH:mm',
                      ).format(assignment.deadline!)
                          : 'не вказано',
                      isPastDue:
                      assignment.deadline != null &&
                          assignment.deadline!.isBefore(DateTime.now()),
                    ),
                    InfoChip(
                      label: 'Макс. бал',
                      value: assignment.maxGrade?.toString() ?? '-',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                          backgroundColor: Colors.teal.shade50,
                          labelStyle: TextStyle(
                            color: Colors.teal.shade800,
                            fontSize: 12,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                          .toList(),
                    ),
                  ),
                if (assignment.media.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Прикріплені файли:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...assignment.media.map(
                            (m) => Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              Icons.attach_file,
                              color: Theme.of(context).primaryColor,
                            ),
                            title: Text(
                              m.displayName,
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
                              m.fileUrl,
                              m.displayName,
                            ),
                            dense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                const Divider(height: 24),
                AssignmentResponsesSection(
                  key: _responsesSectionKey,
                  authToken: widget.authToken,
                  courseId: widget.courseId,
                  assignmentId: assignment.id,
                  currentUserRole: widget.currentUserRole,
                  assignment: assignment,
                  currentUsername: widget.currentUsername,
                  initialStudentResponse: _studentResponse,
                  isLoadingStudentResponse: _isLoadingStudentResponse,
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<Assignment>(
        future: _assignmentFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData && _canSubmit) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Здати / Перездати роботу'),
                    onPressed: () async {
                      // 💡 --- ОНОВЛЕНА ЛОГІКА --- 💡
                      // 1. Отримуємо поточну відповідь, яка вже завантажена
                      final AssignmentResponse? existingResponse = _studentResponse;

                      final result = await Navigator.push<int>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SubmitResponseScreen(
                                authToken: widget.authToken,
                                courseId: widget.courseId,
                                assignmentId: widget.assignmentId,
                                // 2. Передаємо поточну відповідь (або null) на екран здачі
                                existingResponse: existingResponse,
                              )));

                      if (result != null && mounted) {
                        if (result > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Відповідь надіслано / оновлено')));
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                              content: Text(
                                  'Відповідь надіслано, але ID не отримано. Оновлюємо...'),
                              backgroundColor: Colors.orange));
                        }
                        // 3. Просто перезавантажуємо "мою" відповідь.
                        // Бекенд тепер поверне щойно створену.
                        _loadStudentResponseData();
                      }
                    },
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class AssignmentResponsesSection extends StatefulWidget {
  final String authToken;
  final int courseId;
  final int assignmentId;
  final CourseRole currentUserRole;
  final String currentUsername;
  final AssignmentResponse? initialStudentResponse;
  final bool isLoadingStudentResponse;
  final Assignment assignment;

  const AssignmentResponsesSection({
    required Key key,
    required this.authToken,
    required this.courseId,
    required this.assignmentId,
    required this.assignment,
    required this.currentUserRole,
    required this.currentUsername,
    this.initialStudentResponse,
    this.isLoadingStudentResponse = false,
  }) : super(key: key);

  @override
  State<AssignmentResponsesSection> createState() =>
      _AssignmentResponsesSectionState();
}

class _AssignmentResponsesSectionState
    extends State<AssignmentResponsesSection> {
  AssignmentResponse? _currentStudentResponse;
  Future<List<AssignmentResponse>>? _allResponsesFuture;
  bool _isLoadingAllResponses = false;

  @override
  void initState() {
    super.initState();
    _currentStudentResponse = widget.initialStudentResponse;
    if (widget.currentUserRole != CourseRole.STUDENT) {
      _loadAllResponses();
    }
  }

  @override
  void didUpdateWidget(covariant AssignmentResponsesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStudentResponse != oldWidget.initialStudentResponse) {
      if (mounted) {
        setState(() {
          _currentStudentResponse = widget.initialStudentResponse;
        });
      }
    }
    if (widget.assignmentId != oldWidget.assignmentId &&
        widget.currentUserRole != CourseRole.STUDENT) {
      _loadAllResponses();
    }
  }

  void updateStudentResponse(AssignmentResponse? response) {
    if (mounted) {
      setState(() {
        _currentStudentResponse = response;
      });
    }
  }

  void forceReload() {
    if (widget.currentUserRole != CourseRole.STUDENT) {
      _loadAllResponses();
    } else {
      (context.findAncestorStateOfType<_AssignmentDetailScreenState>())
          ?._loadStudentResponseData();
    }
  }

  void _loadAllResponses() {
    if (mounted && widget.currentUserRole != CourseRole.STUDENT) {
      setState(() {
        _isLoadingAllResponses = true;
        _allResponsesFuture = CourseService()
            .getAssignmentResponses(
            widget.authToken, widget.courseId, widget.assignmentId)
            .catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Помилка завантаження відповідей: $e'),
                backgroundColor: Colors.red));
          }
          return <AssignmentResponse>[];
        }).whenComplete(() {
          if (mounted) {
            setState(() => _isLoadingAllResponses = false);
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserRole == CourseRole.STUDENT) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Моя відповідь',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (widget.isLoadingStudentResponse)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            )
          else if (_currentStudentResponse != null)
            _buildResponseTile(_currentStudentResponse!)
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child:
              Text('Ви ще не здали роботу.', style: TextStyle(color: Colors.grey)),
            ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Відповіді студентів',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Оновити список відповідей',
                onPressed: _isLoadingAllResponses ? null : _loadAllResponses,
                color: Colors.grey.shade600,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingAllResponses)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ),
          if (_allResponsesFuture != null)
            FutureBuilder<List<AssignmentResponse>>(
              future: _allResponsesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    !_isLoadingAllResponses) {
                  return const SizedBox.shrink();
                }
                if (snapshot.hasError) {
                  return Text(
                    'Помилка: ${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                    style: const TextStyle(color: Colors.red),
                  );
                }
                final allResponses = snapshot.data ?? [];
                if (allResponses.isEmpty && !_isLoadingAllResponses) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Студенти ще не здали роботи.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                allResponses.sort(
                      (a, b) => a.authorUsername.toLowerCase().compareTo(
                    b.authorUsername.toLowerCase(),
                  ),
                );

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allResponses.length,
                  itemBuilder: (context, index) {
                    return _buildResponseTile(allResponses[index]);
                  },
                );
              },
            )
          else if (!_isLoadingAllResponses)
            const Text(
              'Завантаження списку...',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      );
    }
  }

  Widget _buildResponseTile(AssignmentResponse r) {
    IconData statusIcon = Icons.hourglass_empty;
    Color statusColor = Colors.orange;
    String statusText = 'Здано';
    String lateSuffix = '';

    DateTime? deadline = widget.assignment.deadline;
    final bool deadlinePassed = deadline != null &&
        deadline.isBefore(DateTime.now());

    if (r.isGraded) {
      statusIcon = Icons.check_circle_outline;
      statusColor = Colors.green;
      statusText = 'Оцінено: ${r.grade ?? '-'}';
    } else if (r.isReturned) {
      statusIcon = Icons.replay_outlined;
      statusColor = Colors.blue;
      statusText = 'Повернено';
    } else {
      if (deadlinePassed) {
        lateSuffix = ' (після дедлайну)';
        statusColor = Colors.deepOrange;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(r.authorUsername),
        subtitle: Text(statusText + lateSuffix),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        dense: true,
        onTap: () async {
          int? maxGrade = widget.assignment.maxGrade;

          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ResponseDetailScreen(
                authToken: widget.authToken,
                courseId: widget.courseId,
                assignmentId: widget.assignmentId,
                responseId: r.id,
                currentUserRole: widget.currentUserRole,
                currentUsername: widget.currentUsername,
                assignmentMaxGrade: maxGrade,
              ),
            ),
          );
          if (result == true && mounted) {
            forceReload();
          }
        },
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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxGradeController = TextEditingController();
  final _tagsController = TextEditingController();
  DateTime? _selectedDeadline;
  final List<PlatformFile> _pickedFiles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxGradeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_isLoading) return;
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
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

  Future<void> _pickDeadline() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _selectedDeadline ?? DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDeadline = DateTime(
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final maxGrade = int.tryParse(_maxGradeController.text.trim());
      final tags = _tagsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Створення завдання...'),
          duration: Duration(minutes: 1),
        ),
      );

      final createdAssignmentId = await CourseService().createAssignment(
        widget.authToken,
        widget.courseId,
        title,
        description,
        tags,
        _selectedDeadline,
        maxGrade,
      );

      if (_pickedFiles.isNotEmpty) {
        final pcloud = PCloudService();
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Завантаження файлів (0/${_pickedFiles.length})...'),
            duration: const Duration(minutes: 5),
          ),
        );

        for (int i = 0; i < _pickedFiles.length; i++) {
          if (!mounted) break;
          final f = _pickedFiles[i];
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Файл ${i + 1}/${_pickedFiles.length}: ${f.name}...',
              ),
              duration: const Duration(minutes: 5),
            ),
          );

          if (f.path == null) {
            print("Skipping file without path: ${f.name}");
            continue;
          }

          final publicUrl = await pcloud.uploadFileAndGetPublicLink(
            file: f,
            authToken: widget.authToken,
            purpose: 'assignment-file',
          );

          await CourseService().addMediaToAssignment(
            widget.authToken,
            widget.courseId,
            createdAssignmentId,
            publicUrl,
            f.name,
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
              'Помилка створення завдання: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Назва завдання *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Вкажіть назву' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Опис (інструкції)',
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
                labelText: 'Максимальний бал (напр., 100)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: false),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (int.tryParse(v.trim()) == null || int.parse(v.trim()) < 0)
                  return 'Введіть ціле невід\'ємне число';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Теги (через кому)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(
                _selectedDeadline == null
                    ? 'Дедлайн (необов\'язково)'
                    : 'Дедлайн: ${DateFormat('dd.MM.yyyy HH:mm').format(_selectedDeadline!)}',
              ),
              trailing: OutlinedButton(
                onPressed: _isLoading ? null : _pickDeadline,
                child: Text(_selectedDeadline == null ? 'Обрати' : 'Змінити'),
              ),
              onTap: _isLoading ? null : _pickDeadline,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Прикріпити файли до завдання'),
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
                  String fileSize = file.size > 1048576
                      ? '${(file.size / 1048576).toStringAsFixed(2)} MB'
                      : file.size > 1024
                      ? '${(file.size / 1024).toStringAsFixed(2)} KB'
                      : '${file.size} B';
                  return Card(
                    elevation: 1,
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(file.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(fileSize),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Видалити файл зі списку',
                        onPressed: _isLoading
                            ? null
                            : () =>
                            setState(() => _pickedFiles.removeAt(index)),
                      ),
                      dense: true,
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Створити завдання'),
            ),
          ],
        ),
      ),
    );
  }
}

class SubmitResponseScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final int assignmentId;
  // 💡 --- ДОДАНО --- 💡
  final AssignmentResponse? existingResponse;

  const SubmitResponseScreen({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.assignmentId,
    // 💡 --- ДОДАНО --- 💡
    this.existingResponse,
  });

  @override
  State<SubmitResponseScreen> createState() => _SubmitResponseScreenState();
}

class _SubmitResponseScreenState extends State<SubmitResponseScreen> {
  final List<PlatformFile> _filesToUpload = [];
  bool _isLoading = false;
  String _uploadProgress = '';

  @override
  void dispose() {
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
        final existingPaths = _filesToUpload.map((f) => f.path).toSet();
        setState(() {
          _filesToUpload.addAll(
            result.files.where((f) => !existingPaths.contains(f.path)),
          );
        });
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

  Future<void> _uploadAndSubmit() async {
    if (_isLoading || _filesToUpload.isEmpty || !mounted) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 'Підготовка...';
    });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();

    final List<Map<String, String>> uploadedMediaList = [];
    int createdResponseId = 0;

    try {
      final pCloudService = PCloudService();
      for (int i = 0; i < _filesToUpload.length; i++) {
        if (!mounted) return;
        final file = _filesToUpload[i];

        if (file.path == null) {
          print("Skipping file without path: ${file.name}");
          continue;
        }

        setState(() {
          _uploadProgress =
          'Завантаження ${i + 1}/${_filesToUpload.length}: ${file.name}...';
        });
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_uploadProgress),
            duration: const Duration(minutes: 5),
          ),
        );

        final fileUrl = await pCloudService.uploadFileAndGetPublicLink(
          file: file,
          authToken: widget.authToken,
          purpose: 'assignment-response-file',
        );
        uploadedMediaList.add({'name': file.name, 'fileUrl': fileUrl});
      }

      if (uploadedMediaList.isEmpty) {
        throw Exception("Не вдалося завантажити жодного файлу.");
      }

      // 💡 --- ОНОВЛЕНА ЛОГІКА --- 💡
      // 1. Перевіряємо, чи ми передали існуючу відповідь
      if (widget.existingResponse != null) {
        setState(() => _uploadProgress = 'Видалення старої відповіді...');
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_uploadProgress),
            duration: const Duration(minutes: 1),
          ),
        );

        try {
          // 2. Видаляємо її
          await CourseService().deleteAssignmentResponse(
            widget.authToken,
            widget.courseId,
            widget.assignmentId,
            widget.existingResponse!.id,
          );
          print("Deleted old response ID: ${widget.existingResponse!.id}");
        } catch (delErr) {
          // Не фатально, якщо не вдалося видалити (може, її вже видалили),
          // але логгуємо це.
          print("Could not delete old response: $delErr");
          // Продовжуємо, бо бекенд, ймовірно, все одно впаде з 500,
          // але краще спробувати створити нову, ніж нічого.
        }
      }
      // 💡 --- КІНЕЦЬ ОНОВЛЕННЯ --- 💡


      setState(() {
        _uploadProgress = 'Надсилання відповіді...';
      });
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(_uploadProgress),
          duration: const Duration(minutes: 1),
        ),
      );

      // 3. Створюємо нову відповідь (як і раніше)
      createdResponseId = await CourseService().submitAssignmentResponse(
        widget.authToken,
        widget.courseId,
        widget.assignmentId,
        uploadedMediaList,
      );

      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        Navigator.pop(context, createdResponseId);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Помилка надсилання: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(
          widget.existingResponse != null
              ? 'Перездати роботу'
              : 'Здати роботу'
      )),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Прикріпіть файли вашої роботи:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text('Обрати файли...'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filesToUpload.isEmpty
                  ? const Center(
                child: Text(
                  'Файли не обрано.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: _filesToUpload.length,
                itemBuilder: (context, index) {
                  final file = _filesToUpload[index];
                  String fileSize = file.size > 1048576
                      ? '${(file.size / 1048576).toStringAsFixed(2)} MB'
                      : file.size > 1024
                      ? '${(file.size / 1024).toStringAsFixed(2)} KB'
                      : '${file.size} B';
                  return Card(
                    elevation: 1,
                    child: ListTile(
                      leading: const Icon(
                        Icons.insert_drive_file_outlined,
                      ),
                      title: Text(
                        file.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(fileSize),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Видалити зі списку',
                        onPressed: _isLoading
                            ? null
                            : () => setState(
                              () => _filesToUpload.removeAt(index),
                        ),
                      ),
                      dense: true,
                    ),
                  );
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _uploadProgress,
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isLoading ? 'Завантаження...' : 'Надіслати роботу',
                  style: const TextStyle(fontSize: 16),
                ),
                onPressed: (_isLoading || _filesToUpload.isEmpty)
                    ? null
                    : _uploadAndSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResponseDetailScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final int assignmentId;
  final int responseId;
  final CourseRole currentUserRole;
  final String currentUsername;
  final int? assignmentMaxGrade;

  const ResponseDetailScreen({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.assignmentId,
    required this.responseId,
    required this.currentUserRole,
    required this.currentUsername,
    this.assignmentMaxGrade,
  });

  @override
  State<ResponseDetailScreen> createState() => _ResponseDetailScreenState();
}

class _ResponseDetailScreenState extends State<ResponseDetailScreen> {
  late Future<AssignmentResponse> _responseFuture;
  AssignmentResponse? _currentResponseData;
  bool _isDownloading = false;
  bool _isProcessingAction = false;
  Future<Assignment>? _parentAssignmentFuture;

  @override
  void initState() {
    super.initState();
    final parentState = context
        .findAncestorStateOfType<_AssignmentDetailScreenState>();
    if (parentState != null) {
      _parentAssignmentFuture = parentState._assignmentFuture;
    } else {
      _parentAssignmentFuture = CourseService().getAssignmentDetails(
        widget.authToken,
        widget.courseId,
        widget.assignmentId,
      );
    }
    _load();
  }

  void _load() {
    if (mounted) {
      setState(() {
        _isProcessingAction = false;
        _responseFuture = CourseService()
            .getAssignmentResponseDetails(
          widget.authToken,
          widget.courseId,
          widget.assignmentId,
          widget.responseId,
        )
            .then((response) {
          if (mounted) _currentResponseData = response;
          return response;
        })
            .catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Помилка завантаження деталей відповіді: ${e.toString().replaceFirst("Exception: ", "")}',
                ),
                backgroundColor: Colors.red,
              ),
            );

            Navigator.maybePop(context);
          }
          throw e;
        });
      });
    }
  }

  Future<void> _downloadAndOpen(String publicUrl, String fileName) async {
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
      if (code == null)
        throw Exception("Не вдалося знайти 'code' у посиланні '$publicUrl'.");

      String apiHost = (uri.host == 'e.pcloud.link')
          ? 'eapi.pcloud.com'
          : 'api.pcloud.com';
      final apiUrl = Uri.https(apiHost, '/getpublinkdownload', {'code': code});
      final apiResponse = await http.get(apiUrl);

      if (!mounted) return;

      if (apiResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(apiResponse.body);
        if (jsonResponse['result'] != 0)
          throw Exception("API pCloud помилка: ${jsonResponse['error']}");

        final path = jsonResponse['path'] as String?;
        final hosts = (jsonResponse['hosts'] as List?) ?? [];
        if (hosts.isEmpty || path == null)
          throw Exception("API pCloud не повернуло дані для завантаження.");

        directDownloadUrl = 'https://${hosts.first}$path';
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
        final safeFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final filePath = '${tempDir.path}/$safeFileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (!mounted) return;

        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Відкриття файлу...')),
        );

        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done)
          throw Exception('Не вдалося відкрити: ${result.message}');

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) scaffoldMessenger.hideCurrentSnackBar();
        });
      } else {
        throw Exception(
          'Помилка завантаження файлу. Статус: ${response.statusCode}',
        );
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
      if (mounted) {
        setState(() => _isDownloading = false);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) scaffoldMessenger.hideCurrentSnackBar();
        });
      }
    }
  }

  bool get _canManage =>
      widget.currentUserRole == CourseRole.PROFESSOR ||
          widget.currentUserRole == CourseRole.OWNER;

  bool get _isAuthor =>
      _currentResponseData != null &&
          widget.currentUsername == _currentResponseData!.authorUsername;

  Future<void> _grade(AssignmentResponse resp) async {
    if (_isProcessingAction) return;

    final gradeController = TextEditingController(text: resp.grade?.toString() ?? '');
    final commentController = TextEditingController(text: resp.gradeComment ?? '');
    final int? maxGrade = widget.assignmentMaxGrade;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(resp.isGraded ? 'Змінити оцінку' : 'Оцінити відповідь'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: gradeController,
            keyboardType: TextInputType.numberWithOptions(decimal: false),
            decoration: InputDecoration(
              labelText: 'Оцінка (число)',
              hintText: maxGrade != null ? 'Макс: $maxGrade' : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: commentController,
            decoration: const InputDecoration(
                labelText: 'Коментар (необов\'язково)'),
            maxLines: 3,
          )
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () {
              final grade = int.tryParse(gradeController.text.trim());
              final currentComment = commentController.text.trim();

              if (grade == null || grade < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
                    content: Text('Введіть коректну невід\'ємну оцінку.'),
                    backgroundColor: Colors.orange));
                return;
              }
              if (maxGrade != null && grade > maxGrade) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                    content: Text('Оцінка не може перевищувати максимальну ($maxGrade).'),
                    backgroundColor: Colors.orange));
                return;
              }

              Navigator.pop(dialogContext, {
                'grade': grade,
                'comment': currentComment
              });
            },
            child: const Text('Зберегти оцінку'),
          )
        ],
      ),
    );

    if (result == null || !mounted) return;

    final int grade = result['grade'];
    final String comment = result['comment'];

    if (grade == resp.grade && comment == (resp.gradeComment ?? '')) {
      print("Grade and comment haven't changed.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Змін не виявлено.'), duration: Duration(seconds: 2))
        );
      }
      return;
    }


    setState(() => _isProcessingAction = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await CourseService().gradeAssignmentResponse(
          widget.authToken,
          widget.courseId,
          widget.assignmentId,
          widget.responseId,
          grade,
          comment.isNotEmpty ? comment : null);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Відповідь оцінено')));
        _load();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text(
                'Помилка оцінки: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _cancelGrade(AssignmentResponse resp) async {
    if (_isProcessingAction) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скасувати оцінку?'),
        content: const Text(
          'Ви впевнені, що хочете скасувати виставлену оцінку?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ні'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Так, скасувати',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() => _isProcessingAction = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await CourseService().cancelGradeAssignmentResponse(
        widget.authToken,
        widget.courseId,
        widget.assignmentId,
        widget.responseId,
      );
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Оцінку скасовано')),
        );
        _load();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Помилка скасування оцінки: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _return(AssignmentResponse resp) async {
    if (_isProcessingAction) return;
    final commentController = TextEditingController(
      text: resp.returnComment ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          resp.isReturned
              ? 'Оновити коментар повернення'
              : 'Повернути на доопрацювання',
        ),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            labelText: 'Коментар (необов\'язково)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, commentController.text.trim()),
            child: const Text('Повернути'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    final String comment = result;

    setState(() => _isProcessingAction = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await CourseService().returnAssignmentResponse(
        widget.authToken,
        widget.courseId,
        widget.assignmentId,
        widget.responseId,
        comment.isNotEmpty ? comment : null,
      );
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Відповідь повернуто')),
        );
        _load();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Помилка повернення: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _cancelReturn(AssignmentResponse resp) async {
    if (_isProcessingAction) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скасувати повернення?'),
        content: const Text(
          'Ви впевнені, що хочете скасувати повернення цієї відповіді? Студент не зможе її редагувати.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ні'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Так, скасувати',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() => _isProcessingAction = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await CourseService().cancelReturnAssignmentResponse(
        widget.authToken,
        widget.courseId,
        widget.assignmentId,
        widget.responseId,
      );
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Повернення скасовано')),
        );
        _load();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Помилка скасування повернення: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _deleteResponse(AssignmentResponse resp) async {
    final bool isAuthor = widget.currentUsername == resp.authorUsername;
    final bool isManager = _canManage;

    if (isAuthor && resp.isGraded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Неможливо видалити вже оцінену відповідь.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!isAuthor && !isManager) return;
    if (_isProcessingAction) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити відповідь?'),
        content: Text(
          'Ви впевнені, що хочете видалити цю відповідь?\n${isManager ? "(Дія викладача)" : ""}\nЦю дію неможливо скасувати.',
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

    if (!confirm || !mounted) return;

    setState(() => _isProcessingAction = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await CourseService().deleteAssignmentResponse(
        widget.authToken,
        widget.courseId,
        widget.assignmentId,
        widget.responseId,
      );

      // (Логіку SharedPreferences видалено)

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Відповідь видалено')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Помилка видалення відповіді: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessingAction = false);
      }
    } finally {
      if (mounted && _isProcessingAction) {
        setState(() => _isProcessingAction = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Деталі відповіді'),
        actions: [
          FutureBuilder<AssignmentResponse>(
            future: _responseFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final resp = snapshot.data!;
                final bool isAuthor = widget.currentUsername == resp.authorUsername;
                final bool isManager = _canManage;

                final bool canAuthorDelete = isAuthor && !resp.isGraded;
                final bool canManagerDelete = isManager;

                if (canAuthorDelete || canManagerDelete) {
                  return IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Видалити відповідь',
                    color: Colors.red.shade700,
                    onPressed: _isProcessingAction
                        ? null
                        : () => _deleteResponse(resp),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: FutureBuilder<AssignmentResponse>(
        future: _responseFuture,
        builder: (context, responseSnapshot) {
          if (responseSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (responseSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Помилка завантаження відповіді:\n${responseSnapshot.error.toString().replaceFirst("Exception: ", "")}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final resp = responseSnapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FutureBuilder<Assignment>(
                  future: _parentAssignmentFuture,
                  builder: (context, assignmentSnapshot) {
                    DateTime? assignmentDeadline;
                    bool deadlineHasPassed = false;

                    if (assignmentSnapshot.connectionState == ConnectionState.done &&
                        assignmentSnapshot.hasData) {
                      assignmentDeadline = assignmentSnapshot.data!.deadline;
                      deadlineHasPassed = assignmentDeadline != null &&
                          assignmentDeadline!.isBefore(DateTime.now());
                    } else if (assignmentSnapshot.hasError) {
                      print("Error fetching parent assignment details for deadline check: ${assignmentSnapshot.error}");
                    }

                    String statusText;
                    Color statusColor;
                    IconData statusIcon;
                    bool possiblyLate = false;

                    if (resp.isGraded) {
                      statusText = 'Оцінено';
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                    } else if (resp.isReturned) {
                      statusText = 'Повернено на доопрацювання';
                      statusColor = Colors.blue;
                      statusIcon = Icons.replay;
                    } else {
                      statusText = 'Здано, очікує перевірки';
                      statusColor = deadlineHasPassed ? Colors.deepOrange : Colors.orange;
                      statusIcon = Icons.hourglass_top;
                      possiblyLate = deadlineHasPassed;
                    }

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(statusIcon, color: statusColor, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    statusText + (possiblyLate ? ' (після дедлайну)' : ''),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (resp.isGraded)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 40),
                                child: Text(
                                  'Оцінка: ${resp.grade}',
                                  style: Theme.of(context).textTheme.headlineSmall
                                      ?.copyWith(color: Colors.green.shade800),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: Text(
                                'Автор: ${resp.authorUsername}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (resp.media.isNotEmpty) ...[
                  Text(
                    'Прикріплені файли:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...resp.media.map(
                        (m) => Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          Icons.attach_file,
                          color: Theme.of(context).primaryColor,
                        ),
                        title: Text(
                          m.displayName,
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
                            : () => _downloadAndOpen(m.fileUrl, m.displayName),
                        dense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Студент не прикріпив файли.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                if (resp.gradeComment != null && resp.gradeComment!.isNotEmpty)
                  Card(
                    color: Colors.green.shade50,
                    margin: const EdgeInsets.only(top: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Коментар до оцінки:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(resp.gradeComment!),
                        ],
                      ),
                    ),
                  ),
                if (resp.returnComment != null &&
                    resp.returnComment!.isNotEmpty)
                  Card(
                    color: Colors.blue.shade50,
                    margin: const EdgeInsets.only(top: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Коментар до повернення:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(resp.returnComment!),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                if (_canManage)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isProcessingAction || resp.isReturned
                            ? null
                            : () => _grade(resp),
                        icon: const Icon(Icons.grade_outlined),
                        label: Text(
                          resp.isGraded ? 'Змінити оцінку' : 'Оцінити',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                      if (resp.isGraded)
                        OutlinedButton.icon(
                          onPressed: _isProcessingAction
                              ? null
                              : () => _cancelGrade(resp),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Скасувати оцінку'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade800),
                            disabledForegroundColor: Colors.grey.shade500,
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: _isProcessingAction || resp.isGraded
                            ? null
                            : () => _return(resp),
                        icon: const Icon(Icons.replay_outlined),
                        label: Text(
                          resp.isReturned
                              ? 'Оновити коментар'
                              : 'Повернути',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                      if (resp.isReturned)
                        OutlinedButton.icon(
                          onPressed: _isProcessingAction
                              ? null
                              : () => _cancelReturn(resp),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Скасувати повернення'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade800),
                            disabledForegroundColor: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                if (_isProcessingAction)
                  const Padding(
                    padding: EdgeInsets.only(top: 24.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
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
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _maxGradeController;
  late TextEditingController _tagsController;
  DateTime? _selectedDeadline;
  late List<MediaFile> _existingFiles;
  final List<PlatformFile> _newFiles = [];
  final List<MediaFile> _filesToDelete = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.assignment.title);
    _descriptionController = TextEditingController(
      text: widget.assignment.description,
    );
    _maxGradeController = TextEditingController(
      text: widget.assignment.maxGrade?.toString() ?? '',
    );
    _tagsController = TextEditingController(
      text: widget.assignment.tags.map((t) => t.name).join(', '),
    );
    _selectedDeadline = widget.assignment.deadline;
    _existingFiles = List.from(widget.assignment.media);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxGradeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_isLoading) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );
      if (result != null && mounted) {
        final existingNewPaths = _newFiles.map((f) => f.path).toSet();
        setState(() {
          _newFiles.addAll(
            result.files.where((f) => !existingNewPaths.contains(f.path)),
          );
        });
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

  Future<void> _pickDeadline() async {
    if (_isLoading) return;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _selectedDeadline ?? DateTime.now(),
        ),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDeadline = DateTime(
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final maxGrade = int.tryParse(_maxGradeController.text.trim());
      final tags = _tagsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      bool titleChanged = title != widget.assignment.title;
      bool descChanged = description != widget.assignment.description;
      bool gradeChanged = maxGrade != widget.assignment.maxGrade;
      bool deadlineChanged = _selectedDeadline != widget.assignment.deadline;
      bool tagsChanged = !_listEquals(
        tags,
        widget.assignment.tags.map((t) => t.name).toList(),
      );

      bool textDataChanged =
          titleChanged ||
              descChanged ||
              gradeChanged ||
              deadlineChanged ||
              tagsChanged;

      scaffoldMessenger.hideCurrentSnackBar();

      if (textDataChanged) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Оновлення деталей завдання...'),
            duration: Duration(minutes: 1),
          ),
        );
        await CourseService().patchAssignment(
          widget.authToken,
          widget.courseId,
          widget.assignment.id,
          titleChanged ? title : null,
          descChanged ? description : null,
          tagsChanged ? tags : null,
          deadlineChanged ? _selectedDeadline : null,
          gradeChanged ? maxGrade : null,
        );
      }

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
        final pcloud = PCloudService();
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
          final f = _newFiles[i];
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Файл ${i + 1}/${_newFiles.length}: ${f.name}...'),
              duration: const Duration(minutes: 5),
            ),
          );
          if (f.path == null) continue;

          final publicUrl = await pcloud.uploadFileAndGetPublicLink(
            file: f,
            authToken: widget.authToken,
            purpose: 'assignment-file',
          );
          await CourseService().addMediaToAssignment(
            widget.authToken,
            widget.courseId,
            widget.assignment.id,
            publicUrl,
            f.name,
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
              'Помилка оновлення завдання: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final Set<String> setA = Set.from(a);
    final Set<String> setB = Set.from(b);
    return setA.difference(setB).isEmpty && setB.difference(setA).isEmpty;
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
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Назва завдання *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Вкажіть назву' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Опис',
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
                labelText: 'Макс. бал',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: false),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (int.tryParse(v.trim()) == null || int.parse(v.trim()) < 0)
                  return 'Введіть ціле невід\'ємне число';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Теги (через кому)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(
                _selectedDeadline == null
                    ? 'Дедлайн'
                    : 'Дедлайн: ${DateFormat('dd.MM.yyyy HH:mm').format(_selectedDeadline!)}',
              ),
              trailing: OutlinedButton(
                onPressed: _isLoading ? null : _pickDeadline,
                child: Text(
                  _selectedDeadline == null ? 'Встановити' : 'Змінити',
                ),
              ),
              onTap: _isLoading ? null : _pickDeadline,
            ),
            const SizedBox(height: 24),
            Text(
              'Прикріплені файли',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_existingFiles.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _existingFiles.length,
                itemBuilder: (context, index) {
                  final file = _existingFiles[index];
                  return Card(
                    elevation: 1,
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(
                        file.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      dense: true,
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                  String fileSize = file.size > 1048576
                      ? '${(file.size / 1048576).toStringAsFixed(2)} MB'
                      : file.size > 1024
                      ? '${(file.size / 1024).toStringAsFixed(2)} KB'
                      : '${file.size} B';
                  return Card(
                    color: Colors.green.shade50,
                    elevation: 1,
                    child: ListTile(
                      leading: const Icon(
                        Icons.upload_file,
                        color: Colors.green,
                      ),
                      title: Text(file.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(fileSize),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Скасувати додавання',
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _newFiles.removeAt(index)),
                      ),
                      dense: true,
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
                    elevation: 1,
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
                      dense: true,
                    ),
                  );
                },
              ),
            ],
            if (_existingFiles.isEmpty &&
                _newFiles.isEmpty &&
                _filesToDelete.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Файли не прикріплено.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
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

class InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isPastDue;

  const InfoChip({
    super.key,
    required this.label,
    required this.value,
    this.isPastDue = false,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.info_outline;
    Color chipColor = Colors.grey.shade200;
    Color textColor = Colors.black87;
    Color iconColor = Colors.grey.shade700;

    if (label == 'Дедлайн') {
      icon = Icons.timer_outlined;
      if (isPastDue) {
        chipColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        iconColor = Colors.red.shade700;
      }
    } else if (label == 'Макс. бал') {
      icon = Icons.star_border_outlined;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: iconColor),
      label: Text('$label: $value'),
      labelStyle: TextStyle(fontSize: 12, color: textColor),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      visualDensity: VisualDensity.compact,
    );
  }
}
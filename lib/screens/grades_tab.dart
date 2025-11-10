import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurs/classes/course_models.dart';
import 'package:kurs/screens/CoursesScreen.dart';
import 'package:kurs/screens/assignment_screens.dart';

class GradesTabView extends StatefulWidget {
  final String authToken;
  final int courseId;
  final CourseRole currentUserRole;
  final String currentUsername;

  const GradesTabView({
    super.key,
    required this.authToken,
    required this.courseId,
    required this.currentUserRole,
    required this.currentUsername,
  });

  @override
  State<GradesTabView> createState() => _GradesTabViewState();
}

class _GradesTabViewState extends State<GradesTabView> {
  bool _isLoading = true;
  String? _errorMessage;

  List<CourseMember> _students = [];
  List<Assignment> _assignments = [];
  Map<String, Map<int, AssignmentResponse>> _studentResponses = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Перевіряємо доступ
    if (widget.currentUserRole != CourseRole.PROFESSOR &&
        widget.currentUserRole != CourseRole.OWNER) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Доступ заборонено. Ця вкладка доступна тільки для викладачів.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final courseService = CourseService();

      // Завантажуємо список учасників та завдань паралельно
      final results = await Future.wait([
        courseService.getCourseMembers(widget.authToken, widget.courseId),
        courseService.getAssignments(widget.authToken, widget.courseId),
      ]);

      final List<CourseMember> members = results[0] as List<CourseMember>;
      final List<Assignment> assignments = results[1] as List<Assignment>;

      // Фільтруємо тільки студентів та leaders
      final students = members
          .where(
            (m) => m.role == CourseRole.STUDENT || m.role == CourseRole.LEADER,
          )
          .toList();

      // Завантажуємо відповіді для кожного завдання
      final Map<String, Map<int, AssignmentResponse>> studentResponses = {};

      for (var assignment in assignments) {
        try {
          final responses = await courseService.getAssignmentResponses(
            widget.authToken,
            widget.courseId,
            assignment.id,
          );

          for (var response in responses) {
            if (!studentResponses.containsKey(response.authorUsername)) {
              studentResponses[response.authorUsername] = {};
            }
            studentResponses[response.authorUsername]![assignment.id] =
                response;
          }
        } catch (e) {
          debugPrint(
            'Error loading responses for assignment ${assignment.id}: $e',
          );
        }
      }

      if (mounted) {
        setState(() {
          _students = students;
          _assignments = assignments;
          _studentResponses = studentResponses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Помилка завантаження даних: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (widget.currentUserRole == CourseRole.PROFESSOR ||
                  widget.currentUserRole == CourseRole.OWNER)
                const SizedBox(height: 16),
              if (widget.currentUserRole == CourseRole.PROFESSOR ||
                  widget.currentUserRole == CourseRole.OWNER)
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Спробувати знову'),
                ),
            ],
          ),
        ),
      );
    }

    if (_students.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Немає студентів у цьому курсі',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_assignments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Немає завдань у цьому курсі',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Студентів: ${_students.length} • Завдань: ${_assignments.length}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Оновити',
                onPressed: _loadData,
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                      minHeight: constraints.maxHeight,
                    ),
                    child: _buildGradesTable(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGradesTable() {
    final minColumnWidth = 120.0;
    final studentColumnWidth = 220.0;

    return Table(
      columnWidths: {
        0: FixedColumnWidth(studentColumnWidth),
        ...Map.fromEntries(
          List.generate(
            _assignments.length,
            (i) => MapEntry(i + 1, FixedColumnWidth(minColumnWidth)),
          ),
        ),
        _assignments.length + 1: FixedColumnWidth(minColumnWidth),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
        bottom: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildTableHeaderCell('Студент'),
            ..._assignments.map(
              (assignment) => _buildTableHeaderCell(
                assignment.title,
                tooltip:
                    assignment.title +
                    (assignment.maxGrade != null
                        ? ' (макс: ${assignment.maxGrade})'
                        : ''),
              ),
            ),
            _buildTableHeaderCell('Середній'),
          ],
        ),
        // Data rows
        ..._students.map((student) {
          final responses = _studentResponses[student.username] ?? {};

          int totalGrades = 0;
          double sumGrades = 0;

          for (var assignment in _assignments) {
            final response = responses[assignment.id];
            if (response != null &&
                response.isGraded &&
                response.grade != null) {
              totalGrades++;
              sumGrades += response.grade!;
            }
          }

          final avgGrade = totalGrades > 0
              ? (sumGrades / totalGrades).toStringAsFixed(1)
              : '-';

          return TableRow(
            children: [
              _buildStudentCell(student),
              ..._assignments.map((assignment) {
                final response = responses[assignment.id];
                return _buildGradeCellInTable(
                  response,
                  assignment.maxGrade,
                  studentUsername: student.username,
                  assignmentId: assignment.id,
                );
              }),
              _buildAverageCell(avgGrade, totalGrades > 0),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTableHeaderCell(String label, {String? tooltip}) {
    final cell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: cell);
    }
    return cell;
  }

  Widget _buildStudentCell(CourseMember student) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF7C6BA3),
            child: Text(
              student.username[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (student.role == CourseRole.LEADER)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeCellInTable(
    AssignmentResponse? response,
    int? maxGrade, {
    String? studentUsername,
    int? assignmentId,
  }) {
    final cell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Center(child: _buildGradeCell(response, maxGrade)),
    );

    if (response == null || studentUsername == null || assignmentId == null) {
      return cell;
    }

    return GestureDetector(
      onTap: () =>
          _openResponseDetail(studentUsername, assignmentId, response.id),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: cell),
    );
  }

  Widget _buildAverageCell(String avgGrade, bool hasGrades) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Center(
        child: Text(
          avgGrade,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: hasGrades ? Colors.green.shade700 : Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _openResponseDetail(
    String studentUsername,
    int assignmentId,
    int responseId,
  ) async {
    // Знайдемо максимальну оцінку завдання
    final assignment = _assignments.firstWhere(
      (a) => a.id == assignmentId,
      orElse: () => Assignment(
        id: assignmentId,
        title: '',
        description: '',
        authorUsername: '',
        maxGrade: null,
      ),
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResponseDetailScreen(
          authToken: widget.authToken,
          courseId: widget.courseId,
          assignmentId: assignmentId,
          responseId: responseId,
          currentUserRole: widget.currentUserRole,
          currentUsername: widget.currentUsername,
          assignmentMaxGrade: assignment.maxGrade,
        ),
      ),
    );

    // Оновляємо дані після повернення
    if (mounted) {
      _loadData();
    }
  }

  Widget _buildGradeCell(AssignmentResponse? response, int? maxGrade) {
    if (response == null) {
      return const Center(
        child: Text('—', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    if (response.isReturned) {
      return Tooltip(
        message:
            'Повернуто${response.returnComment != null ? ': ${response.returnComment}' : ''}',
        child: const Center(
          child: Text(
            'Повернуто',
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (response.isGraded && response.grade != null) {
      final grade = response.grade!;
      final percentage = maxGrade != null && maxGrade > 0
          ? (grade / maxGrade * 100)
          : 0.0;

      Color gradeColor;
      if (percentage >= 75) {
        gradeColor = Colors.green.shade700;
      } else if (percentage >= 60) {
        gradeColor = Colors.orange.shade700;
      } else {
        gradeColor = Colors.red.shade700;
      }

      return Tooltip(
        message: response.gradeComment ?? '',
        child: Center(
          child: Text(
            maxGrade != null ? '$grade / $maxGrade' : '$grade',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: gradeColor,
            ),
          ),
        ),
      );
    }

    return const Tooltip(
      message: 'Здано, очікується перевірка',
      child: Center(
        child: Text(
          'Здано',
          style: TextStyle(
            fontSize: 13,
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

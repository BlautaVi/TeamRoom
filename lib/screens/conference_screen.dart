import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:jitsi_meet/jitsi_meet.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../classes/conference_service.dart';
import '../classes/chat_models.dart';
import '../classes/course_models.dart';

class ConferenceScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final String username;
  final String courseName;
  final CourseRole? userRole;

  const ConferenceScreen({
    Key? key,
    required this.authToken,
    required this.courseId,
    required this.username,
    required this.courseName,
    this.userRole,
  }) : super(key: key);

  @override
  State<ConferenceScreen> createState() => _ConferenceScreenState();
}

class _ConferenceScreenState extends State<ConferenceScreen> {
  late ConferenceService _conferenceService;
  late Timer _refreshTimer;
  List<Conference> _conferences = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _subjectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _conferenceService = ConferenceService();
    _loadConferences();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadConferences(),
    );

    // JitsiMeet listener setup (if available in this version)
    // Can be added based on jitsi_meet version
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadConferences() async {
    try {
      final conferences = await _conferenceService.getCourseConferences(
        widget.authToken,
        widget.courseId,
      );
      if (mounted) {
        setState(() {
          _conferences = conferences;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _createConference() async {
    if (_subjectController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введіть назву конференції')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _conferenceService.createConference(
        widget.authToken,
        widget.courseId,
        _subjectController.text,
      );

      if (mounted) {
        _subjectController.clear();
        Navigator.of(context).pop();
        _loadConferences();
        await _joinConferenceInternal(response);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinConference(Conference conference) async {
    if (conference.status != ConferenceStatus.ACTIVE) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Конференція не активна')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _conferenceService.joinConference(
        widget.authToken,
        widget.courseId,
        conference.id,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        await _joinConferenceInternal(response);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinConferenceInternal(ConferenceJoinResponse response) async {
  try {
  // Windows - use InAppWebView
  if (Platform.isWindows) {
  print('Windows detected, using InAppWebView');
  final htmlContent = ConferenceService().generateJitsiHtml(
    jwt: response.jwt,
    roomName: response.roomName,
  subject: 'Конференція - ${widget.courseName}',
  role: response.role,
  jitsiServerUrl: response.jitsiServerUrl,
  );
  final dataUrl = 'data:text/html;charset=utf-8;base64,${base64Encode(utf8.encode(htmlContent))}';
  if (mounted) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => JitsiInAppWebViewScreen(
        url: dataUrl,
         subject: 'Конференція - ${widget.courseName}',
       ),
   ),
   );
   }
   return;
   }

  // Linux/macOS - use webview_flutter
  if (Platform.isLinux || Platform.isMacOS) {
   print('Desktop platform detected, using embedded WebView');
   if (mounted) {
   Navigator.of(context).push(
     MaterialPageRoute(
       builder: (_) => JitsiWebViewScreen(
         jwt: response.jwt,
         roomName: response.roomName,
           subject: 'Конференція - ${widget.courseName}',
           role: response.role,
           jitsiServerUrl: response.jitsiServerUrl,
           username: widget.username,
       ),
   ),
   );
   }
   return;
   }

  // Mobile platforms - request permissions
  try {
  await Permission.camera.request();
  await Permission.microphone.request();
  } catch (e) {
  print('Permission error (non-fatal, continuing): $e');
  // Continue anyway for platforms that don't require permissions
  }

  // Mobile platforms - use native Jitsi
  // Request permissions (already requested above, use defaults)
  final hasCameraPermission = true;
  final hasMicrophonePermission = true;

  // Wait for JWT timing
  final int waitTime = JwtTimingCalculator.calculateJwtWaitTime(
  response.jwt,
  );
  print('Waiting $waitTime ms for JWT timing');
  await Future.delayed(Duration(milliseconds: waitTime));

  // Launch Jitsi meeting
  print('Creating Jitsi options for room: ${response.roomName}');
  var options = JitsiMeetingOptions(room: response.roomName)
  ..serverURL = response.jitsiServerUrl
  ..token = response.jwt
  ..audioMuted = !hasMicrophonePermission
  ..videoMuted = !hasCameraPermission
  ..userDisplayName = widget.username;

  print('Joining meeting with options: serverURL=${options.serverURL}, room=${options.room}');
  await JitsiMeet.joinMeeting(options);
  print('Successfully joined meeting');
    } catch (e) {
      print('Error in _joinConferenceInternal: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка при приєднанні: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateConferenceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Створити конференцію'),
        content: TextField(
          controller: _subjectController,
          decoration: InputDecoration(
            hintText: 'Назва конференції',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: _createConference,
            child: const Text('Створити'),
          ),
        ],
      ),
    );
  }

  bool _canCreateConference() {
    if (widget.userRole == null) return false;
    return widget.userRole == CourseRole.OWNER ||
        widget.userRole == CourseRole.PROFESSOR ||
        widget.userRole == CourseRole.LEADER;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Відеоконференції'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConferences,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _canCreateConference()
          ? FloatingActionButton(
              onPressed: _showCreateConferenceDialog,
              tooltip: 'Створити конференцію',
              child: const Icon(Icons.videocam),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _conferences.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Помилка', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConferences,
              child: const Text('Спробувати ще раз'),
            ),
          ],
        ),
      );
    }

    if (_conferences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Немає конференцій',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Натисніть кнопку, щоб створити нову конференцію',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConferences,
      child: ListView.builder(
        itemCount: _conferences.length,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) =>
            _buildConferenceCard(_conferences[index]),
      ),
    );
  }

  Widget _buildConferenceCard(Conference conference) {
    final isActive = conference.status == ConferenceStatus.ACTIVE;
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final duration = _calculateDuration(conference);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: isActive ? () => _joinConference(conference) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conference.subject,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Створена: ${dateFormatter.format(conference.createdAt.toLocal())}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(conference.status),
                ],
              ),
              const SizedBox(height: 12),
              if (duration.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildInfoChip(
                    icon: Icons.schedule,
                    label: duration,
                  ),
                ),
              _buildParticipantsList(conference),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(
                    icon: Icons.people,
                    label: '${conference.participantCount} учасників',
                  ),
                  if (isActive)
                    ElevatedButton.icon(
                      onPressed: () => _joinConference(conference),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Приєднатися'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _calculateDuration(Conference conference) {
    if (conference.endedAt == null) {
      // Conference is active or not yet ended
      final now = DateTime.now();
      final difference = now.difference(conference.createdAt);
      if (difference.inHours > 0) {
        return 'Тривалість: ${difference.inHours}ч ${difference.inMinutes % 60}м';
      } else if (difference.inMinutes > 0) {
        return 'Тривалість: ${difference.inMinutes}м';
      }
      return '';
    } else {
      // Conference has ended
      final difference = conference.endedAt!.difference(conference.createdAt);
      if (difference.inHours > 0) {
        return 'Тривалість: ${difference.inHours}ч ${difference.inMinutes % 60}м';
      } else if (difference.inMinutes > 0) {
        return 'Тривалість: ${difference.inMinutes}м';
      }
      return 'Тривалість: < 1м';
    }
  }

  Widget _buildStatusBadge(ConferenceStatus status) {
    final isActive = status == ConferenceStatus.ACTIVE;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Text(
        isActive ? 'Активна' : 'Завершена',
        style: TextStyle(
          color: isActive ? Colors.green : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: Colors.grey.withValues(alpha: 0.2),
    );
  }

  Widget _buildParticipantsList(Conference conference) {
    if (conference.participants.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayParticipants = conference.participants.take(3).toList();
    final hasMore = conference.participants.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Учасники:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...displayParticipants.map((participant) {
              return Chip(
                label: Text(participant.username),
                avatar: CircleAvatar(
                  child: Text(
                    participant.username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                backgroundColor: _getRoleColor(participant.role),
              );
            }),
            if (hasMore)
              Chip(
                label: Text('+${conference.participants.length - 3}'),
                backgroundColor: Colors.grey.withValues(alpha: 0.3),
              ),
          ],
        ),
      ],
    );
  }

  Color _getRoleColor(ConferenceRole role) {
    switch (role) {
      case ConferenceRole.MODERATOR:
        return Colors.red.withValues(alpha: 0.3);
      case ConferenceRole.MEMBER:
        return Colors.blue.withValues(alpha: 0.3);
      case ConferenceRole.VIEWER:
        return Colors.orange.withValues(alpha: 0.3);
      default:
        return Colors.grey.withValues(alpha: 0.3);
    }
  }
}

/// WebView екран з підтримкою камери/мікрофону для Windows
class JitsiInAppWebViewScreen extends StatefulWidget {
  final String url;
  final String subject;

  const JitsiInAppWebViewScreen({
    Key? key,
    required this.url,
    required this.subject,
  }) : super(key: key);

  @override
  State<JitsiInAppWebViewScreen> createState() => _JitsiInAppWebViewScreenState();
}

class _JitsiInAppWebViewScreenState extends State<JitsiInAppWebViewScreen> {
  late WebViewController _webViewController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() async {
    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (url) {
            print('⏳ Завантаження: $url');
          },
          onPageFinished: (url) {
            print('✅ Завантажено: $url');
          },
          onWebResourceError: (error) {
            print('❌ Помилка: ${error.description}');
          },
        ))
        ..loadRequest(Uri.parse(widget.url));

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      print('✅ WebView створено для Windows');
    } catch (e) {
      print('❌ Помилка при ініціалізації WebView: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isInitialized
          ? WebViewWidget(controller: _webViewController)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

/// WebView-based Jitsi Meet screen for macOS/Linux
class JitsiWebViewScreen extends StatefulWidget {
  final String jwt;
  final String roomName;
  final String subject;
  final ConferenceRole role;
  final String jitsiServerUrl;
  final String username;

  const JitsiWebViewScreen({
    Key? key,
    required this.jwt,
    required this.roomName,
    required this.subject,
    required this.role,
    required this.jitsiServerUrl,
    required this.username,
  }) : super(key: key);

  @override
  State<JitsiWebViewScreen> createState() => _JitsiWebViewScreenState();
}

class _JitsiWebViewScreenState extends State<JitsiWebViewScreen> {
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _initializeWebViewAsync();
  }

  void _initializeWebViewAsync() {
    // Use post-frame callback to initialize after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebView();
    });
  }

  void _initializeWebView() {
  try {
  // Build Jitsi URL
  final jitsiUrl =
       '${widget.jitsiServerUrl}/${widget.roomName}?jwt=${widget.jwt}';

   // Initialize WebViewController with error handling for plugin issues
   try {
       final controller = WebViewController(
         onPermissionRequest: (request) {
            print('Permission requested: ${request.types}');
            // Автоматично дозволяємо доступ до камери та мікрофону
            try {
              request.grant();
            } catch (e) {
        print('Error granting permission: $e');
             }
      },
    )
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
   ..loadRequest(Uri.parse(jitsiUrl));

  if (mounted) {
  setState(() {
  _webViewController = controller;
  });
  }
  } on MissingPluginException catch (e) {
  print('WebView plugin not available: $e');
   if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
              content: const Text('WebView plugin не доступний. Спробуйте перезавантажити додаток.'),
       backgroundColor: Colors.red,
     ),
  );
  }
  } catch (e) {
   print('Error initializing WebViewController: $e');
  if (mounted) {
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
   content: Text('Помилка при запуску WebView: $e'),
  backgroundColor: Colors.red,
  ),
  );
  }
  }
  } catch (e) {
  print('Error in _initializeWebView: $e');
  if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
  content: Text('Помилка при запуску: $e'),
  backgroundColor: Colors.red,
  ),
  );
  }
  }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _webViewController == null
      ? const Center(child: CircularProgressIndicator())
      : WebViewWidget(controller: _webViewController!),
      );
      }
}


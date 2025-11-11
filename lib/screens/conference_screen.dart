import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../classes/conference_service.dart';
import '../classes/chat_models.dart';

class ConferenceScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final String username;
  final String courseName;

  const ConferenceScreen({
    Key? key,
    required this.authToken,
    required this.courseId,
    required this.username,
    required this.courseName,
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
      final conferences =
          await _conferenceService.getCourseConferences(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Конференція не активна')),
      );
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
      final int waitTime = JwtTimingCalculator.calculateJwtWaitTime(response.jwt);
      await Future.delayed(Duration(milliseconds: waitTime));

      if (Platform.isWindows) {
        // For Windows, open in browser
        await _launchJitsiInBrowser(response);
      } else {
        // For mobile platforms, use WebView
        final html = _conferenceService.generateJitsiHtml(
          jwt: response.jwt,
          roomName: response.roomName,
          subject: 'Конференція',
          role: response.role,
          jitsiServerUrl: response.jitsiServerUrl,
        );

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JitsiWebViewScreen(
                htmlContent: html,
                roomName: response.roomName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка при приєднанні: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchJitsiInBrowser(ConferenceJoinResponse response) async {
    try {
      final jitsiUrl = Uri(
        scheme: 'https',
        host: 'team-room-jitsi.duckdns.org',
        path: '/${response.roomName}',
        queryParameters: {
          'jwt': response.jwt,
        },
      );

      if (await canLaunchUrl(jitsiUrl)) {
        await launchUrl(
          jitsiUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не вдалося відкрити браузер'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: $e'),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateConferenceDialog,
        tooltip: 'Створити конференцію',
        child: const Icon(Icons.videocam),
      ),
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
            Text(
              'Помилка',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          style:
                              Theme.of(context)
                                  .textTheme
                                  .titleMedium
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

  Widget _buildStatusBadge(ConferenceStatus status) {
    final isActive = status == ConferenceStatus.ACTIVE;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: Colors.grey.withOpacity(0.2),
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
                backgroundColor: Colors.grey.withOpacity(0.3),
              ),
          ],
        ),
      ],
    );
  }

  Color _getRoleColor(ConferenceRole role) {
    switch (role) {
      case ConferenceRole.MODERATOR:
        return Colors.red.withOpacity(0.3);
      case ConferenceRole.MEMBER:
        return Colors.blue.withOpacity(0.3);
      case ConferenceRole.VIEWER:
        return Colors.orange.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }
}

/// WebView screen for displaying Jitsi Meet embedded in HTML
class JitsiWebViewScreen extends StatefulWidget {
  final String htmlContent;
  final String roomName;

  const JitsiWebViewScreen({
    Key? key,
    required this.htmlContent,
    required this.roomName,
  }) : super(key: key);

  @override
  State<JitsiWebViewScreen> createState() => _JitsiWebViewScreenState();
}

class _JitsiWebViewScreenState extends State<JitsiWebViewScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Помилка завантаження: ${error.description}'),
                backgroundColor: Colors.red,
              ),
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation including to 'about:blank' for exit
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(widget.htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.roomName),
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Вийти з конференції',
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Example file showing how to integrate conference functionality
/// into existing screens like CoursesScreen and ChatScreen
///
/// Remove this file after understanding the integration patterns

import 'package:flutter/material.dart';
import '../classes/chat_models.dart';
import '../classes/conference_service.dart';
import '../screens/conference_screen.dart';
import '../screens/conference_details_screen.dart';
import '../utils/conference_integration.dart';
import '../widgets/conference_widgets.dart';

// ============================================================================
// EXAMPLE 1: Adding Conference Tab to CoursesScreen
// ============================================================================

class CourseScreenWithConferenceExample extends StatefulWidget {
  const CourseScreenWithConferenceExample({Key? key}) : super(key: key);

  @override
  State<CourseScreenWithConferenceExample> createState() =>
      _CourseScreenWithConferenceExampleState();
}

class _CourseScreenWithConferenceExampleState
    extends State<CourseScreenWithConferenceExample>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Create tabs: Materials, Assignments, Conferences, Grades, etc.
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Курс'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Матеріали'),
            Tab(text: 'Завдання'),
            Tab(icon: Icon(Icons.videocam), text: 'Конференції'),
            Tab(text: 'Оцінки'),
            Tab(text: 'Чат'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Materials tab
          const Center(child: Text('Materials')),
          // Assignments tab
          const Center(child: Text('Assignments')),
          // Conferences tab - use ConferenceScreen
          ConferenceScreen(
            authToken: 'your_auth_token',
            courseId: 1,
            username: 'current_user',
            courseName: 'Course Name',
          ),
          // Grades tab
          const Center(child: Text('Grades')),
          // Chat tab
          const Center(child: Text('Chat')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// ============================================================================
// EXAMPLE 2: Adding Conference Button to CoursesScreen AppBar
// ============================================================================

class CourseScreenWithConferenceButtonExample extends StatelessWidget {
  final String authToken = 'user_token';
  final int courseId = 1;
  final String username = 'john_doe';
  final String courseName = 'Flutter Development';

  const CourseScreenWithConferenceButtonExample({Key? key}) : super(key: key);

  void _openConferences(BuildContext context) {
    ConferenceIntegration.navigateToConferences(
      context,
      authToken: authToken,
      courseId: courseId,
      username: username,
      courseName: courseName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Курс'),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Конференції',
            onPressed: () => _openConferences(context),
          ),
        ],
      ),
      body: const Center(child: Text('Course Content')),
    );
  }
}

// ============================================================================
// EXAMPLE 3: Displaying Active Conference Banner in ChatScreen
// ============================================================================

class ChatScreenWithConferenceBannerExample extends StatefulWidget {
  const ChatScreenWithConferenceBannerExample({Key? key}) : super(key: key);

  @override
  State<ChatScreenWithConferenceBannerExample> createState() =>
      _ChatScreenWithConferenceBannerExampleState();
}

class _ChatScreenWithConferenceBannerExampleState
    extends State<ChatScreenWithConferenceBannerExample> {
  // Mock active conference
  Conference? activeConference;

  @override
  void initState() {
    super.initState();
    // In real app, fetch active conference from API
    _loadActiveConference();
  }

  void _loadActiveConference() {
    // Example: Set a mock conference
    setState(() {
      activeConference = Conference(
        id: 1,
        courseId: 1,
        subject: 'Live Lecture - Flutter Advanced Topics',
        roomName: 'flutter_lecture_001',
        status: ConferenceStatus.ACTIVE,
        createdAt: DateTime.now(),
        participants: [
          ConferenceParticipant(
            username: 'professor',
            role: ConferenceRole.MODERATOR,
            joinedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          ConferenceParticipant(
            username: 'student1',
            role: ConferenceRole.MEMBER,
            joinedAt: DateTime.now(),
          ),
        ],
      );
    });
  }

  void _joinConference(Conference conference) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Приєднання до ${conference.subject}')),
    );
    // Implementation for joining conference
  }

  void _showConferenceDetails(Conference conference) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConferenceDetailsScreen(
          authToken: 'auth_token',
          courseId: 1,
          conference: conference,
          username: 'current_user',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Чат')),
      body: Column(
        children: [
          // Show active conference banner if available
          if (activeConference != null &&
              activeConference!.status == ConferenceStatus.ACTIVE)
            ConferenceBanner(
              conference: activeConference!,
              onTap: () => _showConferenceDetails(activeConference!),
              onJoin: () => _joinConference(activeConference!),
            ),
          // Chat messages
          Expanded(
            child: ListView(
              children: const [
                ListTile(title: Text('Message 1')),
                ListTile(title: Text('Message 2')),
                ListTile(title: Text('Message 3')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 4: Custom List of Conferences with Cards
// ============================================================================

class ConferencesListExample extends StatefulWidget {
  const ConferencesListExample({Key? key}) : super(key: key);

  @override
  State<ConferencesListExample> createState() => _ConferencesListExampleState();
}

class _ConferencesListExampleState extends State<ConferencesListExample> {
  List<Conference> conferences = [
    Conference(
      id: 1,
      courseId: 1,
      subject: 'Advanced Flutter Architecture',
      roomName: 'flutter_arch_001',
      status: ConferenceStatus.ACTIVE,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      participants: [
        ConferenceParticipant(
          username: 'instructor',
          role: ConferenceRole.MODERATOR,
          joinedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        ConferenceParticipant(
          username: 'student1',
          role: ConferenceRole.MEMBER,
          joinedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      ],
    ),
    Conference(
      id: 2,
      courseId: 1,
      subject: 'Q&A Session',
      roomName: 'qa_session_001',
      status: ConferenceStatus.ENDED,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      endedAt: DateTime.now().subtract(const Duration(hours: 12)),
      participants: [],
    ),
  ];

  void _joinConference(Conference conference) {
    ConferenceIntegration.showNotification(
      context,
      'Підключення до ${conference.subject}...',
    );
  }

  void _showDetails(Conference conference) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConferenceDetailsScreen(
          authToken: 'auth_token',
          courseId: 1,
          conference: conference,
          username: 'current_user',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Конференції')),
      body: ListView.builder(
        itemCount: conferences.length,
        itemBuilder: (context, index) {
          final conference = conferences[index];
          return ConferenceCard(
            conference: conference,
            onJoin: () => _joinConference(conference),
            onDetails: () => _showDetails(conference),
          );
        },
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 5: Empty State and Loading
// ============================================================================

class ConferencesWithStatesExample extends StatefulWidget {
  const ConferencesWithStatesExample({Key? key}) : super(key: key);

  @override
  State<ConferencesWithStatesExample> createState() =>
      _ConferencesWithStatesExampleState();
}

class _ConferencesWithStatesExampleState
    extends State<ConferencesWithStatesExample> {
  bool isLoading = true;
  List<Conference> conferences = [];

  @override
  void initState() {
    super.initState();
    _loadConferences();
  }

  Future<void> _loadConferences() async {
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      isLoading = false;
      conferences = [];
    });
  }

  void _createConference() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Створення конференції...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (conferences.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Конференції')),
        body: ConferenceEmptyState(
          message: 'Активних конференцій немає',
          icon: Icons.videocam_off,
          onAction: _createConference,
          actionLabel: 'Створити',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Конференції')),
      body: ListView.builder(
        itemCount: conferences.length,
        itemBuilder: (context, index) => ConferenceCard(
          conference: conferences[index],
          onJoin: () {},
          onDetails: () {},
        ),
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 6: Complete Course Screen Integration
// ============================================================================

/*
class CoursesScreen extends StatefulWidget {
  final String authToken;
  final String username;

  const CoursesScreen({
    Key? key,
    required this.authToken,
    required this.username,
  }) : super(key: key);

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  int _selectedCourseId = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мої курси'),
        actions: [
          // Add this button to navigate to conferences
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Конференції',
            onPressed: () {
              ConferenceIntegration.navigateToConferences(
                context,
                authToken: widget.authToken,
                courseId: _selectedCourseId,
                username: widget.username,
                courseName: 'Course Name',
              );
            },
          ),
        ],
      ),
      body: const Center(child: Text('Course Content')),
    );
  }
}
*/

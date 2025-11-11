import 'package:flutter/material.dart';
import '../classes/chat_models.dart';
import '../screens/conference_screen.dart';
import '../screens/conference_details_screen.dart';
import '../widgets/conference_widgets.dart';

/// Helper class for integrating conference functionality into existing screens
class ConferenceIntegration {
  /// Navigate to the main conference screen
  static void navigateToConferences(
    BuildContext context, {
    required String authToken,
    required int courseId,
    required String username,
    required String courseName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConferenceScreen(
          authToken: authToken,
          courseId: courseId,
          username: username,
          courseName: courseName,
        ),
      ),
    );
  }

  /// Navigate to conference details screen
  static void navigateToConferenceDetails(
    BuildContext context, {
    required String authToken,
    required int courseId,
    required Conference conference,
    required String username,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConferenceDetailsScreen(
          authToken: authToken,
          courseId: courseId,
          conference: conference,
          username: username,
        ),
      ),
    );
  }

  /// Show a dialog to create a new conference
  static Future<String?> showCreateConferenceDialog(
    BuildContext context,
  ) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Створити конференцію'),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Створити'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  /// Show a snackbar notification
  static void showNotification(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Build conference banner widget for chat screen
  static Widget buildConferenceBannerForChat({
    required Conference conference,
    required VoidCallback onTap,
    required VoidCallback onJoin,
  }) {
    return ConferenceBanner(
      conference: conference,
      onTap: onTap,
      onJoin: onJoin,
    );
  }

  /// Build conference card widget
  static Widget buildConferenceCard({
    required Conference conference,
    required VoidCallback onJoin,
    required VoidCallback? onDetails,
    bool isLoading = false,
  }) {
    return ConferenceCard(
      conference: conference,
      onJoin: onJoin,
      onDetails: onDetails,
      isLoading: isLoading,
    );
  }

  /// Build participants list widget
  static Widget buildParticipantsList({
    required List<ConferenceParticipant> participants,
    bool showRole = true,
  }) {
    return ConferenceParticipantsList(
      participants: participants,
      showRole: showRole,
    );
  }

  /// Format conference status for display
  static String formatConferenceStatus(ConferenceStatus status) {
    switch (status) {
      case ConferenceStatus.ACTIVE:
        return 'Активна';
      case ConferenceStatus.ENDED:
        return 'Завершена';
      default:
        return 'Невідома';
    }
  }

  /// Format conference role for display
  static String formatConferenceRole(ConferenceRole role) {
    switch (role) {
      case ConferenceRole.MODERATOR:
        return 'Модератор';
      case ConferenceRole.MEMBER:
        return 'Учасник';
      case ConferenceRole.VIEWER:
        return 'Спостерігач';
      default:
        return 'Невідома роль';
    }
  }

  /// Get color for conference role
  static Color getRoleColor(ConferenceRole role) {
    switch (role) {
      case ConferenceRole.MODERATOR:
        return Colors.red;
      case ConferenceRole.MEMBER:
        return Colors.blue;
      case ConferenceRole.VIEWER:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

/// Extension methods for Conference model
extension ConferenceExtensions on Conference {
  bool get isActive => status == ConferenceStatus.ACTIVE;

  bool get isEnded => status == ConferenceStatus.ENDED;

  String get statusString => ConferenceIntegration.formatConferenceStatus(status);

  int get durationMinutes {
    final end = endedAt ?? DateTime.now();
    return end.difference(createdAt).inMinutes;
  }
}

/// Extension methods for ConferenceParticipant model
extension ConferenceParticipantExtensions on ConferenceParticipant {
  String get roleString => ConferenceIntegration.formatConferenceRole(role);

  bool get isActive => leftAt == null;

  String get durationString {
    final end = leftAt ?? DateTime.now();
    return '${end.difference(joinedAt).inMinutes} хв';
  }
}

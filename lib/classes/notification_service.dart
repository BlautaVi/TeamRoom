import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'notification_models.dart';

typedef NotificationCallback = void Function(WebSocketBroadcast);

class NotificationService {
  final StompClient stompClient;
  final BuildContext context;

  void Function()? _notificationsUnsubscribe;
  final List<NotificationCallback> _listeners = [];

  NotificationService({
    required this.stompClient,
    required this.context,
  });

  void subscribe() {
    if (!stompClient.connected) {
      debugPrint('STOMP not connected, cannot subscribe to notifications');
      return;
    }

    _notificationsUnsubscribe = stompClient.subscribe(
      destination: '/user/queue/notifications',
      callback: _onBroadcastReceived,
    );
    debugPrint('Subscribed to /user/queue/notifications');
  }

  void unsubscribe() {
    _notificationsUnsubscribe?.call();
    _notificationsUnsubscribe = null;
    debugPrint('Unsubscribed from notifications');
  }

  void addListener(NotificationCallback callback) {
    _listeners.add(callback);
  }

  void removeListener(NotificationCallback callback) {
    _listeners.remove(callback);
  }

  void _onBroadcastReceived(StompFrame frame) {
    if (frame.body == null) return;

    try {
      final broadcast = WebSocketBroadcast.fromJson(
        jsonDecode(frame.body!) as Map<String, dynamic>,
      );
      debugPrint('Broadcast received: ${broadcast.type}');

      for (var listener in _listeners) {
        listener(broadcast);
      }

      _showNotification(broadcast);
    } catch (e) {
      debugPrint('Error processing broadcast: $e');
    }
  }

  void _showNotification(WebSocketBroadcast broadcast) {
    if (!context.mounted) return;

    final message = _buildNotificationMessage(broadcast);
    if (message == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _buildNotificationMessage(WebSocketBroadcast broadcast) {
    final payload = broadcast.payload;

    switch (broadcast.type) {
      case WebSocketMessageType.JOINED_TO_COURSE:
        final p = payload as JoinedToCoursePayload;
        return 'Ви приєдналися до курсу "${p.courseName}"';

      case WebSocketMessageType.REMOVED_FROM_COURSE:
        final p = payload as RemovedFromCoursePayload;
        return 'Ви видалені з курсу "${p.courseName}"';

      case WebSocketMessageType.ROLE_CHANGED_IN_COURSE:
        final p = payload as RoleChangedInCoursePayload;
        return 'Ваша роль у курсі "${p.courseName}" змінена: $p.oldRole → $p.newRole';

      case WebSocketMessageType.COURSE_UPDATED:
        final p = payload as CourseUpdatedPayload;
        return 'Курс "${p.courseName}" оновлено';

      case WebSocketMessageType.COURSE_DELETED:
        final p = payload as CourseDeletedPayload;
        return 'Курс "${p.courseName}" видалено';

      case WebSocketMessageType.MATERIAL_CREATED:
        final p = payload as MaterialCreatedPayload;
        return 'Новий матеріал "${p.materialTopic}" у курсі "${p.courseName}"';

      case WebSocketMessageType.MATERIAL_UPDATED:
        final p = payload as MaterialUpdatedPayload;
        return 'Матеріал "${p.materialTopic}" оновлено';

      case WebSocketMessageType.MATERIAL_DELETED:
        final p = payload as MaterialDeletedPayload;
        return 'Матеріал "${p.materialTopic}" видалено';

      case WebSocketMessageType.ASSIGNMENT_CREATED:
        final p = payload as AssignmentCreatedPayload;
        return 'Нове завдання "${p.assignmentTitle}" у курсі "${p.courseName}"';

      case WebSocketMessageType.ASSIGNMENT_UPDATED:
        final p = payload as AssignmentUpdatedPayload;
        return 'Завдання "${p.assignmentTitle}" оновлено';

      case WebSocketMessageType.ASSIGNMENT_DELETED:
        final p = payload as AssignmentDeletedPayload;
        return 'Завдання "${p.assignmentTitle}" видалено';

      case WebSocketMessageType.ASSIGNMENT_RESPONSE_CREATED:
        final p = payload as AssignmentResponseCreatedPayload;
        return '${p.responseAuthorFirstName} ${p.responseAuthorLastName} здав завдання "${p.assignmentTitle}"';

      case WebSocketMessageType.ASSIGNMENT_RESPONSE_UPDATED:
        final p = payload as AssignmentResponseUpdatedPayload;
        return 'Відповідь на завдання "${p.assignmentTitle}" оновлена';

      case WebSocketMessageType.ASSIGNMENT_RESPONSE_DELETED:
        final p = payload as AssignmentResponseDeletedPayload;
        return '${p.responseAuthorFirstName} видалив відповідь на завдання "${p.assignmentTitle}"';

      case WebSocketMessageType.UNKNOWN:
        return null;
    }
  }
  bool isDirectUserAction(WebSocketBroadcast broadcast) {
    switch (broadcast.type) {
      case WebSocketMessageType.JOINED_TO_COURSE:
      case WebSocketMessageType.REMOVED_FROM_COURSE:
      case WebSocketMessageType.ROLE_CHANGED_IN_COURSE:
        return true;
      default:
        return false;
    }
  }
  String? getCourseNameFromBroadcast(WebSocketBroadcast broadcast) {
    final payload = broadcast.payload;
    if (payload is JoinedToCoursePayload) return payload.courseName;
    if (payload is RemovedFromCoursePayload) return payload.courseName;
    if (payload is RoleChangedInCoursePayload) return payload.courseName;
    if (payload is CourseUpdatedPayload) return payload.courseName;
    if (payload is CourseDeletedPayload) return payload.courseName;
    if (payload is MaterialCreatedPayload) return payload.courseName;
    if (payload is MaterialUpdatedPayload) return payload.courseName;
    if (payload is MaterialDeletedPayload) return payload.courseName;
    if (payload is AssignmentCreatedPayload) return payload.courseName;
    if (payload is AssignmentUpdatedPayload) return payload.courseName;
    if (payload is AssignmentDeletedPayload) return payload.courseName;
    if (payload is AssignmentResponseCreatedPayload) return payload.courseName;
    if (payload is AssignmentResponseUpdatedPayload) return payload.courseName;
    if (payload is AssignmentResponseDeletedPayload) return payload.courseName;
    return null;
  }

  int? getCourseIdFromBroadcast(WebSocketBroadcast broadcast) {
    final payload = broadcast.payload;
    if (payload is JoinedToCoursePayload) return payload.courseId;
    if (payload is RemovedFromCoursePayload) return payload.courseId;
    if (payload is RoleChangedInCoursePayload) return payload.courseId;
    if (payload is CourseUpdatedPayload) return payload.courseId;
    if (payload is CourseDeletedPayload) return payload.courseId;
    if (payload is MaterialCreatedPayload) return payload.courseId;
    if (payload is MaterialUpdatedPayload) return payload.courseId;
    if (payload is MaterialDeletedPayload) return payload.courseId;
    if (payload is AssignmentCreatedPayload) return payload.courseId;
    if (payload is AssignmentUpdatedPayload) return payload.courseId;
    if (payload is AssignmentDeletedPayload) return payload.courseId;
    if (payload is AssignmentResponseCreatedPayload) return payload.courseId;
    if (payload is AssignmentResponseUpdatedPayload) return payload.courseId;
    if (payload is AssignmentResponseDeletedPayload) return payload.courseId;
    return null;
  }
}

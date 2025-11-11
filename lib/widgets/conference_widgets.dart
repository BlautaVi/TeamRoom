import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../classes/chat_models.dart';

class ConferenceCard extends StatelessWidget {
  final Conference conference;
  final VoidCallback onJoin;
  final VoidCallback? onDetails;
  final bool isLoading;

  const ConferenceCard({
    Key? key,
    required this.conference,
    required this.onJoin,
    this.onDetails,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isActive = conference.status == ConferenceStatus.ACTIVE;
    final dateFormatter = DateFormat('HH:mm');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isActive
              ? [Colors.blue.withOpacity(0.8), Colors.blue.withOpacity(0.6)]
              : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isActive ? Colors.blue : Colors.grey,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: isActive ? onJoin : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.videocam,
                          color: isActive ? Colors.white : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            conference.subject,
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Учасників: ${conference.participantCount}',
                    style: TextStyle(
                      color: isActive ? Colors.white70 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    dateFormatter.format(conference.createdAt.toLocal()),
                    style: TextStyle(
                      color: isActive ? Colors.white70 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onDetails != null)
                    TextButton.icon(
                      onPressed: onDetails,
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Деталі'),
                      style: TextButton.styleFrom(
                        foregroundColor: isActive ? Colors.white : Colors.grey,
                      ),
                    ),
                  if (isActive)
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : onJoin,
                      icon: const Icon(Icons.call),
                      label: const Text('Приєднатися'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
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
}

class ConferenceBanner extends StatelessWidget {
  final Conference conference;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  const ConferenceBanner({
    Key? key,
    required this.conference,
    required this.onTap,
    required this.onJoin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isActive = conference.status == ConferenceStatus.ACTIVE;

    if (!isActive) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.videocam, color: Colors.red, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Активна конференція',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conference.subject,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.call),
                label: const Text('Приєднатися'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConferenceParticipantsList extends StatelessWidget {
  final List<ConferenceParticipant> participants;
  final bool showRole;

  const ConferenceParticipantsList({
    Key? key,
    required this.participants,
    this.showRole = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('Немає учасників'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: participants.length,
      itemBuilder: (context, index) =>
          _buildParticipantTile(context, participants[index]),
    );
  }

  Widget _buildParticipantTile(
    BuildContext context,
    ConferenceParticipant participant,
  ) {
    final roleColor = _getRoleColor(participant.role);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: roleColor.withOpacity(0.3),
        child: Text(
          participant.username[0].toUpperCase(),
          style: TextStyle(
            color: roleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        participant.username,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: showRole
          ? Text(
              _getRoleLabel(participant.role),
              style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
            )
          : null,
      trailing: participant.leftAt == null
          ? const Chip(
              label: Text('В кімнаті'),
              backgroundColor: Colors.green,
              labelStyle: TextStyle(color: Colors.white, fontSize: 10),
            )
          : const Chip(
              label: Text('Вийшов'),
              backgroundColor: Colors.grey,
              labelStyle: TextStyle(color: Colors.white, fontSize: 10),
            ),
    );
  }

  Color _getRoleColor(ConferenceRole role) {
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

  String _getRoleLabel(ConferenceRole role) {
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
}

class ConferenceEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String actionLabel;

  const ConferenceEmptyState({
    Key? key,
    this.message = 'Конференцій немає',
    this.icon = Icons.videocam_off,
    this.onAction,
    this.actionLabel = 'Створити',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

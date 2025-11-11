import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../classes/conference_service.dart';
import '../classes/chat_models.dart';

class ConferenceDetailsScreen extends StatefulWidget {
  final String authToken;
  final int courseId;
  final Conference conference;
  final String username;

  const ConferenceDetailsScreen({
    Key? key,
    required this.authToken,
    required this.courseId,
    required this.conference,
    required this.username,
  }) : super(key: key);

  @override
  State<ConferenceDetailsScreen> createState() =>
      _ConferenceDetailsScreenState();
}

class _ConferenceDetailsScreenState extends State<ConferenceDetailsScreen> {
  late ConferenceService _conferenceService;
  late Conference _conference;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _conferenceService = ConferenceService();
    _conference = widget.conference;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final conference = await _conferenceService.getConferenceDetails(
        widget.authToken,
        widget.courseId,
        widget.conference.id,
      );
      setState(() {
        _conference = conference;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endConference() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершити конференцію?'),
        content: const Text(
          'Це дія необоротна. Всі учасники будуть відключені.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Завершити'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _conferenceService.endConference(
        widget.authToken,
        widget.courseId,
        widget.conference.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Конференція завершена')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm:ss');
    final isActive = _conference.status == ConferenceStatus.ACTIVE;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Деталі конференції'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: _isLoading && _conference.participants.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConferenceInfo(dateFormatter, isActive),
                    const SizedBox(height: 24),
                    _buildParticipantsSection(),
                    const SizedBox(height: 24),
                    if (isActive) _buildModerationSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildConferenceInfo(DateFormat dateFormatter, bool isActive) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _conference.subject,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Кімната: ${_conference.roomName}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Активна' : 'Завершена',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Створена:',
              dateFormatter.format(_conference.createdAt.toLocal()),
            ),
            const SizedBox(height: 8),
            if (_conference.endedAt != null)
              _buildInfoRow(
                'Завершена:',
                dateFormatter.format(_conference.endedAt!.toLocal()),
              ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Учасники:',
              _conference.participantCount.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Учасники (${_conference.participants.length})',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_conference.participants.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Icon(Icons.people_outline,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('Немає учасників'),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _conference.participants.length,
            itemBuilder: (context, index) =>
                _buildParticipantTile(_conference.participants[index]),
          ),
      ],
    );
  }

  Widget _buildParticipantTile(ConferenceParticipant participant) {
    final isMe = participant.username == widget.username;
    final roleColor = _getRoleColor(participant.role);
    final roleLabel = _getRoleLabel(participant.role);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
          participant.username + (isMe ? ' (ви)' : ''),
          style: TextStyle(
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Роль: $roleLabel',
              style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
            ),
            Text(
              'Приєднався: ${DateFormat('HH:mm:ss').format(participant.joinedAt.toLocal())}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (participant.leftAt != null)
              Text(
                'Вийшов: ${DateFormat('HH:mm:ss').format(participant.leftAt!.toLocal())}',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.red.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Управління конференцією',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _endConference,
                icon: const Icon(Icons.stop_circle),
                label: const Text('Завершити конференцію'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        return 'Невідома';
    }
  }
}

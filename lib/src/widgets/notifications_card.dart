import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationsCard extends StatefulWidget {
  const NotificationsCard({super.key, required this.businessId});

  final String businessId;

  @override
  State<NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<NotificationsCard> {
  List<Map<String, dynamic>> _notifications = const <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notifications = await NotificationService.getForCurrentUser(widget.businessId);
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _loading = false;
    });
  }

  Future<void> _handleTap(Map<String, dynamic> notification) async {
    if (notification['is_read'] == true) return;
    await NotificationService.markRead(notification['id'] as String);
    if (!mounted) return;
    setState(() => notification['is_read'] = true);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade500, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Text('Loading...')
            else if (_notifications.isEmpty)
              const Text('No notifications yet.')
            else
              ..._notifications.map((notification) {
                final isRead = notification['is_read'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _handleTap(notification),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.grey.shade100 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(notification['body'] as String? ?? ''),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

/// Notification bell with an unread-count badge -- without this, the only
/// way to discover a new notification is to open the panel first, which
/// defeats the point of a notification. Refreshes its count on first build
/// and again after the panel (opened via [onTap]) closes.
///
/// [businessIds] is a list rather than a single id so the same widget works
/// both for a single-business screen (Owner Dashboard, a shop's Customer
/// Home) and for "My Shops", which sums unread notifications across every
/// business the customer belongs to.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.businessIds, required this.onTap, this.color});

  final List<String> businessIds;
  final Future<void> Function() onTap;
  final Color? color;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessIds.join(',') != widget.businessIds.join(',')) _refresh();
  }

  Future<void> _refresh() async {
    final ids = widget.businessIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;
    final counts = await Future.wait(ids.map(NotificationService.getUnreadCount));
    if (!mounted) return;
    setState(() => _unreadCount = counts.fold(0, (sum, count) => sum + count));
  }

  Future<void> _handleTap() async {
    await widget.onTap();
    if (!mounted) return;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _handleTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, color: widget.color ?? AppColors.textPrimary),
          if (_unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                child: Text(
                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

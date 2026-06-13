import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../utils/theme.dart';

/// Screen showing user's notifications with read/unread state.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton.icon(
              onPressed: () => provider.markAllAsRead(),
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: const Text(
                'Read All',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, NotificationProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 12),
            Text(
              provider.error!,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none,
                size: 56,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You\'re all caught up!',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: provider.notifications.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final notification = provider.notifications[index];
        return _NotificationTile(
          notification: notification,
          onTap: () {
            if (!notification.isRead) {
              provider.markAsRead(notification.id);
            }
          },
        );
      },
    );
  }
}

/// A single notification list tile.
class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final timeAgo = _formatTimeAgo(notification.createdAt);

    return ListTile(
      onTap: onTap,
      tileColor: isUnread ? AppTheme.primaryColor.withAlpha(10) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _iconColor.withAlpha(25),
          shape: BoxShape.circle,
        ),
        child: Icon(_iconData, color: _iconColor, size: 22),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              notification.title,
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isUnread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            notification.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isUnread ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeAgo,
            style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  /// Determine icon based on notification title keywords.
  IconData get _iconData {
    final title = notification.title.toLowerCase();
    if (title.contains('approve')) return Icons.check_circle;
    if (title.contains('reject')) return Icons.cancel;
    if (title.contains('return')) return Icons.assignment_return;
    if (title.contains('borrow')) return Icons.bookmark_add;
    if (title.contains('overdue')) return Icons.warning;
    return Icons.notifications;
  }

  Color get _iconColor {
    final title = notification.title.toLowerCase();
    if (title.contains('approve')) return AppTheme.successColor;
    if (title.contains('reject')) return AppTheme.errorColor;
    if (title.contains('return')) return AppTheme.returnedColor;
    if (title.contains('borrow')) return AppTheme.primaryColor;
    if (title.contains('overdue')) return AppTheme.warningColor;
    return AppTheme.primaryColor;
  }

  /// Format a DateTime to a human-readable "time ago" string.
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }
}

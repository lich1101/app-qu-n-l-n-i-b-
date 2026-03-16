import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/services/app_firebase.dart';
import '../../data/services/mobile_api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> notifications = <Map<String, dynamic>>[];
  bool loading = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  @override
  void initState() {
    super.initState();
    _fetch();
    if (AppFirebase.isConfigured) {
      AppFirebase.ensureForegroundMessaging().then((_) {
        _foregroundSub?.cancel();
        _foregroundSub = AppFirebase.foregroundMessages.listen((_) {
          _fetch();
        });
      });
    }
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final Map<String, dynamic> data =
        await widget.apiService.getNotifications(widget.token);
    if (!mounted) return;
    setState(() {
      loading = false;
      notifications = ((data['notifications'] ?? <dynamic>[]) as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _markRead(String sourceType, int sourceId) async {
    final bool ok = await widget.apiService.markNotificationRead(
      widget.token,
      sourceType: sourceType,
      sourceId: sourceId,
    );
    if (!mounted) return;
    if (!ok) return;
    await _fetch();
  }

  Future<void> _markAllReadOnExit() async {
    await widget.apiService.markAllNotificationsRead(
      widget.token,
      sourceType: 'in_app',
    );
  }

  Future<void> _clearRead() async {
    await widget.apiService.clearReadNotifications(
      widget.token,
      sourceType: 'in_app',
    );
    await _fetch();
  }

  void _openNotificationDetail(Map<String, dynamic> item) {
    final bool isRead = item['is_read'] == true;
    if (!isRead) {
      _markRead('in_app', (item['id'] ?? 0) as int);
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        final String title = (item['title'] ?? 'Thông báo').toString();
        final String body = (item['body'] ?? '').toString();
        final String type = (item['type'] ?? 'general').toString();
        final String createdAt = (item['created_at'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                body.isEmpty ? 'Không có nội dung chi tiết.' : body,
                style: const TextStyle(color: StitchTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(Icons.info_outline, size: 16, color: StitchTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Loại: $type',
                    style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule, size: 16, color: StitchTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      createdAt,
                      style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'task_comment_tag':
        return Icons.alternate_email;
      case 'task_item_assigned':
        return Icons.assignment_turned_in;
      case 'deadline_reminder':
        return Icons.alarm_on;
      case 'contract_approval':
        return Icons.fact_check;
      case 'facebook_lead':
        return Icons.support_agent;
      default:
        return Icons.notifications_active;
    }
  }

  Color _notificationColor(String type) {
    switch (type) {
      case 'task_comment_tag':
        return StitchTheme.primary;
      case 'task_item_assigned':
        return StitchTheme.success;
      case 'deadline_reminder':
        return StitchTheme.warning;
      case 'contract_approval':
        return StitchTheme.primary;
      case 'facebook_lead':
        return StitchTheme.primary;
      default:
        return StitchTheme.primary;
    }
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final bool isRead = item['is_read'] == true;
    final String title = (item['title'] ?? 'Thông báo').toString();
    final String body = (item['body'] ?? '').toString();
    final String type = (item['type'] ?? 'general').toString();

    return InkWell(
      onTap: () => _openNotificationDetail(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : StitchTheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? StitchTheme.border : StitchTheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _notificationColor(type).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_notificationIcon(type), color: _notificationColor(type)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (body.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: StitchTheme.danger,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Xóa thông báo đã xem',
            onPressed: _clearRead,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (notifications.isEmpty)
              const Text(
                'Chưa có thông báo mới.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              ...notifications.map(_buildNotificationCard),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _markAllReadOnExit();
    super.dispose();
  }
}

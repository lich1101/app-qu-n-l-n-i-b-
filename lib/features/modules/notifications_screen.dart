import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/services/notification_router.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/services/app_firebase.dart';
import '../../data/services/mobile_api_service.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.token,
    required this.apiService,
    this.currentUserId,
    this.currentUserRole,
  });

  final String token;
  final MobileApiService apiService;
  final int? currentUserId;
  final String? currentUserRole;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Set<String> _chatNotificationTypes = <String>{
    'task_chat_message',
    'task_comment_tag',
  };

  List<Map<String, dynamic>> notifications = <Map<String, dynamic>>[];
  bool loading = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  int get _unreadCount =>
      notifications
          .where((Map<String, dynamic> item) => item['is_read'] != true)
          .length;
  int get _readCount =>
      notifications
          .where((Map<String, dynamic> item) => item['is_read'] == true)
          .length;

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
    final Map<String, dynamic> data = await widget.apiService.getNotifications(
      widget.token,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      notifications =
          ((data['notifications'] ?? <dynamic>[]) as List<dynamic>)
              .map((dynamic e) => e as Map<String, dynamic>)
              .toList();
    });
  }

  Future<void> _markRead(
    String sourceType,
    int sourceId, {
    bool refresh = true,
  }) async {
    final bool ok = await widget.apiService.markNotificationRead(
      widget.token,
      sourceType: sourceType,
      sourceId: sourceId,
    );
    if (!mounted) return;
    if (!ok) return;
    if (refresh) {
      await _fetch();
    }
  }

  Future<void> _clearRead() async {
    await widget.apiService.clearReadNotifications(
      widget.token,
      sourceType: 'in_app',
    );
    await _fetch();
  }

  Future<void> _markAllRead() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await widget.apiService.markAllNotificationsRead(
      widget.token,
    );
    if (!mounted) return;
    await _fetch();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã đánh dấu toàn bộ thông báo là đã đọc.'
              : 'Không thể cập nhật trạng thái thông báo.',
        ),
      ),
    );
  }

  int _extractTaskId(Map<String, dynamic> item) {
    final int rootTaskId = ((item['task_id'] as num?) ?? 0).toInt();
    if (rootTaskId > 0) {
      return rootTaskId;
    }
    final dynamic rawData = item['data'];
    if (rawData is Map<String, dynamic>) {
      return ((rawData['task_id'] as num?) ?? 0).toInt();
    }
    if (rawData is Map) {
      return ((rawData['task_id'] as num?) ?? 0).toInt();
    }
    return 0;
  }

  Future<void> _openNotificationDetail(Map<String, dynamic> item) async {
    final bool isRead = item['is_read'] == true;
    final int sourceId = ((item['id'] as num?) ?? 0).toInt();
    final String type = (item['type'] ?? 'general').toString();
    final bool isChatNotification = _chatNotificationTypes.contains(type);
    final int taskId = _extractTaskId(item);

    if (!isRead && sourceId > 0) {
      await _markRead('in_app', sourceId, refresh: false);
    }

    if (isChatNotification && taskId > 0) {
      final Map<String, dynamic>? task = await widget.apiService.getTaskDetail(
        widget.token,
        taskId,
      );
      if (!mounted) return;
      if (task != null && task.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<Widget>(
            builder:
                (_) => ChatDetailScreen(
                  token: widget.token,
                  apiService: widget.apiService,
                  task: task,
                  currentUserId: widget.currentUserId,
                ),
          ),
        );
        await _fetch();
        return;
      }
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'type': type,
      'task_id': item['task_id'],
      ...((item['data'] is Map<String, dynamic>)
          ? item['data'] as Map<String, dynamic>
          : (item['data'] is Map)
              ? (item['data'] as Map).cast<String, dynamic>()
              : <String, dynamic>{}),
    };

    if (!mounted) return;
    await NotificationRouter.routePayload(
      context,
      payload,
      token: widget.token,
      apiService: widget.apiService,
      currentUserId: widget.currentUserId,
      currentUserRole: widget.currentUserRole,
    );

    if (!isRead) {
      await _fetch();
    }
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
          color:
              isRead
                  ? Colors.white
                  : StitchTheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isRead
                    ? StitchTheme.border
                    : StitchTheme.primary.withValues(alpha: 0.2),
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
              child: Icon(
                _notificationIcon(type),
                color: _notificationColor(type),
              ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: StitchTheme.textMuted,
                      ),
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
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(
                foregroundColor: StitchTheme.primary,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Đọc tất cả'),
            ),
          IconButton(
            tooltip:
                _readCount > 0
                    ? 'Xóa toàn bộ thông báo đã đọc'
                    : 'Chưa có thông báo đã đọc để xóa',
            onPressed: _readCount > 0 ? _clearRead : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            if (notifications.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: StitchTheme.border),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _unreadCount > 0
                            ? 'Bạn còn $_unreadCount thông báo chưa đọc.'
                            : 'Tất cả thông báo đã được đọc.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: StitchTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    super.dispose();
  }
}

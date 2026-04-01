import 'package:flutter/material.dart';

import '../../config/app_env.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';
import 'admin_revenue_charts.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.summary,
    this.authUser,
    this.quickActions = const <OverviewQuickAction>[],
    this.adminActions = const <OverviewQuickAction>[],
    this.unreadNotifications = 0,
    this.unreadChats = 0,
    this.onOpenNotifications,
    this.onOpenChat,
    this.token,
    this.apiService,
    this.currentUserRole = '',
  });

  final Map<String, dynamic> summary;
  final Map<String, dynamic>? authUser;
  final List<OverviewQuickAction> quickActions;
  final List<OverviewQuickAction> adminActions;
  final int unreadNotifications;
  final int unreadChats;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenChat;
  final String? token;
  final MobileApiService? apiService;
  final String currentUserRole;

  int _readInt(List<String> keys, {int fallback = 0}) {
    for (final String key in keys) {
      final dynamic value = summary[key];
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        final int? parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return 'Hôm nay';
    }
  }

  String _formatDate(DateTime date) {
    return '${_weekdayName(date.weekday)}, ${date.day} Tháng ${date.month}';
  }

  String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'NB';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  List<Map<String, dynamic>> _extractProgressItems() {
    final dynamic raw =
        summary['project_progress'] ??
        summary['projects'] ??
        summary['project_cards'] ??
        summary['progress_items'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => item)
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _extractActivities() {
    final dynamic raw = summary['recent_activities'] ?? summary['activities'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => item)
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _extractOverloadList() {
    final dynamic raw =
        summary['workload_overload'] ?? summary['overload_list'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => item)
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final String name = (authUser?['name'] ?? 'Bạn').toString();
    final String avatarUrl = AppEnv.resolveMediaUrl(
      (authUser?['avatar_url'] ?? '').toString(),
    );
    final String dateLabel = _formatDate(VietnamTime.now());
    final bool compact = media.size.width < 380;
    final double bottomInset = media.padding.bottom + (compact ? 94 : 90);

    final int totalProjects = _readInt(<String>[
      'projects_total',
      'projects_in_progress',
      'projects',
    ]);
    final int overdueTasks = _readInt(<String>['tasks_overdue', 'overdue']);
    final int pendingTasks = _readInt(<String>[
      'tasks_pending',
      'tasks_waiting_approval',
      'tasks_in_review',
    ]);
    final int onTimeRate = _readInt(<String>[
      'on_time_rate',
      'on_time_percent',
    ]);

    final List<Map<String, dynamic>> progressItems = _extractProgressItems();
    final List<Map<String, dynamic>> activities = _extractActivities();
    final List<Map<String, dynamic>> overloadList = _extractOverloadList();
    final int workloadThreshold = _readInt(<String>[
      'workload_threshold',
    ], fallback: 8);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
        children: <Widget>[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stackActions = constraints.maxWidth < 360;

              Widget actionButton({
                required IconData icon,
                required VoidCallback? onTap,
                required int unreadCount,
              }) {
                return Stack(
                  children: <Widget>[
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: compact ? 42 : 46,
                          height: compact ? 42 : 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: StitchTheme.border),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x080F172A),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: StitchTheme.primary),
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: _UnreadBadge(count: unreadCount),
                      ),
                  ],
                );
              }

              final Widget userInfo = Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: compact ? 22 : 24,
                    backgroundColor: StitchTheme.primary,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child:
                        avatarUrl.isEmpty
                            ? Text(
                              _initials(name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Chào $name!',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 17 : 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final List<Widget> actions = <Widget>[
                if (onOpenNotifications != null)
                  actionButton(
                    icon: Icons.notifications_none,
                    onTap: onOpenNotifications,
                    unreadCount: unreadNotifications,
                  ),
                if (onOpenChat != null)
                  actionButton(
                    icon: Icons.chat_bubble_outline,
                    onTap: onOpenChat,
                    unreadCount: unreadChats,
                  ),
              ];

              final Widget actionCluster = Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < actions.length;
                        index++
                      ) ...<Widget>[
                        if (index > 0) const SizedBox(width: 8),
                        actions[index],
                      ],
                    ],
                  ),
                ],
              );

              if (!stackActions) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: userInfo),
                    if (actions.isNotEmpty) actionCluster,
                  ],
                );
              }

              return Column(
                children: <Widget>[
                  userInfo,
                  if (actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: actionCluster,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (token != null &&
              token!.isNotEmpty &&
              apiService != null &&
              currentUserRole.isNotEmpty) ...<Widget>[
            AdminRevenueCharts(
              token: token!,
              apiService: apiService!,
              currentUserRole: currentUserRole,
            ),
            const SizedBox(height: 20),
          ],
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              StitchMetricCard(
                icon: Icons.folder_open,
                label: 'Tổng dự án',
                value: totalProjects.toString(),
              ),
              StitchMetricCard(
                icon: Icons.calendar_today,
                label: 'Quá hạn',
                value: overdueTasks.toString(),
                accent: StitchTheme.danger,
              ),
              StitchMetricCard(
                icon: Icons.format_list_bulleted,
                label: 'Chờ duyệt',
                value: pendingTasks.toString(),
                accent: StitchTheme.warning,
              ),
              StitchMetricCard(
                icon: Icons.speed,
                label: 'Hiệu suất',
                value: '$onTimeRate%',
                accent: StitchTheme.success,
              ),
            ],
          ),
          if (quickActions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 22),
            const StitchSectionHeader(title: 'Truy cập nhanh'),
            const SizedBox(height: 12),
            _QuickActionsGrid(actions: quickActions),
          ],
          if (adminActions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            const StitchSectionHeader(title: 'Quản trị nhanh'),
            const SizedBox(height: 12),
            _QuickActionsGrid(actions: adminActions),
          ],
          const SizedBox(height: 24),
          const StitchSectionHeader(title: 'Tiến độ dự án'),
          const SizedBox(height: 12),
          if (progressItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StitchTheme.border),
              ),
              child: const Text(
                'Chưa có dữ liệu tiến độ dự án. Các dự án đang triển khai sẽ hiển thị tại đây.',
                style: TextStyle(color: StitchTheme.textMuted),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: progressItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> item = progressItems[index];
                  final String title = (item['name'] ?? 'Dự án').toString();
                  final String team =
                      (item['team'] ?? 'Team nội bộ').toString();
                  final int progress =
                      (item['progress'] ?? 0) is int
                          ? item['progress'] as int
                          : int.tryParse('${item['progress'] ?? 0}') ?? 0;
                  return StitchProgressCard(
                    title: title,
                    subtitle: team,
                    progress: progress,
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          const StitchSectionHeader(title: 'Hoạt động gần đây'),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const Text(
              'Chưa có hoạt động gần đây.',
              style: TextStyle(color: StitchTheme.textMuted),
            )
          else
            ...List<Widget>.generate(activities.length, (int index) {
              final Map<String, dynamic> activity = activities[index];
              final String user =
                  (activity['user'] ?? activity['name'] ?? 'Nhân sự')
                      .toString();
              final String content =
                  (activity['content'] ?? activity['message'] ?? 'cập nhật')
                      .toString();
              final String time =
                  (activity['time'] ?? activity['created_at'] ?? 'vừa xong')
                      .toString();
              return StitchTimelineItem(
                title: '$user $content',
                time: time,
                isLast: index == activities.length - 1,
              );
            }),
          const SizedBox(height: 24),
          const StitchSectionHeader(title: 'Nhân sự quá tải'),
          const SizedBox(height: 12),
          if (overloadList.isEmpty)
            const Text(
              'Chưa có nhân sự quá tải.',
              style: TextStyle(color: StitchTheme.textMuted),
            )
          else
            ...overloadList.map((Map<String, dynamic> item) {
              final String name = (item['name'] ?? 'Nhân sự').toString();
              final String role = (item['role'] ?? '').toString();
              final int active = _readInt(
                <String>[],
                fallback:
                    (item['active_tasks'] ?? 0) is int
                        ? item['active_tasks'] as int
                        : int.tryParse('${item['active_tasks'] ?? 0}') ?? 0,
              );
              final int overdue = _readInt(
                <String>[],
                fallback:
                    (item['overdue_tasks'] ?? 0) is int
                        ? item['overdue_tasks'] as int
                        : int.tryParse('${item['overdue_tasks'] ?? 0}') ?? 0,
              );
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: StitchTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (role.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          role,
                          style: const TextStyle(
                            fontSize: 11,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Công việc đang xử lý',
                          style: TextStyle(
                            fontSize: 11,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                        Text(
                          '$active / $workloadThreshold',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: StitchTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Công việc quá hạn',
                          style: TextStyle(
                            fontSize: 11,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                        Text(
                          overdue.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: StitchTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StitchTheme.danger,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class OverviewQuickAction {
  const OverviewQuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});

  final List<OverviewQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns =
            width >= 390
                ? 4
                : width >= 300
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: width < 360 ? 0.9 : 0.95,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children:
              actions
                  .map((OverviewQuickAction action) => _QuickActionTile(action))
                  .toList(),
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile(this.action);

  final OverviewQuickAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StitchTheme.border),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (action.color ?? StitchTheme.primaryStrong).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                action.icon,
                color: action.color ?? StitchTheme.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

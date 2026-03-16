import 'package:flutter/material.dart';

import '../../config/app_env.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';

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
  });

  final Map<String, dynamic> summary;
  final Map<String, dynamic>? authUser;
  final List<OverviewQuickAction> quickActions;
  final List<OverviewQuickAction> adminActions;
  final int unreadNotifications;
  final int unreadChats;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenChat;

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
    final dynamic raw = summary['project_progress'] ??
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
    final String name = (authUser?['name'] ?? 'Bạn').toString();
    final String avatarUrl = AppEnv.resolveMediaUrl(
      (authUser?['avatar_url'] ?? '').toString(),
    );
    final String dateLabel = _formatDate(DateTime.now());
    final double bottomInset = MediaQuery.of(context).padding.bottom + 80;

    final int totalProjects = _readInt(
      <String>['projects_total', 'projects_in_progress', 'projects'],
    );
    final int overdueTasks = _readInt(<String>['tasks_overdue', 'overdue']);
    final int pendingTasks = _readInt(
      <String>['tasks_pending', 'tasks_waiting_approval', 'tasks_in_review'],
    );
    final int onTimeRate =
        _readInt(<String>['on_time_rate', 'on_time_percent']);

    final List<Map<String, dynamic>> progressItems = _extractProgressItems();
    final List<Map<String, dynamic>> activities = _extractActivities();
    final List<Map<String, dynamic>> overloadList = _extractOverloadList();
    final int workloadThreshold =
        _readInt(<String>['workload_threshold'], fallback: 8);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
        children: <Widget>[
          StitchPageHeader(
            title: 'Trung tâm điều hành',
            subtitle:
                'Theo dõi tiến độ công việc, cảnh báo vận hành và các hành động quan trọng của hệ thống nội bộ.',
            icon: Icons.space_dashboard_outlined,
            stats: <StitchHeaderStat>[
              StitchHeaderStat(label: 'Hôm nay', value: dateLabel),
              StitchHeaderStat(
                label: 'Thông báo chưa đọc',
                value: unreadNotifications.toString(),
                accent: StitchTheme.warning,
              ),
              StitchHeaderStat(
                label: 'Tin nhắn công việc',
                value: unreadChats.toString(),
                accent: StitchTheme.success,
              ),
            ],
          ),
          const SizedBox(height: 16),
          StitchSurfaceCard(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: StitchTheme.primary,
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          _initials(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Xin chào, $name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ưu tiên kiểm tra các hạng mục quá hạn, chờ duyệt và thông báo theo công việc.',
                        style: TextStyle(
                          color: StitchTheme.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: <Widget>[
                    _ActionIconButton(
                      icon: Icons.notifications_none,
                      onTap: onOpenNotifications,
                      showDot: unreadNotifications > 0,
                    ),
                    const SizedBox(height: 8),
                    _ActionIconButton(
                      icon: Icons.chat_bubble_outline,
                      onTap: onOpenChat,
                      showDot: unreadChats > 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
            const StitchEmptyStateCard(
              title: 'Chưa có tiến độ dự án',
              message:
                  'Các dự án đang triển khai sẽ xuất hiện tại đây để theo dõi theo ngày và theo phần trăm hoàn thành.',
              icon: Icons.track_changes_outlined,
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
                  final String team = (item['team'] ?? 'Team nội bộ').toString();
                  final int progress = (item['progress'] ?? 0) is int
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
            const StitchEmptyStateCard(
              title: 'Chưa có nhật ký hoạt động',
              message:
                  'Khi dự án, công việc hoặc đầu việc được cập nhật, dòng thời gian vận hành sẽ hiển thị tại đây.',
              icon: Icons.history_toggle_off_outlined,
            )
          else
            StitchSurfaceCard(
              child: Column(
                children: List<Widget>.generate(
                  activities.length,
                  (int index) {
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
                  },
                ),
              ),
            ),
          const SizedBox(height: 24),
          const StitchSectionHeader(title: 'Nhân sự quá tải'),
          const SizedBox(height: 12),
          if (overloadList.isEmpty)
            const StitchEmptyStateCard(
              title: 'Chưa có cảnh báo quá tải',
              message:
                  'Hệ thống sẽ cảnh báo nhân sự có số lượng công việc xử lý vượt ngưỡng cấu hình.',
              icon: Icons.monitor_heart_outlined,
            )
          else
            ...overloadList.map((Map<String, dynamic> item) {
              final String name = (item['name'] ?? 'Nhân sự').toString();
              final String role = (item['role'] ?? '').toString();
              final int active = _readInt(
                <String>[],
                fallback: (item['active_tasks'] ?? 0) is int
                    ? item['active_tasks'] as int
                    : int.tryParse('${item['active_tasks'] ?? 0}') ?? 0,
              );
              final int overdue = _readInt(
                <String>[],
                fallback: (item['overdue_tasks'] ?? 0) is int
                    ? item['overdue_tasks'] as int
                    : int.tryParse('${item['overdue_tasks'] ?? 0}') ?? 0,
              );
              return StitchSurfaceCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
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

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.onTap,
    required this.showDot,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: StitchTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: StitchTheme.border),
            ),
            child: Icon(icon, color: StitchTheme.primary),
          ),
        ),
        if (showDot)
          const Positioned(
            right: -2,
            top: -2,
            child: _BlinkingDot(),
          ),
      ],
    );
  }
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);
  late final Animation<double> _opacity =
      Tween<double>(begin: 0.3, end: 1).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: StitchTheme.danger,
          shape: BoxShape.circle,
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
        final int columns = width >= 360 ? 4 : 3;
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: 0.95,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: actions
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: StitchTheme.border),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: StitchTheme.shadow,
              blurRadius: 16,
              offset: Offset(0, 8),
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
                color: (action.color ?? StitchTheme.primaryStrong).withValues(alpha: 0.12),
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
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

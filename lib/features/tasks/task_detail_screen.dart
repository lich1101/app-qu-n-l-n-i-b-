import 'package:flutter/material.dart';

import '../../core/messaging/app_tag_message.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/utils/task_item_linear_pace.dart';
import '../../core/utils/vietnam_time.dart';
import '../../data/services/mobile_api_service.dart';
import 'task_item_detail_screen.dart';
import 'task_item_form_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.taskId,
  });

  final String token;
  final MobileApiService apiService;
  final int taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _loading = true;
  String _message = '';
  Map<String, dynamic>? _task;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _departments = <Map<String, dynamic>>[];
  int? _currentUserId;
  String _currentUserRole = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final List<dynamic> responses =
          await Future.wait<dynamic>(<Future<dynamic>>[
            widget.apiService.getTaskDetail(widget.token, widget.taskId),
            widget.apiService.getTaskItems(
              widget.token,
              widget.taskId,
              perPage: 200,
            ),
            widget.apiService.me(widget.token),
          ]);

      final Map<String, dynamic>? task = responses[0] as Map<String, dynamic>?;
      final List<Map<String, dynamic>> items =
          responses[1] as List<Map<String, dynamic>>;
      final Map<String, dynamic> mePayload =
          responses[2] as Map<String, dynamic>;
      final Map<String, dynamic> meBody =
          (mePayload['body'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final dynamic rawId = meBody['id'];

      if (!mounted) return;
      setState(() {
        _task = task;
        _items = items;
        _currentUserId = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
        _currentUserRole = (meBody['role'] ?? '').toString();
        _loading = false;
        _message = task == null ? 'Không tìm thấy công việc.' : '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Không tải được dữ liệu công việc.';
      });
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'todo':
        return 'Cần làm';
      case 'doing':
        return 'Đang làm';
      case 'done':
        return 'Hoàn tất';
      case 'blocked':
        return 'Bị chặn';
      default:
        return value.isEmpty ? '—' : value;
    }
  }

  String _priorityLabel(String value) {
    switch (value) {
      case 'low':
        return 'Thấp';
      case 'medium':
        return 'Trung bình';
      case 'high':
        return 'Cao';
      case 'urgent':
        return 'Khẩn';
      default:
        return value.isEmpty ? '—' : value;
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    final DateTime? dt = VietnamTime.parse(raw);
    if (dt == null) return '—';
    return VietnamTime.formatDate(dt);
  }

  String _assigneeLabel(Map<String, dynamic> item) {
    final Map<String, dynamic>? assignee =
        item['assignee'] is Map<String, dynamic>
            ? item['assignee'] as Map<String, dynamic>
            : null;
    return (assignee?['name'] ?? assignee?['email'] ?? 'Chưa phân công')
        .toString();
  }

  bool _isTaskApprovalOwner() {
    final dynamic rawProject = _task?['project'];
    final Map<String, dynamic>? project =
        rawProject is Map<String, dynamic> ? rawProject : null;
    final int projectOwnerId = _toInt(project?['owner_id']);
    if (_currentUserRole == 'admin') return true;
    if (_currentUserId == null) return false;
    return projectOwnerId > 0 && projectOwnerId == _currentUserId;
  }

  bool get _isAdminRole =>
      _currentUserRole == 'admin' || _currentUserRole == 'administrator';

  /// NV thu hợp đồng: chỉ xem, không thêm/sửa/xóa đầu việc (trừ chủ dự án / admin).
  bool get _isContractCollectorReadOnly {
    if (_currentUserId == null) return false;
    final dynamic rawProject = _task?['project'];
    final Map<String, dynamic>? project =
        rawProject is Map<String, dynamic> ? rawProject : null;
    if (project == null) return false;
    final dynamic rawContract = project['contract'];
    final int collectorId = _toInt(
      project['collector_user_id'] ??
          (rawContract is Map<String, dynamic>
              ? rawContract['collector_user_id']
              : null),
    );
    final int ownerId = _toInt(project['owner_id']);
    if (collectorId <= 0 || collectorId != _currentUserId) return false;
    if (_isAdminRole) return false;
    if (ownerId > 0 && ownerId == _currentUserId) return false;
    return true;
  }

  bool get _canManageItems {
    if (_isContractCollectorReadOnly) return false;
    if (_isAdminRole) return true;
    final int projectOwnerId = _toInt(_task?['project']?['owner_id']);
    if (_currentUserId != null &&
        projectOwnerId > 0 &&
        projectOwnerId == _currentUserId) {
      return true;
    }
    return _currentUserId != null &&
        _toInt(_task?['assignee_id']) == _currentUserId;
  }

  Future<void> _ensureDepartmentsLoaded() async {
    if (_departments.isNotEmpty) return;
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getDepartments(widget.token);
    if (!mounted) return;
    setState(() => _departments = rows);
  }

  Future<void> _openItemEditor({Map<String, dynamic>? item}) async {
    if (!_canManageItems) return;
    await _ensureDepartmentsLoaded();
    if (!mounted) return;
    final bool isEdit = item != null;
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => TaskItemFormScreen(
              token: widget.token,
              apiService: widget.apiService,
              taskId: widget.taskId,
              departments: _departments,
              taskDepartmentId: _toInt(_task?['department_id']),
              taskStartAt: _task?['start_at'],
              taskDeadline: _task?['deadline'],
              projectSummary:
                  _task?['project'] is Map<String, dynamic>
                      ? _task!['project'] as Map<String, dynamic>
                      : null,
              editingItem: item,
            ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      await _fetch();
      if (!mounted) return;
      AppTagMessage.show(
        isEdit ? 'Đã cập nhật đầu việc.' : 'Đã thêm đầu việc mới.',
      );
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    if (!_canManageItems) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa đầu việc'),
          content: Text(
            'Bạn có chắc muốn xóa đầu việc "${(item['title'] ?? 'Đầu việc').toString()}"?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: StitchTheme.danger,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final bool ok = await widget.apiService.deleteTaskItem(
      widget.token,
      widget.taskId,
      _toInt(item['id']),
    );
    if (!mounted) return;
    if (ok) {
      await _fetch();
    }
    if (!mounted) return;
    AppTagMessage.show(
      ok ? 'Đã xóa đầu việc.' : 'Không thể xóa đầu việc.',
      isError: !ok,
    );
  }

  List<_TaskItemGroup> _groupedItems() {
    final Map<String, List<Map<String, dynamic>>> grouped =
        <String, List<Map<String, dynamic>>>{};

    for (final Map<String, dynamic> item in _items) {
      final String label = _assigneeLabel(item);
      grouped.putIfAbsent(label, () => <Map<String, dynamic>>[]).add(item);
    }

    final List<_TaskItemGroup> groups =
        grouped.entries
            .map(
              (MapEntry<String, List<Map<String, dynamic>>> entry) =>
                  _TaskItemGroup(
                    assignee: entry.key,
                    items: List<Map<String, dynamic>>.from(entry.value)..sort(
                      (Map<String, dynamic> a, Map<String, dynamic> b) =>
                          '${a['deadline'] ?? ''}'.compareTo(
                            '${b['deadline'] ?? ''}',
                          ),
                    ),
                  ),
            )
            .toList()
          ..sort((a, b) => a.assignee.compareTo(b.assignee));

    return groups;
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    final int itemId = _toInt(item['id']);
    if (itemId <= 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<Widget>(
        builder:
            (_) => TaskItemDetailScreen(
              token: widget.token,
              apiService: widget.apiService,
              taskId: widget.taskId,
              itemId: itemId,
            ),
      ),
    );
    await _fetch();
  }

  List<Widget> _buildFlatTaskItems({
    required List<_TaskItemGroup> groups,
    required String Function(String value) statusLabel,
    required Future<void> Function(Map<String, dynamic> item) onOpenItem,
    required int Function(dynamic value) toInt,
    required bool canManageItems,
    required Future<void> Function(Map<String, dynamic> item) onEditItem,
    required Future<void> Function(Map<String, dynamic> item) onDeleteItem,
  }) {
    final List<Widget> out = <Widget>[];
    for (int g = 0; g < groups.length; g++) {
      final _TaskItemGroup group = groups[g];
      if (g > 0) {
        out.add(const SizedBox(height: 8));
      }
      out.add(
        _AssigneeHeaderRow(
          assignee: group.assignee,
          itemCount: group.items.length,
          avgProgress:
              group.items.isEmpty
                  ? 0
                  : group.items
                          .map(
                            (Map<String, dynamic> item) =>
                                toInt(item['progress_percent']),
                          )
                          .reduce((int a, int b) => a + b) ~/
                      group.items.length,
        ),
      );
      for (int i = 0; i < group.items.length; i++) {
        final Map<String, dynamic> item = group.items[i];
        final bool lastInGroup = i == group.items.length - 1;
        final bool lastOverall = g == groups.length - 1 && lastInGroup;
        out.add(
          _FlatTaskItemTile(
            item: item,
            statusLabel: statusLabel,
            onOpenItem: onOpenItem,
            toInt: toInt,
            canManageItems: canManageItems,
            onEditItem: onEditItem,
            onDeleteItem: onDeleteItem,
            showDividerBelow: !lastOverall,
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final int progress = _toInt(_task?['progress_percent']);
    final int taskWeight = _toInt(_task?['weight_percent']);
    final int totalItemWeight = _items.fold<int>(
      0,
      (int sum, Map<String, dynamic> item) =>
          sum + _toInt(item['weight_percent']),
    );
    final int remainingWeight = 100 - totalItemWeight;
    final List<_TaskItemGroup> groups = _groupedItems();

    return Scaffold(
      backgroundColor: StitchTheme.formPageBackground,
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        backgroundColor: StitchTheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: <Widget>[
                      if (_message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _message,
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if (_task != null) ...<Widget>[
                        _TaskSummaryHeader(
                          title: (_task?['title'] ?? 'Công việc').toString(),
                          description: (_task?['description'] ?? '').toString(),
                          progress: progress,
                          taskWeight: taskWeight,
                          itemCount: _items.length,
                          totalItemWeight: totalItemWeight,
                          remainingWeight: remainingWeight,
                          status: _statusLabel(
                            (_task?['status'] ?? '').toString(),
                          ),
                          priority: _priorityLabel(
                            (_task?['priority'] ?? '').toString(),
                          ),
                          department:
                              (_task?['department']?['name'] ?? '—').toString(),
                          assignee:
                              (_task?['assignee']?['name'] ?? 'Chưa phân công')
                                  .toString(),
                          deadline: _formatDate(
                            (_task?['deadline'] ?? '').toString(),
                          ),
                          canAddItem: _canManageItems,
                          isApprovalOwner: _isTaskApprovalOwner(),
                          onAddItem: () => _openItemEditor(),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Đầu việc trong công việc',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: StitchTheme.textMain,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (remainingWeight < 0) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            'Tổng tỷ trọng các đầu việc đang vượt 100%.',
                            style: TextStyle(
                              color: StitchTheme.danger,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Chưa có đầu việc nào.',
                              style: TextStyle(
                                color: StitchTheme.textMuted.withValues(
                                  alpha: 0.9,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ..._buildFlatTaskItems(
                            groups: groups,
                            statusLabel: _statusLabel,
                            onOpenItem: _openItem,
                            toInt: _toInt,
                            canManageItems: _canManageItems,
                            onEditItem:
                                (Map<String, dynamic> item) =>
                                    _openItemEditor(item: item),
                            onDeleteItem: _deleteItem,
                          ),
                      ],
                    ],
                  ),
                ),
      ),
    );
  }
}

class _TaskItemGroup {
  const _TaskItemGroup({required this.assignee, required this.items});

  final String assignee;
  final List<Map<String, dynamic>> items;
}

class _TaskSummaryHeader extends StatelessWidget {
  const _TaskSummaryHeader({
    required this.title,
    required this.description,
    required this.progress,
    required this.taskWeight,
    required this.itemCount,
    required this.totalItemWeight,
    required this.remainingWeight,
    required this.status,
    required this.priority,
    required this.department,
    required this.assignee,
    required this.deadline,
    required this.canAddItem,
    required this.isApprovalOwner,
    required this.onAddItem,
  });

  final String title;
  final String description;
  final int progress;
  final int taskWeight;
  final int itemCount;
  final int totalItemWeight;
  final int remainingWeight;
  final String status;
  final String priority;
  final String department;
  final String assignee;
  final String deadline;
  final bool canAddItem;
  final bool isApprovalOwner;
  final VoidCallback onAddItem;

  static const TextStyle _meta = TextStyle(
    fontSize: 12,
    height: 1.45,
    color: StitchTheme.textMuted,
    fontWeight: FontWeight.w400,
  );

  @override
  Widget build(BuildContext context) {
    final int rem = remainingWeight < 0 ? 0 : remainingWeight;
    final Color? allocColor = remainingWeight < 0 ? StitchTheme.danger : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: StitchTheme.textMain,
            letterSpacing: -0.3,
          ),
        ),
        if (description.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(description.trim(), style: _meta.copyWith(fontSize: 13)),
        ],
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 100) / 100,
            minHeight: 6,
            backgroundColor: StitchTheme.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(
              StitchTheme.progressPercentFillColor(progress),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tiến độ hiện tại: $progress%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: StitchTheme.textMuted.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tỷ trọng công việc $taskWeight% · $itemCount đầu việc · '
          'Đã phân bổ $totalItemWeight% · Còn $rem%',
          style: _meta.copyWith(
            color: allocColor ?? StitchTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text('Trạng thái: $status · Ưu tiên: $priority', style: _meta),
        const SizedBox(height: 4),
        Text('Phòng ban: $department · Phụ trách: $assignee', style: _meta),
        const SizedBox(height: 4),
        Text('Deadline: $deadline', style: _meta),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (canAddItem)
              FilledButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm đầu việc'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            if (isApprovalOwner)
              Text(
                'Bạn là người duyệt phiếu đầu việc',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: StitchTheme.primaryStrong.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AssigneeHeaderRow extends StatelessWidget {
  const _AssigneeHeaderRow({
    required this.assignee,
    required this.itemCount,
    required this.avgProgress,
  });

  final String assignee;
  final int itemCount;
  final int avgProgress;

  @override
  Widget build(BuildContext context) {
    final String letter =
        assignee.trim().isEmpty ? '?' : assignee.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: StitchTheme.primary.withValues(alpha: 0.12),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: StitchTheme.primaryStrong,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  assignee.isEmpty ? 'Chưa phân công' : assignee,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: StitchTheme.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$itemCount đầu việc · Tiến độ TB $avgProgress%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: StitchTheme.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatTaskItemTile extends StatelessWidget {
  const _FlatTaskItemTile({
    required this.item,
    required this.statusLabel,
    required this.onOpenItem,
    required this.toInt,
    required this.canManageItems,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.showDividerBelow,
  });

  final Map<String, dynamic> item;
  final String Function(String value) statusLabel;
  final Future<void> Function(Map<String, dynamic> item) onOpenItem;
  final int Function(dynamic value) toInt;
  final bool canManageItems;
  final Future<void> Function(Map<String, dynamic> item) onEditItem;
  final Future<void> Function(Map<String, dynamic> item) onDeleteItem;
  final bool showDividerBelow;

  @override
  Widget build(BuildContext context) {
    final String st = (item['status'] ?? '').toString();
    final Color tone = _taskItemStatusColor(st);
    final int pct = toInt(item['progress_percent']);
    final String itemTitle = (item['title'] ?? 'Đầu việc').toString();

    return Padding(
      padding: EdgeInsets.only(bottom: showDividerBelow ? 10 : 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StitchTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: StitchTheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onOpenItem(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                itemTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  height: 1.25,
                                  color: StitchTheme.textMain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              statusLabel(st),
                              style: TextStyle(
                                color: tone,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if ((item['description'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              (item['description'] ?? '').toString(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: StitchTheme.textMuted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          'Tiến độ: $pct%',
                          style: const TextStyle(
                            color: StitchTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0, 100) / 100,
                            minHeight: 5,
                            color: StitchTheme.progressPercentFillColor(pct),
                            backgroundColor: StitchTheme.surfaceAlt,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: taskItemPaceStatusLine(
                            computeTaskItemLinearPace(item),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Wrap(
                  spacing: 0,
                  runSpacing: 0,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: () => onOpenItem(item),
                      icon: const Icon(Icons.visibility_outlined, size: 17),
                      label: const Text('Chi tiết'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    if (canManageItems) ...<Widget>[
                      TextButton.icon(
                        onPressed: () => onEditItem(item),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Sửa'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => onDeleteItem(item),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text('Xóa'),
                        style: TextButton.styleFrom(
                          foregroundColor: StitchTheme.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _taskItemStatusColor(String status) {
  switch (status) {
    case 'done':
      return StitchTheme.successStrong;
    case 'doing':
      return StitchTheme.primaryStrong;
    case 'blocked':
      return StitchTheme.danger;
    case 'todo':
    default:
      return StitchTheme.warningStrong;
  }
}

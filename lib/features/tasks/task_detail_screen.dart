import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../data/services/mobile_api_service.dart';
import 'task_item_detail_screen.dart';

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
    if (dt == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
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

  bool get _canManageItems {
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

  String _toDateInput(dynamic value) {
    final String raw = (value ?? '').toString().trim();
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime now = DateTime.now();
    DateTime initial = now;
    if (controller.text.trim().isNotEmpty) {
      final DateTime? parsed = DateTime.tryParse(controller.text.trim());
      if (parsed != null) {
        initial = parsed;
      }
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    controller.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openItemEditor({Map<String, dynamic>? item}) async {
    if (!_canManageItems) return;
    await _ensureDepartmentsLoaded();
    if (!mounted) return;
    final bool isEdit = item != null;

    final TextEditingController titleCtrl = TextEditingController(
      text: (item?['title'] ?? '').toString(),
    );
    final TextEditingController descCtrl = TextEditingController(
      text: (item?['description'] ?? '').toString(),
    );
    final TextEditingController progressCtrl = TextEditingController(
      text: '${item?['progress_percent'] ?? 0}',
    );
    final TextEditingController weightCtrl = TextEditingController(
      text: isEdit ? '${item['weight_percent'] ?? 0}' : '10',
    );
    final TextEditingController startCtrl = TextEditingController(
      text:
          isEdit
              ? _toDateInput(item['start_date'])
              : _toDateInput(_task?['start_at']),
    );
    final TextEditingController deadlineCtrl = TextEditingController(
      text:
          isEdit
              ? _toDateInput(item['deadline'])
              : _toDateInput(_task?['deadline']),
    );

    String status = (item?['status'] ?? 'todo').toString();
    String priority = (item?['priority'] ?? 'medium').toString();
    int? assigneeId =
        _toInt(item?['assignee_id']) == 0 ? null : _toInt(item?['assignee_id']);
    bool submitting = false;
    String localMessage = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext sheetContext, StateSetter setModalState) {
            final int taskDepartmentId = _toInt(_task?['department_id']);
            final List<Map<String, dynamic>> staffOptions =
                <Map<String, dynamic>>[
                  for (final Map<String, dynamic> department in _departments)
                    if (taskDepartmentId == 0 ||
                        _toInt(department['id']) == taskDepartmentId)
                      ...((department['staff'] as List<dynamic>? ?? <dynamic>[])
                          .whereType<Map>()
                          .map((Map row) => row.cast<String, dynamic>())),
                ];

            Future<void> submit() async {
              if (titleCtrl.text.trim().isEmpty) {
                setModalState(
                  () => localMessage = 'Vui lòng nhập tiêu đề đầu việc.',
                );
                return;
              }
              final int? progress = int.tryParse(progressCtrl.text.trim());
              final int? weight = int.tryParse(weightCtrl.text.trim());
              if (progress == null || progress < 0 || progress > 100) {
                setModalState(
                  () => localMessage = 'Tiến độ phải từ 0 đến 100.',
                );
                return;
              }
              if (weight == null || weight < 1 || weight > 100) {
                setModalState(
                  () => localMessage = 'Tỷ trọng phải từ 1 đến 100.',
                );
                return;
              }

              setModalState(() {
                submitting = true;
                localMessage = '';
              });

              final bool ok =
                  isEdit
                      ? await widget.apiService.updateTaskItem(
                        widget.token,
                        widget.taskId,
                        _toInt(item['id']),
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        priority: priority,
                        status: status,
                        progressPercent: progress,
                        weightPercent: weight,
                        startDate:
                            startCtrl.text.trim().isEmpty
                                ? null
                                : startCtrl.text.trim(),
                        deadline:
                            deadlineCtrl.text.trim().isEmpty
                                ? null
                                : deadlineCtrl.text.trim(),
                        assigneeId: assigneeId,
                      )
                      : await widget.apiService.createTaskItem(
                        widget.token,
                        widget.taskId,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        priority: priority,
                        status: status,
                        progressPercent: progress,
                        weightPercent: weight,
                        startDate:
                            startCtrl.text.trim().isEmpty
                                ? null
                                : startCtrl.text.trim(),
                        deadline:
                            deadlineCtrl.text.trim().isEmpty
                                ? null
                                : deadlineCtrl.text.trim(),
                        assigneeId: assigneeId,
                      );

              if (!mounted) return;
              if (ok) {
                Navigator.of(sheetContext).pop();
                await _fetch();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit
                          ? 'Đã cập nhật đầu việc.'
                          : 'Đã thêm đầu việc mới.',
                    ),
                  ),
                );
              } else {
                setModalState(() {
                  submitting = false;
                  localMessage =
                      isEdit
                          ? 'Cập nhật đầu việc thất bại.'
                          : 'Tạo đầu việc thất bại.';
                });
              }
            }

            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                24 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isEdit ? 'Sửa đầu việc' : 'Thêm đầu việc',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (localMessage.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        localMessage,
                        style: TextStyle(color: StitchTheme.danger),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: status,
                            decoration: const InputDecoration(
                              labelText: 'Trạng thái',
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(
                                value: 'todo',
                                child: Text('Cần làm'),
                              ),
                              DropdownMenuItem(
                                value: 'doing',
                                child: Text('Đang làm'),
                              ),
                              DropdownMenuItem(
                                value: 'done',
                                child: Text('Hoàn tất'),
                              ),
                              DropdownMenuItem(
                                value: 'blocked',
                                child: Text('Bị chặn'),
                              ),
                            ],
                            onChanged:
                                (String? value) => setModalState(
                                  () => status = value ?? 'todo',
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: priority,
                            decoration: const InputDecoration(
                              labelText: 'Ưu tiên',
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(
                                value: 'low',
                                child: Text('Thấp'),
                              ),
                              DropdownMenuItem(
                                value: 'medium',
                                child: Text('Trung bình'),
                              ),
                              DropdownMenuItem(
                                value: 'high',
                                child: Text('Cao'),
                              ),
                              DropdownMenuItem(
                                value: 'urgent',
                                child: Text('Khẩn'),
                              ),
                            ],
                            onChanged:
                                (String? value) => setModalState(
                                  () => priority = value ?? 'medium',
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: progressCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tiến độ (%)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: weightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tỷ trọng (%)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: startCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Ngày bắt đầu',
                            ),
                            onTap: () => _pickDate(sheetContext, startCtrl),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: deadlineCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Deadline',
                            ),
                            onTap: () => _pickDate(sheetContext, deadlineCtrl),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: assigneeId,
                      decoration: const InputDecoration(
                        labelText: 'Nhân sự phụ trách',
                      ),
                      items:
                          staffOptions
                              .map(
                                (Map<String, dynamic> user) =>
                                    DropdownMenuItem<int>(
                                      value: _toInt(user['id']),
                                      child: Text(
                                        (user['name'] ??
                                                user['email'] ??
                                                'Nhân sự')
                                            .toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                              )
                              .toList(),
                      onChanged:
                          (int? value) =>
                              setModalState(() => assigneeId = value),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting ? null : submit,
                            child: Text(
                              submitting
                                  ? 'Đang lưu...'
                                  : (isEdit ? 'Lưu thay đổi' : 'Tạo đầu việc'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                submitting
                                    ? null
                                    : () => Navigator.of(sheetContext).pop(),
                            child: const Text('Hủy'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Đã xóa đầu việc.' : 'Không thể xóa đầu việc.'),
      ),
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
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: <Widget>[
                      if (_message.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: StitchTheme.border),
                          ),
                          child: Text(
                            _message,
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                            ),
                          ),
                        ),
                      if (_task != null) ...<Widget>[
                        _TaskHeroCard(
                          title: (_task?['title'] ?? 'Công việc').toString(),
                          description: (_task?['description'] ?? '').toString(),
                          progress: progress,
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
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _MetricCard(
                              label: 'Tỷ trọng công việc',
                              value: '$taskWeight%',
                              tone: StitchTheme.primary,
                            ),
                            _MetricCard(
                              label: 'Số đầu việc',
                              value: '${_items.length}',
                              tone: const Color(0xFF0F766E),
                            ),
                            _MetricCard(
                              label: 'Đã phân bổ',
                              value: '$totalItemWeight%',
                              tone: const Color(0xFF7C3AED),
                            ),
                            _MetricCard(
                              label: 'Còn lại để chia',
                              value:
                                  '${remainingWeight < 0 ? 0 : remainingWeight}%',
                              tone:
                                  remainingWeight < 0
                                      ? StitchTheme.danger
                                      : StitchTheme.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: StitchTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Expanded(
                                    child: Text(
                                      'Đầu việc trong công việc',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (_canManageItems)
                                    FilledButton.icon(
                                      onPressed: () => _openItemEditor(),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Thêm đầu việc'),
                                    ),
                                  if (_canManageItems)
                                    const SizedBox(width: 10),
                                  if (_isTaskApprovalOwner())
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: StitchTheme.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Bạn là người duyệt phiếu đầu việc',
                                        style: TextStyle(
                                          color: StitchTheme.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                remainingWeight >= 0
                                    ? 'Tổng tỷ trọng đầu việc hiện là $totalItemWeight%. Hệ thống còn $remainingWeight% để phân bổ.'
                                    : 'Tổng tỷ trọng đầu việc đang vượt 100%. Cần rà lại dữ liệu để tránh lệch tiến độ.',
                                style: TextStyle(
                                  color:
                                      remainingWeight >= 0
                                          ? StitchTheme.textMuted
                                          : StitchTheme.danger,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    'Chưa có đầu việc nào trong công việc này.',
                                    style: TextStyle(
                                      color: StitchTheme.textMuted,
                                    ),
                                  ),
                                )
                              else
                                ...groups.map(
                                  (_TaskItemGroup group) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _TaskGroupCard(
                                      group: group,
                                      formatDate: _formatDate,
                                      statusLabel: _statusLabel,
                                      onOpenItem: _openItem,
                                      toInt: _toInt,
                                      canManageItems: _canManageItems,
                                      onEditItem:
                                          (Map<String, dynamic> item) =>
                                              _openItemEditor(item: item),
                                      onDeleteItem: _deleteItem,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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

class _TaskHeroCard extends StatelessWidget {
  const _TaskHeroCard({
    required this.title,
    required this.description,
    required this.progress,
    required this.status,
    required this.priority,
    required this.department,
    required this.assignee,
    required this.deadline,
  });

  final String title;
  final String description;
  final int progress;
  final String status;
  final String priority;
  final String department;
  final String assignee;
  final String deadline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF3F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StitchTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: StitchTheme.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 100) / 100,
              minHeight: 10,
              backgroundColor: StitchTheme.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(StitchTheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tiến độ hiện tại: $progress%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: StitchTheme.textMain,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MiniChip(label: 'Trạng thái', value: status),
              _MiniChip(label: 'Ưu tiên', value: priority),
              _MiniChip(label: 'Phòng ban', value: department),
              _MiniChip(label: 'Phụ trách', value: assignee),
              _MiniChip(label: 'Deadline', value: deadline),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: tone,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
          children: <InlineSpan>[
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: StitchTheme.textMain,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskGroupCard extends StatelessWidget {
  const _TaskGroupCard({
    required this.group,
    required this.formatDate,
    required this.statusLabel,
    required this.onOpenItem,
    required this.toInt,
    required this.canManageItems,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final _TaskItemGroup group;
  final String Function(String raw) formatDate;
  final String Function(String value) statusLabel;
  final Future<void> Function(Map<String, dynamic> item) onOpenItem;
  final int Function(dynamic value) toInt;
  final bool canManageItems;
  final Future<void> Function(Map<String, dynamic> item) onEditItem;
  final Future<void> Function(Map<String, dynamic> item) onDeleteItem;

  @override
  Widget build(BuildContext context) {
    final int avgProgress =
        group.items.isEmpty
            ? 0
            : group.items
                    .map(
                      (Map<String, dynamic> item) =>
                          toInt(item['progress_percent']),
                    )
                    .reduce((int a, int b) => a + b) ~/
                group.items.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: StitchTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  group.assignee.isEmpty
                      ? 'U'
                      : group.assignee.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: StitchTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.assignee,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.items.length} đầu việc • Tiến độ TB $avgProgress%',
                      style: const TextStyle(
                        color: StitchTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...group.items.map(
            (Map<String, dynamic> item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onOpenItem(item),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              (item['title'] ?? 'Đầu việc').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: StitchTheme.textMuted,
                          ),
                          if (canManageItems)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18),
                              onSelected: (String value) {
                                if (value == 'edit') {
                                  onEditItem(item);
                                  return;
                                }
                                if (value == 'delete') {
                                  onDeleteItem(item);
                                }
                              },
                              itemBuilder:
                                  (BuildContext context) =>
                                      const <PopupMenuEntry<String>>[
                                        PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Text('Sửa'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text('Xóa'),
                                        ),
                                      ],
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: <Widget>[
                          _InlineInfo(
                            label: 'Trạng thái',
                            value: statusLabel(
                              (item['status'] ?? '').toString(),
                            ),
                          ),
                          _InlineInfo(
                            label: 'Tiến độ',
                            value: '${toInt(item['progress_percent'])}%',
                          ),
                          _InlineInfo(
                            label: 'Tỷ trọng',
                            value: '${toInt(item['weight_percent'])}%',
                          ),
                          _InlineInfo(
                            label: 'Deadline',
                            value: formatDate(
                              (item['deadline'] ?? '').toString(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
        children: <InlineSpan>[
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: StitchTheme.textMain,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

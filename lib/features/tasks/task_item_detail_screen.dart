import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/task_item_progress_input.dart';
import '../../core/utils/vietnam_time.dart';
import '../../data/services/mobile_api_service.dart';

class TaskItemDetailScreen extends StatefulWidget {
  const TaskItemDetailScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.taskId,
    required this.itemId,
    this.initialUpdateId,
  });

  final String token;
  final MobileApiService apiService;
  final int taskId;
  final int itemId;
  final int? initialUpdateId;

  @override
  State<TaskItemDetailScreen> createState() => _TaskItemDetailScreenState();
}

class _TaskItemDetailScreenState extends State<TaskItemDetailScreen> {
  bool loading = true;
  Map<String, dynamic>? item;
  Map<String, dynamic>? task;
  List<Map<String, dynamic>> updates = <Map<String, dynamic>>[];
  Map<String, dynamic>? insight;

  int? currentUserId;
  String currentUserRole = '';
  String message = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final List<dynamic> res = await Future.wait<dynamic>([
        widget.apiService.getTaskItemDetail(widget.token, widget.itemId),
        widget.apiService.getTaskItemUpdates(
          widget.token,
          widget.taskId,
          widget.itemId,
        ),
        widget.apiService.me(widget.token),
      ]);
      if (!mounted) return;
      final Map<String, dynamic>? fetchedItem = res[0] as Map<String, dynamic>?;
      final List<Map<String, dynamic>> fetchedUpdates =
          res[1] as List<Map<String, dynamic>>;
      final Map<String, dynamic> mePayload = res[2] as Map<String, dynamic>;

      final Map<String, dynamic> meBody =
          (mePayload['body'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final dynamic rawId = meBody['id'];
      currentUserId = rawId is int ? rawId : int.tryParse('$rawId');
      currentUserRole = (meBody['role'] ?? '').toString();

      item = fetchedItem;
      task = item?['task'] as Map<String, dynamic>?;
      if (widget.initialUpdateId != null && widget.initialUpdateId! > 0) {
        fetchedUpdates.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          final int aId =
              a['id'] is int
                  ? a['id'] as int
                  : int.tryParse('${a['id'] ?? 0}') ?? 0;
          final int bId =
              b['id'] is int
                  ? b['id'] as int
                  : int.tryParse('${b['id'] ?? 0}') ?? 0;
          if (aId == widget.initialUpdateId) return -1;
          if (bId == widget.initialUpdateId) return 1;
          return 0;
        });
      }

      updates = fetchedUpdates;

      if (item != null) {
        final insightData = await widget.apiService.getTaskItemProgressInsight(
          widget.token,
          widget.taskId,
          widget.itemId,
        );
        if (mounted) {
          insight = insightData;
        }
      }

      if (mounted) {
        setState(() {
          loading = false;
          if (item == null) {
            message = 'Không tìm thấy đầu việc.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          message = 'Lỗi kết nối. Vui lòng thử lại sau.';
        });
      }
    }
  }

  bool _isTaskAssignee() {
    final dynamic raw = task?['assignee_id'];
    final int? id = raw is int ? raw : int.tryParse('${raw ?? ''}');
    return currentUserId != null && currentUserId == id;
  }

  bool _isProjectOwner() {
    final dynamic raw =
        (task?['project'] as Map<String, dynamic>?)?['owner_id'];
    final int? id = raw is int ? raw : int.tryParse('${raw ?? ''}');
    return currentUserId != null && currentUserId == id;
  }

  bool _canApprove() {
    return currentUserRole == 'admin' || _isProjectOwner();
  }

  bool _canSubmitReport() {
    final dynamic raw = item?['assignee_id'];
    final int? id = raw is int ? raw : int.tryParse('${raw ?? ''}');
    return currentUserRole == 'admin' ||
        _isTaskAssignee() ||
        (currentUserId != null && currentUserId == id);
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    final DateTime? dt = VietnamTime.parse(raw);
    if (dt == null) return '—';
    return VietnamTime.formatDate(dt);
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return '—';
    final DateTime? dt = VietnamTime.parse(raw);
    if (dt == null) return raw;
    return VietnamTime.formatDateTime(dt);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'todo':
        return 'Cần làm';
      case 'doing':
        return 'Đang làm';
      case 'done':
        return 'Hoàn tất';
      case 'blocked':
        return 'Bị chặn';
      default:
        return status.isEmpty ? '—' : status;
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

  String _reviewStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      case 'pending':
      default:
        return 'Chờ duyệt';
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'todo':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = 'Cần làm';
        break;
      case 'doing':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'Đang làm';
        break;
      case 'done':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'Hoàn tất';
        break;
      case 'blocked':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'Bị chặn';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Chi tiết Đầu việc', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : message.isNotEmpty
              ? Center(child: Text(message))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (item == null) return const SizedBox.shrink();

    final int progress =
        item!['progress_percent'] is int
            ? item!['progress_percent'] as int
            : int.tryParse('${item!['progress_percent']}') ?? 0;

    final int weight =
        item!['weight_percent'] is int
            ? item!['weight_percent'] as int
            : int.tryParse('${item!['weight_percent']}') ?? 0;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: StitchTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${item!['title']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge('${item!['status']}'),
                  ],
                ),
                if ((item!['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${item!['description']}',
                    style: const TextStyle(
                      color: StitchTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _MetaChip(
                      label: 'Ưu tiên',
                      value: _priorityLabel(
                        '${item!['priority'] ?? 'medium'}',
                      ),
                    ),
                    if (task != null) ...<Widget>[
                      _MetaChip(
                        label: 'Thuộc công việc',
                        value: (task!['title'] ?? '—').toString(),
                      ),
                      if (task!['department'] is Map<String, dynamic>)
                        _MetaChip(
                          label: 'Phòng ban (CV)',
                          value:
                              '${(task!['department'] as Map<String, dynamic>)['name'] ?? '—'}',
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  'Nhân sự',
                  item!['assignee']?['name']?.toString() ?? 'Chưa phân công',
                ),
                const Divider(height: 24, thickness: 0.5),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCol(
                        'Bắt đầu',
                        _formatDate('${item!['start_date']}'),
                      ),
                    ),
                    Expanded(
                      child: _buildStatCol(
                        'Deadline',
                        _formatDate('${item!['deadline']}'),
                      ),
                    ),
                    Expanded(child: _buildStatCol('Tỷ trọng', '$weight%')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Tiến độ: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.grey.shade200,
                          color: StitchTheme.primary,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (insight != null) ...[
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
                children: [
                  const Text(
                    'Biểu đồ tiến độ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _InsightMetric(
                        label: 'Dự kiến hôm nay',
                        value:
                            '${insight!['summary']?['expected_progress_today'] ?? 0}%',
                        tone: const Color(0xFF2563EB),
                      ),
                      _InsightMetric(
                        label: 'Thực tế hôm nay',
                        value:
                            '${insight!['summary']?['actual_progress_today'] ?? 0}%',
                        tone: StitchTheme.success,
                      ),
                      _InsightMetric(
                        label: 'Đang chậm',
                        value: '${insight!['summary']?['lag_percent'] ?? 0}%',
                        tone:
                            (insight!['summary']?['is_late'] == true)
                                ? StitchTheme.danger
                                : StitchTheme.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: StitchTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: const <Widget>[
                            _LegendDot(
                              color: Color(0xFF2563EB),
                              label: 'Kỳ vọng',
                            ),
                            SizedBox(width: 16),
                            _LegendDot(
                              color: Color(0xFF16A34A),
                              label: 'Thực tế',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 150,
                          child: _TaskItemInsightChart(
                            points:
                                ((insight!['chart'] ?? []) as List)
                                    .map((e) => e as Map<String, dynamic>)
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.initialUpdateId != null &&
              widget.initialUpdateId! > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: StitchTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: StitchTheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                'Đang mở nhanh phiếu duyệt #${widget.initialUpdateId} từ thông báo.',
                style: const TextStyle(
                  color: StitchTheme.textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          if (_canSubmitReport()) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openReportEditor(),
                icon: const Icon(Icons.add_task),
                label: const Text('Báo cáo tiến độ'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Text(
            'Lịch sử phiếu duyệt',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (updates.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: StitchTheme.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: const Center(
                child: Text(
                  'Chưa có báo cáo nào.',
                  style: TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...updates.map((u) => _buildUpdateCard(u)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> up) {
    final status = '${up['review_status']}';
    final int updateId =
        up['id'] is int
            ? up['id'] as int
            : int.tryParse('${up['id'] ?? 0}') ?? 0;
    final bool isHighlighted =
        widget.initialUpdateId != null && updateId == widget.initialUpdateId;
    Color bClr = StitchTheme.border;
    Color bgHeader = Colors.white;
    if (status == 'pending') {
      bClr = Colors.amber.shade200;
      bgHeader = Colors.amber.shade50;
    } else if (status == 'approved') {
      bClr = Colors.green.shade200;
      bgHeader = Colors.green.shade50;
    } else if (status == 'rejected') {
      bClr = Colors.red.shade200;
      bgHeader = Colors.red.shade50;
    }
    if (isHighlighted) {
      bClr = StitchTheme.primary;
      bgHeader = StitchTheme.primary.withValues(alpha: 0.08);
    }

    final isPending = status == 'pending';
    final int prog =
        up['progress_percent'] is int
            ? up['progress_percent'] as int
            : int.tryParse('${up['progress_percent']}') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bClr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bgHeader,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Phiếu #${up['id']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (isHighlighted)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: StitchTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Từ thông báo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: StitchTheme.primary,
                      ),
                    ),
                  ),
                Text(
                  _formatDateTime('${up['created_at']}'),
                  style: const TextStyle(
                    color: StitchTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCol(
                        'Trạng thái báo cáo',
                        _statusLabel('${up['status']}'),
                      ),
                    ),
                    Expanded(child: _buildStatCol('Tiến độ', '$prog%')),
                    Expanded(
                      child: _buildStatCol(
                        'Người gửi',
                        '${up['submitter']?['name'] ?? '—'}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInfoRow('Kết quả duyệt', _reviewStatusLabel(status)),
                if ((up['note'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Ghi chú: ${up['note']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                if ((up['review_note'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Lý do từ chối: ${up['review_note']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
                if (isPending && _canApprove()) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleReview(up, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleReview(up, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Duyệt phiếu'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReview(
    Map<String, dynamic> update,
    bool isApprove,
  ) async {
    final TextEditingController reasonCtrl = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(isApprove ? 'Duyệt phiếu' : 'Từ chối phiếu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isApprove
                      ? 'Xác nhận duyệt báo cáo tiến độ này?'
                      : 'Vui lòng nhập lý do từ chối:',
                ),
                if (!isApprove) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Lý do...',
                    ),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!isApprove && reasonCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cần nhập lý do!')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApprove ? Colors.green : Colors.red,
                ),
                child: Text(isApprove ? 'Duyệt' : 'Từ chối'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      bool ok;
      if (isApprove) {
        ok = await widget.apiService.approveTaskItemUpdate(
          widget.token,
          widget.taskId,
          widget.itemId,
          update['id'] as int,
          status: update['status']?.toString(),
          progressPercent: TaskItemProgressInput.clampInt(
            int.tryParse('${update['progress_percent']}') ?? 0,
          ),
        );
      } else {
        ok = await widget.apiService.rejectTaskItemUpdate(
          widget.token,
          widget.taskId,
          widget.itemId,
          update['id'] as int,
          reviewNote: reasonCtrl.text.trim(),
        );
      }
      if (ok) {
        _fetch(); // reload all
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Thao tác thất bại.')));
      }
    }
  }

  Future<void> _openReportEditor() async {
    final TextEditingController noteCtrl = TextEditingController();
    final TextEditingController progressCtrl = TextEditingController(
      text: '${item?['progress_percent'] ?? 0}',
    );
    String statusValue = '${item?['status'] ?? 'todo'}';
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setModal) => Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Báo cáo tiến độ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: statusValue,
                          items: const [
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
                              (v) => setModal(() => statusValue = v ?? 'todo'),
                          decoration: const InputDecoration(
                            labelText: 'Trạng thái',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: progressCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Tiến độ (%)',
                            helperText: 'Chỉ nhập 0–100, không vượt quá 100%',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú thêm',
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed:
                                submitting
                                    ? null
                                    : () async {
                                      final int? p =
                                          TaskItemProgressInput.tryParseOptional(
                                        progressCtrl.text,
                                        onInvalid: (String m) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(m)),
                                          );
                                        },
                                      );
                                      if (p == null &&
                                          progressCtrl.text.trim().isNotEmpty) {
                                        return;
                                      }
                                      setModal(() => submitting = true);
                                      final ok = await widget.apiService
                                          .createTaskItemUpdate(
                                            widget.token,
                                            widget.taskId,
                                            widget.itemId,
                                            status: statusValue,
                                            progressPercent: p,
                                            note: noteCtrl.text.trim(),
                                          );
                                      if (ok) {
                                        Navigator.pop(ctx);
                                        _fetch();
                                      } else {
                                        setModal(() => submitting = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Gửi thất bại'),
                                          ),
                                        );
                                      }
                                    },
                            child: Text(
                              submitting ? 'Đang gửi...' : 'Gửi báo cáo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: StitchTheme.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: StitchTheme.primaryStrong.withValues(alpha: 0.22),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.25),
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: StitchTheme.primaryStrong.withValues(alpha: 0.95),
                fontWeight: FontWeight.w700,
              ),
            ),
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

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({
    required this.label,
    required this.value,
    this.tone = StitchTheme.textMain,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
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
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _TaskItemInsightChart extends StatelessWidget {
  const _TaskItemInsightChart({required this.points});

  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có dữ liệu tiến độ để hiển thị.',
          style: TextStyle(color: StitchTheme.textMuted),
        ),
      );
    }

    final List<Map<String, dynamic>> normalizedPoints =
        List<Map<String, dynamic>>.from(points);
    normalizedPoints.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final String aDate = (a['date'] ?? '').toString();
      final String bDate = (b['date'] ?? '').toString();
      if (aDate.isNotEmpty && bDate.isNotEmpty && aDate != bDate) {
        return aDate.compareTo(bDate);
      }
      final String aLabel = (a['label'] ?? '').toString();
      final String bLabel = (b['label'] ?? '').toString();
      return aLabel.compareTo(bLabel);
    });

    final int tickStep = math.max(1, (normalizedPoints.length / 6).ceil());

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double chartWidth = math.max(
          constraints.maxWidth,
          normalizedPoints.length * 56,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TaskItemInsightPainter(points: normalizedPoints),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List<Widget>.generate(normalizedPoints.length, (
                      int index,
                    ) {
                      final bool showLabel =
                          index == 0 ||
                          index == normalizedPoints.length - 1 ||
                          index % tickStep == 0;
                      final String label =
                          showLabel
                              ? _formatAxisLabel(normalizedPoints[index])
                              : '';
                      return SizedBox(
                        width:
                            normalizedPoints.length == 1
                                ? chartWidth
                                : chartWidth / normalizedPoints.length,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: StitchTheme.textMuted,
                          ),
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatAxisLabel(Map<String, dynamic> point) {
    final String date = (point['date'] ?? '').toString();
    final String ymd = VietnamTime.toYmdInput(date);
    if (ymd.length >= 10) {
      return ymd.substring(5, 10);
    }
    final String label = (point['label'] ?? '').toString();
    if (label.length > 8) {
      return label.substring(0, 8);
    }
    return label;
  }
}

class _TaskItemInsightPainter extends CustomPainter {
  const _TaskItemInsightPainter({required this.points});

  final List<Map<String, dynamic>> points;

  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = math.max(40, size.height - 32);
    final Paint gridPaint =
        Paint()
          ..color = StitchTheme.border
          ..strokeWidth = 1;
    final Paint expectedPaint =
        Paint()
          ..color = const Color(0xFF2563EB)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
    final Paint actualPaint =
        Paint()
          ..color = const Color(0xFF16A34A)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
    final Paint pointPaint =
        Paint()
          ..color = const Color(0xFF16A34A)
          ..style = PaintingStyle.fill;
    final Paint expectedPointPaint =
        Paint()
          ..color = const Color(0xFF2563EB)
          ..style = PaintingStyle.fill;

    for (int i = 0; i <= 4; i++) {
      final double y = (chartHeight / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) {
      return;
    }

    final Path expectedPath = Path();
    final Path actualPath = Path();

    for (int i = 0; i < points.length; i++) {
      final Map<String, dynamic> point = points[i];
      final double x =
          points.length == 1
              ? size.width / 2
              : (size.width / (points.length - 1)) * i;
      final double expected = _clampPercent(point['expected_progress']);
      final double actual = _clampPercent(point['actual_progress']);
      final double expectedY = chartHeight - (chartHeight * expected / 100);
      final double actualY = chartHeight - (chartHeight * actual / 100);

      if (i == 0) {
        expectedPath.moveTo(x, expectedY);
        actualPath.moveTo(x, actualY);
      } else {
        expectedPath.lineTo(x, expectedY);
        actualPath.lineTo(x, actualY);
      }

      canvas.drawCircle(Offset(x, expectedY), 2.8, expectedPointPaint);
      canvas.drawCircle(Offset(x, actualY), 3.5, pointPaint);
    }

    canvas.drawPath(expectedPath, expectedPaint);
    canvas.drawPath(actualPath, actualPaint);
  }

  double _clampPercent(dynamic value) {
    final double parsed =
        value is num ? value.toDouble() : double.tryParse('${value ?? 0}') ?? 0;
    return parsed.clamp(0, 100);
  }

  @override
  bool shouldRepaint(covariant _TaskItemInsightPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

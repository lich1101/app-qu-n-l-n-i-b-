import 'dart:math' as math;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

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
  bool loading = true;
  Map<String, dynamic>? task;
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
  String message = '';
  int? currentUserId;
  String currentUserRole = '';

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
    final List<dynamic> responses = await Future.wait<dynamic>(<Future<dynamic>>[
      widget.apiService.getTaskDetail(widget.token, widget.taskId),
      widget.apiService.getTaskItems(widget.token, widget.taskId),
      widget.apiService.me(widget.token),
    ]);
    final Map<String, dynamic>? detail = responses[0] as Map<String, dynamic>?;
    final List<Map<String, dynamic>> rows =
        responses[1] as List<Map<String, dynamic>>;
    final Map<String, dynamic> mePayload =
        responses[2] as Map<String, dynamic>;
    final Map<String, dynamic> meBody =
        (mePayload['body'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    if (!mounted) return;
    setState(() {
      task = detail;
      items = rows;
      loading = false;
      message = detail == null ? 'Không tìm thấy công việc.' : '';
      currentUserId = meBody['id'] is int
          ? meBody['id'] as int
          : int.tryParse('${meBody['id'] ?? ''}');
      currentUserRole = (meBody['role'] ?? '').toString();
    });
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
        return value;
    }
  }

  String _reviewLabel(String value) {
    switch (value) {
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Không duyệt';
      case 'pending':
      default:
        return 'Chờ duyệt';
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    final DateTime? dt = DateTime.tryParse(raw);
    if (dt == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
    final DateTime local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return '—';
    final DateTime? dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final DateTime local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  int _progressValue(Map<String, dynamic> item) {
    return (item['progress_percent'] ?? 0) is int
        ? item['progress_percent'] as int
        : int.tryParse('${item['progress_percent'] ?? 0}') ?? 0;
  }

  String _assigneeLabel(Map<String, dynamic> item) {
    final Map<String, dynamic>? assignee =
        item['assignee'] is Map<String, dynamic>
            ? item['assignee'] as Map<String, dynamic>
            : null;
    return (assignee?['name'] ?? assignee?['email'] ?? 'Chưa phân công')
        .toString();
  }

  bool _isProjectOwner() {
    return currentUserId != null &&
        currentUserId == (task?['project']?['owner_id'] as int?);
  }

  bool _isDepartmentManager() {
    final dynamic raw = task?['department']?['manager_id'];
    final int? managerId = raw is int ? raw : int.tryParse('${raw ?? ''}');
    return currentUserId != null && currentUserId == managerId;
  }

  bool _canApproveItemUpdates() {
    return currentUserRole == 'admin' || _isProjectOwner() || _isDepartmentManager();
  }

  bool _canSubmitReport(Map<String, dynamic> item) {
    final int? assigneeId = item['assignee_id'] is int
        ? item['assignee_id'] as int
        : int.tryParse('${item['assignee_id'] ?? ''}');
    return _canApproveItemUpdates() ||
        (currentUserId != null && currentUserId == assigneeId);
  }

  Future<void> _openItemInsightSheet(Map<String, dynamic> item) async {
    final Map<String, dynamic>? insight = await widget.apiService
        .getTaskItemProgressInsight(
      widget.token,
      widget.taskId,
      (item['id'] ?? 0) as int,
    );
    if (!mounted) return;
    if (insight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tải được biểu đồ tiến độ đầu việc.'),
        ),
      );
      return;
    }

    final Map<String, dynamic> summary =
        (insight['summary'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<Map<String, dynamic>> chart = ((insight['chart'] ?? <dynamic>[])
            as List<dynamic>)
        .map((dynamic row) => row as Map<String, dynamic>)
        .toList();
    final List<Map<String, dynamic>> approvedUpdates =
        ((insight['approved_updates'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic row) => row as Map<String, dynamic>)
            .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    (summary['task_item_title'] ?? item['title'] ?? 'Biểu đồ tiến độ')
                        .toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Công việc: ${(summary['task_title'] ?? task?['title'] ?? '—').toString()}',
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _InsightMetric(
                        label: 'Nhân sự',
                        value: (summary['assignee_name'] ?? '—').toString(),
                      ),
                      _InsightMetric(
                        label: 'Dự kiến hôm nay',
                        value:
                            '${summary['expected_progress_today'] ?? 0}%',
                        tone: const Color(0xFF2563EB),
                      ),
                      _InsightMetric(
                        label: 'Thực tế hôm nay',
                        value: '${summary['actual_progress_today'] ?? 0}%',
                        tone: StitchTheme.success,
                      ),
                      _InsightMetric(
                        label: 'Đang chậm',
                        value: '${summary['lag_percent'] ?? 0}%',
                        tone: (summary['is_late'] == true)
                            ? StitchTheme.danger
                            : StitchTheme.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: StitchTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: const <Widget>[
                            _LegendDot(
                              color: Color(0xFF2563EB),
                              label: 'Tiến độ kỳ vọng',
                            ),
                            SizedBox(width: 16),
                            _LegendDot(
                              color: Color(0xFF16A34A),
                              label: 'Tiến độ thực tế',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 220,
                          child: _TaskItemInsightChart(points: chart),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ReviewInfoRow(
                    label: 'Bắt đầu',
                    value: _formatDate((summary['start_date'] ?? '').toString()),
                  ),
                  const SizedBox(height: 8),
                  _ReviewInfoRow(
                    label: 'Deadline',
                    value: _formatDate((summary['deadline'] ?? '').toString()),
                  ),
                  const SizedBox(height: 8),
                  _ReviewInfoRow(
                    label: 'Phòng ban',
                    value: (summary['department_name'] ?? '—').toString(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Phiếu duyệt đã được chấp thuận',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (approvedUpdates.isEmpty)
                    const Text(
                      'Chưa có phiếu duyệt nào được chấp thuận.',
                      style: TextStyle(
                        color: StitchTheme.textMuted,
                        fontSize: 12,
                      ),
                    )
                  else
                    ...approvedUpdates.map((Map<String, dynamic> update) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: StitchTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Phiếu #${update['id'] ?? ''} • ${update['progress_percent'] ?? '—'}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Người gửi: ${(update['submitter']?['name'] ?? '—').toString()} • ${_formatDateTime((update['created_at'] ?? '').toString())}',
                              style: const TextStyle(
                                color: StitchTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            if ((update['note'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                (update['note'] ?? '').toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Đóng'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _canEditPendingReport(
    Map<String, dynamic> item,
    Map<String, dynamic> update,
  ) {
    if ((update['review_status'] ?? 'pending').toString() != 'pending') {
      return false;
    }
    if (_canApproveItemUpdates()) {
      return true;
    }
    final int? assigneeId = item['assignee_id'] is int
        ? item['assignee_id'] as int
        : int.tryParse('${item['assignee_id'] ?? ''}');
    final Map<String, dynamic>? submitter =
        update['submitter'] is Map<String, dynamic>
            ? update['submitter'] as Map<String, dynamic>
            : null;
    final dynamic submitterRawId = submitter?['id'] ?? update['submitted_by'];
    final int? submitterId = submitterRawId is int
        ? submitterRawId
        : int.tryParse('$submitterRawId');
    return (currentUserId != null && currentUserId == assigneeId) ||
        (currentUserId != null && currentUserId == submitterId);
  }

  List<_TaskItemGroup> _groupedItems() {
    final Map<String, List<Map<String, dynamic>>> grouped =
        <String, List<Map<String, dynamic>>>{};

    for (final Map<String, dynamic> item in items) {
      final Map<String, dynamic>? assignee =
          item['assignee'] is Map<String, dynamic>
              ? item['assignee'] as Map<String, dynamic>
              : null;
      final dynamic assigneeId = assignee?['id'];
      final String label = _assigneeLabel(item);
      final String key = assigneeId != null
          ? 'user_$assigneeId'
          : 'label_${label.toLowerCase()}';
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }

    final List<_TaskItemGroup> groups = grouped.entries.map((entry) {
      final List<Map<String, dynamic>> rows =
          List<Map<String, dynamic>>.from(entry.value)
            ..sort((a, b) {
              final String aDeadline = (a['deadline'] ?? '').toString();
              final String bDeadline = (b['deadline'] ?? '').toString();
              if (aDeadline.isEmpty && bDeadline.isEmpty) return 0;
              if (aDeadline.isEmpty) return 1;
              if (bDeadline.isEmpty) return -1;
              return aDeadline.compareTo(bDeadline);
            });

      return _TaskItemGroup(
        assignee: _assigneeLabel(rows.first),
        items: rows,
      );
    }).toList()
      ..sort((a, b) {
        if (a.assignee == 'Chưa phân công' && b.assignee != 'Chưa phân công') {
          return 1;
        }
        if (b.assignee == 'Chưa phân công' && a.assignee != 'Chưa phân công') {
          return -1;
        }
        return a.assignee.toLowerCase().compareTo(b.assignee.toLowerCase());
      });

    return groups;
  }

  Future<void> _openReportEditor(
    Map<String, dynamic> item, {
    Map<String, dynamic>? update,
  }) async {
    final TextEditingController noteCtrl = TextEditingController(
      text: (update?['note'] ?? '').toString(),
    );
    final TextEditingController progressCtrl = TextEditingController(
      text: update?['progress_percent']?.toString() ?? '',
    );
    String statusValue = (update?['status'] ?? '').toString();
    File? attachment;
    String localMessage = '';
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final double bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            Future<void> pickAttachment() async {
              final FilePickerResult? result =
                  await FilePicker.platform.pickFiles();
              final String? path = result?.files.single.path;
              if (path != null) {
                setModalState(() => attachment = File(path));
              }
            }

            Future<void> submit() async {
              if (submitting) return;
              if (noteCtrl.text.trim().isEmpty &&
                  progressCtrl.text.trim().isEmpty &&
                  statusValue.isEmpty &&
                  attachment == null) {
                setModalState(
                  () => localMessage =
                      'Vui lòng nhập trạng thái, tiến độ, ghi chú hoặc file.',
                );
                return;
              }
              final int? progress = progressCtrl.text.trim().isEmpty
                  ? null
                  : int.tryParse(progressCtrl.text.trim());
              if (progress != null && (progress < 0 || progress > 100)) {
                setModalState(
                  () => localMessage = 'Tiến độ phải nằm trong khoảng 0-100.',
                );
                return;
              }
              setModalState(() {
                submitting = true;
                localMessage = '';
              });

              final bool ok = update == null
                  ? await widget.apiService.createTaskItemUpdate(
                      widget.token,
                      widget.taskId,
                      (item['id'] ?? 0) as int,
                      status: statusValue.isEmpty ? null : statusValue,
                      progressPercent: progress,
                      note: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                      attachment: attachment,
                    )
                  : await widget.apiService.updateTaskItemUpdate(
                      widget.token,
                      widget.taskId,
                      (item['id'] ?? 0) as int,
                      (update['id'] ?? 0) as int,
                      status: statusValue.isEmpty ? null : statusValue,
                      progressPercent: progress,
                      note: noteCtrl.text.trim(),
                      attachment: attachment,
                    );

              if (!mounted || !ctx.mounted) return;
              if (ok) {
                Navigator.of(ctx).pop();
                await _fetch();
                await _openItemUpdateSheet(item);
              } else {
                setModalState(() {
                  submitting = false;
                  localMessage = update == null
                      ? 'Tạo phiếu duyệt thất bại.'
                      : 'Cập nhật phiếu duyệt thất bại.';
                });
              }
            }

            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      update == null
                          ? 'Tạo phiếu duyệt: ${(item['title'] ?? 'Đầu việc').toString()}'
                          : 'Sửa phiếu duyệt #${update['id'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (localMessage.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        localMessage,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: statusValue.isEmpty ? null : statusValue,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'todo', child: Text('Cần làm')),
                        DropdownMenuItem(value: 'doing', child: Text('Đang làm')),
                        DropdownMenuItem(value: 'done', child: Text('Hoàn tất')),
                        DropdownMenuItem(value: 'blocked', child: Text('Bị chặn')),
                      ],
                      onChanged: (String? v) =>
                          setModalState(() => statusValue = v ?? ''),
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái báo cáo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: progressCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tiến độ đề xuất (%)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung phiếu duyệt',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: pickAttachment,
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Chọn file'),
                        ),
                        const SizedBox(width: 8),
                        if (attachment != null)
                          Expanded(
                            child: Text(
                              attachment!.path.split('/').last,
                              style: const TextStyle(
                                fontSize: 11,
                                color: StitchTheme.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting ? null : submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              submitting
                                  ? 'Đang lưu...'
                                  : (update == null
                                      ? 'Gửi phiếu duyệt'
                                      : 'Cập nhật phiếu'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
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

    noteCtrl.dispose();
    progressCtrl.dispose();
  }

  Future<void> _openItemUpdateSheet(Map<String, dynamic> item) async {
    List<Map<String, dynamic>> updates = <Map<String, dynamic>>[];
    Map<String, dynamic>? selectedUpdate;
    bool loadingUpdates = true;
    String localMessage = '';
    final TextEditingController rejectCtrl = TextEditingController();

    Future<void> fetchUpdates(StateSetter setModalState) async {
      setModalState(() => loadingUpdates = true);
      final List<Map<String, dynamic>> rows = await widget.apiService
          .getTaskItemUpdates(widget.token, widget.taskId, (item['id'] ?? 0) as int);
      setModalState(() {
        updates = rows;
        selectedUpdate = rows.isNotEmpty ? rows.first : null;
        loadingUpdates = false;
        localMessage = '';
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final double bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            if (loadingUpdates) {
              fetchUpdates(setModalState);
            }

            Future<void> approveSelected() async {
              final Map<String, dynamic>? update = selectedUpdate;
              if (update == null) return;
              final bool ok = await widget.apiService.approveTaskItemUpdate(
                widget.token,
                widget.taskId,
                (item['id'] ?? 0) as int,
                (update['id'] ?? 0) as int,
                status: (update['status'] ?? '').toString().isEmpty
                    ? null
                    : (update['status'] ?? '').toString(),
                progressPercent: update['progress_percent'] is int
                    ? update['progress_percent'] as int
                    : int.tryParse('${update['progress_percent'] ?? ''}'),
                note: (update['note'] ?? '').toString().trim().isEmpty
                    ? null
                    : (update['note'] ?? '').toString(),
              );
              if (ok) {
                await _fetch();
                await fetchUpdates(setModalState);
                setModalState(
                  () => localMessage = 'Đã duyệt phiếu duyệt đầu việc.',
                );
              } else {
                setModalState(
                  () => localMessage = 'Duyệt phiếu duyệt thất bại.',
                );
              }
            }

            Future<void> rejectSelected() async {
              final Map<String, dynamic>? update = selectedUpdate;
              if (update == null) return;
              final String reason = rejectCtrl.text.trim();
              if (reason.isEmpty) {
                setModalState(
                  () => localMessage = 'Vui lòng nhập lý do từ chối.',
                );
                return;
              }
              final bool ok = await widget.apiService.rejectTaskItemUpdate(
                widget.token,
                widget.taskId,
                (item['id'] ?? 0) as int,
                (update['id'] ?? 0) as int,
                reviewNote: reason,
              );
              if (ok) {
                await fetchUpdates(setModalState);
                setModalState(() {
                  localMessage = 'Đã từ chối phiếu duyệt.';
                  rejectCtrl.clear();
                });
              } else {
                setModalState(
                  () => localMessage = 'Từ chối phiếu duyệt thất bại.',
                );
              }
            }

            Future<void> deleteSelected() async {
              final Map<String, dynamic>? update = selectedUpdate;
              if (update == null) return;
              final bool? okDelete = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Xóa phiếu duyệt'),
                    content: const Text(
                      'Phiếu duyệt đang chờ xử lý sẽ bị xóa. Bạn có chắc không?',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Xóa'),
                      ),
                    ],
                  );
                },
              );
              if (okDelete != true) return;
              final bool ok = await widget.apiService.deleteTaskItemUpdate(
                widget.token,
                widget.taskId,
                (item['id'] ?? 0) as int,
                (update['id'] ?? 0) as int,
              );
              if (ok) {
                await fetchUpdates(setModalState);
                setModalState(() => localMessage = 'Đã xóa phiếu duyệt.');
              } else {
                setModalState(() => localMessage = 'Xóa phiếu duyệt thất bại.');
              }
            }

            final bool canSubmit = _canSubmitReport(item);
            final bool canApprove = selectedUpdate != null &&
                _canApproveItemUpdates() &&
                (selectedUpdate!['review_status'] ?? 'pending').toString() ==
                    'pending';
            final bool canEdit = selectedUpdate != null &&
                _canEditPendingReport(item, selectedUpdate!);

            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Phiếu duyệt: ${(item['title'] ?? 'Đầu việc').toString()}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Nhấn vào từng phiếu để xem chi tiết và phản hồi.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: StitchTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canSubmit)
                            FilledButton(
                              onPressed: () => _openReportEditor(item),
                              child: const Text('Tạo phiếu'),
                            ),
                        ],
                      ),
                      if (localMessage.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          localMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (loadingUpdates)
                        const Center(child: CircularProgressIndicator())
                      else if (updates.isEmpty)
                        const Text(
                          'Chưa có phiếu duyệt nào.',
                          style: TextStyle(color: StitchTheme.textMuted),
                        )
                      else ...<Widget>[
                        ...updates.map((Map<String, dynamic> update) {
                          final bool selected =
                              selectedUpdate?['id'] == update['id'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setModalState(() {
                                selectedUpdate = update;
                                rejectCtrl.clear();
                                localMessage = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? StitchTheme.primary.withValues(
                                          alpha: 0.08,
                                        )
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? StitchTheme.primary
                                        : StitchTheme.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Phiếu #${update['id'] ?? ''} • ${update['submitter']?['name'] ?? 'Nhân sự'}',
                                      style: const TextStyle(
                                        color: StitchTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _reviewLabel(
                                        (update['review_status'] ?? 'pending')
                                            .toString(),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Trạng thái: ${_statusLabel((update['status'] ?? '').toString())} • Tiến độ: ${update['progress_percent'] ?? '—'}%',
                                      style: const TextStyle(
                                        color: StitchTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        if (selectedUpdate != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
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
                                  'Chi tiết phiếu #${selectedUpdate!['id'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Người gửi: ${selectedUpdate!['submitter']?['name'] ?? '—'}',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lúc gửi: ${_formatDateTime((selectedUpdate!['created_at'] ?? '').toString())}',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Trạng thái báo cáo: ${_statusLabel((selectedUpdate!['status'] ?? '').toString())}',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tiến độ đề xuất: ${selectedUpdate!['progress_percent'] ?? '—'}%',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (selectedUpdate!['note'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty
                                      ? 'Không có ghi chú.'
                                      : (selectedUpdate!['note'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if ((selectedUpdate!['review_note'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFED7AA),
                                      ),
                                    ),
                                    child: Text(
                                      'Phản hồi: ${(selectedUpdate!['review_note'] ?? '').toString()}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                                if ((selectedUpdate!['attachment_path'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 10),
                                  Text(
                                    'File: ${(selectedUpdate!['attachment_path'] ?? '').toString()}',
                                    style: const TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (canEdit) ...<Widget>[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      OutlinedButton(
                                        onPressed: () =>
                                            _openReportEditor(item, update: selectedUpdate),
                                        child: const Text('Sửa phiếu'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: deleteSelected,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                        ),
                                        child: const Text('Xóa phiếu'),
                                      ),
                                    ],
                                  ),
                                ],
                                if (canApprove) ...<Widget>[
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: rejectCtrl,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Lý do từ chối (nếu không duyệt)',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: approveSelected,
                                          child: const Text('Duyệt'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: rejectSelected,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                          ),
                                          child: const Text('Từ chối'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Đóng'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    rejectCtrl.dispose();
  }

  Widget _buildItemCard(Map<String, dynamic> item, {bool showAssignee = true}) {
    final String title = (item['title'] ?? 'Đầu việc').toString();
    final String status = (item['status'] ?? '').toString();
    final int progress = _progressValue(item);
    final String start = (item['start_date'] ?? '').toString();
    final String deadline = (item['deadline'] ?? '').toString();
    final String assignee = _assigneeLabel(item);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openItemUpdateSheet(item),
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
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  Icons.assignment_outlined,
                  size: 18,
                  color: StitchTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Trạng thái: ${_statusLabel(status)} • Tiến độ: $progress%',
              style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
            ),
            if (showAssignee) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Phụ trách: $assignee',
                style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Bắt đầu: ${_formatDate(start)} • Deadline: ${_formatDate(deadline)}',
              style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (progress.clamp(0, 100)) / 100,
                minHeight: 6,
                backgroundColor: StitchTheme.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(StitchTheme.primary),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Chạm để xem danh sách phiếu duyệt',
                    style: TextStyle(
                      color: StitchTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_canApproveItemUpdates())
                  TextButton.icon(
                    onPressed: () => _openItemInsightSheet(item),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.show_chart, size: 16),
                    label: const Text('Biểu đồ'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGroup(_TaskItemGroup group) {
    final int averageProgress = group.items.isEmpty
        ? 0
        : group.items.map(_progressValue).reduce((int a, int b) => a + b) ~/
            group.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 42,
                width: 42,
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
                    fontWeight: FontWeight.w700,
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
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.items.length} đầu việc • Tiến độ trung bình $averageProgress%',
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
          ...group.items.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == group.items.length - 1 ? 0 : 12,
              ),
              child: _buildItemCard(entry.value, showAssignee: false),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_TaskItemGroup> groupedItems = _groupedItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: <Widget>[
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: <Widget>[
                  if (message.isNotEmpty)
                    Text(
                      message,
                      style: const TextStyle(color: StitchTheme.textMuted),
                    ),
                  if (task != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: StitchTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (task?['title'] ?? 'Công việc').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Trạng thái: ${_statusLabel((task?['status'] ?? '').toString())}',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tiến độ: ${(task?['progress_percent'] ?? 0)}%',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Deadline: ${_formatDate((task?['deadline'] ?? '').toString())}',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Phòng ban: ${(task?['department']?['name'] ?? '—').toString()}',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Danh sách đầu việc',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Text(
                        'Chưa có đầu việc nào.',
                        style: TextStyle(color: StitchTheme.textMuted),
                      )
                    else
                      ...groupedItems.map(_buildItemGroup),
                  ],
                ],
              ),
      ),
    );
  }
}

class _TaskItemGroup {
  const _TaskItemGroup({
    required this.assignee,
    required this.items,
  });

  final String assignee;
  final List<Map<String, dynamic>> items;
}

class _ReviewInfoRow extends StatelessWidget {
  const _ReviewInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: StitchTheme.textMuted,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
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
            style: const TextStyle(
              color: StitchTheme.textMuted,
              fontSize: 11,
            ),
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
  const _LegendDot({
    required this.color,
    required this.label,
  });

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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: StitchTheme.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TaskItemInsightChart extends StatelessWidget {
  const _TaskItemInsightChart({
    required this.points,
  });

  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có dữ liệu tiến độ để hiển thị.',
          style: TextStyle(
            color: StitchTheme.textMuted,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _TaskItemInsightPainter(points: points),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: points.map((Map<String, dynamic> point) {
                  return Expanded(
                    child: Text(
                      (point['label'] ?? '').toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskItemInsightPainter extends CustomPainter {
  const _TaskItemInsightPainter({
    required this.points,
  });

  final List<Map<String, dynamic>> points;

  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = math.max(40, size.height - 28);
    final Paint gridPaint = Paint()
      ..color = StitchTheme.border
      ..strokeWidth = 1;
    final Paint expectedPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final Paint actualPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final Paint pointPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.fill;

    for (int i = 0; i <= 4; i++) {
      final double y = (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    if (points.length < 2) {
      return;
    }

    final Path expectedPath = Path();
    final Path actualPath = Path();

    for (int i = 0; i < points.length; i++) {
      final Map<String, dynamic> point = points[i];
      final double x = points.length == 1
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

      canvas.drawCircle(Offset(x, actualY), 3.5, pointPaint);
    }

    canvas.drawPath(expectedPath, expectedPaint);
    canvas.drawPath(actualPath, actualPaint);
  }

  double _clampPercent(dynamic value) {
    final double parsed = value is num
        ? value.toDouble()
        : double.tryParse('${value ?? 0}') ?? 0;
    return parsed.clamp(0, 100);
  }

  @override
  bool shouldRepaint(covariant _TaskItemInsightPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

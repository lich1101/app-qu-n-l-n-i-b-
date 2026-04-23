import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/messaging/app_tag_message.dart';
import '../../core/utils/timeline_defaults.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../data/services/mobile_api_service.dart';
import 'create_project_screen.dart';
import '../tasks/project_task_form_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_item_detail_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.projectId,
  });

  final String token;
  final MobileApiService apiService;
  final int projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool loading = true;
  bool submittingHandover = false;
  bool gscLoading = false;
  bool gscNotifySaving = false;
  bool taskActionLoading = false;
  Map<String, dynamic>? project;
  Map<String, dynamic>? gsc;
  List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> departments = <Map<String, dynamic>>[];
  String message = '';
  String gscMessage = '';
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
      gscMessage = '';
    });
    final List<dynamic> responses =
        await Future.wait<dynamic>(<Future<dynamic>>[
          widget.apiService.getProject(widget.token, widget.projectId),
          widget.apiService.getTasks(
            widget.token,
            projectId: widget.projectId,
            perPage: 200,
          ),
          widget.apiService.me(widget.token),
        ]);

    final Map<String, dynamic>? proj = responses[0] as Map<String, dynamic>?;
    final List<Map<String, dynamic>> rows =
        responses[1] as List<Map<String, dynamic>>;
    final Map<String, dynamic> mePayload = responses[2] as Map<String, dynamic>;
    final Map<String, dynamic> meBody =
        (mePayload['body'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final dynamic meRawId = meBody['id'];

    Map<String, dynamic>? gscPayload;
    String gscError = '';
    final String websiteUrl = (proj?['website_url'] ?? '').toString().trim();
    if (proj != null && websiteUrl.isNotEmpty) {
      final Map<String, dynamic> gscRes = await widget.apiService
          .getProjectSearchConsole(widget.token, widget.projectId);
      if (gscRes['error'] == true) {
        gscError = (gscRes['message'] ?? '').toString();
        gscPayload = _appendSyncError(null, gscError);
      } else {
        gscPayload =
            ((gscRes['body'] ?? <String, dynamic>{}) as Map<String, dynamic>)
                .cast<String, dynamic>();
      }
    }
    if (!mounted) return;
    setState(() {
      project = proj;
      tasks = rows;
      gsc = gscPayload;
      gscMessage = gscError;
      currentUserId =
          meRawId is int ? meRawId : int.tryParse('${meRawId ?? ''}');
      currentUserRole = (meBody['role'] ?? '').toString();
      loading = false;
      message = proj == null ? 'Không tìm thấy dự án.' : '';
    });
  }

  int _toId(dynamic value) {
    if (value is int) return value;
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  bool get _isAdminRole =>
      currentUserRole == 'admin' || currentUserRole == 'administrator';

  bool get _canManageProjectTasks {
    if (_isAdminRole) return true;
    final int ownerId = _toId(project?['owner_id'] ?? project?['owner']?['id']);
    return currentUserId != null && ownerId > 0 && ownerId == currentUserId;
  }

  bool get _canEditProject =>
      (project?['permissions']?['can_edit'] ?? false) == true;

  Future<void> _openEditProject() async {
    if (!_canEditProject || project == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<Widget>(
        builder:
            (_) => CreateProjectScreen(
              token: widget.token,
              apiService: widget.apiService,
              projectId: widget.projectId,
              initialProject: Map<String, dynamic>.from(project!),
              canEditAllProjectFields:
                  (project!['permissions']?['can_edit_all_project_fields'] ??
                      false) ==
                  true,
            ),
      ),
    );
    if (!mounted) return;
    await _fetch();
  }

  Future<void> _ensureDepartmentsLoaded() async {
    if (departments.isNotEmpty) return;
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getDepartments(widget.token);
    if (!mounted) return;
    setState(() => departments = rows);
  }

  Future<void> _openTaskSheet({Map<String, dynamic>? editingTask}) async {
    if (!_canManageProjectTasks) return;
    await _ensureDepartmentsLoaded();
    if (!mounted) return;

    final bool isEdit = editingTask != null;
    final ({DateTime? start, DateTime? end}) taskDefaults =
        TimelineDefaults.taskDefaultsFromProject(project);
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => ProjectTaskFormScreen(
              token: widget.token,
              apiService: widget.apiService,
              projectId: widget.projectId,
              projectName: (project?['name'] ?? '').toString(),
              departments: departments,
              existingTasksForWeightHint: tasks,
              defaultStartDate: taskDefaults.start ?? project?['start_date'],
              defaultDeadline: taskDefaults.end ?? project?['deadline'],
              editingTask: editingTask,
            ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      await _fetch();
      if (!mounted) return;
      AppTagMessage.show(
        isEdit ? 'Đã cập nhật công việc.' : 'Đã tạo công việc mới trong dự án.',
      );
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    if (!_canManageProjectTasks || taskActionLoading) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa công việc'),
          content: Text(
            'Bạn có chắc muốn xóa công việc "${(task['title'] ?? 'Công việc').toString()}"?',
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
    setState(() => taskActionLoading = true);
    final bool ok = await widget.apiService.deleteTask(
      widget.token,
      _toId(task['id']),
    );
    if (!mounted) return;
    setState(() => taskActionLoading = false);
    if (ok) {
      await _fetch();
    }
    if (!mounted) return;
    AppTagMessage.show(
      ok ? 'Đã xóa công việc.' : 'Không thể xóa công việc.',
      isError: !ok,
    );
  }

  Future<String?> _promptRejectNote() async {
    final TextEditingController controller = TextEditingController();
    final String? submitted = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Lý do từ chối'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Bắt buộc (tối đa 500 ký tự)',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final String t = controller.text.trim();
                if (t.isEmpty) {
                  return;
                }
                Navigator.pop(ctx, t);
              },
              child: const Text('Gửi'),
            ),
          ],
        );
      },
    );
    return submitted;
  }

  Future<void> _openApprovalQueue() async {
    final Map<String, dynamic>? data = await widget.apiService
        .getProjectApprovalQueue(widget.token, widget.projectId);
    if (!mounted) {
      return;
    }
    if (data == null) {
      AppTagMessage.show(
        'Không tải được danh sách phiếu duyệt.',
        isError: true,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.45,
          maxChildSize: 0.96,
          expand: false,
          builder: (_, ScrollController scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Phiếu duyệt trong dự án',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _ProjectApprovalQueueBody(
                      token: widget.token,
                      apiService: widget.apiService,
                      projectId: widget.projectId,
                      initialData: data,
                      scrollController: scrollController,
                      onNavigateTask: (int taskId) {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => TaskDetailScreen(
                                  token: widget.token,
                                  apiService: widget.apiService,
                                  taskId: taskId,
                                ),
                          ),
                        );
                      },
                      onNavigateItem: (int taskId, int itemId) {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => TaskItemDetailScreen(
                                  token: widget.token,
                                  apiService: widget.apiService,
                                  taskId: taskId,
                                  itemId: itemId,
                                ),
                          ),
                        );
                      },
                      onChanged: () async {
                        await _fetch();
                      },
                      promptRejectNote: _promptRejectNote,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fetchGsc() async {
    final Map<String, dynamic>? currentProject = project;
    if (currentProject == null) return;
    final String websiteUrl =
        (currentProject['website_url'] ?? '').toString().trim();
    if (websiteUrl.isEmpty) {
      setState(() {
        gsc = null;
        gscMessage = '';
      });
      return;
    }

    setState(() => gscLoading = true);
    final Map<String, dynamic> gscRes = await widget.apiService
        .getProjectSearchConsole(widget.token, widget.projectId);
    if (!mounted) return;

    if (gscRes['error'] == true) {
      final String errorMessage = (gscRes['message'] ?? '').toString().trim();
      setState(() {
        gscLoading = false;
        gscMessage = errorMessage;
        gsc = _appendSyncError(gsc, errorMessage);
      });
      return;
    }

    final Map<String, dynamic> payload =
        ((gscRes['body'] ?? <String, dynamic>{}) as Map<String, dynamic>)
            .cast<String, dynamic>();
    setState(() {
      gscLoading = false;
      gscMessage = '';
      gsc = payload;
    });
  }

  Future<void> _toggleGscNotification(bool enabled) async {
    if (gscNotifySaving) return;
    setState(() => gscNotifySaving = true);

    final Map<String, dynamic> res = await widget.apiService
        .updateProjectSearchConsoleNotification(
          widget.token,
          widget.projectId,
          enabled: enabled,
        );
    if (!mounted) return;

    if (res['error'] == true) {
      final String err =
          (res['message'] ?? 'Không cập nhật được thông báo GSC.').toString();
      final Map<String, dynamic>? body =
          res['body'] is Map
              ? (res['body'] as Map).cast<String, dynamic>()
              : null;
      final Map<String, dynamic>? payload =
          body != null && body['data'] is Map
              ? (body['data'] as Map).cast<String, dynamic>()
              : null;
      setState(() {
        gscNotifySaving = false;
        gscMessage = err;
        gsc = payload ?? _appendSyncError(gsc, err);
      });
      AppTagMessage.show(err, isError: true);
      return;
    }

    final Map<String, dynamic>? body =
        res['body'] is Map
            ? (res['body'] as Map).cast<String, dynamic>()
            : null;
    final Map<String, dynamic>? payload =
        body != null && body['data'] is Map
            ? (body['data'] as Map).cast<String, dynamic>()
            : null;
    final String okMessage =
        (body?['message'] ??
                (enabled
                    ? 'Đã bật thông báo Google Search Console.'
                    : 'Đã tắt thông báo Google Search Console.'))
            .toString();

    setState(() {
      gscNotifySaving = false;
      gscMessage = '';
      if (payload != null) {
        gsc = payload;
      }
    });
    if (payload == null) {
      await _fetchGsc();
      if (!mounted) return;
    }

    AppTagMessage.show(okMessage);
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'moi_tao':
        return 'Mới tạo';
      case 'dang_trien_khai':
        return 'Đang triển khai';
      case 'cho_duyet':
        return 'Chờ duyệt';
      case 'hoan_thanh':
        return 'Hoàn thành';
      case 'tam_dung':
        return 'Tạm dừng';
      default:
        return value;
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    final DateTime? dt = VietnamTime.parse(raw);
    if (dt == null) return '—';
    return VietnamTime.formatDate(dt);
  }

  String _formatShortDate(String raw) {
    if (raw.isEmpty) return '—';
    final String ymd = VietnamTime.toYmdInput(raw);
    if (ymd.length >= 10) return ymd.substring(5, 10);
    return raw;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  String _formatNumber(dynamic value) {
    final int number = _toInt(value);
    final String sign = number < 0 ? '-' : '';
    final String digits = number.abs().toString();
    final String grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$sign$grouped';
  }

  String _formatSigned(dynamic value) {
    final int number = _toInt(value);
    if (number > 0) return '+${_formatNumber(number)}';
    return _formatNumber(number);
  }

  String _formatPercent(dynamic value, {int digits = 2}) {
    final double? parsed = _toDoubleOrNull(value);
    if (parsed == null) return '—';
    return '${parsed.toStringAsFixed(digits)}%';
  }

  Map<String, dynamic> _appendSyncError(
    Map<String, dynamic>? source,
    String error,
  ) {
    final Map<String, dynamic> base = <String, dynamic>{
      ...(source ?? <String, dynamic>{}),
    };
    final Map<String, dynamic> status = <String, dynamic>{
      ...((base['status'] is Map)
          ? (base['status'] as Map).cast<String, dynamic>()
          : <String, dynamic>{}),
      'sync_error': error,
    };
    base['status'] = status;
    return base;
  }

  String _handoverLabel(String value) {
    switch (value) {
      case 'pending':
        return 'Đang chờ duyệt bàn giao';
      case 'approved':
        return 'Đã duyệt bàn giao';
      case 'rejected':
        return 'Bị từ chối bàn giao';
      default:
        return 'Chưa bàn giao';
    }
  }

  Future<void> _submitHandover() async {
    final Map<String, dynamic>? currentProject = project;
    if (currentProject == null || submittingHandover) return;
    setState(() => submittingHandover = true);
    final bool ok = await widget.apiService.submitProjectHandover(
      widget.token,
      widget.projectId,
    );
    if (!mounted) return;
    setState(() => submittingHandover = false);
    AppTagMessage.show(
      ok
          ? 'Đã gửi duyệt bàn giao dự án.'
          : 'Gửi duyệt bàn giao thất bại. Kiểm tra tiến độ tối thiểu hoặc quyền thao tác.',
      isError: !ok,
    );
    if (ok) {
      await _fetch();
    }
  }

  Future<void> _reviewHandover(String decision) async {
    final Map<String, dynamic>? currentProject = project;
    if (currentProject == null || submittingHandover) return;

    String reason = '';
    if (decision == 'rejected') {
      final String? input = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          final TextEditingController c = TextEditingController();
          return AlertDialog(
            title: const Text('Từ chối bàn giao'),
            content: TextField(
              controller: c,
              decoration: const InputDecoration(hintText: 'Nhập lý do từ chối'),
              maxLines: 3,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: StitchTheme.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, c.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StitchTheme.danger,
                ),
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      );
      if (input == null || input.trim().isEmpty) return;
      reason = input.trim();
    } else {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder:
            (BuildContext context) => AlertDialog(
              title: const Text('Duyệt bàn giao'),
              content: const Text(
                'Bạn có chắc chắn muốn chấp thuận bàn giao dự án này không?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: StitchTheme.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StitchTheme.success,
                  ),
                  child: const Text('Đồng ý duyệt'),
                ),
              ],
            ),
      );
      if (confirm != true) return;
    }

    setState(() => submittingHandover = true);
    final bool ok = await widget.apiService.reviewProjectHandover(
      widget.token,
      widget.projectId,
      decision: decision,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => submittingHandover = false);
    AppTagMessage.show(
      ok ? 'Đã xử lý phiếu bàn giao.' : 'Xử lý thất bại. Vui lòng thử lại.',
      isError: !ok,
    );
    if (ok) {
      await _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String websiteUrl = (project?['website_url'] ?? '').toString().trim();
    final bool hasLinkedContract =
        project?['contract_id'] != null ||
        ((project?['contract'] is Map) &&
            ((project?['contract'] as Map)['id'] != null));
    final Map<String, dynamic> gscStatus = <String, dynamic>{
      ...((gsc?['status'] is Map)
          ? (gsc?['status'] as Map).cast<String, dynamic>()
          : <String, dynamic>{}),
    };
    final Map<String, dynamic>? gscLatest =
        gsc?['latest'] is Map
            ? (gsc?['latest'] as Map).cast<String, dynamic>()
            : null;
    final List<Map<String, dynamic>> gscTrend =
        gsc?['trend'] is List
            ? (gsc?['trend'] as List)
                .whereType<Map>()
                .map((Map row) => row.cast<String, dynamic>())
                .toList()
            : <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> gscTrendChart =
        gscTrend.isNotEmpty
            ? gscTrend
            : <Map<String, dynamic>>[
              if (gscLatest != null &&
                  ((gscLatest['prior_date'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty))
                <String, dynamic>{
                  'date': (gscLatest['prior_date'] ?? '').toString(),
                  'clicks': _toInt(gscLatest['prior_clicks']),
                  'delta_clicks': 0,
                },
              if (gscLatest != null &&
                  ((gscLatest['metric_date'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty))
                <String, dynamic>{
                  'date': (gscLatest['metric_date'] ?? '').toString(),
                  'clicks': _toInt(gscLatest['last_clicks']),
                  'delta_clicks': _toInt(gscLatest['delta_clicks']),
                },
            ];
    final Map<String, dynamic>? gscSummary =
        gsc?['summary'] is Map
            ? (gsc?['summary'] as Map).cast<String, dynamic>()
            : null;
    final int gscMaxClicks = gscTrendChart.fold<int>(
      1,
      (int prev, Map<String, dynamic> row) =>
          math.max(prev, _toInt(row['clicks'])),
    );
    final bool gscNotifyEnabled =
        (gscStatus['project_notify_enabled'] ?? false) == true;
    final bool gscCanManageNotification =
        (gscStatus['can_manage_notification'] ?? false) == true;
    final bool gscCanEnableNotification =
        (gscStatus['can_enable_notification'] ?? false) == true;
    final String gscEnableBlockReason =
        (gscStatus['enable_block_reason'] ?? '').toString().trim();
    final String gscTrackingStartedAt =
        (gscStatus['tracking_started_at'] ?? '').toString().trim();
    final String gscLastSyncedAt =
        (gscStatus['last_synced_at'] ?? '').toString().trim();
    final bool gscCanToggleNotification =
        gscCanManageNotification &&
        (gscNotifyEnabled || gscCanEnableNotification);
    final String syncError =
        (gscStatus['sync_error'] ?? gscMessage).toString().trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết dự án'),
        actions: <Widget>[
          if (project != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  IconButton(
                    onPressed: _openApprovalQueue,
                    icon: const Icon(Icons.fact_check_outlined),
                    tooltip: 'Danh sách phiếu duyệt',
                  ),
                  if ((int.tryParse(
                            '${project?['pending_review_count'] ?? 0}',
                          ) ??
                          0) >
                      0)
                    Positioned(
                      right: 4,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${int.tryParse('${project?['pending_review_count'] ?? 0}') ?? 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_canEditProject)
            IconButton(
              onPressed: _openEditProject,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Sửa dự án',
            ),
        ],
      ),
      body: SafeArea(
        child:
            loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: <Widget>[
                      if (message.isNotEmpty)
                        Text(
                          message,
                          style: const TextStyle(color: StitchTheme.textMuted),
                        ),
                      if (project != null) ...<Widget>[
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
                                (project?['name'] ?? 'Dự án').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Trạng thái: ${_statusLabel((project?['status'] ?? '').toString())}',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tiến độ: ${(project?['progress_percent'] ?? 0)}%',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Hạn chót: ${_formatDate((project?['deadline'] ?? '').toString())}',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Phụ trách: ${(project?['owner']?['name'] ?? '—').toString()}',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Bàn giao: ${hasLinkedContract ? _handoverLabel((project?['handover_status'] ?? '').toString()) : 'Không yêu cầu (dự án nội bộ)'}',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Website: ${websiteUrl.isEmpty ? '—' : websiteUrl}',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              if (((project?['handover_review_note'] ?? '')
                                      .toString()
                                      .trim())
                                  .isNotEmpty) ...<Widget>[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.warning.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'Ghi chú phản hồi: ${(project?['handover_review_note'] ?? '').toString()}',
                                    style: const TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if ((project?['permissions']?['can_submit_handover'] ==
                                  true)) ...<Widget>[
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        submittingHandover
                                            ? null
                                            : _submitHandover,
                                    icon: const Icon(
                                      Icons.assignment_turned_in_outlined,
                                    ),
                                    label: Text(
                                      submittingHandover
                                          ? 'Đang gửi duyệt...'
                                          : 'Gửi duyệt bàn giao dự án',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Nút này chỉ hoạt động khi tiến độ dự án đạt từ ${(project?['handover_min_progress_percent'] ?? 90)}% trở lên.',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (project?['permissions']?['can_review_handover'] ==
                                      true &&
                                  (project?['handover_status'] ?? '')
                                          .toString() ==
                                      'pending') ...<Widget>[
                                const SizedBox(height: 14),
                                const Text(
                                  'Phê duyệt bàn giao',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            submittingHandover
                                                ? null
                                                : () =>
                                                    _reviewHandover('rejected'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: StitchTheme.danger,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Từ chối'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            submittingHandover
                                                ? null
                                                : () =>
                                                    _reviewHandover('approved'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: StitchTheme.success,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Duyệt'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              Row(
                                children: <Widget>[
                                  const Expanded(
                                    child: Text(
                                      'Google Search Console',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    gscNotifyEnabled ? 'Đang bật' : 'Đang tắt',
                                    style: TextStyle(
                                      color:
                                          gscNotifyEnabled
                                              ? StitchTheme.success
                                              : StitchTheme.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: gscNotifyEnabled,
                                    onChanged:
                                        (gscNotifySaving ||
                                                gscLoading ||
                                                !gscCanToggleNotification)
                                            ? null
                                            : _toggleGscNotification,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tự cập nhật theo ngày theo giờ admin cấu hình (${(gscStatus['sync_time'] ?? '11:17').toString()}).',
                                style: TextStyle(
                                  color: StitchTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              if (gscTrackingStartedAt.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  'Biểu đồ tính từ ngày thêm website: ${_formatDate(gscTrackingStartedAt)}'
                                  '${gscLastSyncedAt.isNotEmpty ? ' • Đồng bộ gần nhất: ${_formatDate(gscLastSyncedAt)}' : ''}',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              if (websiteUrl.isEmpty) ...<Widget>[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.warning.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'Dự án chưa có website_url. Hãy cập nhật URL website để bật thống kê Search Console.',
                                    style: TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if (gscEnableBlockReason.isNotEmpty &&
                                  !gscNotifyEnabled) ...<Widget>[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.warning.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    gscEnableBlockReason,
                                    style: const TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  gscStatus['can_sync'] == false) ...<Widget>[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.warning.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'Chưa thể đồng bộ Search Console. Kiểm tra cấu hình GSC trong Cài đặt hệ thống.',
                                    style: TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  syncError.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.danger.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'Lỗi đồng bộ gần nhất: $syncError',
                                    style: const TextStyle(
                                      color: StitchTheme.textMain,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  gscLoading) ...<Widget>[
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(minHeight: 4),
                                const SizedBox(height: 8),
                                const Text(
                                  'Đang tải dữ liệu Search Console...',
                                  style: TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  !gscLoading &&
                                  gscLatest != null) ...<Widget>[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    _GscMetricCard(
                                      label: 'Ngày thống kê',
                                      value: _formatDate(
                                        (gscLatest['metric_date'] ?? '')
                                            .toString(),
                                      ),
                                      subLabel:
                                          'So với ${_formatDate((gscLatest['prior_date'] ?? '').toString())}',
                                    ),
                                    _GscMetricCard(
                                      label: 'Clicks',
                                      value: _formatNumber(
                                        gscLatest['last_clicks'],
                                      ),
                                      subLabel:
                                          '${_formatSigned(gscLatest['delta_clicks'])} (${_formatPercent(gscLatest['delta_clicks_percent'])})',
                                      positive:
                                          _toInt(gscLatest['delta_clicks']) >=
                                          0,
                                    ),
                                    _GscMetricCard(
                                      label: 'Impressions',
                                      value: _formatNumber(
                                        gscLatest['last_impressions'],
                                      ),
                                      subLabel: _formatSigned(
                                        gscLatest['delta_impressions'],
                                      ),
                                      positive:
                                          _toInt(
                                            gscLatest['delta_impressions'],
                                          ) >=
                                          0,
                                    ),
                                    _GscMetricCard(
                                      label: 'Alerts',
                                      value: _formatNumber(
                                        gscLatest['alerts_total'],
                                      ),
                                      subLabel:
                                          'Brand ${_toInt(gscLatest['alerts_brand'])} • Recipes ${_toInt(gscLatest['alerts_recipes'])}',
                                    ),
                                  ],
                                ),
                                if (gscTrendChart.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          'Biểu đồ tăng trưởng clicks (${_toInt(gscSummary?['days'] ?? gscTrendChart.length)} mốc)',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'TB/ngày: ${_formatNumber(gscSummary?['avg_clicks_per_day'] ?? 0)}',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children:
                                          gscTrendChart.map((
                                            Map<String, dynamic> item,
                                          ) {
                                            final int clicks = _toInt(
                                              item['clicks'],
                                            );
                                            final int delta = _toInt(
                                              item['delta_clicks'],
                                            );
                                            final double ratio =
                                                gscMaxClicks <= 0
                                                    ? 0
                                                    : clicks / gscMaxClicks;
                                            final double normalized = math.max(
                                              0.04,
                                              ratio,
                                            );
                                            final double barHeight =
                                                clicks <= 0
                                                    ? 6
                                                    : 18 + (normalized * 110);
                                            return Container(
                                              width: 44,
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: <Widget>[
                                                  SizedBox(
                                                    height: 148,
                                                    child: Align(
                                                      alignment:
                                                          Alignment
                                                              .bottomCenter,
                                                      child: Container(
                                                        width: 24,
                                                        height: barHeight,
                                                        decoration: BoxDecoration(
                                                          color: (delta >= 0
                                                                  ? StitchTheme
                                                                      .success
                                                                  : StitchTheme
                                                                      .danger)
                                                              .withValues(
                                                                alpha: 0.85,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _formatShortDate(
                                                      (item['date'] ?? '')
                                                          .toString(),
                                                    ),
                                                    style: const TextStyle(
                                                      color:
                                                          StitchTheme.textMuted,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatNumber(clicks),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  !gscLoading &&
                                  gscLatest == null) ...<Widget>[
                                const SizedBox(height: 12),
                                const Text(
                                  'Chưa có dữ liệu Search Console cho dự án này.',
                                  style: TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Công việc trong dự án',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (_canManageProjectTasks)
                              FilledButton.icon(
                                onPressed:
                                    taskActionLoading
                                        ? null
                                        : () => _openTaskSheet(),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Thêm công việc'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...tasks.map((Map<String, dynamic> task) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _ProjectTaskListTile(
                              task: task,
                              projectLabel:
                                  (project?['name'] ?? 'Dự án').toString(),
                              statusLabel: _statusLabel,
                              formatDate: _formatDate,
                              canManage: _canManageProjectTasks,
                              onOpen: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<Widget>(
                                    builder:
                                        (_) => TaskDetailScreen(
                                          token: widget.token,
                                          apiService: widget.apiService,
                                          taskId: (task['id'] ?? 0) as int,
                                        ),
                                  ),
                                );
                              },
                              onEdit:
                                  _canManageProjectTasks
                                      ? () => _openTaskSheet(editingTask: task)
                                      : null,
                              onDelete:
                                  _canManageProjectTasks
                                      ? () => _deleteTask(task)
                                      : null,
                            ),
                          );
                        }),
                        if (tasks.isEmpty)
                          const Text(
                            'Chưa có công việc nào.',
                            style: TextStyle(color: StitchTheme.textMuted),
                          ),
                      ],
                    ],
                  ),
                ),
      ),
    );
  }
}

class _ProjectApprovalQueueBody extends StatefulWidget {
  const _ProjectApprovalQueueBody({
    required this.token,
    required this.apiService,
    required this.projectId,
    required this.initialData,
    required this.scrollController,
    required this.onNavigateTask,
    required this.onNavigateItem,
    required this.onChanged,
    required this.promptRejectNote,
  });

  final String token;
  final MobileApiService apiService;
  final int projectId;
  final Map<String, dynamic> initialData;
  final ScrollController scrollController;
  final void Function(int taskId) onNavigateTask;
  final void Function(int taskId, int itemId) onNavigateItem;
  final Future<void> Function() onChanged;
  final Future<String?> Function() promptRejectNote;

  @override
  State<_ProjectApprovalQueueBody> createState() =>
      _ProjectApprovalQueueBodyState();
}

class _ProjectApprovalQueueBodyState extends State<_ProjectApprovalQueueBody> {
  late Map<String, dynamic> _data;
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.initialData);
  }

  int _toId(dynamic v) {
    if (v is int) {
      return v;
    }
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  Future<void> _reload() async {
    final Map<String, dynamic>? next = await widget.apiService
        .getProjectApprovalQueue(widget.token, widget.projectId);
    if (!mounted || next == null) {
      return;
    }
    setState(() => _data = next);
    await widget.onChanged();
  }

  Future<void> _approveTaskUpdate(int taskId, int updateId) async {
    final String key = 't-$taskId-$updateId';
    setState(() => _busyKey = key);
    final bool ok = await widget.apiService.approveTaskUpdate(
      widget.token,
      taskId,
      updateId,
    );
    if (!mounted) {
      return;
    }
    setState(() => _busyKey = null);
    if (ok) {
      AppTagMessage.show('Đã duyệt báo cáo.');
      await _reload();
    } else {
      AppTagMessage.show('Duyệt thất bại.', isError: true);
    }
  }

  Future<void> _rejectTaskUpdate(int taskId, int updateId) async {
    final String? note = await widget.promptRejectNote();
    if (note == null || note.isEmpty) {
      return;
    }
    final String key = 't-$taskId-$updateId';
    setState(() => _busyKey = key);
    final bool ok = await widget.apiService.rejectTaskUpdate(
      widget.token,
      taskId,
      updateId,
      reviewNote: note,
    );
    if (!mounted) {
      return;
    }
    setState(() => _busyKey = null);
    if (ok) {
      AppTagMessage.show('Đã từ chối báo cáo.');
      await _reload();
    } else {
      AppTagMessage.show('Từ chối thất bại.', isError: true);
    }
  }

  Future<void> _approveItemUpdate(int taskId, int itemId, int updateId) async {
    final String key = 'i-$taskId-$itemId-$updateId';
    setState(() => _busyKey = key);
    final bool ok = await widget.apiService.approveTaskItemUpdate(
      widget.token,
      taskId,
      itemId,
      updateId,
    );
    if (!mounted) {
      return;
    }
    setState(() => _busyKey = null);
    if (ok) {
      AppTagMessage.show('Đã duyệt phiếu.');
      await _reload();
    } else {
      AppTagMessage.show('Duyệt thất bại.', isError: true);
    }
  }

  Future<void> _rejectItemUpdate(int taskId, int itemId, int updateId) async {
    final String? note = await widget.promptRejectNote();
    if (note == null || note.isEmpty) {
      return;
    }
    final String key = 'i-$taskId-$itemId-$updateId';
    setState(() => _busyKey = key);
    final bool ok = await widget.apiService.rejectTaskItemUpdate(
      widget.token,
      taskId,
      itemId,
      updateId,
      reviewNote: note,
    );
    if (!mounted) {
      return;
    }
    setState(() => _busyKey = null);
    if (ok) {
      AppTagMessage.show('Đã từ chối phiếu.');
      await _reload();
    } else {
      AppTagMessage.show('Từ chối thất bại.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> taskRows =
        (_data['tasks'] is List)
            ? (_data['tasks'] as List<dynamic>)
            : <dynamic>[];
    final bool canReview = _data['can_review_progress'] == true;

    if (taskRows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Không có phiếu nào đang chờ duyệt.',
            style: TextStyle(color: StitchTheme.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: taskRows.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> t =
            (taskRows[index] is Map)
                ? (taskRows[index] as Map).cast<String, dynamic>()
                : <String, dynamic>{};
        final int taskId = _toId(t['id']);
        final String taskTitle = (t['title'] ?? 'Công việc').toString();
        final List<dynamic> taskUpdates =
            (t['task_updates_pending'] is List)
                ? (t['task_updates_pending'] as List<dynamic>)
                : <dynamic>[];
        final List<dynamic> items =
            (t['items'] is List) ? (t['items'] as List<dynamic>) : <dynamic>[];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: StitchTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  onTap:
                      taskId > 0 ? () => widget.onNavigateTask(taskId) : null,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          taskTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        '#$taskId',
                        style: const TextStyle(
                          color: StitchTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (taskUpdates.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Báo cáo cấp công việc',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                  ...taskUpdates.map((dynamic u) {
                    final Map<String, dynamic> row =
                        (u is Map)
                            ? u.cast<String, dynamic>()
                            : <String, dynamic>{};
                    final int uid = _toId(row['id']);
                    final String key = 't-$taskId-$uid';
                    final bool busy = _busyKey == key;
                    final Map<String, dynamic>? sub =
                        row['submitter'] is Map
                            ? (row['submitter'] as Map).cast<String, dynamic>()
                            : null;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: StitchTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${(sub?['name'] ?? '—').toString()} · ${_formatQueueDate((row['created_at'] ?? '').toString())}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: StitchTheme.textMuted,
                              ),
                            ),
                            if ((row['note'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  (row['note'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            if (canReview) ...<Widget>[
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  TextButton(
                                    onPressed:
                                        busy
                                            ? null
                                            : () =>
                                                _approveTaskUpdate(taskId, uid),
                                    child: const Text('Duyệt'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        busy
                                            ? null
                                            : () =>
                                                _rejectTaskUpdate(taskId, uid),
                                    child: Text(
                                      'Từ chối',
                                      style: TextStyle(
                                        color: StitchTheme.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                ...items.map((dynamic it) {
                  final Map<String, dynamic> item =
                      (it is Map)
                          ? it.cast<String, dynamic>()
                          : <String, dynamic>{};
                  final int itemId = _toId(item['id']);
                  final String itemTitle =
                      (item['title'] ?? 'Đầu việc').toString();
                  final List<dynamic> pending =
                      (item['pending_updates'] is List)
                          ? (item['pending_updates'] as List<dynamic>)
                          : <dynamic>[];

                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        InkWell(
                          onTap:
                              taskId > 0 && itemId > 0
                                  ? () => widget.onNavigateItem(taskId, itemId)
                                  : null,
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  itemTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                '#$itemId',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...pending.map((dynamic u) {
                          final Map<String, dynamic> row =
                              (u is Map)
                                  ? u.cast<String, dynamic>()
                                  : <String, dynamic>{};
                          final int uid = _toId(row['id']);
                          final String key = 'i-$taskId-$itemId-$uid';
                          final bool busy = _busyKey == key;
                          final Map<String, dynamic>? sub =
                              row['submitter'] is Map
                                  ? (row['submitter'] as Map)
                                      .cast<String, dynamic>()
                                  : null;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: StitchTheme.border.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '${(sub?['name'] ?? '—').toString()} · ${_formatQueueDate((row['created_at'] ?? '').toString())}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: StitchTheme.textMuted,
                                    ),
                                  ),
                                  if ((row['note'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        (row['note'] ?? '').toString(),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  if (canReview) ...<Widget>[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: <Widget>[
                                        TextButton(
                                          onPressed:
                                              busy
                                                  ? null
                                                  : () => _approveItemUpdate(
                                                    taskId,
                                                    itemId,
                                                    uid,
                                                  ),
                                          child: const Text('Duyệt'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              busy
                                                  ? null
                                                  : () => _rejectItemUpdate(
                                                    taskId,
                                                    itemId,
                                                    uid,
                                                  ),
                                          child: Text(
                                            'Từ chối',
                                            style: TextStyle(
                                              color: StitchTheme.danger,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatQueueDate(String raw) {
  if (raw.isEmpty) {
    return '—';
  }
  final DateTime? dt = VietnamTime.parse(raw);
  if (dt == null) {
    return '—';
  }
  return VietnamTime.formatDate(dt);
}

class _ProjectPriStyle {
  const _ProjectPriStyle({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
}

_ProjectPriStyle _projectPriStyleForTask(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'urgent':
      return const _ProjectPriStyle(
        label: 'Khẩn cấp',
        background: Color(0xFFFEE2E2),
        foreground: Color(0xFFDC2626),
        icon: Icons.error,
      );
    case 'high':
      return const _ProjectPriStyle(
        label: 'Cao',
        background: Color(0xFFFFEDD5),
        foreground: Color(0xFFEA580C),
        icon: Icons.flag,
      );
    case 'low':
      return const _ProjectPriStyle(
        label: 'Thấp',
        background: Color(0xFFF1F5F9),
        foreground: Color(0xFF475569),
        icon: Icons.circle,
      );
    default:
      return _ProjectPriStyle(
        label: 'Trung bình',
        background: StitchTheme.primarySoft,
        foreground: StitchTheme.primary,
        icon: Icons.adjust,
      );
  }
}

String _projectTaskShortDeadline(String raw) {
  if (raw.isEmpty) return '—';
  final DateTime? d = VietnamTime.parse(raw);
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';
}

/// Thẻ công việc giống danh sách công việc (ưu tiên, PB, tiến độ, deadline…).
class _ProjectTaskListTile extends StatelessWidget {
  const _ProjectTaskListTile({
    required this.task,
    required this.projectLabel,
    required this.statusLabel,
    required this.formatDate,
    required this.onOpen,
    required this.canManage,
    this.onEdit,
    this.onDelete,
  });

  final Map<String, dynamic> task;
  final String projectLabel;
  final String Function(String value) statusLabel;
  final String Function(String raw) formatDate;
  final VoidCallback onOpen;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse('$v') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final String title = (task['title'] ?? 'Công việc').toString();
    final String priority = (task['priority'] ?? 'medium').toString();
    final _ProjectPriStyle pri = _projectPriStyleForTask(priority);
    final Map<String, dynamic>? department =
        task['department'] as Map<String, dynamic>?;
    final String departmentName = (department?['name'] ?? '—').toString();
    final int progress = _toInt(task['progress_percent']);
    final int comments = _toInt(task['comments_count']);
    final int attachments = _toInt(task['attachments_count']);
    final String status = (task['status'] ?? '').toString();
    final String deadlineRaw = (task['deadline'] ?? '').toString();
    final Map<String, dynamic>? assignee =
        task['assignee'] as Map<String, dynamic>?;
    final Map<String, dynamic>? reviewer =
        task['reviewer'] as Map<String, dynamic>?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StitchTheme.border.withAlpha(128)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: StitchTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      deadlineRaw.isEmpty
                          ? '—'
                          : _projectTaskShortDeadline(deadlineRaw),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pri.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: pri.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                projectLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: StitchTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Phòng ban: $departmentName',
                style: const TextStyle(
                  fontSize: 12,
                  color: StitchTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Trạng thái: ${statusLabel(status)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: StitchTheme.textMuted,
                ),
              ),
              if (assignee != null || reviewer != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'Phụ trách: ${(assignee?['name'] ?? '—')}'
                  '${reviewer != null ? ' • Review: ${reviewer['name']}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: StitchTheme.textMuted,
                  ),
                ),
              ],
              if (attachments > 0 || comments > 0) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (attachments > 0)
                      const Icon(
                        Icons.attach_file,
                        size: 16,
                        color: StitchTheme.textSubtle,
                      ),
                    if (attachments > 0) const SizedBox(width: 4),
                    if (comments > 0) ...<Widget>[
                      const Icon(
                        Icons.chat_bubble_outlined,
                        size: 16,
                        color: StitchTheme.textSubtle,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$comments',
                        style: const TextStyle(
                          fontSize: 12,
                          color: StitchTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (deadlineRaw.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'Hạn: ${formatDate(deadlineRaw)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: StitchTheme.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'Tiến độ',
                    style: TextStyle(
                      fontSize: 12,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                  Text(
                    '$progress%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 100) / 100,
                  minHeight: 6,
                  color: StitchTheme.progressPercentFillColor(progress),
                  backgroundColor: StitchTheme.surfaceAlt,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Chi tiết'),
                    ),
                    if (canManage && onEdit != null)
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Sửa'),
                      ),
                    if (canManage && onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Xóa'),
                        style: TextButton.styleFrom(
                          foregroundColor: StitchTheme.danger,
                        ),
                      ),
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

class _GscMetricCard extends StatelessWidget {
  const _GscMetricCard({
    required this.label,
    required this.value,
    this.subLabel,
    this.positive,
  });

  final String label;
  final String value;
  final String? subLabel;
  final bool? positive;

  @override
  Widget build(BuildContext context) {
    Color subColor = StitchTheme.textMuted;
    if (positive != null) {
      subColor = positive == true ? StitchTheme.success : StitchTheme.danger;
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
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
            label,
            style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if ((subLabel ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(subLabel!, style: TextStyle(color: subColor, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

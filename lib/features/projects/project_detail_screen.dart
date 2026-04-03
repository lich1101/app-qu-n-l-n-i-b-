import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';
import '../tasks/task_detail_screen.dart';

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

  Future<void> _ensureDepartmentsLoaded() async {
    if (departments.isNotEmpty) return;
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getDepartments(widget.token);
    if (!mounted) return;
    setState(() => departments = rows);
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

  Future<void> _openTaskSheet({Map<String, dynamic>? editingTask}) async {
    if (!_canManageProjectTasks) return;
    await _ensureDepartmentsLoaded();
    if (!mounted) return;

    final bool isEdit = editingTask != null;
    final TextEditingController titleCtrl = TextEditingController(
      text: isEdit ? (editingTask['title'] ?? '').toString() : '',
    );
    final TextEditingController descCtrl = TextEditingController(
      text: isEdit ? (editingTask['description'] ?? '').toString() : '',
    );
    final TextEditingController startCtrl = TextEditingController(
      text:
          isEdit
              ? _toDateInput(editingTask['start_at'])
              : _toDateInput(project?['start_date']),
    );
    final TextEditingController deadlineCtrl = TextEditingController(
      text:
          isEdit
              ? _toDateInput(editingTask['deadline'])
              : _toDateInput(project?['deadline']),
    );
    final TextEditingController weightCtrl = TextEditingController(
      text:
          isEdit
              ? '${editingTask['weight_percent'] ?? 0}'
              : '${math.max(1, 100 - tasks.fold<int>(0, (int sum, Map<String, dynamic> row) => sum + _toInt(row['weight_percent'])))}',
    );

    int? departmentId = _toId(editingTask?['department_id']);
    int? assigneeId = _toId(editingTask?['assignee_id']);
    String status = (editingTask?['status'] ?? 'todo').toString();
    String priority = (editingTask?['priority'] ?? 'medium').toString();
    bool submitting = false;
    String localMessage = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext sheetContext, StateSetter setModalState) {
            final List<Map<String, dynamic>> staffOptions =
                <Map<String, dynamic>>[
                  for (final Map<String, dynamic> department in departments)
                    if (departmentId == null ||
                        _toId(department['id']) == departmentId)
                      ...((department['staff'] as List<dynamic>? ?? <dynamic>[])
                          .whereType<Map>()
                          .map((Map row) => row.cast<String, dynamic>())),
                ];

            Future<void> submit() async {
              if (titleCtrl.text.trim().isEmpty) {
                setModalState(
                  () => localMessage = 'Vui lòng nhập tiêu đề công việc.',
                );
                return;
              }
              final int? weight = int.tryParse(weightCtrl.text.trim());
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
                      ? await widget.apiService.updateTask(
                        widget.token,
                        _toId(editingTask['id']),
                        projectId: widget.projectId,
                        departmentId: departmentId,
                        assigneeId: assigneeId,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        priority: priority,
                        status: status,
                        startAt:
                            startCtrl.text.trim().isEmpty
                                ? null
                                : startCtrl.text.trim(),
                        deadline:
                            deadlineCtrl.text.trim().isEmpty
                                ? null
                                : deadlineCtrl.text.trim(),
                        weightPercent: weight,
                      )
                      : await widget.apiService.createTask(
                        widget.token,
                        projectId: widget.projectId,
                        departmentId: departmentId,
                        assigneeId: assigneeId,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        priority: priority,
                        status: status,
                        deadline:
                            deadlineCtrl.text.trim().isEmpty
                                ? null
                                : deadlineCtrl.text.trim(),
                        weightPercent: weight,
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
                          ? 'Đã cập nhật công việc.'
                          : 'Đã tạo công việc mới trong dự án.',
                    ),
                  ),
                );
              } else {
                setModalState(() {
                  submitting = false;
                  localMessage =
                      isEdit
                          ? 'Cập nhật công việc thất bại.'
                          : 'Tạo công việc thất bại.';
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
                      isEdit ? 'Sửa công việc' : 'Thêm công việc mới',
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
                    TextField(
                      controller: weightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tỷ trọng (%)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: departmentId == 0 ? null : departmentId,
                      decoration: const InputDecoration(labelText: 'Phòng ban'),
                      items:
                          departments
                              .map(
                                (Map<String, dynamic> d) =>
                                    DropdownMenuItem<int>(
                                      value: _toId(d['id']),
                                      child: Text(
                                        (d['name'] ?? 'Phòng ban').toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                              )
                              .toList(),
                      onChanged:
                          (int? value) => setModalState(() {
                            departmentId = value;
                            assigneeId = null;
                          }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: assigneeId == 0 ? null : assigneeId,
                      decoration: const InputDecoration(
                        labelText: 'Nhân sự phụ trách',
                      ),
                      items:
                          staffOptions
                              .map(
                                (Map<String, dynamic> user) =>
                                    DropdownMenuItem<int>(
                                      value: _toId(user['id']),
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
                                  : (isEdit ? 'Lưu thay đổi' : 'Tạo công việc'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Đã xóa công việc.' : 'Không thể xóa công việc.'),
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(okMessage)));
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
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _formatShortDate(String raw) {
    if (raw.isEmpty) return '—';
    if (raw.length >= 10) {
      return raw.substring(5, 10);
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã gửi duyệt bàn giao dự án.'
              : 'Gửi duyệt bàn giao thất bại. Kiểm tra tiến độ tối thiểu hoặc quyền thao tác.',
        ),
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Đã xử lý phiếu bàn giao.' : 'Xử lý thất bại. Vui lòng thử lại.',
        ),
      ),
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
      appBar: AppBar(title: const Text('Chi tiết dự án')),
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
                          final String title =
                              (task['title'] ?? 'Công việc').toString();
                          final String status =
                              (task['status'] ?? '').toString();
                          final int progress =
                              (task['progress_percent'] ?? 0) is int
                                  ? task['progress_percent'] as int
                                  : int.tryParse(
                                        '${task['progress_percent'] ?? 0}',
                                      ) ??
                                      0;
                          final String deadline =
                              (task['deadline'] ?? '').toString();
                          return InkWell(
                            onTap: () {
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
                            child: Container(
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
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      if (_canManageProjectTasks)
                                        PopupMenuButton<String>(
                                          tooltip: 'Quản lý công việc',
                                          onSelected: (String value) {
                                            if (value == 'edit') {
                                              _openTaskSheet(editingTask: task);
                                              return;
                                            }
                                            if (value == 'delete') {
                                              _deleteTask(task);
                                            }
                                          },
                                          itemBuilder:
                                              (BuildContext context) => const <
                                                PopupMenuEntry<String>
                                              >[
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
                                  const SizedBox(height: 6),
                                  Text(
                                    'Trạng thái: ${_statusLabel(status)} • Tiến độ: $progress%',
                                    style: const TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (deadline.isNotEmpty)
                                    Text(
                                      'Deadline: ${_formatDate(deadline)}',
                                      style: const TextStyle(
                                        color: StitchTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
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

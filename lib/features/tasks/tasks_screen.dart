import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_env.dart';
import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.tasks,
    required this.statuses,
    required this.currentFilter,
    required this.loading,
    required this.message,
    required this.isAuthenticated,
    required this.onRefresh,
    required this.onUpdateStatus,
    required this.token,
    required this.apiService,
    required this.currentUserRole,
    required this.currentUserId,
  });

  final List<Map<String, dynamic>> tasks;
  final List<String> statuses;
  final String currentFilter;
  final bool loading;
  final String message;
  final bool isAuthenticated;
  final Future<void> Function({String? status, bool silent}) onRefresh;
  final Future<void> Function(Map<String, dynamic> task, String newStatus)
      onUpdateStatus;
  final String? token;
  final MobileApiService apiService;
  final String currentUserRole;
  final int? currentUserId;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _viewMode = 'board';

  String _prettyStatus(String status) {
    if (status.trim().isEmpty) return 'Tất cả';
    const Map<String, String> labels = <String, String>{
      'todo': 'Cần làm',
      'doing': 'Đang làm',
      'done': 'Hoàn tất',
      'blocked': 'Bị chặn',
    };
    if (labels.containsKey(status)) {
      return labels[status]!;
    }
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((String part) =>
            part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'todo':
        return Icons.list_alt;
      case 'doing':
        return Icons.sync;
      case 'done':
        return Icons.verified;
      case 'blocked':
        return Icons.pause_circle_filled;
      default:
        return Icons.circle_outlined;
    }
  }

  bool get _canManageReminders {
    return <String>['admin', 'quan_ly']
        .contains(widget.currentUserRole);
  }

  bool get _canUpdateStatus {
    return <String>['admin', 'quan_ly'].contains(widget.currentUserRole);
  }

  bool get _canImportTasks {
    return <String>['admin', 'quan_ly'].contains(widget.currentUserRole);
  }

  bool get _canCreateTask {
    return <String>['admin', 'quan_ly'].contains(widget.currentUserRole);
  }

  String _fmtDateTime(DateTime date, TimeOfDay time) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    final String hh = time.hour.toString().padLeft(2, '0');
    final String mm = time.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:00';
  }

  Future<void> _importTasks() async {
    if (!_canImportTasks || widget.token == null) return;
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xls', 'xlsx', 'csv'],
    );
    if (result == null || result.files.single.path == null) return;
    final File file = File(result.files.single.path!);
    final Map<String, dynamic> report =
        await widget.apiService.importTasks(widget.token!, file);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          report['error'] != null
              ? 'Import thất bại.'
              : 'Import hoàn tất: ${(report['created'] ?? 0)} tạo mới.',
        ),
      ),
    );
    await widget.onRefresh(status: widget.currentFilter, silent: true);
  }

  Future<void> _openCreateTaskModal() async {
    if (!_canCreateTask || widget.token == null || widget.token!.isEmpty) {
      return;
    }
    final String token = widget.token!;

    List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> departments = <Map<String, dynamic>>[];
    try {
      projects = await widget.apiService.getProjects(token, perPage: 200);
      departments = await widget.apiService.getDepartments(token);
      if (widget.currentUserRole == 'quan_ly' &&
          widget.currentUserId != null) {
        departments = departments
            .where((dynamic d) =>
                '${(d as Map<String, dynamic>)['manager_id'] ?? ''}' ==
                '${widget.currentUserId}')
            .toList();
      }
    } catch (_) {
      // handled in UI below
    }
    if (!mounted) return;

    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    final TextEditingController deadlineCtrl = TextEditingController();
    final TextEditingController progressCtrl =
        TextEditingController(text: '0');
    int? projectId;
    int? departmentId;
    int? assigneeId;
    String priority = 'medium';
    String status =
        widget.statuses.isNotEmpty ? widget.statuses.first : 'todo';
    bool submitting = false;
    String localMessage = '';

    Future<void> pickDeadline(StateSetter setSheetState) async {
      final DateTime now = DateTime.now();
      final DateTime? picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 5),
        initialDate: now,
      );
      if (picked == null) return;
      setSheetState(() {
        deadlineCtrl.text = '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final double bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            final Map<String, dynamic>? selectedProject = projectId == null
                ? null
                : projects.firstWhere(
                    (Map<String, dynamic> p) => p['id'] == projectId,
                    orElse: () => <String, dynamic>{},
                  );
            final bool hasContract =
                selectedProject != null && selectedProject['contract_id'] != null;

            List<Map<String, dynamic>> staffOptions = <Map<String, dynamic>>[];
            if (departmentId != null) {
              final Map<String, dynamic>? dept = departments.firstWhere(
                (Map<String, dynamic> d) => d['id'] == departmentId,
                orElse: () => <String, dynamic>{},
              );
              final List<dynamic> staff =
                  (dept?['staff'] ?? <dynamic>[]) as List<dynamic>;
              staffOptions = staff
                  .map((dynamic e) => e as Map<String, dynamic>)
                  .toList();
            }

            Future<void> submit() async {
              final String title = titleCtrl.text.trim();
              if (projectId == null) {
                setSheetState(() => localMessage = 'Vui lòng chọn dự án.');
                return;
              }
              if (!hasContract) {
                setSheetState(() => localMessage =
                    'Dự án chưa có hợp đồng, không thể tạo công việc.');
                return;
              }
              if (departmentId == null) {
                setSheetState(() => localMessage = 'Vui lòng chọn phòng ban.');
                return;
              }
              if (title.isEmpty) {
                setSheetState(() => localMessage = 'Vui lòng nhập tiêu đề.');
                return;
              }
              if (assigneeId == null) {
                setSheetState(() => localMessage =
                    'Vui lòng chọn nhân sự phụ trách.');
                return;
              }
              final int? progress = progressCtrl.text.trim().isEmpty
                  ? null
                  : int.tryParse(progressCtrl.text.trim());
              if (progress != null && (progress < 0 || progress > 100)) {
                setSheetState(
                    () => localMessage = 'Tiến độ phải từ 0 đến 100.');
                return;
              }
              setSheetState(() {
                submitting = true;
                localMessage = '';
              });
              final bool ok = await widget.apiService.createTask(
                token,
                projectId: projectId!,
                departmentId: departmentId,
                assigneeId: assigneeId,
                title: title,
                description: descCtrl.text.trim(),
                priority: priority,
                status: status,
                deadline:
                    deadlineCtrl.text.trim().isEmpty ? null : deadlineCtrl.text,
                progressPercent: progress,
              );
              if (!mounted) return;
              if (ok) {
                Navigator.of(ctx).pop();
                await widget.onRefresh(
                  status: widget.currentFilter,
                  silent: true,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã tạo công việc mới.')),
                  );
                }
              } else {
                setSheetState(() {
                  submitting = false;
                  localMessage = 'Tạo công việc thất bại.';
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
                    const Text(
                      'Thêm công việc mới',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    if (localMessage.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        localMessage,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: projectId,
                      items: projects
                          .map(
                            (Map<String, dynamic> p) => DropdownMenuItem<int>(
                              value: p['id'] as int?,
                              child: Text(
                                (p['name'] ?? 'Dự án').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) =>
                          setSheetState(() => projectId = v),
                      decoration: const InputDecoration(
                        labelText: 'Dự án',
                      ),
                    ),
                    if (selectedProject != null && !hasContract)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Dự án chưa có hợp đồng, cần thêm hợp đồng trước.',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: departmentId,
                      items: departments
                          .map(
                            (Map<String, dynamic> d) => DropdownMenuItem<int>(
                              value: d['id'] as int?,
                              child: Text(
                                (d['name'] ?? 'Phòng ban').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) {
                        setSheetState(() {
                          departmentId = v;
                          assigneeId = null;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Phòng ban',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: assigneeId,
                      items: staffOptions
                          .map(
                            (Map<String, dynamic> s) => DropdownMenuItem<int>(
                              value: s['id'] as int?,
                              child: Text(
                                (s['name'] ?? s['email'] ?? 'Nhân sự').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) => setSheetState(() => assigneeId = v),
                      decoration: const InputDecoration(
                        labelText: 'Nhân sự phụ trách',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: priority,
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(value: 'low', child: Text('Thấp')),
                              DropdownMenuItem(
                                  value: 'medium', child: Text('Trung bình')),
                              DropdownMenuItem(value: 'high', child: Text('Cao')),
                              DropdownMenuItem(
                                  value: 'urgent', child: Text('Khẩn cấp')),
                            ],
                            onChanged: (String? v) =>
                                setSheetState(() => priority = v ?? 'medium'),
                            decoration: const InputDecoration(labelText: 'Ưu tiên'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: status,
                            items: widget.statuses
                                .map(
                                  (String s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(_prettyStatus(s)),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? v) =>
                                setSheetState(() => status = v ?? status),
                            decoration:
                                const InputDecoration(labelText: 'Trạng thái'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: deadlineCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Hạn hoàn tất',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            onTap: () => pickDeadline(setSheetState),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: progressCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tiến độ (%)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                            child: Text(submitting ? 'Đang tạo...' : 'Tạo công việc'),
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

    titleCtrl.dispose();
    descCtrl.dispose();
    deadlineCtrl.dispose();
    progressCtrl.dispose();
  }

  String _shortDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Chưa có hạn';
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final DateTime local = parsed.toLocal();
    final DateTime now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Hôm nay';
    }
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
  }

  _PriorityStyle _priorityStyle(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'urgent':
        return const _PriorityStyle(
          label: 'Khẩn cấp',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFDC2626),
          icon: Icons.error,
        );
      case 'high':
        return const _PriorityStyle(
          label: 'Cao',
          background: Color(0xFFFFEDD5),
          foreground: Color(0xFFEA580C),
          icon: Icons.flag,
        );
      case 'low':
        return const _PriorityStyle(
          label: 'Thấp',
          background: Color(0xFFF1F5F9),
          foreground: Color(0xFF475569),
          icon: Icons.circle,
        );
      default:
        return _PriorityStyle(
          label: 'Trung bình',
          background: StitchTheme.primarySoft,
          foreground: StitchTheme.primary,
          icon: Icons.adjust,
        );
    }
  }

  Future<void> _openTaskCenter(Map<String, dynamic> task) async {
    final int taskId = (task['id'] ?? 0) as int;
    final String? token = widget.token;
    if (taskId <= 0 || token == null || token.isEmpty) return;

    final TextEditingController commentCtrl = TextEditingController();
    final TextEditingController commentTagCtrl = TextEditingController();
    final TextEditingController commentAttachmentCtrl = TextEditingController();
    final TextEditingController attachTitleCtrl = TextEditingController();
    final TextEditingController attachUrlCtrl = TextEditingController();
    final TextEditingController attachFileCtrl = TextEditingController();
    final TextEditingController reminderAtCtrl = TextEditingController();
    String reminderChannel = 'in_app';
    String reminderTrigger = 'custom';
    int? editingReminderId;

    List<Map<String, dynamic>> comments = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> attachments = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> reminders = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> taskItems = <Map<String, dynamic>>[];
    bool loading = true;
    String localMessage = '';
    bool showCommentOptions = false;
    final bool isTaskDone = (task['status'] ?? '').toString() == 'done';
    final bool canReview = <String>['admin', 'quan_ly']
        .contains(widget.currentUserRole);

    Future<void> refresh(StateSetter setSheetState) async {
      setSheetState(() => loading = true);
      final List<Map<String, dynamic>> c =
          await widget.apiService.getTaskComments(token, taskId);
      final List<Map<String, dynamic>> a =
          await widget.apiService.getTaskAttachments(token, taskId);
      final List<Map<String, dynamic>> r =
          await widget.apiService.getTaskReminders(token, taskId);
      final List<Map<String, dynamic>> items =
          await widget.apiService.getTaskItems(token, taskId);
      setSheetState(() {
        comments = c;
        attachments = a;
        reminders = r;
        taskItems = items;
        loading = false;
      });
    }

    String formatDeadline(String? raw) {
      if (raw == null || raw.isEmpty) return 'Chưa có hạn';
      final DateTime? date = DateTime.tryParse(raw);
      if (date == null) return raw;
      final DateTime local = date.toLocal();
      return '${local.day.toString().padLeft(2, '0')} Th${local.month} ${local.year}';
    }

    String formatDateTime(String? raw) {
      if (raw == null || raw.isEmpty) return 'Chưa xác nhận';
      final DateTime? date = DateTime.tryParse(raw);
      if (date == null) return raw;
      final DateTime local = date.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')} '
          '${local.day.toString().padLeft(2, '0')}/'
          '${local.month.toString().padLeft(2, '0')}/${local.year}';
    }

    Future<void> pickFile(
      TextEditingController controller,
      StateSetter setSheetState,
    ) async {
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles();
      final String? path = result?.files.single.path;
      if (path != null) {
        setSheetState(() => controller.text = path);
      }
    }

    Future<void> openItemReportModal(
      StateSetter setSheetState,
      Map<String, dynamic> item,
    ) async {
      final TextEditingController noteCtrl = TextEditingController();
      final TextEditingController progressCtrl = TextEditingController();
      String statusValue = '';
      File? attachFile;
      String localMessage = '';
      bool submitting = false;

      await showModalBottomSheet(
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
                  setModalState(() => attachFile = File(path));
                }
              }

              Future<void> submit() async {
                if (submitting) return;
                if (noteCtrl.text.trim().isEmpty &&
                    progressCtrl.text.trim().isEmpty &&
                    statusValue.isEmpty &&
                    attachFile == null) {
                  setModalState(() => localMessage =
                      'Vui lòng nhập nội dung hoặc đính kèm.');
                  return;
                }
                final int? progress = progressCtrl.text.trim().isEmpty
                    ? null
                    : int.tryParse(progressCtrl.text.trim());
                if (progress != null && (progress < 0 || progress > 100)) {
                  setModalState(() =>
                      localMessage = 'Tiến độ phải từ 0 đến 100.');
                  return;
                }
                setModalState(() {
                  submitting = true;
                  localMessage = '';
                });
                final bool ok = await widget.apiService.createTaskItemUpdate(
                  token,
                  taskId,
                  (item['id'] ?? 0) as int,
                  status: statusValue.isEmpty ? null : statusValue,
                  progressPercent: progress,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                  attachment: attachFile,
                );
                if (!mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                  await refresh(setSheetState);
                } else {
                  setModalState(() {
                    submitting = false;
                    localMessage = 'Gửi báo cáo thất bại.';
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
                        'Báo cáo đầu việc: ${(item['title'] ?? 'Đầu việc').toString()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (localMessage.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(localMessage,
                            style: const TextStyle(color: Colors.redAccent)),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: statusValue.isEmpty ? null : statusValue,
                        items: widget.statuses
                            .map(
                              (String s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(_prettyStatus(s)),
                              ),
                            )
                            .toList(),
                        onChanged: (String? v) =>
                            setModalState(() => statusValue = v ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái (tuỳ chọn)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: progressCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tiến độ (%)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Nội dung báo cáo'),
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
                          if (attachFile != null)
                            Expanded(
                              child: Text(
                                attachFile!.path.split('/').last,
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child:
                                  Text(submitting ? 'Đang gửi...' : 'Gửi báo cáo'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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

    Future<void> openItemReviewModal(
      StateSetter setSheetState,
      Map<String, dynamic> item,
    ) async {
      final int itemId = (item['id'] ?? 0) as int;
      if (itemId <= 0) return;
      List<Map<String, dynamic>> updates = <Map<String, dynamic>>[];
      bool loadingUpdates = true;
      String localMessage = '';
      String reviewLabel(String value) {
        switch (value) {
          case 'approved':
            return 'Đã duyệt';
          case 'rejected':
            return 'Từ chối';
          case 'pending':
          default:
            return 'Chờ duyệt';
        }
      }

      Future<void> fetchUpdates(StateSetter setModalState) async {
        setModalState(() => loadingUpdates = true);
        updates = await widget.apiService.getTaskItemUpdates(
          token,
          taskId,
          itemId,
        );
        setModalState(() => loadingUpdates = false);
      }

      Future<void> approveUpdate(
        StateSetter setModalState,
        Map<String, dynamic> update,
      ) async {
        final int updateId = (update['id'] ?? 0) as int;
        if (updateId <= 0) return;
        final bool ok = await widget.apiService.approveTaskItemUpdate(
          token,
          taskId,
          itemId,
          updateId,
        );
        setModalState(() {
          localMessage = ok ? 'Đã duyệt báo cáo.' : 'Duyệt báo cáo thất bại.';
        });
        await fetchUpdates(setModalState);
        await refresh(setSheetState);
      }

      Future<void> rejectUpdate(
        StateSetter setModalState,
        Map<String, dynamic> update,
      ) async {
        final int updateId = (update['id'] ?? 0) as int;
        if (updateId <= 0) return;
        final TextEditingController reasonCtrl = TextEditingController();
        final bool? confirmReject = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Từ chối báo cáo'),
              content: TextField(
                controller: reasonCtrl,
                decoration:
                    const InputDecoration(labelText: 'Lý do từ chối'),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Từ chối'),
                ),
              ],
            );
          },
        );
        if (confirmReject != true) {
          reasonCtrl.dispose();
          return;
        }
        final String reason = reasonCtrl.text.trim();
        reasonCtrl.dispose();
        if (reason.isEmpty) {
          setModalState(() => localMessage = 'Vui lòng nhập lý do từ chối.');
          return;
        }
        final bool ok = await widget.apiService.rejectTaskItemUpdate(
          token,
          taskId,
          itemId,
          updateId,
          reviewNote: reason,
        );
        setModalState(() {
          localMessage = ok ? 'Đã từ chối báo cáo.' : 'Từ chối thất bại.';
        });
        await fetchUpdates(setModalState);
        await refresh(setSheetState);
      }

      Future<void> editAndApprove(
        StateSetter setModalState,
        Map<String, dynamic> update,
      ) async {
        final int updateId = (update['id'] ?? 0) as int;
        if (updateId <= 0) return;
        final TextEditingController noteCtrl = TextEditingController(
          text: (update['note'] ?? '').toString(),
        );
        final TextEditingController progressCtrl = TextEditingController(
          text: (update['progress_percent'] ?? '').toString(),
        );
        String statusValue = (update['status'] ?? '').toString();

        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Sửa & duyệt báo cáo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: statusValue.isEmpty ? null : statusValue,
                    items: widget.statuses
                        .map(
                          (String s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(_prettyStatus(s)),
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) => statusValue = v ?? '',
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: progressCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Tiến độ (%)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Ghi chú'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Duyệt'),
                ),
              ],
            );
          },
        );

        if (confirm != true) {
          noteCtrl.dispose();
          progressCtrl.dispose();
          return;
        }
        final int? progress = progressCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(progressCtrl.text.trim());
        final bool ok = await widget.apiService.approveTaskItemUpdate(
          token,
          taskId,
          itemId,
          updateId,
          status: statusValue.isEmpty ? null : statusValue,
          progressPercent: progress,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );
        noteCtrl.dispose();
        progressCtrl.dispose();
        setModalState(() {
          localMessage = ok ? 'Đã duyệt báo cáo.' : 'Duyệt báo cáo thất bại.';
        });
        await fetchUpdates(setModalState);
        await refresh(setSheetState);
      }

      await showModalBottomSheet(
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
              return Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Duyệt báo cáo: ${(item['title'] ?? 'Đầu việc').toString()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (localMessage.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(localMessage,
                          style: const TextStyle(color: StitchTheme.textMuted)),
                    ],
                    const SizedBox(height: 12),
                    if (loadingUpdates)
                      const Center(child: CircularProgressIndicator())
                    else if (updates.isEmpty)
                      const Text(
                        'Chưa có báo cáo nào.',
                        style: TextStyle(color: StitchTheme.textMuted),
                      )
                    else
                      ...updates.map(
                        (Map<String, dynamic> u) {
                          final String reviewStatus =
                              (u['review_status'] ?? 'pending').toString();
                          final bool pending = reviewStatus == 'pending';
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
                                  u['note']?.toString().isNotEmpty == true
                                      ? u['note'].toString()
                                      : 'Không có ghi chú',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Trạng thái: ${u['status'] ?? '—'} • Tiến độ: ${u['progress_percent'] ?? '—'}%',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Duyệt: ${reviewLabel(reviewStatus)}',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                if ((u['review_note'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Lý do: ${u['review_note']}',
                                      style: const TextStyle(
                                        color: StitchTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if ((u['attachment_path'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'File: ${(u['attachment_path'] ?? '').toString()}',
                                      style: const TextStyle(
                                        color: StitchTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (pending)
                                  Row(
                                    children: <Widget>[
                                      OutlinedButton(
                                        onPressed: () =>
                                            editAndApprove(setModalState, u),
                                        child: const Text('Sửa & duyệt'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () =>
                                            approveUpdate(setModalState, u),
                                        child: const Text('Duyệt'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () =>
                                            rejectUpdate(setModalState, u),
                                        child: const Text('Từ chối'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ).toList(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Đóng'),
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

    Future<void> openCreateItemModal(StateSetter setSheetState) async {
      if (!canReview) return;
      int? taskDeptId;
      final dynamic rawDeptId = task['department_id'];
      if (rawDeptId is int) {
        taskDeptId = rawDeptId;
      } else if (rawDeptId is String && rawDeptId.trim().isNotEmpty) {
        taskDeptId = int.tryParse(rawDeptId.trim());
      }
      List<Map<String, dynamic>> departments =
          await widget.apiService.getDepartments(token);
      if (widget.currentUserRole == 'quan_ly' && widget.currentUserId != null) {
        departments = departments
            .where((dynamic d) =>
                '${(d as Map<String, dynamic>)['manager_id'] ?? ''}' ==
                '${widget.currentUserId}')
            .toList();
      }
      int? departmentId = taskDeptId;

      final TextEditingController titleCtrl = TextEditingController();
      final TextEditingController descCtrl = TextEditingController();
      final TextEditingController deadlineCtrl = TextEditingController();
      final TextEditingController progressCtrl =
          TextEditingController(text: '0');
      int? assigneeId;
      String priority = 'medium';
      String status = widget.statuses.isNotEmpty
          ? widget.statuses.first
          : 'todo';
      bool submitting = false;
      String localMsg = '';

      Future<void> pickDeadline(StateSetter setModalState) async {
        final DateTime now = DateTime.now();
        final DateTime? picked = await showDatePicker(
          context: context,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 5),
          initialDate: now,
        );
        if (picked == null) return;
        setModalState(() {
          deadlineCtrl.text = '${picked.year.toString().padLeft(4, '0')}-'
              '${picked.month.toString().padLeft(2, '0')}-'
              '${picked.day.toString().padLeft(2, '0')}';
        });
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext ctx) {
          final double bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return StatefulBuilder(
            builder: (BuildContext ctx, StateSetter setModalState) {
              Map<String, dynamic>? selectedDept;
              if (departmentId != null) {
                selectedDept = departments.firstWhere(
                  (Map<String, dynamic> d) =>
                      '${d['id'] ?? ''}' == '$departmentId',
                  orElse: () => <String, dynamic>{},
                );
              }
              List<Map<String, dynamic>> staffOptions = <Map<String, dynamic>>[];
              if (selectedDept != null && selectedDept.isNotEmpty) {
                staffOptions = ((selectedDept['staff'] ?? <dynamic>[]) as List<dynamic>)
                    .map((dynamic e) => e as Map<String, dynamic>)
                    .toList();
              }
              if (staffOptions.isEmpty && departmentId == null && departments.isNotEmpty) {
                staffOptions = departments
                    .expand((Map<String, dynamic> d) => (d['staff'] ?? <dynamic>[]) as List<dynamic>)
                    .map((dynamic e) => e as Map<String, dynamic>)
                    .toList();
              }

              Future<void> submit() async {
                if (submitting) return;
                if (titleCtrl.text.trim().isEmpty) {
                  setModalState(() => localMsg = 'Vui lòng nhập tiêu đề.');
                  return;
                }
                if (assigneeId == null) {
                  setModalState(
                      () => localMsg = 'Vui lòng chọn nhân sự phụ trách.');
                  return;
                }
                final int? progress = progressCtrl.text.trim().isEmpty
                    ? null
                    : int.tryParse(progressCtrl.text.trim());
                if (progress != null && (progress < 0 || progress > 100)) {
                  setModalState(() =>
                      localMsg = 'Tiến độ phải từ 0 đến 100.');
                  return;
                }
                setModalState(() {
                  submitting = true;
                  localMsg = '';
                });
                final bool ok = await widget.apiService.createTaskItem(
                  token,
                  taskId,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  priority: priority,
                  status: status,
                  progressPercent: progress,
                  deadline:
                      deadlineCtrl.text.trim().isEmpty ? null : deadlineCtrl.text,
                  assigneeId: assigneeId,
                );
                if (!mounted) return;
                if (ok) {
                  Navigator.of(ctx).pop();
                  await refresh(setSheetState);
                } else {
                  setModalState(() {
                    submitting = false;
                    localMsg = 'Tạo đầu việc thất bại.';
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
                      const Text(
                        'Thêm đầu việc',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (localMsg.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(localMsg,
                            style: const TextStyle(color: Colors.redAccent)),
                      ],
                      const SizedBox(height: 12),
                      if (taskDeptId == null) ...<Widget>[
                        DropdownButtonFormField<int>(
                          value: departmentId,
                          items: departments
                              .map(
                                (Map<String, dynamic> d) =>
                                    DropdownMenuItem<int>(
                                  value: d['id'] as int?,
                                  child: Text(
                                    (d['name'] ?? 'Phòng ban').toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (int? v) => setModalState(() {
                            departmentId = v;
                            assigneeId = null;
                          }),
                          decoration: const InputDecoration(
                            labelText: 'Chọn phòng ban',
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      DropdownButtonFormField<int>(
                        value: assigneeId,
                        items: staffOptions
                            .map(
                              (Map<String, dynamic> s) =>
                                  DropdownMenuItem<int>(
                                value: s['id'] as int?,
                                child: Text(
                                  (s['name'] ?? s['email'] ?? 'Nhân sự')
                                      .toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (int? v) =>
                            setModalState(() => assigneeId = v),
                        decoration: const InputDecoration(
                          labelText: 'Nhân sự phụ trách',
                        ),
                      ),
                      if (staffOptions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Chưa có nhân sự trong phòng ban này.',
                            style: TextStyle(
                              color: StitchTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Tiêu đề'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Mô tả'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: priority,
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                    value: 'low', child: Text('Thấp')),
                                DropdownMenuItem(
                                    value: 'medium', child: Text('Trung bình')),
                                DropdownMenuItem(
                                    value: 'high', child: Text('Cao')),
                                DropdownMenuItem(
                                    value: 'urgent', child: Text('Khẩn cấp')),
                              ],
                              onChanged: (String? v) => setModalState(
                                  () => priority = v ?? 'medium'),
                              decoration:
                                  const InputDecoration(labelText: 'Ưu tiên'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: status,
                              items: widget.statuses
                                  .map(
                                    (String s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(_prettyStatus(s)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? v) =>
                                  setModalState(() => status = v ?? status),
                              decoration:
                                  const InputDecoration(labelText: 'Trạng thái'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: deadlineCtrl,
                              readOnly: true,
                              onTap: () => pickDeadline(setModalState),
                              decoration: const InputDecoration(
                                labelText: 'Hạn hoàn tất',
                                suffixIcon: Icon(Icons.calendar_today, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: progressCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Tiến độ (%)',
                              ),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                  submitting ? 'Đang tạo...' : 'Tạo đầu việc'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
      titleCtrl.dispose();
      descCtrl.dispose();
      deadlineCtrl.dispose();
      progressCtrl.dispose();
    }

    Future<void> submitTask(StateSetter setSheetState) async {
      if (! _canUpdateStatus) {
        setSheetState(() {
          localMessage = 'Bạn không có quyền cập nhật trạng thái công việc.';
        });
        return;
      }
      final String? doneStatus =
          widget.statuses.contains('done') ? 'done' : null;
      if (doneStatus == null) {
        setSheetState(() {
          localMessage = 'Không tìm thấy trạng thái hoàn tất để nộp bài.';
        });
        return;
      }
      await widget.onUpdateStatus(task, doneStatus);
      setSheetState(() {
        localMessage = 'Đã cập nhật trạng thái công việc.';
      });
    }

    Future<void> acknowledgeTask(StateSetter setSheetState) async {
      final bool ok = await widget.apiService.acknowledgeTask(token, task);
      setSheetState(() {
        localMessage = ok
            ? 'Đã xác nhận nhận công việc.'
            : 'Xác nhận nhận công việc thất bại.';
      });
      if (ok) await refresh(setSheetState);
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            if (loading &&
                comments.isEmpty &&
                attachments.isEmpty &&
                reminders.isEmpty &&
                taskItems.isEmpty) {
              refresh(setSheetState);
            }
            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.94,
                minChildSize: 0.6,
                maxChildSize: 0.94,
                builder: (BuildContext context, ScrollController controller) {
                  final String title = (task['title'] ?? 'Công việc').toString();
                  final String status =
                      _prettyStatus((task['status'] ?? '').toString());
                  final String projectName =
                      ((task['project'] as Map<String, dynamic>?)?['name'] ?? 'Dự án')
                          .toString();
                  final String priority = (task['priority'] ?? 'medium').toString();
                  final _PriorityStyle priorityStyle = _priorityStyle(priority);
                  return Container(
                    decoration: const BoxDecoration(
                      color: StitchTheme.bg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Row(
                            children: <Widget>[
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.chevron_left, size: 20),
                                label: const Text('Quay lại'),
                              ),
                              const Spacer(),
                              const Text(
                                'Chi tiết Công việc',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.more_horiz),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            children: <Widget>[
                              if (localMessage.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.primarySoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    localMessage,
                                    style: TextStyle(color: StitchTheme.primary),
                                  ),
                                ),
                              if (loading) const LinearProgressIndicator(minHeight: 2),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  _Badge(label: priorityStyle.label, color: priorityStyle.background, textColor: priorityStyle.foreground, icon: priorityStyle.icon),
                                  _Badge(
                                    label: projectName,
                                    color: const Color(0xFFE2E8F0),
                                    textColor: StitchTheme.textMuted,
                                    icon: Icons.folder,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _InfoTile(
                                      icon: Icons.speed,
                                      label: 'Trạng thái',
                                      value: status,
                                      iconColor: StitchTheme.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _InfoTile(
                                      icon: Icons.calendar_month,
                                      label: 'Hạn chót',
                                      value: formatDeadline(
                                        (task['deadline'] ?? '').toString(),
                                      ),
                                      iconColor: StitchTheme.danger,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (task['require_acknowledgement'] == true)
                                _SectionCard(
                                  title: 'Xác nhận nhận công việc',
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Trạng thái: ${formatDateTime((task['acknowledged_at'] ?? '').toString())}',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if ((task['acknowledged_at'] ?? '').toString().isEmpty)
                                        FilledButton(
                                          onPressed: () => acknowledgeTask(setSheetState),
                                          child: const Text('Xác nhận đã nhận công việc'),
                                        ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: 'Mô tả công việc',
                                child: Text(
                                  (task['description'] ??
                                          'Chưa có mô tả chi tiết cho công việc này.')
                                      .toString(),
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: 'Đầu việc',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    if (canReview)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => openCreateItemModal(setSheetState),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Thêm đầu việc'),
                                        ),
                                      ),
                                    if (taskItems.isEmpty)
                                      const Text(
                                        'Chưa có đầu việc nào.',
                                        style: TextStyle(color: StitchTheme.textMuted),
                                      )
                                    else
                                      ...taskItems.map((Map<String, dynamic> item) {
                                        final String itemTitle =
                                            (item['title'] ?? 'Đầu việc').toString();
                                        final String itemStatus = _prettyStatus(
                                            (item['status'] ?? 'todo').toString());
                                        final int progress =
                                            item['progress_percent'] is int
                                                ? item['progress_percent'] as int
                                                : int.tryParse(
                                                        '${item['progress_percent'] ?? 0}') ??
                                                    0;
                                        final Map<String, dynamic>? assignee =
                                            item['assignee'] as Map<String, dynamic>?;
                                        final String assigneeName =
                                            (assignee?['name'] ??
                                                    assignee?['email'] ??
                                                    'Chưa phân công')
                                                .toString();
                                        final bool isItemAssignee =
                                            widget.currentUserId != null &&
                                                '${item['assignee_id'] ?? ''}' ==
                                                    '${widget.currentUserId}';
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: StitchTheme.border),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    child: Text(
                                                      itemTitle,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: StitchTheme.primarySoft,
                                                      borderRadius:
                                                          BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      itemStatus,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: StitchTheme.primary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Phụ trách: $assigneeName',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: StitchTheme.textMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Tiến độ: $progress%',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: StitchTheme.textMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: <Widget>[
                                                  if (isItemAssignee)
                                                    FilledButton(
                                                      onPressed: () =>
                                                          openItemReportModal(setSheetState, item),
                                                      child: const Text('Báo cáo'),
                                                    ),
                                                  if (canReview) ...<Widget>[
                                                    const SizedBox(width: 8),
                                                    OutlinedButton(
                                                      onPressed: () =>
                                                          openItemReviewModal(setSheetState, item),
                                                      child:
                                                          const Text('Duyệt báo cáo'),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tài liệu đính kèm',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              if (attachments.isEmpty)
                                const Text(
                                  'Chưa có tài liệu đính kèm.',
                                  style: TextStyle(color: StitchTheme.textMuted),
                                )
                              else
                                ...attachments.map(
                                  (Map<String, dynamic> a) => _AttachmentTile(
                                    title: (a['title'] ?? a['type'] ?? 'Tài liệu').toString(),
                                    subtitle: (a['external_url'] ?? a['file_path'] ?? '').toString(),
                                    icon: _attachmentIcon((a['type'] ?? '').toString()),
                                    onDelete: () async {
                                      final bool ok = await widget.apiService
                                          .deleteTaskAttachment(
                                        token,
                                        taskId,
                                        (a['id'] ?? 0) as int,
                                      );
                                      setSheetState(() {
                                        localMessage = ok
                                            ? 'Đã xoá tài liệu đính kèm.'
                                            : 'Xoá tài liệu thất bại.';
                                      });
                                      await refresh(setSheetState);
                                    },
                                  ),
                                ),
                              const SizedBox(height: 12),
                              ExpansionTile(
                                title: const Text('Thêm tài liệu'),
                                childrenPadding: const EdgeInsets.only(bottom: 12),
                                children: <Widget>[
                                  TextField(
                                    controller: attachTitleCtrl,
                                    decoration: const InputDecoration(labelText: 'Tiêu đề'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: attachUrlCtrl,
                                    decoration: const InputDecoration(labelText: 'Liên kết tài liệu'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: attachFileCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Đường dẫn tệp nội bộ',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => pickFile(attachFileCtrl, setSheetState),
                                    icon: const Icon(Icons.attach_file, size: 18),
                                    label: const Text('Chọn file'),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton(
                                    onPressed: () async {
                                      final String link = attachUrlCtrl.text.trim();
                                      final String filePath =
                                          attachFileCtrl.text.trim();
                                      if (link.isEmpty && filePath.isEmpty) {
                                        setSheetState(() {
                                          localMessage =
                                              'Vui lòng nhập liên kết hoặc chọn file.';
                                        });
                                        return;
                                      }
                                      final String effectiveType =
                                          filePath.isNotEmpty ? 'file' : 'link';
                                      final bool ok = await widget.apiService
                                          .createTaskAttachment(
                                        token,
                                        taskId,
                                        type: effectiveType,
                                        title: attachTitleCtrl.text.trim().isEmpty
                                            ? null
                                            : attachTitleCtrl.text.trim(),
                                        externalUrl: link.isEmpty ? null : link,
                                        filePath: filePath.isEmpty ? null : filePath,
                                        isHandover: true,
                                      );
                                      setSheetState(() {
                                        localMessage = ok
                                            ? 'Đã thêm tài liệu đính kèm.'
                                            : 'Thêm tài liệu thất bại.';
                                        if (ok) {
                                          attachTitleCtrl.clear();
                                          attachUrlCtrl.clear();
                                          attachFileCtrl.clear();
                                        }
                                      });
                                      await refresh(setSheetState);
                                    },
                                    child: const Text('Tải lên'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: <Widget>[
                                  Text(
                                    'Hoạt động & Thảo luận',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: StitchTheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      comments.length.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (comments.isEmpty)
                                const Text(
                                  'Chưa có trao đổi nào.',
                                  style: TextStyle(color: StitchTheme.textMuted),
                                )
                              else
                                ...comments.map(
                                  (Map<String, dynamic> c) => _CommentBubble(
                                    name: ((c['user'] as Map<String, dynamic>?)?['name'] ??
                                            'Nhân sự')
                                        .toString(),
                                    time: (c['created_at'] ?? 'vừa xong').toString(),
                                    content: (c['content'] ?? '').toString(),
                                    attachment:
                                        (c['attachment_path'] ?? '').toString(),
                                    attachmentName:
                                        (c['attachment_name'] ?? '').toString(),
                                    onDelete: () async {
                                      final bool ok = await widget.apiService
                                          .deleteTaskComment(
                                        token,
                                        taskId,
                                        (c['id'] ?? 0) as int,
                                      );
                                      setSheetState(() {
                                        localMessage = ok
                                            ? 'Đã xoá bình luận.'
                                            : 'Xoá bình luận thất bại.'
                                            ;
                                      });
                                      await refresh(setSheetState);
                                    },
                                  ),
                                ),
                              const SizedBox(height: 16),
                              ExpansionTile(
                                title: const Text('Nhắc hạn'),
                                children: <Widget>[
                                  if (!_canManageReminders)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text('Bạn không có quyền quản lý nhắc hạn.'),
                                    ),
                                  DropdownButtonFormField<String>(
                                    value: reminderChannel,
                                    decoration: const InputDecoration(labelText: 'Kênh'),
                                    items: const <DropdownMenuItem<String>>[
                                      DropdownMenuItem<String>(
                                        value: 'in_app',
                                        child: Text('Trong ứng dụng'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'email',
                                        child: Text('Email'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'telegram',
                                        child: Text('Telegram'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'zalo',
                                        child: Text('Zalo'),
                                      ),
                                    ],
                                    onChanged: _canManageReminders
                                        ? (String? v) {
                                            if (v != null) {
                                              setSheetState(() => reminderChannel = v);
                                            }
                                          }
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: reminderTrigger,
                                    decoration: const InputDecoration(labelText: 'Kích hoạt'),
                                    items: const <DropdownMenuItem<String>>[
                                      DropdownMenuItem<String>(
                                        value: 'days_3',
                                        child: Text('Trước 3 ngày'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'day_1',
                                        child: Text('Trước 1 ngày'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'overdue',
                                        child: Text('Quá hạn'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'custom',
                                        child: Text('Tuỳ chỉnh'),
                                      ),
                                    ],
                                    onChanged: _canManageReminders
                                        ? (String? v) {
                                            if (v != null) {
                                              setSheetState(() => reminderTrigger = v);
                                            }
                                          }
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: reminderAtCtrl,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Thời gian nhắc (YYYY-MM-DD HH:MM:SS)',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _canManageReminders
                                        ? () async {
                                            final DateTime now = DateTime.now();
                                            final DateTime? date = await showDatePicker(
                                              context: context,
                                              firstDate: DateTime(now.year - 2),
                                              lastDate: DateTime(now.year + 5),
                                              initialDate: now,
                                            );
                                            if (date == null || !context.mounted) return;
                                            final TimeOfDay? time = await showTimePicker(
                                              context: context,
                                              initialTime: TimeOfDay.now(),
                                            );
                                            if (time == null) return;
                                            setSheetState(() {
                                              reminderAtCtrl.text = _fmtDateTime(date, time);
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.event_outlined, size: 16),
                                    label: const Text('Chọn ngày giờ'),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton(
                                    onPressed: _canManageReminders
                                        ? () async {
                                            final String scheduledAt =
                                                reminderAtCtrl.text.trim();
                                            if (scheduledAt.isEmpty) {
                                              setSheetState(() {
                                                localMessage =
                                                    'Vui lòng chọn thời gian nhắc.';
                                              });
                                              return;
                                            }
                                            final bool ok = editingReminderId == null
                                                ? await widget.apiService.createTaskReminder(
                                                    token,
                                                    taskId,
                                                    channel: reminderChannel,
                                                    triggerType: reminderTrigger,
                                                    scheduledAt: scheduledAt,
                                                  )
                                                : await widget.apiService.updateTaskReminder(
                                                    token,
                                                    taskId,
                                                    editingReminderId!,
                                                    channel: reminderChannel,
                                                    triggerType: reminderTrigger,
                                                    scheduledAt: scheduledAt,
                                                  );
                                            setSheetState(() {
                                              localMessage = ok
                                                  ? (editingReminderId == null
                                                      ? 'Đã thêm reminder.'
                                                      : 'Đã cập nhật reminder.')
                                                  : (editingReminderId == null
                                                      ? 'Thêm reminder thất bại.'
                                                      : 'Cập nhật reminder thất bại.');
                                              if (ok) {
                                                reminderAtCtrl.clear();
                                                editingReminderId = null;
                                              }
                                            });
                                            await refresh(setSheetState);
                                          }
                                        : null,
                                    child: Text(
                                      editingReminderId == null
                                          ? 'Thêm reminder'
                                          : 'Cập nhật reminder',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...reminders.map(
                                    (Map<String, dynamic> r) => ListTile(
                                      dense: true,
                                      title: Text('${r['trigger_type']} • ${r['channel']}'),
                                      subtitle: Text((r['scheduled_at'] ?? '').toString()),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.more_horiz),
                                        onPressed: _canManageReminders
                                            ? () async {
                                                final int reminderId =
                                                    (r['id'] ?? 0) as int;
                                                final String scheduled =
                                                    (r['scheduled_at'] ?? '').toString();
                                                final String channel =
                                                    (r['channel'] ?? 'in_app').toString();
                                                final String trigger =
                                                    (r['trigger_type'] ?? 'custom').toString();
                                                final String? action =
                                                    await showModalBottomSheet<String>(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return SafeArea(
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: <Widget>[
                                                          ListTile(
                                                            leading:
                                                                const Icon(Icons.edit_outlined),
                                                            title: const Text('Sửa reminder'),
                                                            onTap: () =>
                                                                Navigator.of(context).pop('edit'),
                                                          ),
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons.delete_outline,
                                                              color: Colors.red,
                                                            ),
                                                            title: const Text('Xoá reminder'),
                                                            onTap: () =>
                                                                Navigator.of(context).pop('delete'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                                if (action == 'edit') {
                                                  setSheetState(() {
                                                    editingReminderId = reminderId;
                                                    reminderAtCtrl.text = scheduled;
                                                    reminderChannel = channel;
                                                    reminderTrigger = trigger;
                                                    localMessage =
                                                        'Đang sửa reminder #$editingReminderId';
                                                  });
                                                } else if (action == 'delete') {
                                                  final bool ok = await widget.apiService
                                                      .deleteTaskReminder(
                                                    token,
                                                    taskId,
                                                    reminderId,
                                                  );
                                                  setSheetState(() {
                                                    localMessage = ok
                                                        ? 'Đã xoá reminder.'
                                                        : 'Xoá reminder thất bại.';
                                                  });
                                                  await refresh(setSheetState);
                                                }
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            border: Border(
                              top: BorderSide(color: StitchTheme.border),
                            ),
                          ),
                          child: Column(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  TextButton.icon(
                                    onPressed: isTaskDone
                                        ? null
                                        : () {
                                            setSheetState(() {
                                              showCommentOptions =
                                                  !showCommentOptions;
                                            });
                                          },
                                    icon: Icon(
                                      showCommentOptions
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 18,
                                    ),
                                    label: const Text('Tùy chọn'),
                                  ),
                                  const Spacer(),
                                  if (showCommentOptions)
                                    const Text(
                                      'Tag + File',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: StitchTheme.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                              if (isTaskDone)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Công việc đã hoàn thành, không thể gửi trao đổi.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: StitchTheme.textMuted,
                                    ),
                                  ),
                                ),
                              if (showCommentOptions) ...<Widget>[
                                TextField(
                                  controller: commentTagCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Tag user IDs (vd: 12, 15)',
                                  ),
                                  enabled: !isTaskDone,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: commentAttachmentCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Đường dẫn tệp hoặc liên kết',
                                  ),
                                  enabled: !isTaskDone,
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: isTaskDone
                                      ? null
                                      : () => pickFile(
                                            commentAttachmentCtrl,
                                            setSheetState,
                                          ),
                                  icon: const Icon(Icons.attach_file, size: 18),
                                  label: const Text('Chọn file'),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: StitchTheme.surfaceAlt,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: StitchTheme.border),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: TextField(
                                              controller: commentCtrl,
                                              minLines: 1,
                                              maxLines: 3,
                                              decoration: const InputDecoration(
                                                hintText: 'Viết bình luận...',
                                                border: InputBorder.none,
                                                isDense: true,
                                              ),
                                              enabled: !isTaskDone,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: isTaskDone
                                                ? null
                                                : () => pickFile(
                                                      commentAttachmentCtrl,
                                                      setSheetState,
                                                    ),
                                            icon: const Icon(Icons.attach_file,
                                                color: StitchTheme.textSubtle),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: isTaskDone
                                        ? null
                                        : () async {
                                          final String content = commentCtrl.text.trim();
                                          if (content.isEmpty) return;
                                          final List<int> tags = commentTagCtrl.text
                                              .split(',')
                                              .map((String raw) => raw.trim())
                                              .where((String raw) => raw.isNotEmpty)
                                              .map((String raw) => int.tryParse(raw))
                                              .whereType<int>()
                                              .toList();
                                          final String attachment =
                                              commentAttachmentCtrl.text.trim();
                                          final bool ok = await widget.apiService
                                              .createTaskComment(
                                            token,
                                            taskId,
                                            content: content,
                                            taggedUserIds: tags.isEmpty ? null : tags,
                                            attachmentPath:
                                                attachment.isEmpty ? null : attachment,
                                          );
                                          setSheetState(() {
                                            localMessage =
                                                ok ? 'Đã gửi bình luận.' : 'Gửi bình luận thất bại.';
                                            if (ok) {
                                              commentCtrl.clear();
                                              commentTagCtrl.clear();
                                              commentAttachmentCtrl.clear();
                                            }
                                          });
                                          await refresh(setSheetState);
                                        },
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                    child: const Icon(Icons.send, size: 18),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: _canUpdateStatus
                                    ? () => submitTask(setSheetState)
                                    : null,
                                icon: const Icon(Icons.task_alt, size: 18),
                                label: const Text('Nộp bài'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    commentCtrl.dispose();
    commentTagCtrl.dispose();
    commentAttachmentCtrl.dispose();
    attachTitleCtrl.dispose();
    attachUrlCtrl.dispose();
    attachFileCtrl.dispose();
    reminderAtCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom + 80;
    final List<String> statuses = <String>['', ...widget.statuses];
    final List<Map<String, dynamic>> timelineTasks =
        List<Map<String, dynamic>>.from(widget.tasks);
    timelineTasks.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime? da =
          DateTime.tryParse((a['deadline'] ?? '').toString())?.toLocal();
      final DateTime? db =
          DateTime.tryParse((b['deadline'] ?? '').toString())?.toLocal();
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    return SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Bảng công việc',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.currentFilter.isEmpty
                      ? 'Theo dõi toàn bộ công việc theo trạng thái và hạn chót.'
                      : 'Đang lọc: ${_prettyStatus(widget.currentFilter)}.',
                  style: const TextStyle(
                    color: StitchTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SegmentedControl(
                  value: _viewMode,
                  options: const <String, String>{
                    'board': 'Bảng',
                    'timeline': 'Dòng thời gian',
                    'gantt': 'Biểu đồ Gantt',
                  },
                  onChanged: (String value) => setState(() => _viewMode = value),
                ),
                if ((_canImportTasks || _canCreateTask) && widget.isAuthenticated)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        if (_canImportTasks)
                          OutlinedButton.icon(
                            onPressed: _importTasks,
                            icon: const Icon(Icons.file_upload_outlined),
                            label: const Text('Import Excel'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        if (_canCreateTask)
                          OutlinedButton.icon(
                            onPressed: _openCreateTaskModal,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Thêm công việc'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                final String status = statuses[index];
                final bool selected = widget.currentFilter == status;
                final String label = _prettyStatus(status);
                final IconData icon =
                    status.isEmpty ? Icons.list_alt : _statusIcon(status);
                return InkWell(
                  onTap: () => widget.onRefresh(status: status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selected ? StitchTheme.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(icon,
                            size: 18,
                            color: selected
                                ? StitchTheme.primary
                                : StitchTheme.textSubtle),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? StitchTheme.primary
                                : StitchTheme.textSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => widget.onRefresh(status: widget.currentFilter),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
                children: <Widget>[
                  if (!widget.isAuthenticated)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: StitchTheme.border),
                      ),
                      child: const Text(
                        'Vui lòng đăng nhập ở tab Tài khoản để thao tác công việc.',
                        style: TextStyle(color: StitchTheme.textMuted),
                      ),
                    ),
                  if (widget.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (widget.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        widget.message,
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                    ),
                  if (_viewMode == 'gantt')
                    _buildGanttView(widget.tasks)
                  else if (_viewMode == 'timeline')
                    ...timelineTasks.map(_buildTimelineItem)
                  else
                    ...widget.tasks.map(_buildTaskCard),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final String title = (task['title'] ?? 'Công việc').toString();
    final Map<String, dynamic>? project = task['project'] as Map<String, dynamic>?;
    final String projectName = (project?['name'] ?? 'Dự án nội bộ').toString();
    final Map<String, dynamic>? department =
        task['department'] as Map<String, dynamic>?;
    final String departmentName =
        (department?['name'] ?? '—').toString();
    final String priority = (task['priority'] ?? 'medium').toString();
    final _PriorityStyle priorityStyle = _priorityStyle(priority);
    final String deadlineLabel = _shortDate((task['deadline'] ?? '').toString());

    final int progress = (task['progress_percent'] ?? 0) is int
        ? task['progress_percent'] as int
        : int.tryParse('${task['progress_percent'] ?? 0}') ?? 0;

    final int comments = (task['comments_count'] ?? 0) is int
        ? task['comments_count'] as int
        : int.tryParse('${task['comments_count'] ?? 0}') ?? 0;

    final int attachments = (task['attachments_count'] ?? 0) is int
        ? task['attachments_count'] as int
        : int.tryParse('${task['attachments_count'] ?? 0}') ?? 0;

    final List<_AvatarInfo> avatars = <_AvatarInfo>[];
    final Map<String, dynamic>? assignee =
        task['assignee'] as Map<String, dynamic>?;
    if (assignee != null) {
      avatars.add(_AvatarInfo(name: (assignee['name'] ?? 'A').toString()));
    }
    final Map<String, dynamic>? reviewer =
        task['reviewer'] as Map<String, dynamic>?;
    if (reviewer != null) {
      avatars.add(_AvatarInfo(name: (reviewer['name'] ?? 'R').toString()));
    }

    return GestureDetector(
      onTap: widget.isAuthenticated ? () => _openTaskCenter(task) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityStyle.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(priorityStyle.icon, size: 14, color: priorityStyle.foreground),
                      const SizedBox(width: 4),
                      Text(
                        priorityStyle.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: priorityStyle.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: <Widget>[
                    if (attachments > 0)
                      const Icon(Icons.attach_file, color: StitchTheme.textSubtle, size: 18),
                    if (_canUpdateStatus)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: StitchTheme.textSubtle),
                        onSelected: (String value) {
                          if (!widget.isAuthenticated) return;
                          widget.onUpdateStatus(task, value);
                        },
                        itemBuilder: (BuildContext context) {
                          return widget.statuses
                              .where((String s) => s != task['status'])
                              .map(
                                (String s) => PopupMenuItem<String>(
                                  value: s,
                                  child: Text('Chuyển: ${_prettyStatus(s)}'),
                                ),
                              )
                              .toList();
                        },
                      )
                    else
                      const Tooltip(
                        message: 'Không có quyền đổi trạng thái',
                        child: Icon(Icons.lock_outline, color: StitchTheme.textSubtle),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              projectName,
              style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Phòng ban: $departmentName',
              style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                if (avatars.isNotEmpty) _AvatarStack(avatars: avatars),
                const Spacer(),
                if (comments > 0)
                  Row(
                    children: <Widget>[
                      const Icon(Icons.chat_bubble, size: 16, color: StitchTheme.textSubtle),
                      const SizedBox(width: 4),
                      Text(
                        comments.toString(),
                        style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: StitchTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    deadlineLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (progress > 0) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'Tiến độ',
                    style: TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                  ),
                  Text(
                    '$progress%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 100) / 100,
                  minHeight: 6,
                  color: StitchTheme.primary,
                  backgroundColor: StitchTheme.surfaceAlt,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> task) {
    final String title = (task['title'] ?? 'Công việc').toString();
    final String projectName =
        ((task['project'] as Map<String, dynamic>?)?['name'] ?? 'Dự án').toString();
    final String deadlineLabel = _shortDate((task['deadline'] ?? '').toString());
    final String status = _prettyStatus((task['status'] ?? '').toString());

    return GestureDetector(
      onTap: widget.isAuthenticated ? () => _openTaskCenter(task) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              children: <Widget>[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: StitchTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 2,
                  height: 64,
                  color: StitchTheme.border,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          deadlineLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$projectName • $status',
                      style: const TextStyle(
                        fontSize: 12,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGanttView(List<Map<String, dynamic>> tasks) {
    final List<Map<String, dynamic>> rows = tasks.map((task) {
      final DateTime now = DateTime.now();
      final DateTime? start =
          DateTime.tryParse((task['start_at'] ?? '').toString())?.toLocal();
      final DateTime? deadline =
          DateTime.tryParse((task['deadline'] ?? '').toString())?.toLocal();
      final DateTime startDate =
          start ?? (deadline?.subtract(const Duration(days: 3)) ?? now);
      final DateTime endDate = deadline ?? startDate.add(const Duration(days: 3));
      return <String, dynamic>{
        'title': (task['title'] ?? 'Công việc').toString(),
        'start': startDate,
        'end': endDate.isBefore(startDate) ? startDate : endDate,
        'priority': (task['priority'] ?? 'medium').toString(),
      };
    }).toList();

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StitchTheme.border),
        ),
        child: const Text(
          'Chưa có dữ liệu biểu đồ Gantt.',
          style: TextStyle(color: StitchTheme.textMuted),
        ),
      );
    }

    DateTime minStart = rows.first['start'] as DateTime;
    DateTime maxEnd = rows.first['end'] as DateTime;
    for (final Map<String, dynamic> row in rows) {
      final DateTime s = row['start'] as DateTime;
      final DateTime e = row['end'] as DateTime;
      if (s.isBefore(minStart)) minStart = s;
      if (e.isAfter(maxEnd)) maxEnd = e;
    }
    final int totalDays = maxEnd.difference(minStart).inDays + 1;
    final int safeTotal = totalDays <= 0 ? 1 : totalDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double labelWidth = 110;
          final double barWidth = (constraints.maxWidth - labelWidth).clamp(80, 1000);
          return Column(
            children: rows.map((Map<String, dynamic> row) {
              final DateTime s = row['start'] as DateTime;
              final DateTime e = row['end'] as DateTime;
              final int offset = s.difference(minStart).inDays;
              final int span = e.difference(s).inDays + 1;
              final double left = (offset / safeTotal) * barWidth;
              final double width = (span / safeTotal) * barWidth;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: labelWidth,
                      child: Text(
                        row['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      width: barWidth,
                      child: Stack(
                        children: <Widget>[
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: StitchTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Positioned(
                            left: left,
                            child: Container(
                              height: 10,
                              width: width.clamp(12, barWidth),
                              decoration: BoxDecoration(
                                color: StitchTheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}


class _PriorityStyle {
  const _PriorityStyle({
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

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: StitchTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.entries.map((MapEntry<String, String> entry) {
          final bool selected = entry.key == value;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: Center(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? StitchTheme.primary
                          : StitchTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AvatarInfo {
  _AvatarInfo({required this.name});

  final String name;

  String get initials {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'NB';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars});

  final List<_AvatarInfo> avatars;

  @override
  Widget build(BuildContext context) {
    final int count = avatars.length.clamp(0, 3);
    return SizedBox(
      width: 24 + (count - 1) * 16,
      height: 28,
      child: Stack(
        children: List<Widget>.generate(count, (int index) {
          final _AvatarInfo avatar = avatars[index];
          return Positioned(
            left: index * 16,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: StitchTheme.primary,
              child: Text(
                avatar.initials,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
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
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: StitchTheme.textSubtle,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: StitchTheme.textSubtle,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: StitchTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  subtitle.isEmpty ? 'Liên kết nội bộ' : subtitle,
                  style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: StitchTheme.textSubtle),
          ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.name,
    required this.time,
    required this.content,
    required this.attachment,
    required this.attachmentName,
    required this.onDelete,
  });

  final String name;
  final String time;
  final String content;
  final String attachment;
  final String attachmentName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: StitchTheme.primary,
            child: Text(
              name.isEmpty ? 'U' : name.characters.first.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: const TextStyle(fontSize: 10, color: StitchTheme.textSubtle),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: StitchTheme.textMuted,
                            height: 1.45,
                          ),
                          children: _buildLinkifiedTextSpans(context, content),
                        ),
                      ),
                      if (attachment.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _openExternalUrl(context, attachment),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: StitchTheme.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: StitchTheme.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.attach_file,
                                  size: 16,
                                  color: StitchTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _attachmentNameFromPath(
                                      attachment,
                                      fallback: attachmentName,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: StitchTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18, color: StitchTheme.textSubtle),
          ),
        ],
      ),
    );
  }
}

IconData _attachmentIcon(String type) {
  switch (type.toLowerCase()) {
    case 'video':
      return Icons.play_circle;
    case 'file':
      return Icons.description;
    default:
      return Icons.link;
  }
}

String _resolveExternalUrl(String value) {
  return AppEnv.resolveMediaUrl(value);
}

String _attachmentNameFromPath(
  String rawValue, {
  String? fallback,
}) {
  final String preferred = (fallback ?? '').trim();
  if (preferred.isNotEmpty) {
    return preferred;
  }

  final String resolved = _resolveExternalUrl(rawValue);
  final Uri? uri = Uri.tryParse(resolved);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    final String name = uri.pathSegments.last;
    if (name.isNotEmpty) {
      return Uri.decodeComponent(name);
    }
  }

  return rawValue;
}

Future<void> _openExternalUrl(BuildContext context, String rawValue) async {
  final String resolved = _resolveExternalUrl(rawValue);
  final Uri? uri = Uri.tryParse(resolved);
  if (uri == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Liên kết không hợp lệ.')));
    return;
  }

  final bool opened = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không mở được liên kết hoặc tệp đính kèm.')),
    );
  }
}

List<InlineSpan> _buildLinkifiedTextSpans(
  BuildContext context,
  String text,
) {
  final RegExp linkReg = RegExp(r'https?:\/\/[^\s]+', caseSensitive: false);
  final List<InlineSpan> spans = <InlineSpan>[];
  int currentIndex = 0;

  for (final RegExpMatch match in linkReg.allMatches(text)) {
    final int start = match.start;
    final int end = match.end;
    if (start > currentIndex) {
      spans.add(TextSpan(text: text.substring(currentIndex, start)));
    }

    final String rawUrl = text.substring(start, end);
    spans.add(
      TextSpan(
        text: rawUrl,
        style: TextStyle(
          color: StitchTheme.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
        recognizer:
            TapGestureRecognizer()
              ..onTap = () => _openExternalUrl(context, rawUrl),
      ),
    );
    currentIndex = end;
  }

  if (currentIndex < text.length) {
    spans.add(TextSpan(text: text.substring(currentIndex)));
  }

  if (spans.isEmpty) {
    spans.add(TextSpan(text: text));
  }

  return spans;
}

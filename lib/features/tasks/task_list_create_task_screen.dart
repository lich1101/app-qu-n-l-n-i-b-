import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/timeline_defaults.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/stitch_form_layout.dart';
import '../../core/widgets/stitch_searchable_select.dart';
import '../../core/widgets/stitch_task_form_sheet.dart';
import '../../data/services/mobile_api_service.dart';

/// Tạo công việc từ màn danh sách (full-screen, thay cho bottom sheet).
class TaskListCreateTaskScreen extends StatefulWidget {
  const TaskListCreateTaskScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.projects,
    required this.departments,
    required this.statuses,
  });

  final String token;
  final MobileApiService apiService;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> departments;
  final List<String> statuses;

  @override
  State<TaskListCreateTaskScreen> createState() =>
      _TaskListCreateTaskScreenState();
}

class _TaskListCreateTaskScreenState extends State<TaskListCreateTaskScreen> {
  late final TextEditingController titleCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController startCtrl;
  late final TextEditingController deadlineCtrl;
  late final TextEditingController weightCtrl;

  List<Map<String, dynamic>> projectTasks = <Map<String, dynamic>>[];
  bool loadingProjectWeights = false;
  int? projectId;
  int? departmentId;
  int? assigneeId;
  late String priority;
  late String status;
  bool submitting = false;
  String localMessage = '';

  String _statusLabel(String status) {
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
        .map(
          (String part) =>
              part.isEmpty
                  ? ''
                  : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController();
    descCtrl = TextEditingController();
    startCtrl = TextEditingController();
    deadlineCtrl = TextEditingController();
    weightCtrl = TextEditingController(text: '100');
    priority = 'medium';
    status = widget.statuses.isNotEmpty ? widget.statuses.first : 'todo';
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    startCtrl.dispose();
    deadlineCtrl.dispose();
    weightCtrl.dispose();
    super.dispose();
  }

  DateTime? _deadlineCapForSelectedProject() {
    if (projectId == null) return null;
    for (final Map<String, dynamic> p in widget.projects) {
      if (p['id'] == projectId) {
        return TimelineDefaults.taskDefaultsFromProject(p).end;
      }
    }
    return null;
  }

  Future<void> _pickDeadline() async {
    final DateTime lastDate = VietnamTime.pickerLastDateWithCap(
      _deadlineCapForSelectedProject(),
    );
    final DateTime firstDate = VietnamTime.pickerFirstDateSafe(lastDate);
    DateTime initial = VietnamTime.pickerInitialDate(deadlineCtrl.text);
    initial = VietnamTime.clampPickerInitial(initial, firstDate, lastDate);
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() {
      deadlineCtrl.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickStart() async {
    final DateTime lastDate = VietnamTime.pickerLastDateWithCap(
      _deadlineCapForSelectedProject(),
    );
    final DateTime firstDate = VietnamTime.pickerFirstDateSafe(lastDate);
    DateTime initial = VietnamTime.pickerInitialDate(startCtrl.text);
    initial = VietnamTime.clampPickerInitial(initial, firstDate, lastDate);
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() {
      startCtrl.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _loadProjectTasks(int? nextProjectId) async {
    if (nextProjectId == null) {
      setState(() {
        projectTasks = <Map<String, dynamic>>[];
        loadingProjectWeights = false;
      });
      return;
    }
    setState(() => loadingProjectWeights = true);
    final List<Map<String, dynamic>> rows = await widget.apiService.getTasks(
      widget.token,
      projectId: nextProjectId,
      perPage: 200,
    );
    if (!mounted) return;
    setState(() {
      projectTasks = rows;
      loadingProjectWeights = false;
    });
  }

  Future<void> _submit() async {
    final String title = titleCtrl.text.trim();
    if (projectId == null) {
      setState(() => localMessage = 'Vui lòng chọn dự án.');
      return;
    }
    if (departmentId == null) {
      setState(() => localMessage = 'Vui lòng chọn phòng ban.');
      return;
    }
    if (title.isEmpty) {
      setState(() => localMessage = 'Vui lòng nhập tiêu đề.');
      return;
    }
    if (assigneeId == null) {
      setState(() => localMessage = 'Vui lòng chọn nhân sự phụ trách.');
      return;
    }
    final List<Map<String, dynamic>> siblingTasks = projectTasks;
    final int siblingWeightTotal = siblingTasks.fold<int>(
      0,
      (int sum, Map<String, dynamic> task) =>
          sum + (int.tryParse((task['weight_percent'] ?? 0).toString()) ?? 0),
    );
    final int currentWeight = int.tryParse(weightCtrl.text.trim()) ?? 0;
    final int projectedWeightTotal = siblingWeightTotal + currentWeight;
    final int remainingWeight = math.max(0, 100 - siblingWeightTotal);
    final int? weight =
        weightCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(weightCtrl.text.trim());
    if (weight != null && (weight < 1 || weight > 100)) {
      setState(() => localMessage = 'Tỷ trọng phải từ 1 đến 100.');
      return;
    }
    if (projectedWeightTotal > 100) {
      setState(
        () =>
            localMessage =
                'Tổng tỷ trọng không được lố 100%. Mức nhập tối đa: $remainingWeight%',
      );
      return;
    }
    final DateTime? projectCap = _deadlineCapForSelectedProject();
    if (!VietnamTime.ymdNotAfterCap(startCtrl.text.trim(), projectCap)) {
      setState(
        () => localMessage = 'Ngày bắt đầu không được sau ngày kết thúc dự án.',
      );
      return;
    }
    if (!VietnamTime.ymdNotAfterCap(deadlineCtrl.text.trim(), projectCap)) {
      setState(
        () =>
            localMessage =
                'Deadline công việc không được sau ngày kết thúc dự án.',
      );
      return;
    }
    setState(() {
      submitting = true;
      localMessage = '';
    });
    final bool ok = await widget.apiService.createTask(
      widget.token,
      projectId: projectId!,
      departmentId: departmentId,
      assigneeId: assigneeId,
      title: title,
      description: descCtrl.text.trim(),
      priority: priority,
      status: status,
      startAt: startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
      deadline:
          deadlineCtrl.text.trim().isEmpty ? null : deadlineCtrl.text.trim(),
      weightPercent: weight,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        submitting = false;
        localMessage = 'Tạo công việc thất bại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? selectedProject =
        projectId == null
            ? null
            : widget.projects.firstWhere(
              (Map<String, dynamic> p) => p['id'] == projectId,
              orElse: () => <String, dynamic>{},
            );
    final List<Map<String, dynamic>> siblingTasks = projectTasks;
    final int siblingWeightTotal = siblingTasks.fold<int>(
      0,
      (int sum, Map<String, dynamic> task) =>
          sum + (int.tryParse((task['weight_percent'] ?? 0).toString()) ?? 0),
    );
    final int currentWeight = int.tryParse(weightCtrl.text.trim()) ?? 0;
    final int projectedWeightTotal = siblingWeightTotal + currentWeight;
    final int remainingWeight = math.max(0, 100 - siblingWeightTotal);

    List<Map<String, dynamic>> staffOptions = <Map<String, dynamic>>[];
    if (departmentId != null) {
      final Map<String, dynamic>? dept = widget.departments.firstWhere(
        (Map<String, dynamic> d) => d['id'] == departmentId,
        orElse: () => <String, dynamic>{},
      );
      final List<dynamic> staff =
          (dept?['staff'] ?? <dynamic>[]) as List<dynamic>;
      staffOptions =
          staff.map((dynamic e) => e as Map<String, dynamic>).toList();
    }

    return Scaffold(
      backgroundColor: StitchTheme.formPageBackground,
      resizeToAvoidBottomInset: true,
      appBar: stitchFormAppBar(
        context: context,
        title: 'Thêm công việc mới',
        onClose: submitting ? () {} : () => Navigator.of(context).maybePop(),
      ),
      bottomNavigationBar: StitchFormBottomBar(
        primaryLoading: submitting,
        primaryLabel: submitting ? 'Đang tạo...' : 'Tạo công việc',
        onPrimary: submitting ? null : _submit,
        onSecondary: submitting ? null : () => Navigator.of(context).maybePop(),
        secondaryLabel: 'Hủy',
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: <Widget>[
            StitchFormSection(
              margin: EdgeInsets.zero,
              child: stitchTaskFormSheetHeader(
                context,
                subtitle:
                    'Điền thông tin chi tiết để khởi tạo công việc trong dự án.',
              ),
            ),
            if (localMessage.isNotEmpty)
              StitchFormSection(
                margin: EdgeInsets.zero,
                child: stitchTaskFormMessage(localMessage),
              ),
            StitchFormSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const StitchFormSectionHeader(
                    icon: Icons.folder_special_outlined,
                    title: 'Dự án & nội dung',
                  ),
                  StitchSearchableSelectField<int>(
                    value: projectId,
                    sheetTitle: 'Chọn dự án',
                    label: 'Dự án',
                    searchHint: 'Tìm theo tên dự án...',
                    options:
                        widget.projects
                            .map(
                              (Map<String, dynamic> p) =>
                                  StitchSelectOption<int>(
                                    value: p['id'] as int,
                                    label: (p['name'] ?? 'Dự án').toString(),
                                  ),
                            )
                            .toList(),
                    onChanged: (int? v) async {
                      if (v == null) return;
                      final Map<String, dynamic> nextProject = widget.projects
                          .firstWhere(
                            (Map<String, dynamic> p) => p['id'] == v,
                            orElse: () => <String, dynamic>{},
                          );
                      if (nextProject.isEmpty) return;
                      final int? nextOwnerId = int.tryParse(
                        '${nextProject['owner_id'] ?? nextProject['owner']?['id'] ?? ''}',
                      );
                      final int? nextDepartmentId = int.tryParse(
                        '${nextProject['owner']?['department_id'] ?? nextProject['department_id'] ?? ''}',
                      );
                      final String nextRequirement =
                          '${nextProject['customer_requirement'] ?? ''}'
                              .toString();
                      final ({DateTime? start, DateTime? end}) td =
                          TimelineDefaults.taskDefaultsFromProject(nextProject);
                      setState(() {
                        projectId = v;
                        departmentId = nextDepartmentId ?? departmentId;
                        assigneeId = nextOwnerId ?? assigneeId;
                        startCtrl.text = VietnamTime.toYmdInput(td.start);
                        deadlineCtrl.text = VietnamTime.toYmdInput(td.end);
                        if (descCtrl.text.trim().isEmpty &&
                            nextRequirement.trim().isNotEmpty) {
                          descCtrl.text = nextRequirement;
                        }
                      });
                      await _loadProjectTasks(v);
                    },
                    decoration: stitchTaskDropdownDecoration(context, 'Dự án'),
                  ),
                  if (selectedProject != null &&
                      selectedProject.isNotEmpty &&
                      selectedProject['contract_id'] == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Dự án chưa có hợp đồng, hệ thống xử lý theo luồng dự án nội bộ.',
                        style: TextStyle(
                          color: StitchTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề',
                    ).applyDefaults(Theme.of(context).inputDecorationTheme),
                  ),
                  const SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: descCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      alignLabelWithHint: true,
                    ).applyDefaults(Theme.of(context).inputDecorationTheme),
                  ),
                ],
              ),
            ),
            StitchFormSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const StitchFormSectionHeader(
                    icon: Icons.tune_rounded,
                    title: 'Trạng thái & thời gian',
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: StitchSearchableSelectField<String>(
                          value: status,
                          sheetTitle: 'Chọn trạng thái',
                          label: 'Trạng thái',
                          searchHint: 'Tìm trạng thái...',
                          options:
                              widget.statuses
                                  .map(
                                    (String s) => StitchSelectOption<String>(
                                      value: s,
                                      label: _statusLabel(s),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (String? v) =>
                                  setState(() => status = v ?? status),
                          decoration: stitchTaskDropdownDecoration(
                            context,
                            'Trạng thái',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StitchSearchableSelectField<String>(
                          value: priority,
                          sheetTitle: 'Chọn mức ưu tiên',
                          label: 'Ưu tiên',
                          searchHint: 'Tìm mức ưu tiên...',
                          options: const <StitchSelectOption<String>>[
                            StitchSelectOption<String>(
                              value: 'low',
                              label: 'Thấp',
                            ),
                            StitchSelectOption<String>(
                              value: 'medium',
                              label: 'Trung bình',
                            ),
                            StitchSelectOption<String>(
                              value: 'high',
                              label: 'Cao',
                            ),
                            StitchSelectOption<String>(
                              value: 'urgent',
                              label: 'Khẩn cấp',
                            ),
                          ],
                          onChanged:
                              (String? v) =>
                                  setState(() => priority = v ?? 'medium'),
                          decoration: stitchTaskDropdownDecoration(
                            context,
                            'Ưu tiên',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kStitchTaskFormGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          readOnly: true,
                          decoration: stitchTaskDateDecoration(
                            context,
                            'Ngày bắt đầu',
                          ),
                          onTap: _pickStart,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: deadlineCtrl,
                          readOnly: true,
                          decoration: stitchTaskDateDecoration(
                            context,
                            'Deadline',
                          ),
                          onTap: _pickDeadline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Tỷ trọng (%)',
                      suffixText: '%',
                      helperText: 'Còn lại trong dự án: $remainingWeight%',
                      labelStyle: TextStyle(
                        color:
                            projectedWeightTotal > 100
                                ? StitchTheme.danger
                                : StitchTheme.labelEmphasis,
                        fontWeight:
                            projectedWeightTotal > 100
                                ? FontWeight.bold
                                : FontWeight.w600,
                      ),
                    ).applyDefaults(Theme.of(context).inputDecorationTheme),
                  ),
                  if (projectedWeightTotal > 100)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Đã vượt quá 100%!',
                        style: TextStyle(
                          color: StitchTheme.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            StitchFormSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const StitchFormSectionHeader(
                    icon: Icons.groups_outlined,
                    title: 'Phân công',
                  ),
                  StitchSearchableSelectField<int>(
                    value: departmentId,
                    sheetTitle: 'Chọn phòng ban',
                    label: 'Phòng ban',
                    searchHint: 'Tìm theo tên phòng ban...',
                    options:
                        widget.departments
                            .map(
                              (Map<String, dynamic> d) =>
                                  StitchSelectOption<int>(
                                    value: d['id'] as int,
                                    label:
                                        (d['name'] ?? 'Phòng ban').toString(),
                                  ),
                            )
                            .toList(),
                    onChanged: (int? v) {
                      setState(() {
                        departmentId = v;
                        assigneeId = null;
                      });
                    },
                    decoration: stitchTaskDropdownDecoration(
                      context,
                      'Phòng ban',
                    ),
                  ),
                  const SizedBox(height: kStitchTaskFormGap),
                  StitchSearchableSelectField<int>(
                    value: assigneeId,
                    sheetTitle: 'Chọn nhân sự phụ trách',
                    label: 'Nhân sự phụ trách',
                    searchHint: 'Tìm theo tên hoặc email...',
                    options:
                        staffOptions
                            .map(
                              (Map<String, dynamic> s) =>
                                  StitchSelectOption<int>(
                                    value: s['id'] as int,
                                    label:
                                        (s['name'] ?? s['email'] ?? 'Nhân sự')
                                            .toString(),
                                    subtitle:
                                        (s['email'] ?? '')
                                                .toString()
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : (s['email'] ?? '').toString(),
                                  ),
                            )
                            .toList(),
                    onChanged: (int? v) => setState(() => assigneeId = v),
                    decoration: stitchTaskDropdownDecoration(
                      context,
                      'Nhân sự phụ trách',
                    ),
                  ),
                  const SizedBox(height: kStitchTaskFormGap),
                  Row(
                    children: <Widget>[
                      OutlinedButton(
                        onPressed:
                            projectId == null || remainingWeight <= 0
                                ? null
                                : () {
                                  setState(() {
                                    weightCtrl.text =
                                        math.max(1, remainingWeight).toString();
                                  });
                                },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: StitchTheme.primaryStrong,
                          side: BorderSide(
                            color: StitchTheme.primary.withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        child: Text('Điền phần còn lại ($remainingWeight%)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          projectedWeightTotal == 100
                              ? const Color(0xFFECFDF3)
                              : projectedWeightTotal > 100
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            projectedWeightTotal == 100
                                ? const Color(0xFFA7F3D0)
                                : projectedWeightTotal > 100
                                ? const Color(0xFFFECACA)
                                : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Text(
                      loadingProjectWeights
                          ? 'Đang kiểm tra tổng tỷ trọng công việc trong dự án...'
                          : 'Tổng tỷ trọng công việc của dự án sau khi lưu sẽ là $projectedWeightTotal%. Mốc hợp lý là 100%.',
                      style: TextStyle(
                        color:
                            projectedWeightTotal == 100
                                ? const Color(0xFF047857)
                                : projectedWeightTotal > 100
                                ? Colors.redAccent
                                : const Color(0xFFB45309),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: StitchTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: StitchTheme.border),
                    ),
                    child: const Text(
                      'Tiến độ công việc sẽ được hệ thống tự tính từ các đầu việc và tỷ trọng của từng đầu việc. Bạn chỉ cần nhập tỷ trọng công việc trong dự án.',
                      style: TextStyle(
                        color: StitchTheme.textMuted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

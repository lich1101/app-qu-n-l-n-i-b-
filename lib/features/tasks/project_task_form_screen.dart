import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/stitch_form_layout.dart';
import '../../core/widgets/stitch_searchable_select.dart';
import '../../core/widgets/stitch_task_form_sheet.dart';
import '../../data/services/mobile_api_service.dart';

/// Form tạo/sửa công việc trong ngữ cảnh một dự án (full-screen, style Winmap).
class ProjectTaskFormScreen extends StatefulWidget {
  const ProjectTaskFormScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.projectId,
    required this.projectName,
    required this.departments,
    required this.existingTasksForWeightHint,
    this.defaultStartDate,
    this.defaultDeadline,
    this.editingTask,
  });

  final String token;
  final MobileApiService apiService;
  final int projectId;
  final String projectName;
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> existingTasksForWeightHint;
  /// Khi tạo mới: mặc định theo timeline dự án (nếu có).
  final dynamic defaultStartDate;
  final dynamic defaultDeadline;
  final Map<String, dynamic>? editingTask;

  bool get isEdit => editingTask != null;

  @override
  State<ProjectTaskFormScreen> createState() => _ProjectTaskFormScreenState();
}

class _ProjectTaskFormScreenState extends State<ProjectTaskFormScreen> {
  late final TextEditingController titleCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController startCtrl;
  late final TextEditingController deadlineCtrl;
  late final TextEditingController weightCtrl;

  late int? departmentId;
  late int? assigneeId;
  late String status;
  late String priority;
  bool submitting = false;
  String localMessage = '';

  int _toId(dynamic value) {
    if (value is int) return value;
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  String _toDateInput(dynamic value) => VietnamTime.toYmdInput(value);

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? t = widget.editingTask;
    final bool edit = t != null;
    titleCtrl = TextEditingController(
      text: edit ? (t['title'] ?? '').toString() : '',
    );
    descCtrl = TextEditingController(
      text: edit ? (t['description'] ?? '').toString() : '',
    );
    startCtrl = TextEditingController(
      text:
          edit
              ? _toDateInput(t['start_at'])
              : _toDateInput(widget.defaultStartDate),
    );
    deadlineCtrl = TextEditingController(
      text:
          edit
              ? _toDateInput(t['deadline'])
              : _toDateInput(widget.defaultDeadline),
    );
    weightCtrl = TextEditingController(
      text:
          edit
              ? '${t['weight_percent'] ?? 0}'
              : '${math.max(1, 100 - widget.existingTasksForWeightHint.fold<int>(0, (int sum, Map<String, dynamic> row) => sum + (int.tryParse('${row['weight_percent'] ?? 0}') ?? 0)))}',
    );
    departmentId = edit ? _toId(t['department_id']) : null;
    if (departmentId == 0) departmentId = null;
    assigneeId = edit ? _toId(t['assignee_id']) : null;
    if (assigneeId == 0) assigneeId = null;
    status = (t?['status'] ?? 'todo').toString();
    priority = (t?['priority'] ?? 'medium').toString();
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

  DateTime? get _projectDeadlineCap =>
      VietnamTime.parseDateOnly(widget.defaultDeadline);

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime lastDate =
        VietnamTime.pickerLastDateWithCap(_projectDeadlineCap);
    final DateTime firstDate = VietnamTime.pickerFirstDateSafe(lastDate);
    DateTime initial = VietnamTime.pickerInitialDate(controller.text);
    initial = VietnamTime.clampPickerInitial(initial, firstDate, lastDate);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;
    setState(() {
      controller.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _submit() async {
    if (titleCtrl.text.trim().isEmpty) {
      setState(() => localMessage = 'Vui lòng nhập tiêu đề công việc.');
      return;
    }
    final int? weight = int.tryParse(weightCtrl.text.trim());
    if (weight == null || weight < 1 || weight > 100) {
      setState(() => localMessage = 'Tỷ trọng phải từ 1 đến 100.');
      return;
    }
    final DateTime? cap = _projectDeadlineCap;
    if (!VietnamTime.ymdNotAfterCap(startCtrl.text.trim(), cap)) {
      setState(
        () => localMessage =
            'Ngày bắt đầu không được sau ngày kết thúc dự án.',
      );
      return;
    }
    if (!VietnamTime.ymdNotAfterCap(deadlineCtrl.text.trim(), cap)) {
      setState(
        () => localMessage =
            'Deadline công việc không được sau ngày kết thúc dự án.',
      );
      return;
    }
    setState(() {
      submitting = true;
      localMessage = '';
    });

    final bool ok =
        widget.isEdit
            ? await widget.apiService.updateTask(
              widget.token,
              _toId(widget.editingTask!['id']),
              projectId: widget.projectId,
              departmentId: departmentId,
              assigneeId: assigneeId,
              title: titleCtrl.text.trim(),
              description: descCtrl.text.trim(),
              priority: priority,
              status: status,
              startAt:
                  startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
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
              startAt:
                  startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
              deadline:
                  deadlineCtrl.text.trim().isEmpty
                      ? null
                      : deadlineCtrl.text.trim(),
              weightPercent: weight,
            );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        submitting = false;
        localMessage =
            widget.isEdit
                ? 'Cập nhật công việc thất bại.'
                : 'Tạo công việc thất bại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String subtitle =
        widget.projectName.trim().isEmpty
            ? 'Giao việc trong dự án hiện tại.'
            : 'Giao việc trong dự án «${widget.projectName.trim()}».';

    final List<Map<String, dynamic>> staffOptions = <Map<String, dynamic>>[
      for (final Map<String, dynamic> department in widget.departments)
        if (departmentId == null || _toId(department['id']) == departmentId)
          ...((department['staff'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map>()
              .map((Map row) => row.cast<String, dynamic>())),
    ];

    return Scaffold(
      backgroundColor: StitchTheme.formPageBackground,
      resizeToAvoidBottomInset: true,
      appBar: stitchFormAppBar(
        context: context,
        title: widget.isEdit ? 'Sửa công việc' : 'Thêm công việc mới',
        onClose: submitting ? () {} : () => Navigator.of(context).maybePop(),
      ),
      bottomNavigationBar: StitchFormBottomBar(
        primaryLoading: submitting,
        primaryLabel:
            submitting
                ? 'Đang lưu...'
                : (widget.isEdit ? 'Lưu thay đổi' : 'Tạo công việc'),
        onPrimary: submitting ? null : _submit,
        onSecondary:
            submitting ? null : () => Navigator.of(context).maybePop(),
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
                subtitle: subtitle,
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
                    icon: Icons.edit_note_outlined,
                    title: 'Nội dung',
                  ),
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
                    title: 'Trạng thái & ưu tiên',
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
                          options: const <StitchSelectOption<String>>[
                            StitchSelectOption<String>(
                              value: 'todo',
                              label: 'Cần làm',
                            ),
                            StitchSelectOption<String>(
                              value: 'doing',
                              label: 'Đang làm',
                            ),
                            StitchSelectOption<String>(
                              value: 'done',
                              label: 'Hoàn tất',
                            ),
                            StitchSelectOption<String>(
                              value: 'blocked',
                              label: 'Bị chặn',
                            ),
                          ],
                          onChanged:
                              (String? value) =>
                                  setState(() => status = value ?? 'todo'),
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
                              label: 'Khẩn',
                            ),
                          ],
                          onChanged:
                              (String? value) => setState(
                                () => priority = value ?? 'medium',
                              ),
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
                          onTap: () => _pickDate(startCtrl),
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
                          onTap: () => _pickDate(deadlineCtrl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tỷ trọng (%)',
                      suffixText: '%',
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
                    icon: Icons.groups_outlined,
                    title: 'Phân công',
                  ),
                  StitchSearchableSelectField<int>(
                    value: departmentId == 0 ? null : departmentId,
                    sheetTitle: 'Chọn phòng ban',
                    label: 'Phòng ban',
                    searchHint: 'Tìm theo tên phòng ban...',
                    options:
                        widget.departments
                            .map(
                              (Map<String, dynamic> d) =>
                                  StitchSelectOption<int>(
                                    value: _toId(d['id']),
                                    label: (d['name'] ?? 'Phòng ban').toString(),
                                  ),
                            )
                            .toList(),
                    onChanged: (int? value) {
                      setState(() {
                        departmentId = value;
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
                    value: assigneeId == 0 ? null : assigneeId,
                    sheetTitle: 'Chọn nhân sự phụ trách',
                    label: 'Nhân sự phụ trách',
                    searchHint: 'Tìm theo tên hoặc email...',
                    options:
                        staffOptions
                            .map(
                              (Map<String, dynamic> user) =>
                                  StitchSelectOption<int>(
                                    value: _toId(user['id']),
                                    label:
                                        (user['name'] ??
                                                user['email'] ??
                                                'Nhân sự')
                                            .toString(),
                                    subtitle:
                                        (user['email'] ?? '')
                                                .toString()
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : (user['email'] ?? '').toString(),
                                  ),
                            )
                            .toList(),
                    onChanged: (int? value) =>
                        setState(() => assigneeId = value),
                    decoration: stitchTaskDropdownDecoration(
                      context,
                      'Nhân sự phụ trách',
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

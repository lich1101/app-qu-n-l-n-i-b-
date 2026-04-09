import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/task_item_progress_input.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/stitch_form_layout.dart';
import '../../core/widgets/stitch_searchable_select.dart';
import '../../core/widgets/stitch_task_form_sheet.dart';
import '../../data/services/mobile_api_service.dart';

/// Thêm / sửa đầu việc trong ngữ cảnh một công việc (full-screen).
class TaskItemFormScreen extends StatefulWidget {
  const TaskItemFormScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.taskId,
    required this.departments,
    required this.taskDepartmentId,
    this.taskStartAt,
    this.taskDeadline,
    this.editingItem,
  });

  final String token;
  final MobileApiService apiService;
  final int taskId;
  final List<Map<String, dynamic>> departments;
  final int taskDepartmentId;
  final dynamic taskStartAt;
  final dynamic taskDeadline;
  final Map<String, dynamic>? editingItem;

  bool get isEdit => editingItem != null;

  @override
  State<TaskItemFormScreen> createState() => _TaskItemFormScreenState();
}

class _TaskItemFormScreenState extends State<TaskItemFormScreen> {
  late final TextEditingController titleCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController progressCtrl;
  late final TextEditingController weightCtrl;
  late final TextEditingController startCtrl;
  late final TextEditingController deadlineCtrl;

  late String status;
  late String priority;
  int? assigneeId;
  bool submitting = false;
  String localMessage = '';

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  String _toDateInput(dynamic value) => VietnamTime.toYmdInput(value);

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? item = widget.editingItem;
    final bool edit = item != null;
    titleCtrl = TextEditingController(
      text: (item?['title'] ?? '').toString(),
    );
    descCtrl = TextEditingController(
      text: (item?['description'] ?? '').toString(),
    );
    progressCtrl = TextEditingController(
      text: '${item?['progress_percent'] ?? 0}',
    );
    weightCtrl = TextEditingController(
      text: edit ? '${item['weight_percent'] ?? 0}' : '10',
    );
    startCtrl = TextEditingController(
      text:
          edit
              ? _toDateInput(item['start_date'])
              : _toDateInput(widget.taskStartAt),
    );
    deadlineCtrl = TextEditingController(
      text:
          edit
              ? _toDateInput(item['deadline'])
              : _toDateInput(widget.taskDeadline),
    );
    status = (item?['status'] ?? 'todo').toString();
    priority = (item?['priority'] ?? 'medium').toString();
    assigneeId =
        _toInt(item?['assignee_id']) == 0 ? null : _toInt(item?['assignee_id']);
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    progressCtrl.dispose();
    weightCtrl.dispose();
    startCtrl.dispose();
    deadlineCtrl.dispose();
    super.dispose();
  }

  DateTime? get _taskDeadlineCap =>
      VietnamTime.parseDateOnly(widget.taskDeadline);

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime lastDate =
        VietnamTime.pickerLastDateWithCap(_taskDeadlineCap);
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
      setState(() => localMessage = 'Vui lòng nhập tiêu đề đầu việc.');
      return;
    }
    final int? progress = TaskItemProgressInput.tryParseOptional(
      progressCtrl.text,
      onInvalid: (String m) {
        setState(() => localMessage = m);
      },
    );
    if (progress == null) {
      if (progressCtrl.text.trim().isEmpty) {
        setState(() => localMessage = 'Vui lòng nhập tiến độ (0–100%).');
      }
      return;
    }
    final int? weight = int.tryParse(weightCtrl.text.trim());
    if (weight == null || weight < 1 || weight > 100) {
      setState(() => localMessage = 'Tỷ trọng phải từ 1 đến 100.');
      return;
    }
    final DateTime? cap = _taskDeadlineCap;
    if (!VietnamTime.ymdNotAfterCap(startCtrl.text.trim(), cap)) {
      setState(
        () => localMessage =
            'Ngày bắt đầu đầu việc không được sau deadline công việc.',
      );
      return;
    }
    if (!VietnamTime.ymdNotAfterCap(deadlineCtrl.text.trim(), cap)) {
      setState(
        () => localMessage =
            'Hạn đầu việc không được sau deadline công việc.',
      );
      return;
    }

    setState(() {
      submitting = true;
      localMessage = '';
    });

    final bool ok =
        widget.isEdit
            ? await widget.apiService.updateTaskItem(
              widget.token,
              widget.taskId,
              _toInt(widget.editingItem!['id']),
              title: titleCtrl.text.trim(),
              description: descCtrl.text.trim(),
              priority: priority,
              status: status,
              progressPercent: progress,
              weightPercent: weight,
              startDate:
                  startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
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
                  startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
              deadline:
                  deadlineCtrl.text.trim().isEmpty
                      ? null
                      : deadlineCtrl.text.trim(),
              assigneeId: assigneeId,
            );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        submitting = false;
        localMessage =
            widget.isEdit
                ? 'Cập nhật đầu việc thất bại.'
                : 'Tạo đầu việc thất bại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int taskDepartmentId = widget.taskDepartmentId;
    final List<Map<String, dynamic>> staffOptions = <Map<String, dynamic>>[
      for (final Map<String, dynamic> department in widget.departments)
        if (taskDepartmentId == 0 ||
            _toInt(department['id']) == taskDepartmentId)
          ...((department['staff'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map>()
              .map((Map row) => row.cast<String, dynamic>())),
    ];

    return Scaffold(
      backgroundColor: StitchTheme.formPageBackground,
      resizeToAvoidBottomInset: true,
      appBar: stitchFormAppBar(
        context: context,
        title: widget.isEdit ? 'Sửa đầu việc' : 'Thêm đầu việc',
        onClose: submitting ? () {} : () => Navigator.of(context).maybePop(),
      ),
      bottomNavigationBar: StitchFormBottomBar(
        primaryLoading: submitting,
        primaryLabel:
            submitting
                ? 'Đang lưu...'
                : (widget.isEdit ? 'Lưu thay đổi' : 'Tạo đầu việc'),
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
                subtitle:
                    'Nhập tiêu đề, mô tả và phân công để theo dõi tiến độ từng hạng mục.',
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
                    title: 'Trạng thái & tiến độ',
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
                          controller: progressCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Tiến độ (%)',
                            helperText: 'Chỉ 0–100%',
                            suffixText: '%',
                          ).applyDefaults(
                            Theme.of(context).inputDecorationTheme,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tỷ trọng (%)',
                            suffixText: '%',
                          ).applyDefaults(
                            Theme.of(context).inputDecorationTheme,
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
                  StitchSearchableSelectField<int>(
                    value: assigneeId,
                    sheetTitle: 'Chọn nhân sự phụ trách',
                    label: 'Nhân sự phụ trách',
                    searchHint: 'Tìm theo tên hoặc email...',
                    options:
                        staffOptions
                            .map(
                              (Map<String, dynamic> user) =>
                                  StitchSelectOption<int>(
                                    value: _toInt(user['id']),
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

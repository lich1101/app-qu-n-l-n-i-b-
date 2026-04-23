import 'package:flutter/material.dart';

import '../../core/messaging/app_tag_message.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_form_layout.dart';
import '../../core/widgets/stitch_searchable_select.dart';
import '../../core/widgets/stitch_task_form_sheet.dart';
import '../../core/utils/timeline_defaults.dart';
import '../../core/utils/vietnam_time.dart';
import '../../data/services/mobile_api_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({
    super.key,
    required this.token,
    required this.apiService,
    this.initialContractId,
    this.initialContractTitle,
    this.projectId,
    this.initialProject,
    this.canEditAllProjectFields,
  });

  final String token;
  final MobileApiService apiService;
  final String? initialContractId;
  final String? initialContractTitle;
  final int? projectId;
  final Map<String, dynamic>? initialProject;

  /// null = suy từ [initialProject].permissions; true = admin (đủ trường).
  final bool? canEditAllProjectFields;

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController requirementCtrl = TextEditingController();
  final TextEditingController serviceOtherCtrl = TextEditingController();
  final TextEditingController repoUrlCtrl = TextEditingController();
  final TextEditingController websiteUrlCtrl = TextEditingController();

  String selectedContractId = '';
  List<Map<String, dynamic>> contracts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> owners = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> workflowTopics = <Map<String, dynamic>>[];
  String selectedOwnerId = '';
  String selectedWorkflowTopicId = '';
  String originalWorkflowTopicId = '';
  List<_ServiceOptionData> serviceOptions = const <_ServiceOptionData>[
    _ServiceOptionData('backlinks', 'Backlinks', Icons.link),
    _ServiceOptionData('viet_content', 'Content', Icons.edit_note),
    _ServiceOptionData('audit_content', 'Audit Content', Icons.fact_check),
    _ServiceOptionData(
      'cham_soc_website_tong_the',
      'Website Care',
      Icons.public,
    ),
    _ServiceOptionData('noi_bo', 'Dự án nội bộ', Icons.corporate_fare),
    _ServiceOptionData('khac', 'Khác', Icons.more_horiz),
  ];
  String selectedService = 'backlinks';
  DateTime? startDate;
  DateTime? deadline;
  bool saving = false;
  String message = '';

  bool get _isEditMode => (widget.projectId ?? 0) > 0;

  bool get _lockCoreProjectFields {
    if (!_isEditMode) return false;
    if (widget.canEditAllProjectFields != null) {
      return !widget.canEditAllProjectFields!;
    }
    final Map<String, dynamic>? perms =
        widget.initialProject?['permissions'] as Map<String, dynamic>?;
    return perms?['can_edit_all_project_fields'] != true;
  }

  @override
  void initState() {
    super.initState();
    _hydrateInitialProject();
    _loadMeta();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    requirementCtrl.dispose();
    serviceOtherCtrl.dispose();
    repoUrlCtrl.dispose();
    websiteUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    try {
      final Map<String, dynamic> meta = await widget.apiService.getMeta();
      final List<dynamic> services =
          (meta['service_types'] ?? <dynamic>[]) as List<dynamic>;
      List<_ServiceOptionData> mapped = serviceOptions;
      if (services.isNotEmpty) {
        mapped =
            services.map((dynamic e) {
              final String value = e.toString();
              return _ServiceOptionData(
                value,
                _serviceLabel(value),
                _serviceIcon(value),
              );
            }).toList();
      }
      final List<dynamic> responses =
          await Future.wait<dynamic>(<Future<dynamic>>[
            widget.apiService.getContracts(
              widget.token,
              perPage: 200,
              availableOnly: true,
              projectId: _isEditMode ? widget.projectId : null,
            ),
            widget.apiService.getUsersLookup(
              widget.token,
              purpose: 'project_owner',
            ),
            widget.apiService.getWorkflowTopics(widget.token),
          ]);
      if (!mounted) return;
      final Map<String, dynamic> contractPayload =
          responses[0] as Map<String, dynamic>;
      final List<Map<String, dynamic>> ownerRows =
          responses[1] as List<Map<String, dynamic>>;
      final List<Map<String, dynamic>> topicRows =
          responses[2] as List<Map<String, dynamic>>;
      final List<dynamic> contractData =
          (contractPayload['data'] ?? []) as List<dynamic>;
      setState(() {
        serviceOptions = mapped;
        if (mapped.isNotEmpty &&
            !mapped.any((item) => item.value == selectedService)) {
          selectedService = mapped.first.value;
        }
        contracts = contractData.map((e) => e as Map<String, dynamic>).toList();

        if (widget.initialContractId != null &&
            widget.initialContractId!.isNotEmpty) {
          if (!contracts.any((c) => '${c['id']}' == widget.initialContractId)) {
            contracts.insert(0, <String, dynamic>{
              'id': int.tryParse(widget.initialContractId!) ?? 0,
              'code': 'CTR',
              'title': widget.initialContractTitle ?? 'Hợp đồng được chọn',
            });
          }
          selectedContractId = widget.initialContractId!;
        }

        if (_isEditMode &&
            selectedContractId.isNotEmpty &&
            !contracts.any((c) => '${c['id']}' == selectedContractId)) {
          final Map<String, dynamic> currentContract =
              ((widget.initialProject?['contract'] ??
                      widget.initialProject?['linked_contract'])
                  as Map<String, dynamic>?) ??
              <String, dynamic>{};
          contracts.insert(0, <String, dynamic>{
            'id': int.tryParse(selectedContractId) ?? 0,
            'code': (currentContract['code'] ?? 'CTR').toString(),
            'title':
                (currentContract['title'] ?? 'Hợp đồng hiện tại').toString(),
          });
        }

        owners = ownerRows;
        if (_isEditMode &&
            selectedOwnerId.isNotEmpty &&
            !owners.any((u) => '${u['id']}' == selectedOwnerId)) {
          final Map<String, dynamic> currentOwner =
              (widget.initialProject?['owner'] as Map<String, dynamic>?) ??
              <String, dynamic>{};
          owners = <Map<String, dynamic>>[
            <String, dynamic>{
              'id': int.tryParse(selectedOwnerId) ?? 0,
              'name': (currentOwner['name'] ?? 'Nhân sự hiện tại').toString(),
              'role': (currentOwner['role'] ?? 'nhan_vien').toString(),
            },
            ...owners,
          ];
        }
        workflowTopics = topicRows;
        if (!workflowTopics.any(
          (Map<String, dynamic> topic) =>
              '${topic['id']}' == selectedWorkflowTopicId,
        )) {
          selectedWorkflowTopicId = '';
        }
      });
      if (!_isEditMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncDatesFromSelectedContract();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        message = 'Không tải được dữ liệu form dự án. Vui lòng thử lại.';
      });
    }
  }

  void _hydrateInitialProject() {
    if (!_isEditMode) return;
    final Map<String, dynamic> source =
        widget.initialProject ?? <String, dynamic>{};
    if (source.isEmpty) return;

    nameCtrl.text = (source['name'] ?? '').toString();
    requirementCtrl.text = (source['customer_requirement'] ?? '').toString();
    serviceOtherCtrl.text = (source['service_type_other'] ?? '').toString();
    repoUrlCtrl.text = (source['repo_url'] ?? '').toString();
    websiteUrlCtrl.text = (source['website_url'] ?? '').toString();

    final String serviceType = (source['service_type'] ?? '').toString().trim();
    if (serviceType.isNotEmpty) {
      selectedService = serviceType;
    }

    final dynamic rawContractId =
        source['contract_id'] ??
        source['contract']?['id'] ??
        source['linked_contract']?['id'] ??
        0;
    final int contractId = int.tryParse('$rawContractId') ?? 0;
    if (contractId > 0) {
      selectedContractId = '$contractId';
    }

    final int ownerId =
        int.tryParse('${source['owner_id'] ?? source['owner']?['id'] ?? 0}') ??
        0;
    if (ownerId > 0) {
      selectedOwnerId = '$ownerId';
    }

    final int workflowTopicId =
        int.tryParse(
          '${source['workflow_topic_id'] ?? source['workflow_topic']?['id'] ?? 0}',
        ) ??
        0;
    if (workflowTopicId > 0) {
      selectedWorkflowTopicId = '$workflowTopicId';
      originalWorkflowTopicId = '$workflowTopicId';
    } else {
      selectedWorkflowTopicId = '';
      originalWorkflowTopicId = '';
    }

    startDate = _parseDate(source['start_date']);
    deadline = _parseDate(source['deadline']);
  }

  void _syncDatesFromSelectedContract() {
    if (_isEditMode) return;
    if (selectedContractId.isEmpty) return;
    Map<String, dynamic>? row;
    for (final Map<String, dynamic> c in contracts) {
      if ('${c['id']}' == selectedContractId) {
        row = c;
        break;
      }
    }
    if (row == null) return;
    final ({DateTime? start, DateTime? end}) r =
        TimelineDefaults.datesFromContract(row);
    setState(() {
      startDate = r.start;
      deadline = r.end;
    });
  }

  DateTime? _parseDate(dynamic value) {
    return VietnamTime.parse((value ?? '').toString().trim());
  }

  String _serviceLabel(String value) {
    switch (value) {
      case 'backlinks':
        return 'Backlinks';
      case 'viet_content':
        return 'Content';
      case 'audit_content':
        return 'Audit Content';
      case 'cham_soc_website_tong_the':
        return 'Website Care';
      case 'noi_bo':
        return 'Dự án nội bộ';
      case 'khac':
        return 'Khác';
      default:
        return value.replaceAll('_', ' ');
    }
  }

  IconData _serviceIcon(String value) {
    switch (value) {
      case 'backlinks':
        return Icons.link;
      case 'viet_content':
        return Icons.edit_note;
      case 'audit_content':
        return Icons.fact_check;
      case 'cham_soc_website_tong_the':
        return Icons.public;
      case 'noi_bo':
        return Icons.corporate_fare;
      case 'khac':
        return Icons.more_horiz;
      default:
        return Icons.work_outline;
    }
  }

  Future<void> _pickDeadline() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
      initialDate: deadline ?? now,
    );
    if (date == null) return;
    setState(() => deadline = date);
  }

  Future<void> _pickStartDate() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: DateTime(now.year + 10),
      initialDate: startDate ?? now,
    );
    if (date == null) return;
    setState(() => startDate = date);
  }

  String? _toYmd(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmWorkflowReapply() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận đổi barem'),
          content: const Text(
            'Đổi sang topic mới sẽ xóa toàn bộ công việc/đầu việc hiện tại để sinh lại theo barem mới. Bạn có chắc chắn muốn tiếp tục?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Đồng ý đổi'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _submit() async {
    final String name = nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => message = 'Vui lòng nhập tên dự án.');
      return;
    }
    if (selectedService == 'khac' && serviceOtherCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập loại dịch vụ khác.');
      return;
    }
    setState(() {
      saving = true;
      message = '';
    });
    final int? newWorkflowTopicId =
        selectedWorkflowTopicId.isEmpty
            ? null
            : int.tryParse(selectedWorkflowTopicId);
    final int? oldWorkflowTopicId =
        originalWorkflowTopicId.isEmpty
            ? null
            : int.tryParse(originalWorkflowTopicId);

    bool confirmReapplyWorkflow = false;
    if (_isEditMode &&
        oldWorkflowTopicId != null &&
        oldWorkflowTopicId > 0 &&
        newWorkflowTopicId != null &&
        newWorkflowTopicId > 0 &&
        oldWorkflowTopicId != newWorkflowTopicId) {
      final bool confirmed = await _confirmWorkflowReapply();
      if (!mounted) return;
      if (!confirmed) {
        setState(() {
          saving = false;
          message = 'Đã huỷ cập nhật barem topic.';
        });
        return;
      }
      confirmReapplyWorkflow = true;
    }

    bool ok = false;
    String failureMessage =
        _isEditMode ? 'Cập nhật dự án thất bại.' : 'Tạo dự án thất bại.';

    if (_isEditMode) {
      Map<String, dynamic>
      result = await widget.apiService.updateProjectWithMeta(
        widget.token,
        widget.projectId!,
        name: name,
        serviceType: selectedService,
        serviceTypeOther:
            selectedService == 'khac' ? serviceOtherCtrl.text.trim() : null,
        contractId: int.tryParse(selectedContractId),
        ownerId: selectedOwnerId.isEmpty ? null : int.tryParse(selectedOwnerId),
        workflowTopicId: newWorkflowTopicId,
        startDate: _toYmd(startDate),
        deadline: _toYmd(deadline),
        customerRequirement:
            requirementCtrl.text.trim().isEmpty
                ? null
                : requirementCtrl.text.trim(),
        repoUrl:
            repoUrlCtrl.text.trim().isEmpty ? null : repoUrlCtrl.text.trim(),
        websiteUrl:
            websiteUrlCtrl.text.trim().isEmpty
                ? null
                : websiteUrlCtrl.text.trim(),
        confirmReapplyWorkflow: confirmReapplyWorkflow ? true : null,
      );
      ok = result['ok'] == true;
      if (!ok) {
        final String code = (result['code'] ?? '').toString();
        if (code == 'workflow_topic_reapply_confirmation_required') {
          final bool confirmed = await _confirmWorkflowReapply();
          if (confirmed) {
            result = await widget.apiService.updateProjectWithMeta(
              widget.token,
              widget.projectId!,
              name: name,
              serviceType: selectedService,
              serviceTypeOther:
                  selectedService == 'khac'
                      ? serviceOtherCtrl.text.trim()
                      : null,
              contractId: int.tryParse(selectedContractId),
              ownerId:
                  selectedOwnerId.isEmpty
                      ? null
                      : int.tryParse(selectedOwnerId),
              workflowTopicId: newWorkflowTopicId,
              startDate: _toYmd(startDate),
              deadline: _toYmd(deadline),
              customerRequirement:
                  requirementCtrl.text.trim().isEmpty
                      ? null
                      : requirementCtrl.text.trim(),
              repoUrl:
                  repoUrlCtrl.text.trim().isEmpty
                      ? null
                      : repoUrlCtrl.text.trim(),
              websiteUrl:
                  websiteUrlCtrl.text.trim().isEmpty
                      ? null
                      : websiteUrlCtrl.text.trim(),
              confirmReapplyWorkflow: true,
            );
            ok = result['ok'] == true;
            if (!ok) {
              failureMessage = (result['message'] ?? failureMessage).toString();
            }
          } else {
            failureMessage = 'Đã huỷ cập nhật barem topic.';
          }
        } else {
          failureMessage = (result['message'] ?? failureMessage).toString();
        }
      }
    } else {
      ok = await widget.apiService.createProject(
        widget.token,
        name: name,
        serviceType: selectedService,
        serviceTypeOther:
            selectedService == 'khac' ? serviceOtherCtrl.text.trim() : null,
        contractId: int.tryParse(selectedContractId),
        ownerId: selectedOwnerId.isEmpty ? null : int.tryParse(selectedOwnerId),
        workflowTopicId: newWorkflowTopicId,
        startDate: _toYmd(startDate),
        deadline: _toYmd(deadline),
        customerRequirement:
            requirementCtrl.text.trim().isEmpty
                ? null
                : requirementCtrl.text.trim(),
        repoUrl:
            repoUrlCtrl.text.trim().isEmpty ? null : repoUrlCtrl.text.trim(),
        websiteUrl:
            websiteUrlCtrl.text.trim().isEmpty
                ? null
                : websiteUrlCtrl.text.trim(),
      );
    }
    if (!mounted) return;
    setState(() {
      saving = false;
      message =
          ok
              ? (_isEditMode
                  ? 'Cập nhật dự án thành công.'
                  : 'Tạo dự án thành công.')
              : failureMessage;
    });
    if (ok) {
      AppTagMessage.show(
        _isEditMode ? 'Cập nhật dự án thành công.' : 'Tạo dự án thành công.',
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String deadlineLabel =
        deadline == null
            ? 'Chọn ngày'
            : '${deadline!.day.toString().padLeft(2, '0')}/'
                '${deadline!.month.toString().padLeft(2, '0')}/'
                '${deadline!.year}';
    final String startDateLabel =
        startDate == null
            ? 'Chọn ngày'
            : '${startDate!.day.toString().padLeft(2, '0')}/'
                '${startDate!.month.toString().padLeft(2, '0')}/'
                '${startDate!.year}';
    InputDecoration fieldDecoration(
      String label, {
      String? hint,
      IconData? prefixIcon,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 18, color: StitchTheme.textSubtle),
        suffixIcon: suffixIcon,
      );
    }

    return Scaffold(
      backgroundColor: StitchTheme.formPageBackground,
      resizeToAvoidBottomInset: true,
      appBar: stitchFormAppBar(
        context: context,
        title: _isEditMode ? 'Sửa dự án' : 'Tạo dự án',
        onClose: saving ? () {} : () => Navigator.of(context).maybePop(),
      ),
      bottomNavigationBar: StitchFormBottomBar(
        primaryLoading: saving,
        primaryLabel:
            saving
                ? (_isEditMode ? 'Đang cập nhật...' : 'Đang tạo...')
                : (_isEditMode ? 'Lưu cập nhật dự án' : 'Tạo dự án ngay'),
        onPrimary: saving ? null : _submit,
        onSecondary: saving ? null : () => Navigator.of(context).maybePop(),
        secondaryLabel: 'Hủy',
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            StitchFormSection(
              margin: EdgeInsets.zero,
              child: stitchTaskFormSheetHeader(
                context,
                subtitle:
                    _isEditMode
                        ? (_lockCoreProjectFields
                            ? 'Bạn là phụ trách dự án: chỉ sửa được tên, loại dịch vụ, trạng thái, yêu cầu, link… (không đổi HĐ, barem, ngày, chủ dự án).'
                            : 'Điều chỉnh thông tin dự án. Nếu đổi topic barem, hệ thống sẽ yêu cầu xác nhận làm mới công việc.')
                        : 'Điền thông tin chính xác để hệ thống tự liên kết hợp đồng, nhân sự triển khai và luồng công việc.',
              ),
            ),
            StitchFormSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const StitchFormSectionHeader(
                    icon: Icons.info_outline_rounded,
                    title: 'Thông tin cơ bản',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: fieldDecoration(
                      'Tên dự án',
                      hint: 'Ví dụ: Chiến dịch SEO Q4',
                      prefixIcon: Icons.work_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StitchSearchableSelectField<String>(
                    value:
                        contracts.any((c) => '${c['id']}' == selectedContractId)
                            ? selectedContractId
                            : (selectedContractId.isEmpty ? '' : null),
                    sheetTitle: 'Chọn hợp đồng',
                    label: 'Hợp đồng liên kết',
                    searchHint: 'Tìm theo mã hoặc tiêu đề hợp đồng...',
                    options: <StitchSelectOption<String>>[
                      const StitchSelectOption<String>(
                        value: '',
                        label: 'Không liên kết hợp đồng (dự án nội bộ)',
                      ),
                      ...contracts.map(
                        (Map<String, dynamic> c) => StitchSelectOption<String>(
                          value: '${c['id']}',
                          label: '${c['code'] ?? 'CTR'} • ${c['title'] ?? ''}',
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      final String next = value ?? '';
                      setState(() => selectedContractId = next);
                      if (next.isEmpty) {
                        setState(() {
                          startDate = null;
                          deadline = null;
                        });
                        return;
                      }
                      _syncDatesFromSelectedContract();
                    },
                    enabled: !_lockCoreProjectFields,
                    decoration: fieldDecoration(
                      'Hợp đồng liên kết',
                      prefixIcon: Icons.description_outlined,
                    ),
                  ),
                  if (contracts.isEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa có hợp đồng để chọn. Bạn vẫn có thể tạo dự án nội bộ.',
                      style: TextStyle(
                        color: StitchTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  StitchSearchableSelectField<String>(
                    value: selectedOwnerId.isEmpty ? null : selectedOwnerId,
                    sheetTitle: 'Chọn người phụ trách',
                    label: 'Người phụ trách triển khai',
                    searchHint: 'Tìm theo tên hoặc vai trò...',
                    options:
                        owners
                            .map(
                              (
                                Map<String, dynamic> u,
                              ) => StitchSelectOption<String>(
                                value: '${u['id']}',
                                label:
                                    '${u['name'] ?? ''} (${u['role'] ?? ''})',
                              ),
                            )
                            .toList(),
                    onChanged: (String? value) {
                      setState(() => selectedOwnerId = value ?? '');
                    },
                    enabled: !_lockCoreProjectFields,
                    decoration: fieldDecoration(
                      'Người phụ trách triển khai',
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StitchSearchableSelectField<String>(
                    value:
                        selectedWorkflowTopicId.isEmpty
                            ? ''
                            : selectedWorkflowTopicId,
                    sheetTitle: 'Chọn barem theo Topic',
                    label: 'Barem công việc theo Topic',
                    searchHint: 'Tìm theo tên topic...',
                    options: <StitchSelectOption<String>>[
                      const StitchSelectOption<String>(
                        value: '',
                        label: 'Không dùng barem (tạo dự án trống)',
                      ),
                      ...workflowTopics.map(
                        (
                          Map<String, dynamic> topic,
                        ) => StitchSelectOption<String>(
                          value: '${topic['id']}',
                          label:
                              '${topic['name'] ?? ''}'
                              '${(topic['code'] ?? '').toString().isEmpty ? '' : ' • ${topic['code']}'}'
                              ' (${(topic['tasks'] as List<dynamic>? ?? <dynamic>[]).length} công việc mẫu)',
                        ),
                      ),
                    ],
                    onChanged: (String? value) {
                      setState(() => selectedWorkflowTopicId = value ?? '');
                    },
                    enabled: !_lockCoreProjectFields,
                    decoration: fieldDecoration(
                      'Barem công việc theo Topic',
                      prefixIcon: Icons.account_tree_outlined,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nếu chọn barem, hệ thống tự sinh công việc và đầu việc theo timeline dự án.',
                    style: TextStyle(
                      color: StitchTheme.textMuted,
                      fontSize: 12,
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
                    icon: Icons.category_outlined,
                    title: 'Loại dịch vụ',
                  ),
                  const Text(
                    'Chọn loại dịch vụ chính cho dự án.',
                    style: TextStyle(
                      color: StitchTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.65,
                    children:
                        serviceOptions
                            .map(
                              (option) => _ServiceOption(
                                label: option.label,
                                icon: option.icon,
                                selected: selectedService == option.value,
                                onTap:
                                    () => setState(
                                      () => selectedService = option.value,
                                    ),
                              ),
                            )
                            .toList(),
                  ),
                  if (selectedService == 'khac') ...<Widget>[
                    const SizedBox(height: 10),
                    TextField(
                      controller: serviceOtherCtrl,
                      decoration: fieldDecoration(
                        'Loại dịch vụ khác',
                        hint: 'Nhập tên dịch vụ',
                        prefixIcon: Icons.edit_note_outlined,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            StitchFormSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const StitchFormSectionHeader(
                    icon: Icons.calendar_today_outlined,
                    title: 'Thời gian & tài liệu',
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: GestureDetector(
                          onTap: _lockCoreProjectFields ? null : _pickStartDate,
                          child: AbsorbPointer(
                            child: TextField(
                              decoration: fieldDecoration(
                                'Ngày bắt đầu',
                                hint: startDateLabel,
                                prefixIcon: Icons.event_available_outlined,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _lockCoreProjectFields ? null : _pickDeadline,
                          child: AbsorbPointer(
                            child: TextField(
                              decoration: fieldDecoration(
                                'Hạn chót tổng',
                                hint: deadlineLabel,
                                prefixIcon: Icons.event_outlined,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: requirementCtrl,
                    maxLines: 4,
                    decoration: fieldDecoration(
                      'Yêu cầu của khách hàng',
                      hint:
                          'Mô tả chi tiết các yêu cầu và mong muốn từ khách hàng...',
                      prefixIcon: Icons.notes_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: repoUrlCtrl,
                    decoration: fieldDecoration(
                      'Link lưu tài liệu dự án (tuỳ chọn)',
                      hint: 'https://example.com/...',
                      prefixIcon: Icons.folder_open_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: websiteUrlCtrl,
                    decoration: fieldDecoration(
                      'Website dự án (Google Search Console)',
                      hint: 'https://example.com/',
                      prefixIcon: Icons.language_outlined,
                    ),
                  ),
                ],
              ),
            ),
            if (message.isNotEmpty) ...<Widget>[
              StitchFormSection(
                margin: EdgeInsets.zero,
                child: Text(
                  message,
                  style: TextStyle(
                    color:
                        message.contains('thành công')
                            ? StitchTheme.success
                            : StitchTheme.danger,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceOption extends StatelessWidget {
  const _ServiceOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? StitchTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? StitchTheme.primary : StitchTheme.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: selected ? Colors.white : StitchTheme.textSubtle),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: selected ? Colors.white : StitchTheme.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOptionData {
  const _ServiceOptionData(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

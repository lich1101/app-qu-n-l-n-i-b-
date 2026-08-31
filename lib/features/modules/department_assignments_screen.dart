import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class DepartmentAssignmentsScreen extends StatefulWidget {
  const DepartmentAssignmentsScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canCreate,
    required this.canUpdate,
  });

  final String token;
  final MobileApiService apiService;
  final bool canCreate;
  final bool canUpdate;

  @override
  State<DepartmentAssignmentsScreen> createState() =>
      _DepartmentAssignmentsScreenState();
}

class _DepartmentAssignmentsScreenState
    extends State<DepartmentAssignmentsScreen> {
  bool loading = false;
  String message = '';
  List<Map<String, dynamic>> assignments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> departments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> contracts = <Map<String, dynamic>>[];
  int? formClientId;
  int? formContractId;
  int? formDepartmentId;
  final TextEditingController requirementCtrl = TextEditingController();
  final TextEditingController deadlineCtrl = TextEditingController();
  final TextEditingController valueCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    requirementCtrl.dispose();
    deadlineCtrl.dispose();
    valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getDepartmentAssignments(widget.token);
    final List<Map<String, dynamic>> deptRows = await widget.apiService
        .getDepartments(widget.token);

    final Map<String, dynamic> clientPayload = await widget.apiService
        .getClients(widget.token, perPage: 100);
    final Map<String, dynamic> contractPayload = await widget.apiService
        .getContracts(widget.token, perPage: 100);

    if (!mounted) return;

    final List<dynamic> clientData =
        (clientPayload['data'] ?? []) as List<dynamic>;
    final List<dynamic> contractData =
        (contractPayload['data'] ?? []) as List<dynamic>;

    setState(() {
      loading = false;
      assignments = rows;
      departments = deptRows;
      clients = clientData.map((e) => e as Map<String, dynamic>).toList();
      contracts = contractData.map((e) => e as Map<String, dynamic>).toList();
    });
  }

  Future<bool> _create() async {
    if (!widget.canCreate) {
      setState(() => message = 'Bạn không có quyền tạo điều phối.');
      return false;
    }
    if (formClientId == null || formDepartmentId == null) {
      setState(() => message = 'Vui lòng chọn khách hàng và phòng ban.');
      return false;
    }
    final double? value = double.tryParse(valueCtrl.text.trim());
    final bool ok = await widget.apiService.createDepartmentAssignment(
      widget.token,
      clientId: formClientId!,
      contractId: formContractId,
      departmentId: formDepartmentId!,
      requirements:
          requirementCtrl.text.trim().isEmpty
              ? null
              : requirementCtrl.text.trim(),
      deadline:
          deadlineCtrl.text.trim().isEmpty ? null : deadlineCtrl.text.trim(),
      allocatedValue: value,
    );
    if (!mounted) return false;
    setState(
      () => message = ok ? 'Đã tạo điều phối.' : 'Tạo điều phối thất bại.',
    );
    if (ok) {
      formClientId = null;
      formContractId = null;
      formDepartmentId = null;
      requirementCtrl.clear();
      deadlineCtrl.clear();
      valueCtrl.clear();
      await _fetch();
    }
    return ok;
  }

  void _resetForm() {
    formClientId = null;
    formContractId = null;
    formDepartmentId = null;
    requirementCtrl.clear();
    deadlineCtrl.clear();
    valueCtrl.clear();
  }

  bool get _messageIsError =>
      message.contains('thất bại') ||
      message.startsWith('Vui lòng') ||
      message.contains('không');

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'Đang triển khai';
      case 'done':
        return 'Hoàn tất';
      default:
        return 'Mới';
    }
  }

  Future<void> _openForm() async {
    setState(() {
      message = '';
      _resetForm();
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              decoration: stitchFormSheetSurfaceDecoration(),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const StitchFormSheetTitleBar(
                      title: 'Tạo điều phối',
                      subtitle:
                          'Chọn khách hàng, phòng ban và yêu cầu để phân phối công việc nội bộ.',
                      icon: Icons.account_tree_rounded,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Column(
                        children: <Widget>[
                          DropdownButtonFormField<int>(
                            value: formClientId,
                            decoration: const InputDecoration(
                              labelText: 'Khách hàng',
                            ),
                            items:
                                clients
                                    .map(
                                      (client) => DropdownMenuItem<int>(
                                        value: client['id'] as int,
                                        child: Text(
                                          (client['name'] ?? '').toString(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) =>
                                    setSheetState(() => formClientId = value),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            value: formContractId,
                            decoration: const InputDecoration(
                              labelText: 'Hợp đồng',
                            ),
                            items:
                                contracts
                                    .map(
                                      (contract) => DropdownMenuItem<int>(
                                        value: contract['id'] as int,
                                        child: Text(
                                          (contract['title'] ?? '').toString(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) =>
                                    setSheetState(() => formContractId = value),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            value: formDepartmentId,
                            decoration: const InputDecoration(
                              labelText: 'Phòng ban',
                            ),
                            items:
                                departments
                                    .map(
                                      (dept) => DropdownMenuItem<int>(
                                        value: dept['id'] as int,
                                        child: Text(
                                          (dept['name'] ?? '').toString(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setSheetState(
                                  () => formDepartmentId = value,
                                ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: deadlineCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Hạn chót (YYYY-MM-DD)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: valueCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Giá trị phân bổ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: requirementCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Yêu cầu chi tiết',
                            ),
                            maxLines: 2,
                          ),
                          if (message.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            StitchFeedbackBanner(
                              message: message,
                              isError: _messageIsError,
                            ),
                          ],
                        ],
                      ),
                    ),
                    StitchFormSheetActions(
                      primaryLabel: 'Tạo điều phối',
                      onPrimary: () async {
                        final bool ok = await _create();
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.of(context).pop();
                        } else {
                          setSheetState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() => _resetForm());
  }

  Future<void> _updateProgress(
    Map<String, dynamic> assignment,
    String status,
    int progressPercent,
    String note,
  ) async {
    if (!widget.canUpdate) return;
    final bool ok = await widget.apiService.updateDepartmentAssignment(
      widget.token,
      assignment['id'] as int,
      status: status,
      progressPercent: progressPercent,
      progressNote: note,
    );
    if (!mounted) return;
    setState(
      () => message = ok ? 'Đã cập nhật tiến độ.' : 'Cập nhật thất bại.',
    );
    if (ok) await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điều phối phòng ban'),
        actions: <Widget>[
          if (widget.canCreate)
            IconButton(icon: const Icon(Icons.add), onPressed: _openForm),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              StitchAdminHeader(
                title: 'Danh sách điều phối',
                subtitle:
                    'Theo dõi việc phân bổ khách hàng, hợp đồng và tiến độ xử lý theo từng phòng ban.',
                icon: Icons.account_tree_rounded,
                actionLabel: widget.canCreate ? 'Thêm' : null,
                onAction: widget.canCreate ? _openForm : null,
              ),
              if (message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: StitchFeedbackBanner(
                    message: message,
                    isError: _messageIsError,
                  ),
                ),
              const SizedBox(height: 14),
              if (loading)
                const StitchLoadingState(label: 'Đang tải điều phối...')
              else if (assignments.isEmpty)
                const StitchEmptyState(
                  title: 'Chưa có điều phối',
                  subtitle:
                      'Tạo điều phối để các phòng ban nhìn rõ khách hàng và yêu cầu cần xử lý.',
                  icon: Icons.account_tree_outlined,
                )
              else
                ...assignments.map((assignment) {
                  final Map<String, dynamic>? client =
                      assignment['client'] as Map<String, dynamic>?;
                  final Map<String, dynamic>? dept =
                      assignment['department'] as Map<String, dynamic>?;
                  final TextEditingController noteCtrl = TextEditingController(
                    text: (assignment['progress_note'] ?? '').toString(),
                  );
                  int progress =
                      int.tryParse(
                        (assignment['progress_percent'] ?? 0).toString(),
                      ) ??
                      0;
                  String status = (assignment['status'] ?? 'new').toString();
                  return StitchFilterCard(
                    title: (client?['name'] ?? 'Khách hàng').toString(),
                    subtitle: 'Phòng ban: ${(dept?['name'] ?? '—').toString()}',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: StitchTheme.progressPercentFillColor(
                          progress,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: StitchTheme.progressPercentFillColor(progress),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Text(
                              'Tiến độ',
                              style: TextStyle(
                                color: StitchTheme.textMuted,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$progress%',
                              style: TextStyle(
                                color: StitchTheme.progressPercentFillColor(
                                  progress,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: progress.clamp(0, 100) / 100,
                            color: StitchTheme.progressPercentFillColor(
                              progress,
                            ),
                            backgroundColor: StitchTheme.surfaceAlt,
                          ),
                        ),
                        if ((assignment['requirements'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            (assignment['requirements'] ?? '').toString(),
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (widget.canUpdate) ...<Widget>[
                          const Divider(height: 24),
                          DropdownButtonFormField<String>(
                            value: status,
                            decoration: const InputDecoration(
                              labelText: 'Trạng thái',
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(
                                value: 'new',
                                child: Text('Mới'),
                              ),
                              DropdownMenuItem(
                                value: 'in_progress',
                                child: Text('Đang triển khai'),
                              ),
                              DropdownMenuItem(
                                value: 'done',
                                child: Text('Hoàn tất'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              status = value;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Tiến độ (%)',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              progress = int.tryParse(value) ?? progress;
                            },
                            controller: TextEditingController(
                              text: progress.toString(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: noteCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ghi chú',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed:
                                () => _updateProgress(
                                  assignment,
                                  status,
                                  progress,
                                  noteCtrl.text.trim(),
                                ),
                            child: const Text('Cập nhật'),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

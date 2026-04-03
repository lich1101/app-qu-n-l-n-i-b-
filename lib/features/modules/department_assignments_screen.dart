import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
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
    final List<Map<String, dynamic>> rows =
        await widget.apiService.getDepartmentAssignments(widget.token);
    final List<Map<String, dynamic>> deptRows =
        await widget.apiService.getDepartments(widget.token);

    final Map<String, dynamic> clientPayload =
        await widget.apiService.getClients(widget.token, perPage: 100);
    final Map<String, dynamic> contractPayload =
        await widget.apiService.getContracts(widget.token, perPage: 100);

    if (!mounted) return;

    final List<dynamic> clientData = (clientPayload['data'] ?? []) as List<dynamic>;
    final List<dynamic> contractData = (contractPayload['data'] ?? []) as List<dynamic>;

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
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: StitchTheme.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Tạo điều phối',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
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
                          (value) => setSheetState(() => formClientId = value),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: formContractId,
                      decoration: const InputDecoration(labelText: 'Hợp đồng'),
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
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: formDepartmentId,
                      decoration: const InputDecoration(labelText: 'Phòng ban'),
                      items:
                          departments
                              .map(
                                (dept) => DropdownMenuItem<int>(
                                  value: dept['id'] as int,
                                  child: Text((dept['name'] ?? '').toString()),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) =>
                              setSheetState(() => formDepartmentId = value),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deadlineCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hạn chót (YYYY-MM-DD)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: valueCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Giá trị phân bổ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: requirementCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Yêu cầu chi tiết',
                      ),
                      maxLines: 2,
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final bool ok = await _create();
                              if (!mounted) return;
                              if (ok) {
                                Navigator.of(context).pop();
                              } else {
                                setSheetState(() {});
                              }
                            },
                            child: const Text('Tạo điều phối'),
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
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Danh sách điều phối',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.canCreate)
                    ElevatedButton.icon(
                      onPressed: _openForm,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Thêm'),
                    ),
                ],
              ),
              if (message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    message,
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                ),
              const SizedBox(height: 16),
              if (loading)
                const Center(child: CircularProgressIndicator())
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
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (client?['name'] ?? 'Khách hàng').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            (dept?['name'] ?? 'Phòng ban').toString(),
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Trạng thái: ${(assignment['status'] ?? 'new').toString()}',
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                            ),
                          ),
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

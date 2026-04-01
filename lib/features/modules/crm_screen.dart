import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManageClients,
    required this.canManagePayments,
    required this.canDelete,
    required this.currentUserRole,
  });

  final String token;
  final MobileApiService apiService;
  final bool canManageClients;
  final bool canManagePayments;
  final bool canDelete;
  final String currentUserRole;

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  bool loading = false;
  String search = '';
  String message = '';
  List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> payments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> leadTypes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> departments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> staffUsers = <Map<String, dynamic>>[];
  int? leadTypeId;
  int? assignedDepartmentId;
  int? assignedStaffId;
  List<int> careStaffIds = <int>[];
  int? editingClientId;
  int? editingPaymentId;
  final TextEditingController clientNameCtrl = TextEditingController();
  final TextEditingController clientCompanyCtrl = TextEditingController();
  final TextEditingController clientEmailCtrl = TextEditingController();
  final TextEditingController clientPhoneCtrl = TextEditingController();
  final TextEditingController leadSourceCtrl = TextEditingController();
  final TextEditingController leadChannelCtrl = TextEditingController();
  final TextEditingController leadMessageCtrl = TextEditingController();
  final TextEditingController paymentAmountCtrl = TextEditingController();
  String paymentStatus = 'pending';
  int? paymentClientId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    clientNameCtrl.dispose();
    clientCompanyCtrl.dispose();
    clientEmailCtrl.dispose();
    clientPhoneCtrl.dispose();
    leadSourceCtrl.dispose();
    leadChannelCtrl.dispose();
    leadMessageCtrl.dispose();
    paymentAmountCtrl.dispose();
    super.dispose();
  }

  List<int> _normalizeCareStaffIds(dynamic value) {
    if (value is! List<dynamic>) {
      return <int>[];
    }

    final Set<int> ids = <int>{};
    for (final dynamic item in value) {
      if (item is Map<String, dynamic>) {
        final int id =
            int.tryParse((item['id'] ?? '').toString()) ?? 0;
        if (id > 0) {
          ids.add(id);
        }
      } else if (item is int && item > 0) {
        ids.add(item);
      }
    }

    return ids.toList()..sort();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final bool isAdmin = widget.currentUserRole == 'admin';
    final List<Map<String, dynamic>> types = await widget.apiService
        .getLeadTypes(widget.token);
    final List<Map<String, dynamic>> deptData =
        isAdmin
            ? await widget.apiService.getDepartments(widget.token)
            : <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> staffData =
        isAdmin
            ? await widget.apiService.getUsersAccounts(widget.token)
            : <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> c = await widget.apiService.getClients(
      widget.token,
    );
    final List<Map<String, dynamic>> p = await widget.apiService.getPayments(
      widget.token,
    );
    setState(() {
      loading = false;
      leadTypes = types;
      departments = deptData;
      staffUsers = staffData;
      if (leadTypeId == null && types.isNotEmpty) {
        leadTypeId = types.first['id'] as int?;
      }
      clients = c;
      payments = p;
    });
  }

  Future<void> _importClients() async {
    if (!widget.canManageClients) {
      setState(() => message = 'Bạn không có quyền import khách hàng.');
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xls', 'xlsx', 'csv'],
    );
    if (result == null || result.files.single.path == null) return;
    final File file = File(result.files.single.path!);
    final Map<String, dynamic> report = await widget.apiService.importClients(
      widget.token,
      file,
    );
    if (!mounted) return;
    final List<dynamic> errors =
        (report['errors'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> warnings =
        (report['warnings'] as List<dynamic>?) ?? <dynamic>[];

    final StringBuffer summary = StringBuffer();
    if (report['error'] != null) {
      summary.write('Import thất bại.');
    } else {
      summary.write(
        'Import hoàn tất: ${(report['created'] ?? 0)} tạo mới, ${(report['updated'] ?? 0)} cập nhật, ${(report['skipped'] ?? 0)} bỏ qua.',
      );
    }
    if (errors.isNotEmpty) {
      final dynamic first = errors.first;
      summary.write(
        '\nLỗi: dòng ${first is Map<String, dynamic> ? (first['row'] ?? '-') : '-'} - ${first is Map<String, dynamic> ? (first['message'] ?? 'Không xác định') : first.toString()}',
      );
    }
    if (warnings.isNotEmpty) {
      final dynamic first = warnings.first;
      summary.write(
        '\nCảnh báo: dòng ${first is Map<String, dynamic> ? (first['row'] ?? '-') : '-'} - ${first is Map<String, dynamic> ? (first['message'] ?? 'Không xác định') : first.toString()}',
      );
    }
    setState(() {
      message = summary.toString();
    });
    await _fetch();
  }

  Future<bool> _saveClient() async {
    if (!widget.canManageClients) {
      setState(() => message = 'Bạn không có quyền quản lý khách hàng.');
      return false;
    }
    if (clientNameCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập tên khách hàng.');
      return false;
    }
    final bool ok =
        editingClientId == null
            ? await widget.apiService.createClient(
              widget.token,
              name: clientNameCtrl.text.trim(),
              company:
                  clientCompanyCtrl.text.trim().isEmpty
                      ? null
                      : clientCompanyCtrl.text.trim(),
              email:
                  clientEmailCtrl.text.trim().isEmpty
                      ? null
                      : clientEmailCtrl.text.trim(),
              phone:
                  clientPhoneCtrl.text.trim().isEmpty
                      ? null
                      : clientPhoneCtrl.text.trim(),
              careStaffIds: careStaffIds,
              assignedDepartmentId: assignedDepartmentId,
              assignedStaffId: assignedStaffId,
              leadTypeId: leadTypeId,
              leadSource:
                  leadSourceCtrl.text.trim().isEmpty
                      ? null
                      : leadSourceCtrl.text.trim(),
              leadChannel:
                  leadChannelCtrl.text.trim().isEmpty
                      ? null
                      : leadChannelCtrl.text.trim(),
              leadMessage:
                  leadMessageCtrl.text.trim().isEmpty
                      ? null
                      : leadMessageCtrl.text.trim(),
            )
            : await widget.apiService.updateClient(
              widget.token,
              editingClientId!,
              name: clientNameCtrl.text.trim(),
              company:
                  clientCompanyCtrl.text.trim().isEmpty
                      ? null
                      : clientCompanyCtrl.text.trim(),
              email:
                  clientEmailCtrl.text.trim().isEmpty
                      ? null
                      : clientEmailCtrl.text.trim(),
              phone:
                  clientPhoneCtrl.text.trim().isEmpty
                      ? null
                      : clientPhoneCtrl.text.trim(),
              careStaffIds: careStaffIds,
              assignedDepartmentId: assignedDepartmentId,
              assignedStaffId: assignedStaffId,
              leadTypeId: leadTypeId,
              leadSource:
                  leadSourceCtrl.text.trim().isEmpty
                      ? null
                      : leadSourceCtrl.text.trim(),
              leadChannel:
                  leadChannelCtrl.text.trim().isEmpty
                      ? null
                      : leadChannelCtrl.text.trim(),
              leadMessage:
                  leadMessageCtrl.text.trim().isEmpty
                      ? null
                      : leadMessageCtrl.text.trim(),
            );
    if (!mounted) return false;
    setState(() {
      message =
          ok
              ? (editingClientId == null
                  ? 'Tạo khách hàng thành công.'
                  : 'Cập nhật khách hàng thành công.')
              : 'Lưu khách hàng thất bại.';
      if (ok) {
        editingClientId = null;
        clientNameCtrl.clear();
        clientCompanyCtrl.clear();
        clientEmailCtrl.clear();
        clientPhoneCtrl.clear();
        leadSourceCtrl.clear();
        leadChannelCtrl.clear();
        leadMessageCtrl.clear();
        leadTypeId =
            leadTypes.isNotEmpty ? leadTypes.first['id'] as int? : null;
        assignedDepartmentId = null;
        assignedStaffId = null;
        careStaffIds = <int>[];
      }
    });
    if (ok) await _fetch();
    return ok;
  }

  Future<void> _deleteClient(int id) async {
    if (!widget.canDelete) {
      setState(() => message = 'Bạn không có quyền xóa khách hàng.');
      return;
    }
    final bool ok = await widget.apiService.deleteClient(widget.token, id);
    if (!mounted) return;
    setState(() {
      message = ok ? 'Xóa khách hàng thành công.' : 'Xóa khách hàng thất bại.';
    });
    if (ok) await _fetch();
  }

  Future<bool> _savePayment() async {
    if (!widget.canManagePayments) {
      setState(() => message = 'Bạn không có quyền quản lý thanh toán.');
      return false;
    }
    final double? amount = double.tryParse(paymentAmountCtrl.text.trim());
    if (paymentClientId == null || amount == null) {
      setState(
        () => message = 'Vui lòng chọn khách hàng và nhập số tiền hợp lệ.',
      );
      return false;
    }
    final bool ok =
        editingPaymentId == null
            ? await widget.apiService.createPayment(
              widget.token,
              clientId: paymentClientId!,
              amount: amount,
              status: paymentStatus,
            )
            : await widget.apiService.updatePayment(
              widget.token,
              editingPaymentId!,
              clientId: paymentClientId!,
              amount: amount,
              status: paymentStatus,
            );
    if (!mounted) return false;
    setState(() {
      message =
          ok
              ? (editingPaymentId == null
                  ? 'Tạo thanh toán thành công.'
                  : 'Cập nhật thanh toán thành công.')
              : 'Lưu thanh toán thất bại.';
      if (ok) {
        editingPaymentId = null;
        paymentAmountCtrl.clear();
        paymentClientId = null;
        paymentStatus = 'pending';
      }
    });
    if (ok) await _fetch();
    return ok;
  }

  Future<void> _deletePayment(int id) async {
    if (!widget.canDelete) {
      setState(() => message = 'Bạn không có quyền xóa thanh toán.');
      return;
    }
    final bool ok = await widget.apiService.deletePayment(widget.token, id);
    if (!mounted) return;
    setState(() {
      message = ok ? 'Xóa thanh toán thành công.' : 'Xóa thanh toán thất bại.';
    });
    if (ok) await _fetch();
  }

  void _resetClientForm() {
    editingClientId = null;
    clientNameCtrl.clear();
    clientCompanyCtrl.clear();
    clientEmailCtrl.clear();
    clientPhoneCtrl.clear();
    leadSourceCtrl.clear();
    leadChannelCtrl.clear();
    leadMessageCtrl.clear();
    leadTypeId = leadTypes.isNotEmpty ? leadTypes.first['id'] as int? : null;
    assignedDepartmentId = null;
    assignedStaffId = null;
    careStaffIds = <int>[];
  }

  void _resetPaymentForm() {
    editingPaymentId = null;
    paymentAmountCtrl.clear();
    paymentClientId = null;
    paymentStatus = 'pending';
  }

  Future<void> _openClientForm({Map<String, dynamic>? client}) async {
    setState(() {
      message = '';
      if (client == null) {
        _resetClientForm();
      } else {
        editingClientId = (client['id'] ?? 0) as int;
        clientNameCtrl.text = (client['name'] ?? '').toString();
        clientCompanyCtrl.text = (client['company'] ?? '').toString();
        clientEmailCtrl.text = (client['email'] ?? '').toString();
        clientPhoneCtrl.text = (client['phone'] ?? '').toString();
        leadSourceCtrl.text = (client['lead_source'] ?? '').toString();
        leadChannelCtrl.text = (client['lead_channel'] ?? '').toString();
        leadMessageCtrl.text = (client['lead_message'] ?? '').toString();
        leadTypeId = client['lead_type_id'] as int?;
        assignedDepartmentId = client['assigned_department_id'] as int?;
        assignedStaffId = client['assigned_staff_id'] as int?;
        careStaffIds = _normalizeCareStaffIds(client['care_staff_users']);
      }
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
                    Text(
                      editingClientId == null
                          ? 'Tạo khách hàng'
                          : 'Sửa khách hàng',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: clientNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên khách hàng',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: clientCompanyCtrl,
                      decoration: const InputDecoration(labelText: 'Công ty'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: clientEmailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: clientPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: leadTypeId,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái khách hàng tiềm năng',
                      ),
                      items:
                          leadTypes
                              .map(
                                (Map<String, dynamic> t) =>
                                    DropdownMenuItem<int>(
                                      value: t['id'] as int,
                                      child: Text((t['name'] ?? '').toString()),
                                    ),
                              )
                              .toList(),
                      onChanged:
                          widget.canManageClients
                              ? (int? value) =>
                                  setSheetState(() => leadTypeId = value)
                              : null,
                    ),
                    if (widget.currentUserRole == 'admin') ...<Widget>[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: assignedDepartmentId,
                        decoration: const InputDecoration(
                          labelText: 'Phòng ban phụ trách',
                        ),
                        items:
                            departments
                                .map(
                                  (Map<String, dynamic> d) =>
                                      DropdownMenuItem<int>(
                                        value: d['id'] as int,
                                        child: Text(
                                          (d['name'] ?? '').toString(),
                                        ),
                                      ),
                                )
                                .toList(),
                        onChanged:
                            (int? value) => setSheetState(
                              () => assignedDepartmentId = value,
                            ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: assignedStaffId,
                        decoration: const InputDecoration(
                          labelText: 'Nhân sự phụ trách',
                        ),
                        items:
                            staffUsers
                                .map(
                                  (
                                    Map<String, dynamic> u,
                                  ) => DropdownMenuItem<int>(
                                    value: u['id'] as int,
                                    child: Text(
                                      '${(u['name'] ?? '').toString()} • ${(u['role'] ?? '').toString()}',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (int? value) =>
                                setSheetState(() => assignedStaffId = value),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Danh sách nhân viên chăm sóc',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (BuildContext context) {
                          final List<Map<String, dynamic>> selectedCareStaff =
                              staffUsers.where((Map<String, dynamic> u) {
                                final int uid =
                                    int.tryParse((u['id'] ?? '').toString()) ??
                                    0;
                                return uid > 0 && careStaffIds.contains(uid);
                              }).toList();
                          final List<Map<String, dynamic>> availableCareStaff =
                              staffUsers.where((Map<String, dynamic> u) {
                                final int uid =
                                    int.tryParse((u['id'] ?? '').toString()) ??
                                    0;
                                return uid > 0 && !careStaffIds.contains(uid);
                              }).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: StitchTheme.bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: StitchTheme.border),
                                ),
                                child:
                                    selectedCareStaff.isEmpty
                                        ? const Text(
                                          'Chưa thêm nhân viên chăm sóc nào.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: StitchTheme.textMuted,
                                          ),
                                        )
                                        : Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children:
                                              selectedCareStaff.map((
                                                Map<String, dynamic> u,
                                              ) {
                                                final int uid =
                                                    int.tryParse(
                                                      (u['id'] ?? '')
                                                          .toString(),
                                                    ) ??
                                                    0;
                                                return InputChip(
                                                  label: Text(
                                                    (u['name'] ?? '')
                                                        .toString(),
                                                  ),
                                                  onDeleted:
                                                      () => setSheetState(() {
                                                        careStaffIds =
                                                            careStaffIds
                                                                .where(
                                                                  (
                                                                    int id,
                                                                  ) => id != uid,
                                                                )
                                                                .toList();
                                                      }),
                                                );
                                              }).toList(),
                                        ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: StitchTheme.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: StitchTheme.border),
                                ),
                                child:
                                    availableCareStaff.isEmpty
                                        ? const Text(
                                          'Đã chọn hết nhân sự khả dụng.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: StitchTheme.textMuted,
                                          ),
                                        )
                                        : Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children:
                                              availableCareStaff.map((
                                                Map<String, dynamic> u,
                                              ) {
                                                final int uid =
                                                    int.tryParse(
                                                      (u['id'] ?? '')
                                                          .toString(),
                                                    ) ??
                                                    0;
                                                if (uid <= 0) {
                                                  return const SizedBox.shrink();
                                                }
                                                return ActionChip(
                                                  avatar: const Icon(
                                                    Icons.add,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    (u['name'] ?? '')
                                                        .toString(),
                                                  ),
                                                  onPressed:
                                                      () => setSheetState(() {
                                                        careStaffIds = <int>{
                                                          ...careStaffIds,
                                                          uid,
                                                        }.toList()
                                                          ..sort();
                                                      }),
                                                );
                                              }).toList(),
                                        ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Nhân sự chăm sóc chỉ có quyền xem thông tin khách hàng và thêm ghi chú chăm sóc.',
                        style: TextStyle(
                          fontSize: 12,
                          color: StitchTheme.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: leadSourceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nguồn khách hàng tiềm năng',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: leadChannelCtrl,
                      decoration: const InputDecoration(labelText: 'Kênh'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: leadMessageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tin nhắn/ghi chú',
                      ),
                      maxLines: 2,
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(message),
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
                            onPressed:
                                widget.canManageClients
                                    ? () async {
                                      final bool ok = await _saveClient();
                                      if (!context.mounted) return;
                                      if (ok) {
                                        Navigator.of(context).pop();
                                      } else {
                                        setSheetState(() {});
                                      }
                                    }
                                    : null,
                            child: Text(
                              editingClientId == null
                                  ? 'Lưu khách hàng'
                                  : 'Cập nhật khách hàng',
                            ),
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
    setState(() => _resetClientForm());
  }

  Future<void> _openPaymentForm({Map<String, dynamic>? payment}) async {
    setState(() {
      message = '';
      if (payment == null) {
        _resetPaymentForm();
      } else {
        editingPaymentId = (payment['id'] ?? 0) as int;
        paymentClientId = (payment['client_id'] ?? 0) as int;
        paymentAmountCtrl.text = (payment['amount'] ?? '').toString();
        paymentStatus = (payment['status'] ?? 'pending').toString();
      }
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
                    Text(
                      editingPaymentId == null
                          ? 'Tạo thanh toán'
                          : 'Sửa thanh toán',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: paymentClientId,
                      decoration: const InputDecoration(
                        labelText: 'Khách hàng',
                      ),
                      items:
                          clients
                              .map(
                                (Map<String, dynamic> c) =>
                                    DropdownMenuItem<int>(
                                      value: (c['id'] ?? 0) as int,
                                      child: Text(
                                        ((c['company'] ??
                                                c['name'] ??
                                                'Khách hàng'))
                                            .toString(),
                                      ),
                                    ),
                              )
                              .toList(),
                      onChanged:
                          widget.canManagePayments
                              ? (int? value) =>
                                  setSheetState(() => paymentClientId = value)
                              : null,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: paymentAmountCtrl,
                      decoration: const InputDecoration(labelText: 'Số tiền'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: paymentStatus,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'pending',
                          child: Text('Chờ thanh toán'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'paid',
                          child: Text('Đã thanh toán'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'overdue',
                          child: Text('Quá hạn'),
                        ),
                      ],
                      onChanged:
                          widget.canManagePayments
                              ? (String? value) {
                                if (value == null) return;
                                setSheetState(() => paymentStatus = value);
                              }
                              : null,
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(message),
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
                            onPressed:
                                widget.canManagePayments
                                    ? () async {
                                      final bool ok = await _savePayment();
                                      if (!context.mounted) return;
                                      if (ok) {
                                        Navigator.of(context).pop();
                                      } else {
                                        setSheetState(() {});
                                      }
                                    }
                                    : null,
                            child: Text(
                              editingPaymentId == null
                                  ? 'Lưu thanh toán'
                                  : 'Cập nhật thanh toán',
                            ),
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
    setState(() => _resetPaymentForm());
  }

  @override
  Widget build(BuildContext context) {
    final int totalClients = clients.length;
    final int totalPayments = payments.length;
    final int pendingPayments =
        payments.where((Map<String, dynamic> payment) {
          final String status =
              (payment['status'] ?? '').toString().toLowerCase();
          return status.contains('pending') || status.contains('cho');
        }).length;

    final List<Map<String, dynamic>> filteredClients =
        clients.where((Map<String, dynamic> client) {
          if (search.isEmpty) return true;
          final String hay =
              '${client['company'] ?? ''} ${client['name'] ?? ''} ${client['email'] ?? ''}'
                  .toLowerCase();
          return hay.contains(search.toLowerCase());
        }).toList();

    final List<Map<String, dynamic>> filteredPayments =
        payments.where((Map<String, dynamic> payment) {
          if (search.isEmpty) return true;
          final Map<String, dynamic>? client =
              payment['client'] as Map<String, dynamic>?;
          final String hay =
              '${client?['company'] ?? ''} ${client?['name'] ?? ''} ${payment['status'] ?? ''}'
                  .toLowerCase();
          return hay.contains(search.toLowerCase());
        }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khách hàng'),
        actions: <Widget>[
          if (widget.canManageClients)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: _importClients,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const StitchHeroCard(
              title: 'Phân hệ khách hàng',
              subtitle:
                  'Theo dõi khách hàng, thanh toán và phối hợp phòng ban theo dự án.',
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.35,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                StitchMetricCard(
                  icon: Icons.people_alt,
                  label: 'Khách hàng',
                  value: totalClients.toString(),
                  accent: StitchTheme.primary,
                ),
                StitchMetricCard(
                  icon: Icons.receipt_long,
                  label: 'Giao dịch',
                  value: totalPayments.toString(),
                  accent: StitchTheme.success,
                ),
                StitchMetricCard(
                  icon: Icons.warning_amber,
                  label: 'Chờ thanh toán',
                  value: pendingPayments.toString(),
                  accent: StitchTheme.warning,
                ),
                StitchMetricCard(
                  icon: Icons.query_stats,
                  label: 'Theo dõi',
                  value:
                      (filteredClients.length + filteredPayments.length)
                          .toString(),
                  accent: StitchTheme.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            StitchFilterCard(
              title: 'Bộ lọc khách hàng',
              subtitle:
                  'Tìm theo khách hàng, email hoặc trạng thái thanh toán để thu hẹp danh sách đang theo dõi.',
              trailing: null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  StitchFilterField(
                    label: 'Tìm kiếm',
                    hint:
                        'Nhập tên khách hàng, email hoặc từ khóa liên quan đến giao dịch.',
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm khách hàng / trạng thái thanh toán',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (String value) {
                        setState(() => search = value.trim());
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: StitchTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Đang hiển thị ${filteredClients.length} khách hàng và ${filteredPayments.length} giao dịch phù hợp.',
                      style: const TextStyle(
                        color: StitchTheme.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (message.isNotEmpty) ...<Widget>[
              Text(message),
              const SizedBox(height: 8),
            ],
            if (loading) const Center(child: CircularProgressIndicator()),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Khách hàng',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.canManageClients)
                  ElevatedButton.icon(
                    onPressed: () => _openClientForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ...filteredClients.map(
              (Map<String, dynamic> client) => Card(
                child: ListTile(
                  title: Text(
                    ((client['company'] ?? client['name'] ?? 'Khách hàng'))
                        .toString(),
                  ),
                  subtitle: Builder(
                    builder: (BuildContext context) {
                      final Map<String, dynamic>? leadType =
                          client['lead_type'] as Map<String, dynamic>?;
                      final Map<String, dynamic>? tier =
                          client['revenue_tier'] as Map<String, dynamic>?;
                      final Map<String, dynamic>? dept =
                          client['assigned_department']
                              as Map<String, dynamic>?;
                      final Map<String, dynamic>? staff =
                          client['assigned_staff'] as Map<String, dynamic>? ??
                          client['sales_owner'] as Map<String, dynamic>?;
                      final List<dynamic> careStaffRaw =
                          (client['care_staff_users'] as List<dynamic>?) ??
                          <dynamic>[];
                      final String careStaffLabel = careStaffRaw
                          .map((dynamic item) {
                            if (item is Map<String, dynamic>) {
                              return (item['name'] ?? '').toString();
                            }
                            return '';
                          })
                          .where((String name) => name.trim().isNotEmpty)
                          .take(2)
                          .join(', ');
                      final List<String> meta = <String>[
                        (client['email'] ?? 'Chưa có email').toString(),
                        if (leadType != null)
                          (leadType['name'] ?? '').toString(),
                        if (tier != null) (tier['label'] ?? '').toString(),
                        if (dept != null) (dept['name'] ?? '').toString(),
                        if (staff != null) (staff['name'] ?? '').toString(),
                        if (careStaffLabel.isNotEmpty) 'CSKH: $careStaffLabel',
                      ];
                      return Text(meta.join(' • '));
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.canManageClients)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openClientForm(client: client),
                        ),
                      if (widget.canDelete)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed:
                              () => _deleteClient((client['id'] ?? 0) as int),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Thanh toán',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.canManagePayments)
                  ElevatedButton.icon(
                    onPressed: () => _openPaymentForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ...filteredPayments.map(
              (Map<String, dynamic> payment) => Card(
                child: ListTile(
                  title: Text(
                    ((payment['client'] as Map<String, dynamic>?)?['company'] ??
                            (payment['client']
                                as Map<String, dynamic>?)?['name'] ??
                            'Khách hàng')
                        .toString(),
                  ),
                  subtitle: Text('${payment['status']} • ${payment['amount']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.canManagePayments)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openPaymentForm(payment: payment),
                        ),
                      if (widget.canDelete)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed:
                              () => _deletePayment((payment['id'] ?? 0) as int),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

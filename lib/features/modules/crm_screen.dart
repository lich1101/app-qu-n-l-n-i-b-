import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/staff_multi_filter_row.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';
import 'client_detail_screen.dart';

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
  /// POST/PUT /crm/clients — api: admin, quan_ly, nhan_vien
  final bool canManageClients;
  /// POST/PUT /crm/payments — api: admin, ke_toan
  final bool canManagePayments;
  /// DELETE /crm/clients và DELETE /crm/payments — api: chỉ admin
  final bool canDelete;
  final String currentUserRole;

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  bool loading = false;
  bool loadingMore = false;
  bool _savingClientForm = false;
  bool _savingPaymentForm = false;
  String search = '';
  String message = '';
  List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> payments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> leadTypes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> departments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> staffUsers = <Map<String, dynamic>>[];
  
  int clientsPage = 1;
  int clientsLastPage = 1;
  int clientsTotal = 0;
  int paymentsPage = 1;
  int paymentsLastPage = 1;
  int paymentsTotal = 0;

  int? leadTypeId;
  int? assignedDepartmentId;
  int? assignedStaffId;
  List<int> careStaffIds = <int>[];
  List<int> clientListStaffFilterIds = <int>[];
  List<Map<String, dynamic>> clientFilterStaffOptions =
      <Map<String, dynamic>>[];
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
  final ScrollController scrollController = ScrollController();
  String paymentStatus = 'pending';
  int? paymentClientId;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    _fetch();
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !loading &&
        !loadingMore) {
      if (clientsPage < clientsLastPage || paymentsPage < paymentsLastPage) {
        _fetchMore();
      }
    }
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
    scrollController.dispose();
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
    setState(() {
      loading = true;
      clientsPage = 1;
      paymentsPage = 1;
    });
    final String normalizedRole = widget.currentUserRole.toLowerCase();
    final bool canAssignClientOwner = <String>[
      'admin',
      'administrator',
      'quan_ly',
    ].contains(normalizedRole);

    // Metadata can be fetched in parallel if needed, but let's keep it simple
    final List<Map<String, dynamic>> types = await widget.apiService
        .getLeadTypes(widget.token);
    final List<Map<String, dynamic>> deptData =
        canAssignClientOwner
            ? await widget.apiService.getDepartments(widget.token)
            : <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> staffData =
        canAssignClientOwner
            ? await widget.apiService.getUsersLookup(
              widget.token,
              purpose: 'operational_assignee',
            )
            : <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> staffFilterRows =
        await widget.apiService.getUsersLookup(widget.token);

    final Map<String, dynamic> clientPayload = await widget.apiService.getClients(
      widget.token,
      page: 1,
      perPage: 20,
      search: search,
      assignedStaffIds:
          clientListStaffFilterIds.isEmpty ? null : clientListStaffFilterIds,
    );
    final Map<String, dynamic> paymentPayload = await widget.apiService.getPayments(
      widget.token,
      page: 1,
      perPage: 10,
    );

    if (!mounted) return;

    setState(() {
      loading = false;
      leadTypes = types;
      departments = deptData;
      staffUsers = staffData;
      clientFilterStaffOptions = staffFilterRows;
      if (leadTypeId == null && types.isNotEmpty) {
        leadTypeId = types.first['id'] as int?;
      }
      
      final List<dynamic> clientList = (clientPayload['data'] ?? []) as List<dynamic>;
      clients = clientList.map((e) => e as Map<String, dynamic>).toList();
      clientsLastPage = (clientPayload['last_page'] ?? 1) as int;
      clientsTotal = (clientPayload['total'] ?? 0) as int;

      final List<dynamic> paymentList = (paymentPayload['data'] ?? []) as List<dynamic>;
      payments = paymentList.map((e) => e as Map<String, dynamic>).toList();
      paymentsLastPage = (paymentPayload['last_page'] ?? 1) as int;
      paymentsTotal = (paymentPayload['total'] ?? 0) as int;
    });
  }

  Future<void> _fetchMore() async {
    if (loadingMore) return;
    setState(() => loadingMore = true);

    if (clientsPage < clientsLastPage) {
      final int nextPage = clientsPage + 1;
      final Map<String, dynamic> payload = await widget.apiService.getClients(
        widget.token,
        page: nextPage,
        perPage: 20,
        search: search,
        assignedStaffIds:
            clientListStaffFilterIds.isEmpty ? null : clientListStaffFilterIds,
      );
      if (mounted) {
        final List<dynamic> newList = (payload['data'] ?? []) as List<dynamic>;
        setState(() {
          clients.addAll(newList.map((e) => e as Map<String, dynamic>).toList());
          clientsPage = nextPage;
          clientsLastPage = (payload['last_page'] ?? 1) as int;
          clientsTotal = (payload['total'] ?? 0) as int;
        });
      }
    }

    if (paymentsPage < paymentsLastPage) {
      final int nextPage = paymentsPage + 1;
      final Map<String, dynamic> payload = await widget.apiService.getPayments(
        widget.token,
        page: nextPage,
        perPage: 10,
      );
      if (mounted) {
        final List<dynamic> newList = (payload['data'] ?? []) as List<dynamic>;
        setState(() {
          payments.addAll(newList.map((e) => e as Map<String, dynamic>).toList());
          paymentsPage = nextPage;
          paymentsLastPage = (payload['last_page'] ?? 1) as int;
          paymentsTotal = (payload['total'] ?? 0) as int;
        });
      }
    }

    if (mounted) {
      setState(() => loadingMore = false);
    }
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
    if (_savingClientForm) {
      return false;
    }
    if (!widget.canManageClients) {
      setState(() => message = 'Bạn không có quyền quản lý khách hàng.');
      return false;
    }
    if (clientNameCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập tên khách hàng.');
      return false;
    }
    setState(() => _savingClientForm = true);
    final String roleLower = widget.currentUserRole.toLowerCase();
    final bool canAssignClientOwner = <String>{
      'admin',
      'administrator',
      'quan_ly',
    }.contains(roleLower);
    final Map<String, dynamic> result =
        editingClientId == null
            ? await widget.apiService.createClientWithMeta(
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
            : await widget.apiService.updateClientWithMeta(
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
              careStaffIds: canAssignClientOwner ? careStaffIds : null,
              assignedDepartmentId:
                  canAssignClientOwner ? assignedDepartmentId : null,
              assignedStaffId: canAssignClientOwner ? assignedStaffId : null,
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
    final bool ok = result['ok'] == true;
    final String apiMessage = (result['message'] ?? '').toString().trim();
    if (!mounted) return false;
    if (!ok && apiMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiMessage),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          backgroundColor: StitchTheme.dangerStrong,
        ),
      );
    }
    setState(() {
      message =
          ok
              ? (editingClientId == null
                  ? 'Tạo khách hàng thành công.'
                  : 'Cập nhật khách hàng thành công.')
              : (apiMessage.isNotEmpty ? apiMessage : 'Lưu khách hàng thất bại.');
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
      _savingClientForm = false;
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
    if (_savingPaymentForm) {
      return false;
    }
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
    setState(() => _savingPaymentForm = true);
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
      _savingPaymentForm = false;
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
      _savingClientForm = false;
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
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: stitchFormSheetSurfaceDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  StitchFormSheetTitleBar(
                    title:
                        editingClientId == null
                            ? 'Thêm khách hàng'
                            : 'Sửa khách hàng',
                    subtitle:
                        editingClientId == null
                            ? 'Số điện thoại không được trùng với khách đã có. Hệ thống sẽ từ chối tạo mới và báo tên khách cũ.'
                            : 'Đổi SĐT sang số đã dùng cho khách khác cũng không được phép.',
                    icon:
                        editingClientId == null
                            ? Icons.person_add_alt_1_rounded
                            : Icons.edit_note_rounded,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                    TextField(
                      controller: clientNameCtrl,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Tên khách hàng',
                      ),
                    ),
                    SizedBox(height: kStitchTaskFormGap),
                    TextField(
                      controller: clientCompanyCtrl,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Công ty',
                      ),
                    ),
                    SizedBox(height: kStitchTaskFormGap),
                    TextField(
                      controller: clientEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Email',
                      ),
                    ),
                    SizedBox(height: kStitchTaskFormGap),
                    TextField(
                      controller: clientPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Số điện thoại',
                        hint: 'Nhập đúng SĐT để tránh trùng',
                      ),
                    ),
                    SizedBox(height: kStitchTaskFormGap),
                    DropdownButtonFormField<int>(
                      value: leadTypeId,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Trạng thái khách hàng tiềm năng',
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
                    if (editingClientId != null &&
                        !<String>{
                          'admin',
                          'administrator',
                          'quan_ly',
                        }.contains(widget.currentUserRole.toLowerCase())) ...<Widget>[
                      SizedBox(height: kStitchTaskFormGap),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: StitchTheme.warningSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: StitchTheme.warningStrong.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Text(
                          'Để đổi phụ trách hoặc nhóm chăm sóc, dùng chức năng «Chuyển phụ trách khách hàng» (thông báo / màn hình phiếu) — không đổi trực tiếp trên form này.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: StitchTheme.textMain.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ],
                    if ([
                      'admin',
                      'administrator',
                      'quan_ly',
                    ].contains(widget.currentUserRole.toLowerCase())) ...<Widget>[
                      SizedBox(height: kStitchTaskFormGap),
                      DropdownButtonFormField<int?>(
                        value: assignedDepartmentId,
                        decoration: stitchSheetInputDecoration(
                          context,
                          label: 'Phòng ban phụ trách',
                          hint:
                              'Chọn phòng trước để lọc nhân sự phụ trách theo phòng.',
                        ),
                        items: <DropdownMenuItem<int?>>[
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— Chưa chọn phòng ban —'),
                          ),
                          ...departments.map(
                            (Map<String, dynamic> d) =>
                                DropdownMenuItem<int?>(
                                  value: d['id'] as int,
                                  child: Text((d['name'] ?? '').toString()),
                                ),
                          ),
                        ],
                        onChanged: (int? value) => setSheetState(() {
                          assignedDepartmentId = value;
                          if (value != null && value > 0) {
                            final bool stillOk = staffUsers.any(
                              (Map<String, dynamic> u) =>
                                  int.tryParse('${u['id']}') == assignedStaffId &&
                                  (int.tryParse(
                                            '${u['department_id'] ?? ''}',
                                          ) ??
                                          0) ==
                                      value,
                            );
                            if (!stillOk) {
                              assignedStaffId = null;
                            }
                          }
                        }),
                      ),
                      SizedBox(height: kStitchTaskFormGap),
                      Builder(
                        builder: (BuildContext context) {
                          final List<Map<String, dynamic>> staffFiltered =
                              assignedDepartmentId != null &&
                                      assignedDepartmentId! > 0
                                  ? staffUsers
                                      .where((Map<String, dynamic> u) {
                                        final int ud =
                                            int.tryParse(
                                              '${u['department_id'] ?? ''}',
                                            ) ??
                                            0;
                                        return ud == assignedDepartmentId;
                                      })
                                      .toList()
                                  : staffUsers;
                          final bool staffValueValid =
                              assignedStaffId != null &&
                              staffFiltered.any(
                                (Map<String, dynamic> u) =>
                                    int.tryParse('${u['id']}') ==
                                    assignedStaffId,
                              );
                          final int? staffDropdownValue =
                              staffValueValid ? assignedStaffId : null;

                          return DropdownButtonFormField<int?>(
                            value: staffDropdownValue,
                            decoration: stitchSheetInputDecoration(
                              context,
                              label: 'Nhân sự phụ trách',
                              hint:
                                  assignedDepartmentId != null &&
                                          assignedDepartmentId! > 0
                                      ? 'Chỉ nhân viên thuộc phòng đã chọn.'
                                      : null,
                            ),
                            items: <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('— Chọn nhân sự —'),
                              ),
                              ...staffFiltered.map(
                                (Map<String, dynamic> u) =>
                                    DropdownMenuItem<int?>(
                                      value: int.tryParse('${u['id']}'),
                                      child: Text(
                                        '${(u['name'] ?? '').toString()} • ${(u['role'] ?? '').toString()}',
                                      ),
                                    ),
                              ),
                            ],
                            onChanged: (int? value) => setSheetState(() {
                              assignedStaffId = value;
                              if (value != null) {
                                for (final Map<String, dynamic> u
                                    in staffUsers) {
                                  if (int.tryParse('${u['id']}') == value) {
                                    final int? did = int.tryParse(
                                      '${u['department_id'] ?? ''}',
                                    );
                                    if (did != null && did > 0) {
                                      assignedDepartmentId = did;
                                    }
                                    break;
                                  }
                                }
                              }
                            }),
                          );
                        },
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
                    SizedBox(height: kStitchTaskFormGap),
                    TextField(
                      controller: leadSourceCtrl,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Nguồn khách hàng tiềm năng',
                      ),
                    ),
                    SizedBox(height: kStitchTaskFormGap),
                    TextField(
                      controller: leadChannelCtrl,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Kênh',
                      ),
                    ),
                    SizedBox(height: kStitchTaskFormGap),
                    TextField(
                      controller: leadMessageCtrl,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Tin nhắn/ghi chú',
                      ),
                      maxLines: 2,
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      SizedBox(height: kStitchTaskFormGap),
                      StitchFeedbackBanner(
                        message: message,
                        isError: !message.contains('thành công'),
                      ),
                    ],
                    SizedBox(height: kStitchTaskFormGap),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: StitchTheme.surface,
                      border: Border(top: BorderSide(color: StitchTheme.border.withValues(alpha: 0.85))),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: StitchTheme.textMain.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _savingClientForm
                                      ? null
                                      : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: StitchTheme.border),
                                foregroundColor: StitchTheme.textMain,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  widget.canManageClients && !_savingClientForm
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
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: StitchTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                _savingClientForm
                                    ? (editingClientId == null
                                        ? 'Đang tạo...'
                                        : 'Đang cập nhật...')
                                    : (editingClientId == null
                                        ? 'Lưu khách hàng'
                                        : 'Cập nhật'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _savingClientForm = false;
      _resetClientForm();
    });
  }

  Future<void> _openPaymentForm({Map<String, dynamic>? payment}) async {
    setState(() {
      message = '';
      _savingPaymentForm = false;
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
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: stitchFormSheetSurfaceDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  StitchFormSheetTitleBar(
                    title:
                        editingPaymentId == null
                            ? 'Ghi nhận thanh toán'
                            : 'Sửa thanh toán',
                    subtitle:
                        'Liên kết khoản thu với khách hàng trong CRM.',
                    icon: Icons.receipt_long_rounded,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                    DropdownButtonFormField<int>(
                      value: paymentClientId,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Khách hàng',
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
                    SizedBox(height: kStitchTaskFormGap),
                    TextField(
                      controller: paymentAmountCtrl,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Số tiền (VNĐ)',
                        hint: 'VD: 5000000',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: kStitchTaskFormGap),
                    DropdownButtonFormField<String>(
                      value: paymentStatus,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label: 'Trạng thái',
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
                      SizedBox(height: kStitchTaskFormGap),
                      StitchFeedbackBanner(
                        message: message,
                        isError: !message.contains('thành công'),
                      ),
                    ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: StitchTheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: StitchTheme.border.withValues(alpha: 0.85),
                        ),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: StitchTheme.textMain.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _savingPaymentForm
                                      ? null
                                      : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: StitchTheme.border,
                                ),
                                foregroundColor: StitchTheme.textMain,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  widget.canManagePayments &&
                                          !_savingPaymentForm
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
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: StitchTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                _savingPaymentForm
                                    ? (editingPaymentId == null
                                        ? 'Đang tạo...'
                                        : 'Đang cập nhật...')
                                    : (editingPaymentId == null
                                        ? 'Lưu thanh toán'
                                        : 'Cập nhật thanh toán'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _savingPaymentForm = false;
      _resetPaymentForm();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int pendingPayments =
        payments.where((Map<String, dynamic> payment) {
          final String status =
              (payment['status'] ?? '').toString().toLowerCase();
          return status.contains('pending') || status.contains('cho');
        }).length;

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
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const StitchHeroCard(
              title: 'Phân hệ khách hàng',
              subtitle:
                  'Theo dõi khách hàng, thanh toán và phối hợp phòng ban theo dự án.',
            ),
            SizedBox(height: kStitchTaskFormGap),
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
                  value: clientsTotal.toString(),
                  accent: StitchTheme.primary,
                ),
                StitchMetricCard(
                  icon: Icons.receipt_long,
                  label: 'Giao dịch',
                  value: paymentsTotal.toString(),
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
                      (clientsTotal + paymentsTotal)
                          .toString(),
                  accent: StitchTheme.textMuted,
                ),
              ],
            ),
            SizedBox(height: kStitchTaskFormGap),
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
                      onChanged: (String value) => search = value.trim(),
                      onSubmitted: (_) => _fetch(),
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  StaffMultiFilterRow(
                    users: clientFilterStaffOptions,
                    selectedIds: clientListStaffFilterIds,
                    title: 'Nhân sự phụ trách khách hàng',
                    onChanged: (List<int> ids) {
                      setState(() => clientListStaffFilterIds = ids);
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: loading ? null : _fetch,
                      icon: const Icon(Icons.filter_alt_outlined, size: 18),
                      label: const Text('Áp dụng lọc khách hàng'),
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: StitchTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Đang hiển thị ${clients.length} khách hàng và ${payments.length} giao dịch (Tổng: $clientsTotal KH, $paymentsTotal GD).',
                      style: const TextStyle(
                        color: StitchTheme.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: kStitchTaskFormGap),
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
            ...clients.map(
              (Map<String, dynamic> client) {
                final int clientId = (client['id'] ?? 0) as int;
                final Map<String, dynamic>? leadType = client['lead_type'] as Map<String, dynamic>?;
                final Map<String, dynamic>? staff = client['assigned_staff'] as Map<String, dynamic>? ?? client['sales_owner'] as Map<String, dynamic>?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: StitchTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: StitchTheme.textMain.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ClientDetailScreen(token: widget.token, apiService: widget.apiService, clientId: clientId),
                      ));
                    },
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 6,
                            decoration: BoxDecoration(
                              color: StitchTheme.primary,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: StitchTheme.primary.withValues(alpha: 0.1),
                                        child: Text(
                                          ((client['company'] ?? client['name'] ?? 'K')).toString().isNotEmpty 
                                            ? ((client['company'] ?? client['name'] ?? 'K')).toString().characters.first.toUpperCase() 
                                            : 'K',
                                          style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ((client['company'] ?? client['name'] ?? 'Khách hàng')).toString(),
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.email_outlined, size: 13, color: StitchTheme.textMuted),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    (client['email'] ?? 'Chưa có email').toString(),
                                                    style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (widget.canManageClients)
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 20, color: StitchTheme.textMuted),
                                          onSelected: (val) {
                                            if (val == 'edit') _openClientForm(client: client);
                                            if (val == 'delete' && widget.canDelete) _deleteClient(clientId);
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Sửa')])),
                                            if (widget.canDelete) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 8), Text('Xóa', style: TextStyle(color: Colors.red))])),
                                          ],
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: kStitchTaskFormGap),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (leadType != null) _buildBadge(leadType['name']?.toString() ?? '—', StitchTheme.primary),
                                      if (staff != null) _buildBadge('Phụ trách: ${staff['name']}', StitchTheme.success),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
            ...payments.map(
              (Map<String, dynamic> payment) {
                final String pStatus = (payment['status'] ?? '').toString();
                final Color pColor = pStatus.toLowerCase() == 'paid' ? StitchTheme.success : StitchTheme.warning;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StitchTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: pColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.payments_outlined, color: pColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ((payment['client'] as Map<String, dynamic>?)?['company'] ?? (payment['client'] as Map<String, dynamic>?)?['name'] ?? 'Khách hàng').toString(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text('${payment['amount']?.toString() ?? '0'} • $pStatus', style: const TextStyle(color: StitchTheme.textSubtle, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (widget.canManagePayments || widget.canDelete)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20, color: StitchTheme.textMuted),
                          onSelected: (val) {
                            if (val == 'edit' && widget.canManagePayments) _openPaymentForm(payment: payment);
                            if (val == 'delete' && widget.canDelete) _deletePayment((payment['id'] ?? 0) as int);
                          },
                          itemBuilder: (context) => [
                            if (widget.canManagePayments) const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Sửa')])),
                            if (widget.canDelete) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 8), Text('Xóa', style: TextStyle(color: Colors.red))])),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
            if (loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!loadingMore &&
                clientsPage >= clientsLastPage &&
                paymentsPage >= paymentsLastPage &&
                clients.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Đã hiển thị toàn bộ danh sách.',
                    style: TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                  ),
                ),
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

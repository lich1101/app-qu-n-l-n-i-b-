import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';
import '../projects/create_project_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
    this.canCreate = false,
    required this.canDelete,
    required this.canApprove,
    required this.currentUserRole,
    required this.currentUserId,
  });

  final String token;
  final MobileApiService apiService;
  /// Edit existing contracts (admin, quan_ly, ke_toan)
  final bool canManage;
  /// Create new contracts (admin, quan_ly, nhan_vien, ke_toan)
  final bool canCreate;
  final bool canDelete;
  final bool canApprove;
  final String currentUserRole;
  final int? currentUserId;

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController valueCtrl = TextEditingController();
  final TextEditingController paymentTimesCtrl = TextEditingController(text: '1');
  final TextEditingController signedCtrl = TextEditingController();
  final TextEditingController startCtrl = TextEditingController();
  final TextEditingController endCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();
  final TextEditingController careNoteTitleCtrl = TextEditingController();
  final TextEditingController careNoteDetailCtrl = TextEditingController();

  bool loading = false;
  bool loadingMore = false;
  String message = '';
  String filterStatus = '';
  int? filterClientId;
  int? formClientId;
  int? editingId;
  String status = 'draft';
  
  int currentPage = 1;
  int lastPage = 1;
  int totalContracts = 0;
  final ScrollController scrollController = ScrollController();

  List<Map<String, dynamic>> contracts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> products = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> collectors = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> careStaffUsers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> payments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> costs = <Map<String, dynamic>>[];
  int? collectorUserId;
  List<int> careStaffIds = <int>[];
  bool editingCanManage = true;

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
        !loadingMore &&
        currentPage < lastPage) {
      _fetchMore();
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    titleCtrl.dispose();
    valueCtrl.dispose();
    paymentTimesCtrl.dispose();
    signedCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    notesCtrl.dispose();
    careNoteTitleCtrl.dispose();
    careNoteDetailCtrl.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      currentPage = 1;
    });
    
    // Clients might also be paginated now, let's take a reasonable amount for the dropdown
    final Map<String, dynamic> clientPayload =
        await widget.apiService.getClients(widget.token, perPage: 100);
    final List<Map<String, dynamic>> productRows =
        await widget.apiService.getProducts(widget.token);
    final List<Map<String, dynamic>> collectorRows =
        await widget.apiService.getUsersLookup(
      widget.token,
      purpose: 'contract_collector',
    );
    final List<Map<String, dynamic>> careStaffRows =
        await widget.apiService.getUsersLookup(
      widget.token,
      purpose: 'contract_care_staff',
    );
    
    final Map<String, dynamic> contractPayload =
        await widget.apiService.getContracts(
      widget.token,
      page: 1,
      perPage: 20,
      search: searchCtrl.text.trim(),
      status: filterStatus,
      clientId: filterClientId,
      withItems: true,
    );

    if (!mounted) return;
    
    final List<dynamic> clientData = (clientPayload['data'] ?? []) as List<dynamic>;
    final List<dynamic> contractData = (contractPayload['data'] ?? []) as List<dynamic>;

    setState(() {
      loading = false;
      clients = clientData.map((e) => e as Map<String, dynamic>).toList();
      products = productRows;
      collectors = collectorRows;
      careStaffUsers = careStaffRows;
      contracts = contractData.map((e) => e as Map<String, dynamic>).toList();
      lastPage = (contractPayload['last_page'] ?? 1) as int;
      totalContracts = (contractPayload['total'] ?? 0) as int;
    });
  }

  Future<void> _fetchMore() async {
    if (loadingMore || currentPage >= lastPage) return;
    setState(() => loadingMore = true);

    final int nextPage = currentPage + 1;
    final Map<String, dynamic> payload = await widget.apiService.getContracts(
      widget.token,
      page: nextPage,
      perPage: 20,
      search: searchCtrl.text.trim(),
      status: filterStatus,
      clientId: filterClientId,
      withItems: true,
    );

    if (mounted) {
      final List<dynamic> newData = (payload['data'] ?? []) as List<dynamic>;
      setState(() {
        loadingMore = false;
        contracts.addAll(newData.map((e) => e as Map<String, dynamic>).toList());
        currentPage = nextPage;
        lastPage = (payload['last_page'] ?? 1) as int;
        totalContracts = (payload['total'] ?? 0) as int;
      });
    }
  }

  Future<void> _importContracts() async {
    if (!widget.canCreate && !widget.canManage) {
      setState(() => message = 'Bạn không có quyền import hợp đồng.');
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xls', 'xlsx', 'csv'],
    );
    if (result == null || result.files.single.path == null) return;
    final File file = File(result.files.single.path!);
    final Map<String, dynamic> report =
        await widget.apiService.importContracts(widget.token, file);
    if (!mounted) return;
    setState(() {
      message = report['error'] != null
          ? 'Import thất bại.'
          : 'Import hoàn tất: ${(report['created'] ?? 0)} tạo mới, ${(report['updated'] ?? 0)} cập nhật.';
    });
    await _fetch();
  }

  String _fmtDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (date == null) return;
    if (!mounted) return;
    setState(() => controller.text = _fmtDate(date));
  }

  String _safeDate(dynamic raw) {
    if (raw == null) return '';
    final String value = raw.toString();
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  double _parseNumberInput(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();

    String value = raw.toString().trim();
    if (value.isEmpty) return 0;

    value = value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'₫|đ|VNĐ|VND', caseSensitive: false), '');

    final bool hasComma = value.contains(',');
    final bool hasDot = value.contains('.');

    if (hasComma && hasDot) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma) {
      final List<String> parts = value.split(',');
      value = parts.length > 2 || (parts.length == 2 && parts[1].length == 3)
          ? value.replaceAll(',', '')
          : value.replaceFirst(',', '.');
    } else if (hasDot) {
      final List<String> parts = value.split('.');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        value = value.replaceAll('.', '');
      }
    }

    value = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(value) ?? 0;
  }

  double _itemTotal(Map<String, dynamic> item) {
    final double price = _parseNumberInput(item['unit_price']);
    final double qty = math.max(1, _parseNumberInput(item['quantity']));
    return price * qty;
  }

  void _syncValueController([List<Map<String, dynamic>>? sourceItems]) {
    final List<Map<String, dynamic>> rows = sourceItems ?? items;
    if (rows.isEmpty) {
      valueCtrl.text = '';
      return;
    }
    valueCtrl.text = _itemsTotalFromRows(rows).toStringAsFixed(0);
  }

  double _itemsTotalFromRows(List<Map<String, dynamic>> rows) {
    return rows.fold<double>(
      0,
      (double acc, Map<String, dynamic> item) => acc + _itemTotal(item),
    );
  }

  double _itemsTotal() {
    return _itemsTotalFromRows(items);
  }

  void _addItem([StateSetter? setSheetState]) {
    void apply() {
      final List<Map<String, dynamic>> nextItems = <Map<String, dynamic>>[
        ...items,
        <String, dynamic>{
          'product_id': null,
          'product_name': '',
          'unit': '',
          'unit_price': '',
          'quantity': 1,
          'note': '',
        }
      ];
      items = nextItems;
      _syncValueController(nextItems);
    }

    if (setSheetState != null) {
      setSheetState(apply);
    } else {
      setState(apply);
    }
  }

  void _removeItem(int index, [StateSetter? setSheetState]) {
    void apply() {
      if (index < 0 || index >= items.length) return;
      final List<Map<String, dynamic>> nextItems = List<Map<String, dynamic>>.from(items);
      nextItems.removeAt(index);
      items = nextItems;
      _syncValueController(nextItems);
    }

    if (setSheetState != null) {
      setSheetState(apply);
    } else {
      setState(apply);
    }
  }

  void _updateItem(int index, Map<String, dynamic> changes, [StateSetter? setSheetState]) {
    void apply() {
      final List<Map<String, dynamic>> nextItems = items.asMap().entries.map((entry) {
        if (entry.key != index) return entry.value;
        return <String, dynamic>{...entry.value, ...changes};
      }).toList();
      items = nextItems;
      _syncValueController(nextItems);
    }

    if (setSheetState != null) {
      setSheetState(apply);
    } else {
      setState(apply);
    }
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'signed':
        return 'Đã ký';
      case 'success':
        return 'Thành công';
      case 'active':
        return 'Đang hiệu lực';
      case 'expired':
        return 'Hết hạn';
      case 'cancelled':
        return 'Hủy';
      case 'draft':
      default:
        return 'Nháp';
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'active':
        return StitchTheme.success;
      case 'success':
        return StitchTheme.success;
      case 'signed':
        return StitchTheme.primary;
      case 'expired':
        return StitchTheme.warning;
      case 'cancelled':
        return StitchTheme.danger;
      case 'draft':
      default:
        return StitchTheme.textMuted;
    }
  }

  String _money(dynamic raw) {
    if (raw == null) return '—';
    final double value = _parseNumberInput(raw);
    return '${value.toStringAsFixed(0)} đ';
  }

  int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  bool? _readBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final String value = (raw ?? '').toString().trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == '1' || value == 'true' || value == 'yes') return true;
    if (value == '0' || value == 'false' || value == 'no') return false;
    return null;
  }

  bool _canManageContract(Map<String, dynamic>? contract) {
    if (!widget.canManage) return false;
    if (contract == null) return widget.canManage;

    final bool? apiPermission = _readBool(contract['can_manage']);
    if (apiPermission != null) {
      return apiPermission;
    }

    if (widget.currentUserRole != 'nhan_vien') {
      return true;
    }

    final int uid = widget.currentUserId ?? 0;
    if (uid <= 0) return false;

    final Map<String, dynamic>? client =
        contract['client'] as Map<String, dynamic>?;

    return _readInt(contract['created_by']) == uid ||
        _readInt(contract['collector_user_id']) == uid ||
        _readInt(client?['assigned_staff_id']) == uid ||
        _readInt(client?['sales_owner_id']) == uid;
  }

  bool _canDeleteContract(Map<String, dynamic>? contract) {
    if (!widget.canDelete) return false;
    if (contract == null) return widget.canDelete;

    final bool? apiPermission = _readBool(contract['can_delete']);
    if (apiPermission != null) {
      return apiPermission;
    }

    return _canManageContract(contract);
  }

  List<int> _normalizeCareStaffIds(dynamic rawValues) {
    if (rawValues is! List<dynamic>) return <int>[];

    final Set<int> ids = <int>{};
    for (final dynamic raw in rawValues) {
      final int? value =
          raw is Map<String, dynamic> ? _readInt(raw['id']) : _readInt(raw);
      if (value != null && value > 0) {
        ids.add(value);
      }
    }

    final List<int> normalized = ids.toList()..sort();
    return normalized;
  }

  String _safeDateTime(dynamic raw) {
    if (raw == null) return '—';
    final DateTime? date = DateTime.tryParse(raw.toString());
    if (date == null) return raw.toString();
    final String hh = date.hour.toString().padLeft(2, '0');
    final String mm = date.minute.toString().padLeft(2, '0');
    return '${_fmtDate(date)} $hh:$mm';
  }

  bool get _isEmployee => widget.currentUserRole == 'nhan_vien';

  bool get _canChooseCollector =>
      <String>['admin', 'quan_ly', 'ke_toan'].contains(widget.currentUserRole);

  int? get _defaultCollectorUserId {
    if (<String>['nhan_vien', 'quan_ly'].contains(widget.currentUserRole)) {
      return widget.currentUserId;
    }
    return null;
  }

  String _approvalLabel(String value) {
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

  Future<bool> _save({bool createAndApprove = false}) async {
    final bool isCreating = editingId == null;
    if (isCreating && !widget.canCreate && !widget.canManage) {
      setState(() => message = 'Bạn không có quyền tạo hợp đồng.');
      return false;
    }
    if (!isCreating && !widget.canManage) {
      setState(() => message = 'Bạn không có quyền sửa hợp đồng.');
      return false;
    }
    if (editingId != null && !editingCanManage) {
      setState(() => message = 'Bạn chỉ có quyền xem hợp đồng này.');
      return false;
    }
    if (titleCtrl.text.trim().isEmpty || formClientId == null) {
      setState(() => message = 'Vui lòng nhập tiêu đề và chọn khách hàng.');
      return false;
    }
    final String rawValue = valueCtrl.text.trim();
    final double valueInput = rawValue.isEmpty ? 0 : _parseNumberInput(rawValue);
    if (rawValue.isNotEmpty && valueInput <= 0) {
      setState(() => message = 'Giá trị hợp đồng không hợp lệ.');
      return false;
    }
    final double value = items.isNotEmpty ? _itemsTotal() : valueInput;
    final int? paymentTimes = int.tryParse(paymentTimesCtrl.text.trim());
    final List<Map<String, dynamic>> payloadItems = items
        .map(
          (Map<String, dynamic> item) => <String, dynamic>{
            'product_id': item['product_id'],
            'product_name': item['product_name'],
            'unit': item['unit'],
            'unit_price': item['unit_price'],
            'quantity': item['quantity'],
            'note': item['note'],
          },
        )
        .toList();

    final bool ok = editingId == null
        ? await widget.apiService.createContract(
            widget.token,
            title: titleCtrl.text.trim(),
            clientId: formClientId!,
            collectorUserId: collectorUserId,
            careStaffIds: careStaffIds,
            value: value,
            paymentTimes: paymentTimes,
            status: status,
            createAndApprove: createAndApprove,
            signedAt: signedCtrl.text.trim().isEmpty
                ? null
                : signedCtrl.text.trim(),
            startDate:
                startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
            endDate: endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
            notes:
                notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            items: payloadItems,
          )
        : await widget.apiService.updateContract(
            widget.token,
            editingId!,
            title: titleCtrl.text.trim(),
            clientId: formClientId!,
            collectorUserId: collectorUserId,
            careStaffIds: careStaffIds,
            value: value,
            paymentTimes: paymentTimes,
            status: status,
            signedAt: signedCtrl.text.trim().isEmpty
                ? null
                : signedCtrl.text.trim(),
            startDate:
                startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
            endDate: endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
            notes:
                notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            items: payloadItems,
          );

    if (!mounted) return false;
    setState(() {
      message = ok
          ? (editingId == null
              ? (createAndApprove
                  ? 'Đã tạo và duyệt hợp đồng.'
                  : 'Tạo hợp đồng thành công.')
              : 'Cập nhật hợp đồng thành công.')
          : 'Lưu hợp đồng thất bại.';
    });
    if (ok) {
      _resetForm();
      await _fetch();
    }
    return ok;
  }

  Future<void> _delete(int id) async {
    if (!widget.canDelete) {
      setState(() => message = 'Bạn không có quyền xóa hợp đồng.');
      return;
    }
    final bool ok = await widget.apiService.deleteContract(widget.token, id);
    if (!mounted) return;
    setState(() {
      message = ok ? 'Xóa hợp đồng thành công.' : 'Xóa hợp đồng thất bại.';
    });
    if (ok) await _fetch();
  }

  Future<void> _openForm({Map<String, dynamic>? contract}) async {
    if (contract != null && !_canManageContract(contract)) {
      setState(() => message = 'Bạn chỉ có quyền xem hợp đồng này.');
      return;
    }

    Map<String, dynamic>? detail = contract;
    if (contract != null) {
      final int id = _readInt(contract['id']) ?? 0;
      if (id > 0) {
        final Map<String, dynamic> fetched =
            await widget.apiService.getContractDetail(widget.token, id);
        if (fetched.isNotEmpty) {
          detail = fetched;
        }
      }
    }
    if (!mounted) return;

    setState(() {
      message = '';
      if (detail == null) {
        editingCanManage = true;
        _resetForm();
      } else {
        editingCanManage = _canManageContract(detail);
        editingId = _readInt(detail['id']) ?? 0;
        titleCtrl.text = (detail['title'] ?? '').toString();
        valueCtrl.text = (detail['value'] ?? '').toString();
        paymentTimesCtrl.text = (detail['payment_times'] ?? 1).toString();
        signedCtrl.text = _safeDate(detail['signed_at']);
        startCtrl.text = _safeDate(detail['start_date']);
        endCtrl.text = _safeDate(detail['end_date']);
        notesCtrl.text = (detail['notes'] ?? '').toString();
        status = (detail['status'] ?? 'draft').toString();
        formClientId = _readInt(detail['client_id']);
        collectorUserId = _readInt(detail['collector_user_id']);
        careStaffIds = _normalizeCareStaffIds(detail['care_staff_users']);
        items = ((detail['items'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic e) {
          final Map<String, dynamic> item = e as Map<String, dynamic>;
          return <String, dynamic>{
            'product_id': item['product_id'],
            'product_name': item['product_name'] ?? '',
            'unit': item['unit'] ?? '',
            'unit_price': item['unit_price'] ?? '',
            'quantity': item['quantity'] ?? 1,
            'note': item['note'] ?? '',
          };
        }).toList();
        _syncValueController(items.isEmpty ? null : items);
      }
    });

    if (editingId != null) {
      final int id = editingId ?? 0;
      final List<Map<String, dynamic>> paymentRows =
          await widget.apiService.getContractPayments(widget.token, id);
      final List<Map<String, dynamic>> costRows =
          await widget.apiService.getContractCosts(widget.token, id);
      if (!mounted) return;
      setState(() {
        payments = paymentRows;
        costs = costRows;
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: StitchTheme.surfaceAlt,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(editingId == null ? 'Tạo Hợp Đồng' : 'Sửa Hợp Đồng', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 20, color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                    const SizedBox(height: 12),
                    const Text(
                      'Mã hợp đồng sẽ tự sinh khi lưu, người dùng không cần nhập thủ công.',
                      style: TextStyle(
                        color: StitchTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề hợp đồng *',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: formClientId,
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Chọn khách hàng *'),
                        ),
                        ...clients.map(
                          (Map<String, dynamic> c) => DropdownMenuItem<int?>(
                            value: c['id'] as int?,
                            child: Text(
                              (c['name'] ?? 'Khách hàng').toString(),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (int? value) {
                        setSheetState(() => formClientId = value);
                      },
                      decoration: const InputDecoration(labelText: 'Khách hàng'),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: StitchTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: StitchTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Nhân viên thu theo hợp đồng',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isEmployee
                                ? 'Bạn tạo hợp đồng nào thì hợp đồng đó tự đứng tên bạn và không đổi sang người khác.'
                                : widget.currentUserRole == 'quan_ly'
                                    ? 'Trưởng phòng có thể giữ chính mình hoặc chọn nhân sự trong phòng để đứng tên thu hợp đồng.'
                                    : widget.canApprove
                                        ? 'Admin/Kế toán có thể chọn mọi nhân viên và có thêm nút tạo & duyệt.'
                                        : 'Chọn nhân sự phụ trách thu hợp đồng.',
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int?>(
                            value: collectorUserId,
                            items: <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Chọn nhân viên thu'),
                              ),
                              ...collectors.map(
                                (Map<String, dynamic> user) =>
                                    DropdownMenuItem<int?>(
                                  value: _readInt(user['id']),
                                  child: Text(
                                    (user['name'] ?? 'Nhân sự').toString(),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: _canChooseCollector
                                ? (int? value) {
                                    setSheetState(() => collectorUserId = value);
                                  }
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Nhân viên thu',
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Nhân viên chăm sóc hợp đồng',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Nhóm này có quyền xem hợp đồng và thêm nhật ký chăm sóc để cập nhật tiến độ.',
                            style: TextStyle(
                              color: StitchTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (BuildContext context) {
                              final List<Map<String, dynamic>> selectedCareStaff =
                                  careStaffUsers.where((Map<String, dynamic> user) {
                                    final int uid = _readInt(user['id']) ?? 0;
                                    return uid > 0 && careStaffIds.contains(uid);
                                  }).toList();
                              final List<Map<String, dynamic>> availableCareStaff =
                                  careStaffUsers.where((Map<String, dynamic> user) {
                                    final int uid = _readInt(user['id']) ?? 0;
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
                                    child: selectedCareStaff.isEmpty
                                        ? const Text(
                                            'Chưa thêm nhân viên chăm sóc hợp đồng nào.',
                                            style: TextStyle(
                                              color: StitchTheme.textMuted,
                                              fontSize: 13,
                                            ),
                                          )
                                        : Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: selectedCareStaff.map((Map<String, dynamic> user) {
                                              final int uid = _readInt(user['id']) ?? 0;
                                              return InputChip(
                                                label: Text((user['name'] ?? 'Nhân sự').toString()),
                                                onDeleted: () => setSheetState(() {
                                                  careStaffIds = careStaffIds.where((int id) => id != uid).toList();
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
                                    child: availableCareStaff.isEmpty
                                        ? const Text(
                                            'Đã chọn hết nhân sự khả dụng.',
                                            style: TextStyle(
                                              color: StitchTheme.textMuted,
                                              fontSize: 13,
                                            ),
                                          )
                                        : Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: availableCareStaff.map((Map<String, dynamic> user) {
                                              final int uid = _readInt(user['id']) ?? 0;
                                              if (uid <= 0) {
                                                return const SizedBox.shrink();
                                              }
                                              return ActionChip(
                                                avatar: const Icon(Icons.add, size: 16),
                                                label: Text((user['name'] ?? 'Nhân sự').toString()),
                                                onPressed: () => setSheetState(() {
                                                  careStaffIds = <int>{...careStaffIds, uid}.toList()..sort();
                                                }),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: valueCtrl,
                      keyboardType: TextInputType.number,
                      readOnly: items.isNotEmpty,
                      decoration: InputDecoration(
                        labelText: items.isNotEmpty
                            ? 'Giá trị (tự tính theo sản phẩm)'
                            : 'Giá trị (VNĐ)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: paymentTimesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số lần thanh toán',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: status,
                      items: <DropdownMenuItem<String>>[
                        ...<String>[
                          'draft',
                          'signed',
                          'success',
                          'active',
                          'expired',
                          'cancelled'
                        ].map(
                          (String s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(_statusLabel(s)),
                          ),
                        ),
                      ],
                      onChanged: (String? value) {
                        setSheetState(() => status = value ?? 'draft');
                      },
                      decoration: const InputDecoration(labelText: 'Trạng thái'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: signedCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(signedCtrl),
                      decoration: const InputDecoration(
                        labelText: 'Ngày ký',
                        suffixIcon: Icon(Icons.event),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: startCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(startCtrl),
                      decoration: const InputDecoration(
                        labelText: 'Bắt đầu hiệu lực',
                        suffixIcon: Icon(Icons.event),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: endCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(endCtrl),
                      decoration: const InputDecoration(
                        labelText: 'Hết hiệu lực',
                        suffixIcon: Icon(Icons.event),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Sản phẩm trong hợp đồng',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton(
                          onPressed: () => _addItem(setSheetState),
                          child: const Text('Thêm sản phẩm'),
                        ),
                      ],
                    ),
                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: StitchTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: StitchTheme.border),
                        ),
                        child: const Text(
                          'Chưa có sản phẩm. Thêm để tự tính giá trị hợp đồng.',
                          style: TextStyle(color: StitchTheme.textMuted),
                        ),
                      )
                    else
                      Column(
                        children: items.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final Map<String, dynamic> item = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: StitchTheme.border),
                            ),
                            child: Column(
                              children: <Widget>[
                                DropdownButtonFormField<int?>(
                                  value: item['product_id'] as int?,
                                  decoration:
                                      const InputDecoration(labelText: 'Sản phẩm'),
                                  items: <DropdownMenuItem<int?>>[
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Chọn sản phẩm'),
                                    ),
                                    ...products.map(
                                      (Map<String, dynamic> p) =>
                                          DropdownMenuItem<int?>(
                                        value: p['id'] as int?,
                                        child: Text(
                                          (p['name'] ?? 'Sản phẩm').toString(),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (int? value) {
                                    final Map<String, dynamic> selected =
                                        products.firstWhere(
                                      (Map<String, dynamic> p) =>
                                          p['id'] == value,
                                      orElse: () => <String, dynamic>{},
                                    );
                                    _updateItem(
                                      index,
                                      <String, dynamic>{
                                        'product_id': value,
                                        'product_name': selected['name'] ?? '',
                                        'unit': selected['unit'] ?? '',
                                        'unit_price': selected['unit_price'] ?? '',
                                      },
                                      setSheetState,
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            (item['unit'] ?? '').toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'Đơn vị',
                                        ),
                                        onChanged: (value) => _updateItem(
                                          index,
                                          <String, dynamic>{'unit': value},
                                          setSheetState,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            (item['unit_price'] ?? '').toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'Đơn giá',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) => _updateItem(
                                          index,
                                          <String, dynamic>{'unit_price': value},
                                          setSheetState,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            (item['quantity'] ?? 1).toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'Số lượng',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) => _updateItem(
                                          index,
                                          <String, dynamic>{
                                            'quantity': value,
                                          },
                                          setSheetState,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: StitchTheme.surfaceAlt,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: StitchTheme.border,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            const Text(
                                              'Giá trị',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: StitchTheme.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _money(_itemTotal(item)),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            (item['note'] ?? '').toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'Ghi chú',
                                        ),
                                        onChanged: (value) => _updateItem(
                                          index,
                                          <String, dynamic>{'note': value},
                                          setSheetState,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _removeItem(index, setSheetState),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Xóa dòng'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Thanh toán hợp đồng',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (widget.canApprove)
                          TextButton(
                            onPressed: () => _openPaymentSheet(),
                            child: const Text('Thêm'),
                          ),
                      ],
                    ),
                    if (payments.isEmpty)
                      const Text(
                        'Chưa có thanh toán.',
                        style: TextStyle(color: StitchTheme.textMuted),
                      )
                    else
                      Column(
                        children: payments.map((Map<String, dynamic> p) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(_money(p['amount'])),
                              subtitle: Text(
                                'Ngày thu: ${_safeDate(p['paid_at'])} • ${p['method'] ?? '—'}',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: <Widget>[
                                  if (widget.canApprove)
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () =>
                                          _openPaymentSheet(payment: p),
                                    ),
                                  if (widget.canApprove)
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: StitchTheme.danger,
                                      ),
                                      onPressed: () =>
                                          _deletePayment(_readInt(p['id']) ?? 0),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Chi phí hợp đồng',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (widget.canApprove)
                          TextButton(
                            onPressed: () => _openCostSheet(),
                            child: const Text('Thêm'),
                          ),
                      ],
                    ),
                    if (costs.isEmpty)
                      const Text(
                        'Chưa có chi phí.',
                        style: TextStyle(color: StitchTheme.textMuted),
                      )
                    else
                      Column(
                        children: costs.map((Map<String, dynamic> c) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(_money(c['amount'])),
                              subtitle: Text(
                                '${c['cost_type'] ?? 'Chi phí'} • ${_safeDate(c['cost_date'])}',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: <Widget>[
                                  if (widget.canApprove)
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _openCostSheet(cost: c),
                                    ),
                                  if (widget.canApprove)
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: StitchTheme.danger,
                                      ),
                                      onPressed: () =>
                                          _deleteCost(_readInt(c['id']) ?? 0),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                    ],
                    const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
                    ),
                    child: Column(
                      children: [
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
                                  final NavigatorState navigator = Navigator.of(context);
                                  final bool ok = await _save();
                                  if (!mounted) return;
                                  if (ok) {
                                    navigator.pop();
                                  } else {
                                    setSheetState(() {});
                                  }
                                },
                                child: Text(editingId == null ? 'Lưu hợp đồng' : 'Cập nhật', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        if (editingId == null && widget.canApprove) ...<Widget>[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed: () async {
                                final NavigatorState navigator = Navigator.of(context);
                                final bool ok = await _save(createAndApprove: true);
                                if (!mounted) return;
                                if (ok) {
                                  navigator.pop();
                                } else {
                                  setSheetState(() {});
                                }
                              },
                              child: const Text('Tạo và duyệt', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
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
    setState(() => _resetForm());
  }

  Future<void> _openPaymentSheet({Map<String, dynamic>? payment}) async {
    if (!widget.canApprove) {
      setState(() => message = 'Chỉ Admin/Kế toán được quản lý thanh toán.');
      return;
    }
    if (editingId == null) {
      setState(() => message = 'Vui lòng lưu hợp đồng trước.');
      return;
    }
    final TextEditingController amountCtrl = TextEditingController(
      text: payment != null ? (payment['amount'] ?? '').toString() : '',
    );
    final TextEditingController dateCtrl = TextEditingController(
      text: payment != null ? _safeDate(payment['paid_at']) : '',
    );
    final TextEditingController methodCtrl = TextEditingController(
      text: payment != null ? (payment['method'] ?? '').toString() : '',
    );
    final TextEditingController noteCtrl = TextEditingController(
      text: payment != null ? (payment['note'] ?? '').toString() : '',
    );
    String localMessage = '';

    double contractTotal() {
      return items.isNotEmpty
          ? _itemsTotal()
          : _parseNumberInput(valueCtrl.text.trim());
    }

    double currentPaymentBaseTotal() {
      return payments.fold<double>(0, (double sum, Map<String, dynamic> row) {
        final int rowId = _readInt(row['id']) ?? 0;
        final int editingPaymentId = _readInt(payment?['id']) ?? 0;
        if (editingPaymentId > 0 && rowId == editingPaymentId) {
          return sum;
        }
        return sum + _parseNumberInput(row['amount']);
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double total = contractTotal();
            final double basePaid = currentPaymentBaseTotal();
            final double currentAmount = _parseNumberInput(amountCtrl.text.trim());
            final double remaining = math.max(0, total - basePaid);
            final double projected = basePaid + currentAmount;

            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: StitchTheme.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      payment == null ? 'Thêm thanh toán' : 'Sửa thanh toán',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: StitchTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: StitchTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Giá trị hợp đồng: ${_money(total)}'),
                          const SizedBox(height: 4),
                          Text(
                            'Còn có thể thu: ${_money(remaining)}',
                            style: TextStyle(
                              color: remaining > 0
                                  ? Colors.green.shade700
                                  : Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (projected > total + 0.0001)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Số tiền đang nhập vượt tổng giá trị hợp đồng.',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (localMessage.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        localMessage,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dateCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(dateCtrl),
                      decoration: const InputDecoration(
                        labelText: 'Ngày thu',
                        suffixIcon: Icon(Icons.event),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: methodCtrl,
                      decoration: const InputDecoration(labelText: 'Phương thức'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final NavigatorState navigator = Navigator.of(context);
                              final double amount =
                                  _parseNumberInput(amountCtrl.text.trim());
                              if (amount <= 0) {
                                setModalState(() => localMessage = 'Số tiền không hợp lệ.');
                                return;
                              }
                              if (amount > remaining + 0.0001) {
                                setModalState(() => localMessage =
                                    'Số tiền thanh toán vượt giá trị hợp đồng.');
                                return;
                              }
                              final bool ok = payment == null
                                  ? await widget.apiService.createContractPayment(
                                      widget.token,
                                      editingId!,
                                      amount: amount,
                                      paidAt: dateCtrl.text.trim().isEmpty
                                          ? null
                                          : dateCtrl.text.trim(),
                                      method: methodCtrl.text.trim().isEmpty
                                          ? null
                                          : methodCtrl.text.trim(),
                                      note: noteCtrl.text.trim().isEmpty
                                          ? null
                                          : noteCtrl.text.trim(),
                                    )
                                  : await widget.apiService.updateContractPayment(
                                      widget.token,
                                      editingId!,
                                      _readInt(payment['id']) ?? 0,
                                      amount: amount,
                                      paidAt: dateCtrl.text.trim().isEmpty
                                          ? null
                                          : dateCtrl.text.trim(),
                                      method: methodCtrl.text.trim().isEmpty
                                          ? null
                                          : methodCtrl.text.trim(),
                                      note: noteCtrl.text.trim().isEmpty
                                          ? null
                                          : noteCtrl.text.trim(),
                                    );
                              if (!mounted) return;
                              setState(() {
                                message = ok
                                    ? 'Đã lưu thanh toán.'
                                    : 'Lưu thanh toán thất bại.';
                              });
                              if (ok) {
                                final List<Map<String, dynamic>> paymentRows =
                                    await widget.apiService.getContractPayments(
                                        widget.token, editingId!);
                                if (!mounted) return;
                                setState(() {
                                  payments = paymentRows;
                                });
                                navigator.pop();
                              }
                            },
                            child: const Text('Lưu'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
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

  Future<void> _deletePayment(int paymentId) async {
    if (editingId == null) return;
    final bool ok = await widget.apiService
        .deleteContractPayment(widget.token, editingId!, paymentId);
    if (!mounted) return;
    setState(() {
      message = ok ? 'Đã xóa thanh toán.' : 'Xóa thanh toán thất bại.';
    });
    if (ok) {
      final List<Map<String, dynamic>> paymentRows =
          await widget.apiService.getContractPayments(widget.token, editingId!);
      if (!mounted) return;
      setState(() {
        payments = paymentRows;
      });
    }
  }

  Future<void> _openCostSheet({Map<String, dynamic>? cost}) async {
    if (!widget.canApprove) {
      setState(() => message = 'Chỉ Admin/Kế toán được quản lý chi phí.');
      return;
    }
    if (editingId == null) {
      setState(() => message = 'Vui lòng lưu hợp đồng trước.');
      return;
    }
    final TextEditingController amountCtrl = TextEditingController(
      text: cost != null ? (cost['amount'] ?? '').toString() : '',
    );
    final TextEditingController dateCtrl = TextEditingController(
      text: cost != null ? _safeDate(cost['cost_date']) : '',
    );
    final TextEditingController typeCtrl = TextEditingController(
      text: cost != null ? (cost['cost_type'] ?? '').toString() : '',
    );
    final TextEditingController noteCtrl = TextEditingController(
      text: cost != null ? (cost['note'] ?? '').toString() : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: StitchTheme.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  cost == null ? 'Thêm chi phí' : 'Sửa chi phí',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  onTap: () => _pickDate(dateCtrl),
                  decoration: const InputDecoration(
                    labelText: 'Ngày chi',
                    suffixIcon: Icon(Icons.event),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(labelText: 'Loại chi phí'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final NavigatorState navigator = Navigator.of(context);
                          final double? amount =
                              double.tryParse(amountCtrl.text.trim());
                          if (amount == null) {
                            setState(() => message = 'Số tiền không hợp lệ.');
                            return;
                          }
                          final bool ok = cost == null
                              ? await widget.apiService.createContractCost(
                                  widget.token,
                                  editingId!,
                                  amount: amount,
                                  costDate: dateCtrl.text.trim().isEmpty
                                      ? null
                                      : dateCtrl.text.trim(),
                                  costType: typeCtrl.text.trim().isEmpty
                                      ? null
                                      : typeCtrl.text.trim(),
                                  note: noteCtrl.text.trim().isEmpty
                                      ? null
                                      : noteCtrl.text.trim(),
                                )
                              : await widget.apiService.updateContractCost(
                                  widget.token,
                                  editingId!,
                                  _readInt(cost['id']) ?? 0,
                                  amount: amount,
                                  costDate: dateCtrl.text.trim().isEmpty
                                      ? null
                                      : dateCtrl.text.trim(),
                                  costType: typeCtrl.text.trim().isEmpty
                                      ? null
                                      : typeCtrl.text.trim(),
                                  note: noteCtrl.text.trim().isEmpty
                                      ? null
                                      : noteCtrl.text.trim(),
                                );
                          if (!mounted) return;
                          setState(() {
                            message = ok
                                ? 'Đã lưu chi phí.'
                                : 'Lưu chi phí thất bại.';
                          });
                          if (ok) {
                            final List<Map<String, dynamic>> costRows =
                                await widget.apiService.getContractCosts(
                                    widget.token, editingId!);
                            if (!mounted) return;
                            setState(() {
                              costs = costRows;
                            });
                            navigator.pop();
                          }
                        },
                        child: const Text('Lưu'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
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
  }

  Future<void> _deleteCost(int costId) async {
    if (editingId == null) return;
    final bool ok = await widget.apiService
        .deleteContractCost(widget.token, editingId!, costId);
    if (!mounted) return;
    setState(() {
      message = ok ? 'Đã xóa chi phí.' : 'Xóa chi phí thất bại.';
    });
    if (ok) {
      final List<Map<String, dynamic>> costRows =
          await widget.apiService.getContractCosts(widget.token, editingId!);
      if (!mounted) return;
      setState(() {
        costs = costRows;
      });
    }
  }

  void _resetForm() {
    editingId = null;
    editingCanManage = true;
    formClientId = null;
    collectorUserId = _defaultCollectorUserId;
    careStaffIds = <int>[];
    status = 'draft';
    titleCtrl.clear();
    valueCtrl.clear();
    paymentTimesCtrl.text = '1';
    signedCtrl.clear();
    startCtrl.clear();
    endCtrl.clear();
    notesCtrl.clear();
    items = <Map<String, dynamic>>[];
    payments = <Map<String, dynamic>>[];
    costs = <Map<String, dynamic>>[];
  }

  Future<void> _openDetail({required Map<String, dynamic> contract}) async {
    final int id = _readInt(contract['id']) ?? 0;
    if (id <= 0) {
      setState(() => message = 'Không tải được chi tiết hợp đồng.');
      return;
    }

    final Map<String, dynamic> detail =
        await widget.apiService.getContractDetail(widget.token, id);
    if (!mounted) return;
    if (detail.isEmpty) {
      setState(() => message = 'Không tải được chi tiết hợp đồng.');
      return;
    }

    careNoteTitleCtrl.clear();
    careNoteDetailCtrl.clear();

    Map<String, dynamic> detailData = Map<String, dynamic>.from(detail);
    bool savingCareNote = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final List<Map<String, dynamic>> careStaffRows =
                ((detailData['care_staff_users'] ?? <dynamic>[]) as List<dynamic>)
                    .map(
                      (dynamic row) =>
                          Map<String, dynamic>.from(row as Map<String, dynamic>),
                    )
                    .toList();
            final List<Map<String, dynamic>> careNotes =
                ((detailData['care_notes'] ?? <dynamic>[]) as List<dynamic>)
                    .map(
                      (dynamic row) =>
                          Map<String, dynamic>.from(row as Map<String, dynamic>),
                    )
                    .toList();
            final bool canAddCareNote =
                _readBool(detailData['can_add_care_note']) ?? false;

            final bool canCreateProject =
                _readBool(detailData['can_create_project']) ?? false;
            final bool showCreateProjectBtn = canCreateProject &&
                detailData['approval_status'] == 'approved' &&
                (detailData['project_id'] == null || detailData['project_id'].toString().isEmpty || detailData['project_id'].toString() == 'null');

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: StitchTheme.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: StitchTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: StitchTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: StitchTheme.textMain.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                              border: Border.all(color: StitchTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (detailData['title'] ?? 'Chi tiết hợp đồng').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.business_center_outlined, size: 16, color: StitchTheme.textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${(detailData['code'] ?? '').toString()} • ${((detailData['client'] as Map<String, dynamic>?)?['name'] ?? 'Khách hàng').toString()}',
                                        style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildBadge(
                                      _statusLabel((detailData['status'] ?? 'draft').toString()),
                                      _statusColor((detailData['status'] ?? 'draft').toString()),
                                    ),
                                    _buildBadge(
                                      _approvalLabel((detailData['approval_status'] ?? 'pending').toString()),
                                      detailData['approval_status'] == 'approved' ? StitchTheme.success : StitchTheme.warning,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text('Thông tin Tài chính', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: StitchTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: StitchTheme.border),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow('Giá trị hợp đồng', _money(detailData['value']), bold: true),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                                _buildDetailRow('Đã thu', _money(detailData['payments_total']), textColor: StitchTheme.successStrong),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                                _buildDetailRow('Công nợ', _money(detailData['debt_outstanding']), textColor: StitchTheme.dangerStrong),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                                _buildDetailRow('Chi phí', _money(detailData['costs_total'])),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text('Thông tin Chung', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: StitchTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: StitchTheme.border),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow('Nhân viên thu', ((detailData['collector'] as Map<String, dynamic>?)?['name'] ?? '—').toString()),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                                _buildDetailRow('Dự án', ((detailData['project'] as Map<String, dynamic>?)?['name'] ?? 'Chưa liên kết').toString()),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                                _buildDetailRow('Ngày ký', _safeDate(detailData['signed_at'])),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                                _buildDetailRow('Thời gian', '${_safeDate(detailData['start_date'])} → ${_safeDate(detailData['end_date'])}'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          if (showCreateProjectBtn) ...<Widget>[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreateProjectScreen(
                                        token: widget.token,
                                        apiService: widget.apiService,
                                        initialContractId: detailData['id'].toString(),
                                        initialContractTitle: detailData['title']?.toString(),
                                      ),
                                    ),
                                  ).then((_) => _fetch());
                                },
                                icon: const Icon(Icons.rocket_launch, size: 18),
                                label: const Text('Tạo Dự án Triển khai'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          const Text('Nhân sự CSKH', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 12),
                          if (careStaffRows.isEmpty)
                            const Text('Chưa phân công nhân sự CSKH.', style: TextStyle(color: StitchTheme.textMuted))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: careStaffRows.map((row) {
                                final n = (row['name'] ?? 'U').toString();
                                return Chip(
                                  avatar: CircleAvatar(
                                    backgroundColor: StitchTheme.primary.withValues(alpha: 0.1),
                                    child: Text(n.isNotEmpty ? n.substring(0, 1).toUpperCase() : 'U', style: TextStyle(color: StitchTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  label: Text(n),
                                  backgroundColor: StitchTheme.surface,
                                  side: const BorderSide(color: StitchTheme.border),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 24),

                          const Text('Nhật ký chăm sóc', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text(
                            'Ghi lại các tương tác, tiến độ và yêu cầu để nhóm cùng nắm được.',
                            style: TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                          ),
                          if (canAddCareNote) ...<Widget>[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: StitchTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: StitchTheme.border),
                              ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: careNoteTitleCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Tiêu đề ngắn',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  TextField(
                                    controller: careNoteDetailCtrl,
                                    minLines: 2,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      labelText: 'Nội dung chi tiết...',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: savingCareNote
                                          ? null
                                          : () async {
                                              final String title = careNoteTitleCtrl.text.trim();
                                              final String detailText = careNoteDetailCtrl.text.trim();
                                              if (title.isEmpty || detailText.isEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Vui lòng nhập tiêu đề và nội dung.')),
                                                );
                                                return;
                                              }
                                              setSheetState(() => savingCareNote = true);
                                              final Map<String, dynamic>? note = await widget.apiService.createContractCareNote(widget.token, id, title: title, detail: detailText);
                                              if (!context.mounted) return;
                                              setSheetState(() => savingCareNote = false);
                                              if (note == null) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lưu thất bại.')));
                                                return;
                                              }
                                              setSheetState(() {
                                                final List<dynamic> nextNotes = List<dynamic>.from((detailData['care_notes'] ?? <dynamic>[]) as List<dynamic>);
                                                nextNotes.insert(0, note);
                                                detailData['care_notes'] = nextNotes;
                                              });
                                              careNoteTitleCtrl.clear();
                                              careNoteDetailCtrl.clear();
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật nhật ký.')));
                                            },
                                      child: Text(savingCareNote ? 'Đang lưu...' : 'Gửi nhật ký'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (careNotes.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Chưa có lịch sử chăm sóc.', style: TextStyle(color: StitchTheme.textSubtle, fontStyle: FontStyle.italic)),
                              ),
                            )
                          else
                            ...careNotes.map((Map<String, dynamic> note) {
                              final Map<String, dynamic>? user = note['user'] as Map<String, dynamic>?;
                              final String uName = (user?['name'] ?? 'Ẩn danh').toString();
                              final String initial = uName.isNotEmpty ? uName.substring(0, 1).toUpperCase() : '?';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: StitchTheme.primary.withValues(alpha: 0.1),
                                      child: Text(initial, style: TextStyle(color: StitchTheme.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: StitchTheme.surface,
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(16),
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                          border: Border.all(color: StitchTheme.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(uName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                                ),
                                                Text(_safeDateTime(note['created_at']), style: const TextStyle(color: StitchTheme.textSubtle, fontSize: 11)),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              (note['title'] ?? '').toString(),
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Text((note['detail'] ?? '').toString(), style: const TextStyle(color: StitchTheme.textMuted)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            );
          },
        );
      },
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool bold = false, Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: textColor ?? StitchTheme.textMain)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final int active =
        contracts.where((Map<String, dynamic> c) => c['status'] == 'active').length;
    final int signed =
        contracts.where((Map<String, dynamic> c) => c['status'] == 'signed').length;
    final int expired =
        contracts.where((Map<String, dynamic> c) => c['status'] == 'expired').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hợp đồng'),
        actions: <Widget>[
          if (widget.canCreate || widget.canManage)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: _importContracts,
            ),
          if (widget.canCreate || widget.canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: <Widget>[
          const StitchHeroCard(
            title: 'Khách hàng → Hợp đồng → Dự án',
            subtitle:
                'Tạo hợp đồng theo khách hàng, theo dõi trạng thái và hiệu lực trước khi tạo công việc.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              StitchMetricCard(
                icon: Icons.description_outlined,
                label: 'Tổng hợp đồng',
                value: totalContracts.toString(),
              ),
              StitchMetricCard(
                icon: Icons.verified_outlined,
                label: 'Đang hiệu lực',
                value: active.toString(),
                accent: StitchTheme.success,
              ),
              StitchMetricCard(
                icon: Icons.check_circle_outline,
                label: 'Đã ký',
                value: signed.toString(),
                accent: StitchTheme.primary,
              ),
              StitchMetricCard(
                icon: Icons.event_busy,
                label: 'Hết hạn',
                value: expired.toString(),
                accent: StitchTheme.warning,
              ),
            ],
          ),
          if (message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StitchTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Text(
                message,
                style: const TextStyle(color: StitchTheme.textMuted),
              ),
            ),
          ],
          const SizedBox(height: 18),
          StitchFilterCard(
            title: 'Bộ lọc hợp đồng',
            subtitle:
                'Lọc theo mã, khách hàng và trạng thái để thao tác hợp đồng nhanh hơn.',
            trailing: OutlinedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('Lọc'),
            ),
            child: Column(
              children: <Widget>[
                StitchFilterField(
                  label: 'Tìm kiếm',
                  child: TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Mã hợp đồng, tiêu đề hoặc khách hàng',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StitchFilterField(
                  label: 'Trạng thái',
                  child: DropdownButtonFormField<String>(
                    value: filterStatus,
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Tất cả trạng thái'),
                      ),
                      ...<String>['draft', 'signed', 'success', 'active', 'expired', 'cancelled']
                          .map(
                            (String s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(_statusLabel(s)),
                            ),
                          ),
                    ],
                    onChanged: (String? value) {
                      setState(() => filterStatus = value ?? '');
                    },
                    decoration: const InputDecoration(
                      hintText: 'Tất cả trạng thái',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StitchFilterField(
                  label: 'Khách hàng',
                  child: DropdownButtonFormField<int?>(
                    value: filterClientId,
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả khách hàng'),
                      ),
                      ...clients.map(
                        (Map<String, dynamic> c) => DropdownMenuItem<int?>(
                          value: c['id'] as int?,
                          child: Text(
                            (c['name'] ?? 'Khách hàng').toString(),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (int? value) {
                      setState(() => filterClientId = value);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Tất cả khách hàng',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Đang hiển thị ${contracts.length} trên tổng số $totalContracts hợp đồng.',
            style: const TextStyle(
              color: StitchTheme.textMuted,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (contracts.isEmpty)
            const Text(
              'Chưa có hợp đồng.',
              style: TextStyle(color: StitchTheme.textMuted),
            )
          else
            ...contracts.map((Map<String, dynamic> c) => _buildContractItem(c)),
          if (loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (!loadingMore && currentPage >= lastPage && contracts.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Đã hiển thị toàn bộ hợp đồng.',
                  style: TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildContractItem(Map<String, dynamic> c) {
    final Color statusColor = _statusColor((c['status'] ?? '').toString());
    final Map<String, dynamic>? client = c['client'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: StitchTheme.textMain.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(width: 5, color: statusColor), // Vạch màu bên trái
              Expanded(
                child: InkWell(
                  onTap: () => _openDetail(contract: c), // Bấm cả thẻ để Xem details
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    (c['title'] ?? 'Hợp đồng').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${c['code'] ?? ''} • ${(client?['name'] ?? 'Khách hàng').toString()}',
                                    style: const TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.canManage || _canDeleteContract(c)) ...<Widget>[
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 32,
                                width: 32,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20, color: StitchTheme.textMuted),
                                  padding: EdgeInsets.zero,
                                  position: PopupMenuPosition.under,
                                  onSelected: (String val) {
                                    if (val == 'edit') _openForm(contract: c);
                                    if (val == 'delete') _delete((c['id'] ?? 0) as int);
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    if (widget.canManage)
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Sửa hợp đồng'),
                                      ),
                                    if (_canDeleteContract(c))
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Xóa', style: TextStyle(color: StitchTheme.danger)),
                                      ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                _statusLabel((c['status'] ?? '').toString()),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            if (c['approval_status'] == 'pending')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: StitchTheme.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Chờ duyệt',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: StitchTheme.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: StitchTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: StitchTheme.border.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(child: _buildMetricCol(Icons.monetization_on_outlined, 'Giá trị', _money(c['value']))),
                                  Expanded(child: _buildMetricCol(Icons.account_balance_wallet_outlined, 'Đã thu', _money(c['payments_total']), highlight: true)),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1),
                              ),
                              Row(
                                children: <Widget>[
                                  Expanded(child: _buildMetricCol(Icons.warning_amber_rounded, 'Công nợ', _money(c['debt_outstanding']), color: StitchTheme.danger)),
                                  Expanded(child: _buildMetricCol(Icons.calendar_month_outlined, 'Hiệu lực', '${_safeDate(c['start_date'])} -> ${_safeDate(c['end_date'])}')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.person_outline, size: 14, color: StitchTheme.textSubtle),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Thu tiền: ${((c['collector'] as Map<String, dynamic>?)?['name'] ?? '—').toString()}',
                                style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (c['approval_status'] == 'pending' && widget.canApprove) ...<Widget>[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                final bool ok = await widget.apiService.approveContract(widget.token, (c['id'] ?? 0) as int);
                                if (!mounted) return;
                                setState(() {
                                  message = ok ? 'Đã duyệt hợp đồng.' : 'Duyệt hợp đồng thất bại.';
                                });
                                if (ok) await _fetch();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: StitchTheme.success),
                                foregroundColor: StitchTheme.success,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Duyệt ngang'),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCol(IconData icon, String label, String value, {bool highlight = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 12, color: color ?? StitchTheme.textSubtle),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color ?? StitchTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            color: color ?? StitchTheme.textMain,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

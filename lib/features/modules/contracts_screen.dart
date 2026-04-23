import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/messaging/app_tag_message.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/staff_multi_filter_row.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';
import '../projects/create_project_screen.dart';

List<Map<String, dynamic>> _normalizePaymentDisplayRows(dynamic raw) {
  if (raw == null) return <Map<String, dynamic>>[];
  final List<dynamic> list = raw is List<dynamic> ? raw : <dynamic>[];
  return list.map((dynamic e) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(e as Map);
    m.putIfAbsent('row_type', () => 'record');
    return m;
  }).toList();
}

List<Map<String, dynamic>> _normalizeCostDisplayRows(dynamic raw) {
  if (raw == null) return <Map<String, dynamic>>[];
  final List<dynamic> list = raw is List<dynamic> ? raw : <dynamic>[];
  return list.map((dynamic e) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(e as Map);
    m.putIfAbsent('row_type', () => 'record');
    return m;
  }).toList();
}

/// Cùng quy tắc API: `start >= signed`, `end > start` (chuỗi `yyyy-MM-dd`).
String? _validateContractYmdOrder(String signed, String start, String end) {
  final String s = signed.trim();
  final String a = start.trim();
  final String e = end.trim();
  if (s.isEmpty || a.isEmpty || e.isEmpty) {
    return 'Vui lòng nhập đủ ngày ký, ngày bắt đầu hiệu lực và ngày kết thúc.';
  }
  if (a.compareTo(s) < 0) {
    return 'Ngày bắt đầu hiệu lực phải từ ngày ký trở đi.';
  }
  if (e.compareTo(a) <= 0) {
    return 'Ngày kết thúc phải sau ngày bắt đầu hiệu lực.';
  }
  return null;
}

class _VnCurrencyInputFormatter extends TextInputFormatter {
  const _VnCurrencyInputFormatter();

  static String formatDigits(String raw) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final String reversed = digits.split('').reversed.join();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(reversed[i]);
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String formatted = formatDigits(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
    this.canCreate = false,
    required this.canDelete,
    required this.canApprove,
    required this.canCreateContractFinanceLines,
    required this.canEditContractFinanceLines,
    required this.currentUserRole,
    required this.currentUserId,
    this.initialContractId,
    this.initialFinanceRequestId,

    /// Push `contract_approval`: nhấn mạnh khối duyệt hợp đồng + cuộn tới.
    this.initialFocusPendingContractApproval = false,
  });

  final String token;
  final MobileApiService apiService;

  /// Edit existing contracts (admin, quan_ly, ke_toan)
  final bool canManage;

  /// Create new contracts (admin, quan_ly, nhan_vien, ke_toan)
  final bool canCreate;
  final bool canDelete;

  /// POST /contracts/{id}/approve — admin, ke_toan
  final bool canApprove;

  /// POST /contracts/{id}/payments|costs — thêm dòng thu/chi
  final bool canCreateContractFinanceLines;

  /// PUT/DELETE dòng thu/chi — admin, ke_toan
  final bool canEditContractFinanceLines;
  final String currentUserRole;
  final int? currentUserId;
  final int? initialContractId;
  final int? initialFinanceRequestId;
  final bool initialFocusPendingContractApproval;

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController valueCtrl = TextEditingController();
  final TextEditingController paymentTimesCtrl = TextEditingController(
    text: '1',
  );
  final TextEditingController signedCtrl = TextEditingController();
  final TextEditingController startCtrl = TextEditingController();
  final TextEditingController endCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();
  final TextEditingController careNoteTitleCtrl = TextEditingController();
  final TextEditingController careNoteDetailCtrl = TextEditingController();

  bool loading = false;

  /// Đang tải lại khi đã có danh sách — không thay toàn bộ list bằng spinner (tránh nhảy scroll).
  bool _listRefreshing = false;
  bool loadingMore = false;
  bool _savingContractForm = false;
  String message = '';
  String filterStatus = '';
  int? filterClientId;
  int? formClientId;
  int? formOpportunityId;
  int? editingId;
  String status = 'draft';

  int currentPage = 1;
  int lastPage = 1;
  int totalContracts = 0;
  final ScrollController scrollController = ScrollController();
  bool _autoOpenedInitialContract = false;

  /// Tổng theo bộ lọc (API, không phụ thuộc trang hiện tại).
  double aggregateRevenueTotal = 0;
  double aggregateCashflowTotal = 0;
  double aggregateDebtTotal = 0;
  double aggregateCostsTotal = 0;

  List<Map<String, dynamic>> contracts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> formClients = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> linkableOpportunities = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> products = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> collectors = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> careStaffUsers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> payments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> costs = <Map<String, dynamic>>[];
  int? collectorUserId;
  List<int> careStaffIds = <int>[];
  List<int> contractListStaffFilterIds = <int>[];
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

  void _maybeOpenInitialContractDetail() {
    if (_autoOpenedInitialContract) return;
    final int? contractId = widget.initialContractId;
    if (contractId == null || contractId <= 0) return;

    _autoOpenedInitialContract = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openDetail(
        contract: <String, dynamic>{'id': contractId},
        focusFinanceRequestId: widget.initialFinanceRequestId,
        focusPendingContractApproval:
            widget.initialFocusPendingContractApproval,
      );
    });
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
      if (contracts.isEmpty) {
        loading = true;
        _listRefreshing = false;
      } else {
        loading = false;
        _listRefreshing = true;
      }
      currentPage = 1;
    });

    try {
      // Clients might also be paginated now, let's take a reasonable amount for the dropdown
      final Map<String, dynamic> clientPayload = await widget.apiService
          .getClients(widget.token, perPage: 100);
      final Map<String, dynamic> formClientPayload = await widget.apiService
          .getClients(widget.token, perPage: 100, assignedOnly: true);
      final List<Map<String, dynamic>> productRows = await widget.apiService
          .getProducts(widget.token);
      final List<Map<String, dynamic>> collectorRows = await widget.apiService
          .getUsersLookup(widget.token, purpose: 'contract_collector');
      final List<Map<String, dynamic>> careStaffRows = await widget.apiService
          .getUsersLookup(widget.token, purpose: 'contract_care_staff');

      final Map<String, dynamic> contractPayload = await widget.apiService
          .getContracts(
            widget.token,
            page: 1,
            perPage: 20,
            search: searchCtrl.text.trim(),
            status: filterStatus,
            clientId: filterClientId,
            withItems: true,
            staffIds:
                contractListStaffFilterIds.isEmpty
                    ? null
                    : contractListStaffFilterIds,
          );

      if (!mounted) return;

      final List<dynamic> clientData =
          (clientPayload['data'] ?? []) as List<dynamic>;
      final List<dynamic> formClientData =
          (formClientPayload['data'] ?? []) as List<dynamic>;
      final List<dynamic> contractData =
          (contractPayload['data'] ?? []) as List<dynamic>;

      _applyContractAggregates(contractPayload['aggregates']);

      setState(() {
        loading = false;
        _listRefreshing = false;
        clients = clientData.map((e) => e as Map<String, dynamic>).toList();
        formClients =
            formClientData.map((e) => e as Map<String, dynamic>).toList();
        products = productRows;
        collectors = collectorRows;
        careStaffUsers = careStaffRows;
        contracts = contractData.map((e) => e as Map<String, dynamic>).toList();
        lastPage = (contractPayload['last_page'] ?? 1) as int;
        totalContracts = (contractPayload['total'] ?? 0) as int;
      });
      _maybeOpenInitialContractDetail();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          _listRefreshing = false;
        });
      }
    }
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
      staffIds:
          contractListStaffFilterIds.isEmpty
              ? null
              : contractListStaffFilterIds,
    );

    if (mounted) {
      final List<dynamic> newData = (payload['data'] ?? []) as List<dynamic>;
      _applyContractAggregates(payload['aggregates']);
      setState(() {
        loadingMore = false;
        contracts.addAll(
          newData.map((e) => e as Map<String, dynamic>).toList(),
        );
        currentPage = nextPage;
        lastPage = (payload['last_page'] ?? 1) as int;
        totalContracts = (payload['total'] ?? 0) as int;
      });
    }
  }

  void _applyContractAggregates(dynamic raw) {
    if (raw is! Map) return;
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    aggregateRevenueTotal = _parseNumberInput(m['revenue_total']);
    aggregateCashflowTotal = _parseNumberInput(m['cashflow_total']);
    aggregateDebtTotal = _parseNumberInput(m['debt_total']);
    aggregateCostsTotal = _parseNumberInput(m['costs_total']);
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
    final Map<String, dynamic> report = await widget.apiService.importContracts(
      widget.token,
      file,
    );
    if (!mounted) return;
    setState(() {
      message =
          report['error'] != null
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
    return VietnamTime.toYmdInput(raw);
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
      value =
          parts.length > 2 || (parts.length == 2 && parts[1].length == 3)
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

  String _formatMoneyInput(dynamic raw) {
    if (raw == null) return '';
    return _VnCurrencyInputFormatter.formatDigits(raw.toString());
  }

  String _todayInputDate() {
    return VietnamTime.todayIso();
  }

  Future<void> _openContractSoftCopyModal({
    required BuildContext context,
    required int contractId,
    required bool canManage,
    required Future<void> Function() onChanged,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.62,
          child: _ContractSoftCopySheet(
            token: widget.token,
            api: widget.apiService,
            contractId: contractId,
            canManage: canManage,
            onChanged: onChanged,
          ),
        );
      },
    );
  }

  double _itemTotal(Map<String, dynamic> item) {
    final double price = _parseNumberInput(item['unit_price']);
    final double qty = math.max(1, _parseNumberInput(item['quantity']));
    return price * qty;
  }

  double _currentSubtotalValue([List<Map<String, dynamic>>? sourceItems]) {
    final List<Map<String, dynamic>> rows = sourceItems ?? items;
    if (rows.isNotEmpty) {
      return _itemsTotalFromRows(rows);
    }
    return _parseNumberInput(valueCtrl.text.trim());
  }

  double _currentContractTotal([List<Map<String, dynamic>>? sourceItems]) {
    return _currentSubtotalValue(sourceItems);
  }

  void _syncValueController([List<Map<String, dynamic>>? sourceItems]) {
    final List<Map<String, dynamic>> rows = sourceItems ?? items;
    if (rows.isNotEmpty) {
      final double subtotal = _itemsTotalFromRows(rows);
      valueCtrl.text = _formatMoneyInput(subtotal.toStringAsFixed(0));
      return;
    }
    if (sourceItems != null) {
      valueCtrl.clear();
    }
  }

  double _itemsTotalFromRows(List<Map<String, dynamic>> rows) {
    return rows.fold<double>(
      0,
      (double acc, Map<String, dynamic> item) => acc + _itemTotal(item),
    );
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
        },
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
      final List<Map<String, dynamic>> nextItems =
          List<Map<String, dynamic>>.from(items);
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

  void _updateItem(
    int index,
    Map<String, dynamic> changes, [
    StateSetter? setSheetState,
  ]) {
    void apply() {
      final List<Map<String, dynamic>> nextItems =
          items.asMap().entries.map((entry) {
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
    return '${_formatMoneyInput(_parseNumberInput(raw).toStringAsFixed(0))} đ';
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

  /// Lịch sử thao tác sau duyệt (API: activity_logs).
  List<Widget> _contractActivityLogSection(Map<String, dynamic> detailData) {
    final List<dynamic> logs =
        (detailData['activity_logs'] ??
                detailData['activityLogs'] ??
                <dynamic>[])
            as List<dynamic>;
    final List<Widget> out = <Widget>[
      const SizedBox(height: 24),
      const Text(
        'Lịch sử thao tác (sau duyệt)',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 6),
      const Text(
        'Chỉnh sửa và thao tác sau khi hợp đồng đã được duyệt.',
        style: TextStyle(color: StitchTheme.textMuted, fontSize: 13),
      ),
      const SizedBox(height: 12),
    ];
    if (logs.isEmpty) {
      out.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'Chưa có lịch sử thao tác.',
              style: TextStyle(
                color: StitchTheme.textSubtle,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
      return out;
    }
    for (final dynamic raw in logs) {
      final Map<String, dynamic> log = Map<String, dynamic>.from(
        raw as Map<dynamic, dynamic>,
      );
      final Map<String, dynamic>? u = log['user'] as Map<String, dynamic>?;
      final String actor = (u?['name'] ?? '—').toString();
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StitchTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: StitchTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$actor • ${_safeDateTime(log['created_at'])}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: StitchTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (log['summary'] ?? '').toString(),
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return out;
  }

  bool get _isEmployee => widget.currentUserRole == 'nhan_vien';

  bool get _canChooseCollector =>
      <String>['admin', 'quan_ly', 'ke_toan'].contains(widget.currentUserRole);

  /// Khi tạo mới: mặc định là người đang đăng nhập (có thể đổi nếu được phép).
  int? get _defaultCollectorUserId {
    final int? uid = widget.currentUserId;
    if (uid != null && uid > 0) return uid;
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

  String _financeTypeLabel(String value) {
    switch (value) {
      case 'cost':
        return 'Phiếu chi phí';
      case 'payment':
      default:
        return 'Phiếu thu tiền';
    }
  }

  String _financeStatusLabel(String value) {
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

  Color _financeStatusColor(String value) {
    switch (value) {
      case 'approved':
        return StitchTheme.success;
      case 'rejected':
        return StitchTheme.danger;
      case 'pending':
      default:
        return StitchTheme.warning;
    }
  }

  Color _statusSoftColor(String value) {
    switch (value) {
      case 'active':
        return StitchTheme.primarySoft;
      case 'success':
        return StitchTheme.successSoft;
      case 'signed':
        return StitchTheme.primarySoft;
      case 'expired':
        return StitchTheme.warningSoft;
      case 'cancelled':
        return StitchTheme.dangerSoft;
      case 'draft':
      default:
        return StitchTheme.surfaceAlt;
    }
  }

  IconData _statusIcon(String value) {
    switch (value) {
      case 'active':
        return Icons.bolt_rounded;
      case 'success':
        return Icons.verified_rounded;
      case 'signed':
        return Icons.draw_rounded;
      case 'expired':
        return Icons.event_busy_rounded;
      case 'cancelled':
        return Icons.block_rounded;
      case 'draft':
      default:
        return Icons.edit_note_rounded;
    }
  }

  Widget _buildContractStatusBadge(String value) {
    final Color fg = _statusColor(value);
    final Color bg = _statusSoftColor(value);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon(value), color: fg, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusLabel(value),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _save({bool createAndApprove = false}) async {
    if (_savingContractForm) {
      return false;
    }
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
    final double valueInput =
        rawValue.isEmpty ? 0 : _parseNumberInput(rawValue);
    if (rawValue.isNotEmpty && valueInput <= 0) {
      setState(() => message = 'Giá trị hợp đồng không hợp lệ.');
      return false;
    }
    final String? contractDateErr = _validateContractYmdOrder(
      signedCtrl.text,
      startCtrl.text,
      endCtrl.text,
    );
    if (contractDateErr != null) {
      setState(() => message = contractDateErr);
      return false;
    }
    final int validProductLines =
        items.where((Map<String, dynamic> item) {
          final int? pid = _readInt(item['product_id']);
          final String name = (item['product_name'] ?? '').toString().trim();
          return (pid != null && pid > 0) || name.isNotEmpty;
        }).length;
    if (validProductLines < 1) {
      setState(
        () =>
            message =
                'Vui lòng thêm ít nhất một dòng sản phẩm hoặc dịch vụ vào hợp đồng.',
      );
      return false;
    }
    final double subtotalValue = _currentSubtotalValue();
    final double value = _currentContractTotal();
    final int? paymentTimes = int.tryParse(paymentTimesCtrl.text.trim());
    final List<Map<String, dynamic>> payloadItems =
        items.map((Map<String, dynamic> item) {
          final Map<String, dynamic> row = <String, dynamic>{
            'product_id': item['product_id'],
            'product_name': item['product_name'],
            'unit': item['unit'],
            'unit_price': item['unit_price'],
            'quantity': item['quantity'],
            'note': item['note'],
          };
          final int? lineId = _readInt(item['id']);
          if (editingId != null && lineId != null && lineId > 0) {
            row['id'] = lineId;
          }
          return row;
        }).toList();
    final List<Map<String, dynamic>> pendingPaymentRequests =
        editingId == null
            ? payments
                .where(
                  (Map<String, dynamic> row) =>
                      (row['row_type']?.toString() ?? '') == 'create_draft',
                )
                .map(
                  (Map<String, dynamic> row) => <String, dynamic>{
                    'amount': _parseNumberInput(row['amount']),
                    'paid_at':
                        (row['paid_at'] ?? '').toString().trim().isEmpty
                            ? null
                            : row['paid_at'],
                    'method':
                        (row['method'] ?? '').toString().trim().isEmpty
                            ? null
                            : row['method'],
                    'note':
                        (row['note'] ?? '').toString().trim().isEmpty
                            ? null
                            : row['note'],
                  },
                )
                .toList()
            : <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> pendingCostRequests =
        editingId == null
            ? costs
                .where(
                  (Map<String, dynamic> row) =>
                      (row['row_type']?.toString() ?? '') == 'create_draft',
                )
                .map(
                  (Map<String, dynamic> row) => <String, dynamic>{
                    'amount': _parseNumberInput(row['amount']),
                    'cost_date':
                        (row['cost_date'] ?? '').toString().trim().isEmpty
                            ? null
                            : row['cost_date'],
                    'cost_type':
                        (row['cost_type'] ?? '').toString().trim().isEmpty
                            ? null
                            : row['cost_type'],
                    'note':
                        (row['note'] ?? '').toString().trim().isEmpty
                            ? null
                            : row['note'],
                  },
                )
                .toList()
            : <Map<String, dynamic>>[];

    setState(() => _savingContractForm = true);
    final bool ok =
        editingId == null
            ? await widget.apiService.createContract(
              widget.token,
              title: titleCtrl.text.trim(),
              clientId: formClientId!,
              opportunityId: formOpportunityId,
              collectorUserId: collectorUserId,
              subtotalValue: subtotalValue,
              value: value,
              paymentTimes: paymentTimes,
              createAndApprove: createAndApprove,
              signedAt:
                  signedCtrl.text.trim().isEmpty
                      ? null
                      : signedCtrl.text.trim(),
              startDate:
                  startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
              endDate: endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
              notes:
                  notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
              items: payloadItems,
              pendingPaymentRequests: pendingPaymentRequests,
              pendingCostRequests: pendingCostRequests,
            )
            : await widget.apiService.updateContract(
              widget.token,
              editingId!,
              title: titleCtrl.text.trim(),
              clientId: formClientId!,
              opportunityId: formOpportunityId,
              collectorUserId: collectorUserId,
              subtotalValue: subtotalValue,
              value: value,
              paymentTimes: paymentTimes,
              signedAt:
                  signedCtrl.text.trim().isEmpty
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
      message =
          ok
              ? (editingId == null
                  ? (createAndApprove
                      ? 'Đã tạo và duyệt hợp đồng.'
                      : 'Tạo hợp đồng thành công.')
                  : 'Cập nhật hợp đồng thành công.')
              : 'Lưu hợp đồng thất bại.';
      _savingContractForm = false;
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

  Future<bool> _rejectContract(int contractId, BuildContext context) async {
    if (!widget.canApprove) {
      if (mounted) {
        setState(() => message = 'Bạn không có quyền không duyệt hợp đồng.');
      }
      return false;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext ctx) => AlertDialog(
            title: const Text('Không duyệt hợp đồng'),
            content: const Text(
              'Xác nhận không duyệt hợp đồng này? Trạng thái sẽ chuyển sang «Hủy».',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Đóng'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Không duyệt'),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return false;

    final bool ok = await widget.apiService.rejectContract(
      widget.token,
      contractId,
    );
    if (!mounted) return false;
    setState(() {
      message =
          ok ? 'Đã không duyệt hợp đồng.' : 'Không duyệt hợp đồng thất bại.';
    });
    if (ok) {
      await _fetch();
    }
    return ok;
  }

  Future<void> _loadLinkableOpportunitiesForForm() async {
    final int? cid = formClientId;
    if (cid == null || cid <= 0) {
      if (!mounted) return;
      setState(() => linkableOpportunities = <Map<String, dynamic>>[]);
      return;
    }
    final Map<String, dynamic> payload = await widget.apiService
        .getOpportunities(
          widget.token,
          perPage: 80,
          page: 1,
          clientId: cid,
          linkableForContract: true,
          excludeContractId: editingId,
        );
    final List<dynamic> rows =
        (payload['data'] ?? <dynamic>[]) as List<dynamic>;
    if (!mounted) return;
    setState(() {
      linkableOpportunities =
          rows.map((e) => e as Map<String, dynamic>).toList();
    });
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
        final Map<String, dynamic> fetched = await widget.apiService
            .getContractDetail(widget.token, id);
        if (fetched.isNotEmpty) {
          detail = fetched;
        }
      }
    }
    if (!mounted) return;

    setState(() {
      message = '';
      _savingContractForm = false;
      if (detail == null) {
        editingCanManage = true;
        _resetForm();
      } else {
        editingCanManage = _canManageContract(detail);
        editingId = _readInt(detail['id']) ?? 0;
        titleCtrl.text = (detail['title'] ?? '').toString();
        valueCtrl.text = _formatMoneyInput(
          detail['subtotal_value'] ?? detail['value'],
        );
        paymentTimesCtrl.text = (detail['payment_times'] ?? 1).toString();
        signedCtrl.text = _safeDate(detail['signed_at']);
        startCtrl.text = _safeDate(detail['start_date']);
        endCtrl.text = _safeDate(detail['end_date']);
        notesCtrl.text = (detail['notes'] ?? '').toString();
        status = (detail['status'] ?? 'draft').toString();
        formClientId = _readInt(detail['client_id']);
        formOpportunityId = _readInt(detail['opportunity_id']);
        collectorUserId = _readInt(detail['collector_user_id']);
        careStaffIds = _normalizeCareStaffIds(detail['care_staff_users']);
        items =
            ((detail['items'] ?? <dynamic>[]) as List<dynamic>).map((
              dynamic e,
            ) {
              final Map<String, dynamic> item = e as Map<String, dynamic>;
              return <String, dynamic>{
                if (item['id'] != null) 'id': item['id'],
                'product_id': item['product_id'],
                'product_name': item['product_name'] ?? '',
                'unit': item['unit'] ?? '',
                'unit_price': _formatMoneyInput(item['unit_price']),
                'quantity': item['quantity'] ?? 1,
                'note': item['note'] ?? '',
              };
            }).toList();
        _syncValueController(items.isEmpty ? null : items);
        payments = _normalizePaymentDisplayRows(
          detail['payments_display'] ?? detail['payments'],
        );
        costs = _normalizeCostDisplayRows(
          detail['costs_display'] ?? detail['costs'],
        );
      }
    });

    if (formClientId != null && formClientId! > 0) {
      await _loadLinkableOpportunitiesForForm();
    }
    if (!mounted) return;

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
                children: [
                  StitchFormSheetTitleBar(
                    title: editingId == null ? 'Tạo hợp đồng' : 'Sửa hợp đồng',
                    subtitle:
                        'Mã hợp đồng sẽ tự sinh khi lưu. Trạng thái duyệt, thu tiền và hiệu lực được hệ thống tự tính theo nghiệp vụ web.',
                    icon:
                        editingId == null
                            ? Icons.note_add_rounded
                            : Icons.edit_document,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: StitchTheme.primarySoft,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: StitchTheme.primaryStrong.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    editingId == null
                                        ? Icons.note_add_rounded
                                        : Icons.edit_document,
                                    color: StitchTheme.primaryStrong,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        editingId == null
                                            ? 'Tạo hợp đồng mới'
                                            : 'Chỉnh sửa hợp đồng hiện có',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: StitchTheme.textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Mã hợp đồng sẽ tự sinh khi lưu. Trạng thái hợp đồng được hệ thống tự cập nhật theo duyệt, thu tiền và ngày kết thúc.',
                                        style: TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 12.5,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          StitchFilterCard(
                            title: 'Thông tin chung',
                            subtitle:
                                'Nhập tiêu đề, khách hàng và người phụ trách thu cho hợp đồng.',
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                StitchFilterField(
                                  label: 'Tiêu đề hợp đồng',
                                  child: TextField(
                                    controller: titleCtrl,
                                    decoration: stitchSheetInputDecoration(
                                      context,
                                      label: 'Tiêu đề hợp đồng *',
                                      hint:
                                          'Ví dụ: Hợp đồng backlink thương hiệu',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                StitchFilterField(
                                  label: 'Khách hàng',
                                  child: DropdownButtonFormField<int?>(
                                    value: formClientId,
                                    items: <DropdownMenuItem<int?>>[
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Chọn khách hàng *'),
                                      ),
                                      ...formClients.map(
                                        (Map<String, dynamic> c) =>
                                            DropdownMenuItem<int?>(
                                              value: c['id'] as int?,
                                              child: Text(
                                                (c['name'] ?? 'Khách hàng')
                                                    .toString(),
                                              ),
                                            ),
                                      ),
                                    ],
                                    onChanged: (int? value) async {
                                      setState(() {
                                        formClientId = value;
                                        formOpportunityId = null;
                                      });
                                      await _loadLinkableOpportunitiesForForm();
                                      setSheetState(() {});
                                    },
                                    decoration: stitchSheetInputDecoration(
                                      context,
                                      label: 'Khách hàng',
                                      hint:
                                          'Chọn khách hàng đang đứng tên hợp đồng',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                StitchFilterField(
                                  label: 'Cơ hội liên kết (tuỳ chọn)',
                                  child: DropdownButtonFormField<int?>(
                                    value: formOpportunityId,
                                    items: <DropdownMenuItem<int?>>[
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Không chọn cơ hội'),
                                      ),
                                      ...linkableOpportunities.map(
                                        (Map<String, dynamic> o) =>
                                            DropdownMenuItem<int?>(
                                              value: o['id'] as int?,
                                              child: Text(
                                                (o['title'] ?? 'Cơ hội')
                                                    .toString(),
                                              ),
                                            ),
                                      ),
                                    ],
                                    onChanged:
                                        formClientId == null
                                            ? null
                                            : (int? value) {
                                              setState(
                                                () => formOpportunityId = value,
                                              );
                                              setSheetState(() {});
                                            },
                                    decoration: stitchSheetInputDecoration(
                                      context,
                                      label: 'Cơ hội',
                                      hint:
                                          'Chỉ hiển thị cơ hội chưa gắn hợp đồng khác',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.surfaceAlt,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: StitchTheme.border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.account_circle_outlined,
                                              size: 18,
                                              color: StitchTheme.primaryStrong,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'Nhân viên thu theo hợp đồng',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _isEmployee
                                            ? 'Bạn tạo hợp đồng nào thì hợp đồng đó tự đứng tên bạn và không đổi sang người khác.'
                                            : widget.currentUserRole ==
                                                'quan_ly'
                                            ? 'Trưởng phòng có thể giữ chính mình hoặc chọn nhân sự trong phòng để đứng tên thu hợp đồng.'
                                            : widget.canApprove
                                            ? 'Admin/Kế toán có thể chọn mọi nhân viên và có thêm nút tạo và duyệt.'
                                            : widget.canEditContractFinanceLines
                                            ? 'Admin/Kế toán có thể chỉnh sửa cả dòng thu chi đã ghi nhận.'
                                            : 'Chọn nhân sự phụ trách thu hợp đồng.',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 12.5,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<int?>(
                                        value: collectorUserId,
                                        items: <DropdownMenuItem<int?>>[
                                          const DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text('Chọn nhân viên thu'),
                                          ),
                                          if (widget.currentUserId != null &&
                                              widget.currentUserId! > 0 &&
                                              !collectors.any(
                                                (Map<String, dynamic> u) =>
                                                    _readInt(u['id']) ==
                                                    widget.currentUserId,
                                              ))
                                            DropdownMenuItem<int?>(
                                              value: widget.currentUserId,
                                              child: Text(
                                                'Nhân sự #${widget.currentUserId}',
                                              ),
                                            ),
                                          ...collectors.map(
                                            (Map<String, dynamic> user) =>
                                                DropdownMenuItem<int?>(
                                                  value: _readInt(user['id']),
                                                  child: Text(
                                                    (user['name'] ?? 'Nhân sự')
                                                        .toString(),
                                                  ),
                                                ),
                                          ),
                                        ],
                                        onChanged:
                                            _canChooseCollector
                                                ? (int? value) {
                                                  setSheetState(
                                                    () =>
                                                        collectorUserId = value,
                                                  );
                                                }
                                                : null,
                                        decoration: stitchSheetInputDecoration(
                                          context,
                                          label: 'Nhân viên thu',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          StitchFilterCard(
                            title: 'Sản phẩm trong hợp đồng',
                            subtitle:
                                'Mỗi sản phẩm sẽ tự cộng vào tổng giá trị hợp đồng.',
                            trailing: TextButton.icon(
                              onPressed: () => _addItem(setSheetState),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Thêm'),
                            ),
                            padding: const EdgeInsets.all(16),
                            child:
                                items.isEmpty
                                    ? Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: StitchTheme.surfaceAlt,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: StitchTheme.border,
                                        ),
                                      ),
                                      child: const Text(
                                        'Chưa có sản phẩm. Thêm dòng sản phẩm để hệ thống tự tính giá trị hợp đồng.',
                                        style: TextStyle(
                                          color: StitchTheme.textMuted,
                                          height: 1.45,
                                        ),
                                      ),
                                    )
                                    : Column(
                                      children:
                                          items.asMap().entries.map((entry) {
                                            final int index = entry.key;
                                            final Map<String, dynamic> item =
                                                entry.value;
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: StitchTheme.border,
                                                ),
                                                boxShadow: const <BoxShadow>[
                                                  BoxShadow(
                                                    color: Color(0x120F172A),
                                                    blurRadius: 18,
                                                    offset: Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                children: <Widget>[
                                                  Row(
                                                    children: <Widget>[
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              StitchTheme
                                                                  .primarySoft,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'Sản phẩm ${index + 1}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 12,
                                                            color:
                                                                StitchTheme
                                                                    .primaryStrong,
                                                          ),
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      TextButton.icon(
                                                        onPressed:
                                                            () => _removeItem(
                                                              index,
                                                              setSheetState,
                                                            ),
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 18,
                                                        ),
                                                        label: const Text(
                                                          'Xóa',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  DropdownButtonFormField<int?>(
                                                    value:
                                                        item['product_id']
                                                            as int?,
                                                    decoration:
                                                        stitchSheetInputDecoration(
                                                          context,
                                                          label: 'Sản phẩm',
                                                        ),
                                                    items: <
                                                      DropdownMenuItem<int?>
                                                    >[
                                                      const DropdownMenuItem<
                                                        int?
                                                      >(
                                                        value: null,
                                                        child: Text(
                                                          'Chọn sản phẩm',
                                                        ),
                                                      ),
                                                      ...products.map(
                                                        (
                                                          Map<String, dynamic>
                                                          p,
                                                        ) => DropdownMenuItem<
                                                          int?
                                                        >(
                                                          value:
                                                              p['id'] as int?,
                                                          child: Text(
                                                            (p['name'] ??
                                                                    'Sản phẩm')
                                                                .toString(),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    onChanged: (int? value) {
                                                      final Map<String, dynamic>
                                                      selected = products
                                                          .firstWhere(
                                                            (
                                                              Map<
                                                                String,
                                                                dynamic
                                                              >
                                                              p,
                                                            ) =>
                                                                p['id'] ==
                                                                value,
                                                            orElse:
                                                                () =>
                                                                    <
                                                                      String,
                                                                      dynamic
                                                                    >{},
                                                          );
                                                      _updateItem(index, <
                                                        String,
                                                        dynamic
                                                      >{
                                                        'product_id': value,
                                                        'product_name':
                                                            selected['name'] ??
                                                            '',
                                                        'unit':
                                                            selected['unit'] ??
                                                            '',
                                                        'unit_price':
                                                            _formatMoneyInput(
                                                              selected['unit_price'],
                                                            ),
                                                      }, setSheetState);
                                                    },
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: <Widget>[
                                                      Expanded(
                                                        child: TextFormField(
                                                          initialValue:
                                                              (item['unit'] ??
                                                                      '')
                                                                  .toString(),
                                                          decoration:
                                                              stitchSheetInputDecoration(
                                                                context,
                                                                label: 'Đơn vị',
                                                              ),
                                                          onChanged:
                                                              (
                                                                value,
                                                              ) => _updateItem(
                                                                index,
                                                                <
                                                                  String,
                                                                  dynamic
                                                                >{
                                                                  'unit': value,
                                                                },
                                                                setSheetState,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: TextFormField(
                                                          initialValue:
                                                              _formatMoneyInput(
                                                                item['unit_price'],
                                                              ),
                                                          decoration:
                                                              stitchSheetInputDecoration(
                                                                context,
                                                                label:
                                                                    'Đơn giá',
                                                              ),
                                                          keyboardType:
                                                              TextInputType
                                                                  .number,
                                                          inputFormatters: const <
                                                            TextInputFormatter
                                                          >[
                                                            _VnCurrencyInputFormatter(),
                                                          ],
                                                          onChanged:
                                                              (
                                                                value,
                                                              ) => _updateItem(
                                                                index,
                                                                <
                                                                  String,
                                                                  dynamic
                                                                >{
                                                                  'unit_price':
                                                                      _formatMoneyInput(
                                                                        value,
                                                                      ),
                                                                },
                                                                setSheetState,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: <Widget>[
                                                      Expanded(
                                                        child: TextFormField(
                                                          initialValue:
                                                              (item['quantity'] ??
                                                                      1)
                                                                  .toString(),
                                                          decoration:
                                                              stitchSheetInputDecoration(
                                                                context,
                                                                label:
                                                                    'Số lượng',
                                                              ),
                                                          keyboardType:
                                                              TextInputType
                                                                  .number,
                                                          onChanged:
                                                              (
                                                                value,
                                                              ) => _updateItem(
                                                                index,
                                                                <
                                                                  String,
                                                                  dynamic
                                                                >{
                                                                  'quantity':
                                                                      value,
                                                                },
                                                                setSheetState,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 14,
                                                                vertical: 14,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                StitchTheme
                                                                    .surfaceAlt,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  16,
                                                                ),
                                                            border: Border.all(
                                                              color:
                                                                  StitchTheme
                                                                      .border,
                                                            ),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: <Widget>[
                                                              const Text(
                                                                'Giá trị',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      StitchTheme
                                                                          .textMuted,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 6,
                                                              ),
                                                              Text(
                                                                _money(
                                                                  _itemTotal(
                                                                    item,
                                                                  ),
                                                                ),
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  fontSize: 15,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  TextFormField(
                                                    initialValue:
                                                        (item['note'] ?? '')
                                                            .toString(),
                                                    decoration:
                                                        stitchSheetInputDecoration(
                                                          context,
                                                          label: 'Ghi chú',
                                                          hint:
                                                              'Điều khoản riêng hoặc lưu ý cho dòng sản phẩm',
                                                        ),
                                                    onChanged:
                                                        (value) => _updateItem(
                                                          index,
                                                          <String, dynamic>{
                                                            'note': value,
                                                          },
                                                          setSheetState,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                    ),
                          ),

                          const SizedBox(height: 14),
                          StitchFilterCard(
                            title: 'Giá trị và hiệu lực',
                            subtitle:
                                'Theo dõi giá trị hợp đồng, số lần thanh toán và mốc thời gian hiệu lực.',
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                StitchFilterField(
                                  label: 'Giá trị hợp đồng',
                                  hint:
                                      'Tự động tính theo tổng giá trị các dòng sản phẩm/dịch vụ.',
                                  child: TextField(
                                    controller: valueCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: const <TextInputFormatter>[
                                      _VnCurrencyInputFormatter(),
                                    ],
                                    readOnly: true,
                                    decoration: stitchSheetInputDecoration(
                                      context,
                                      label: 'Giá trị (tự tính)',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                StitchFilterField(
                                  label: 'Số lần thanh toán',
                                  child: TextField(
                                    controller: paymentTimesCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: stitchSheetInputDecoration(
                                      context,
                                      label: 'Số lần thanh toán',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                StitchFilterField(
                                  label: 'Trạng thái hợp đồng',
                                  hint:
                                      'Hệ thống tự cập nhật theo duyệt, thu tiền, công nợ và ngày kết thúc.',
                                  child: _buildContractStatusBadge(status),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: signedCtrl,
                                        readOnly: true,
                                        onTap: () => _pickDate(signedCtrl),
                                        decoration: stitchSheetInputDecoration(
                                          context,
                                          label: 'Ngày ký',
                                        ).copyWith(
                                          suffixIcon: const Icon(Icons.event),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: startCtrl,
                                        readOnly: true,
                                        onTap: () => _pickDate(startCtrl),
                                        decoration: stitchSheetInputDecoration(
                                          context,
                                          label: 'Bắt đầu hiệu lực',
                                        ).copyWith(
                                          suffixIcon: const Icon(Icons.event),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                StitchFilterField(
                                  label: 'Ngày hết hiệu lực',
                                  child: TextField(
                                    controller: endCtrl,
                                    readOnly: true,
                                    onTap: () => _pickDate(endCtrl),
                                    decoration: stitchSheetInputDecoration(
                                      context,
                                      label: 'Hết hiệu lực',
                                    ).copyWith(
                                      suffixIcon: const Icon(Icons.event),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                StitchFilterField(
                                  label: 'Ghi chú nội bộ',
                                  child: TextField(
                                    controller: notesCtrl,
                                    maxLines: 3,
                                    decoration: stitchSheetInputDecoration(
                                      context,
                                      label: 'Ghi chú',
                                      hint:
                                          'Điều khoản, phạm vi hoặc lưu ý nội bộ cho hợp đồng',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          StitchFilterCard(
                            title: 'Thanh toán hợp đồng',
                            subtitle:
                                'Theo dõi các khoản thu đã ghi nhận và khoản đang chờ duyệt.',
                            trailing:
                                widget.canCreateContractFinanceLines
                                    ? TextButton.icon(
                                      onPressed: () => _openPaymentSheet(),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Thêm'),
                                    )
                                    : null,
                            padding: const EdgeInsets.all(16),
                            child:
                                payments.isEmpty
                                    ? const Text(
                                      'Chưa có thanh toán.',
                                      style: TextStyle(
                                        color: StitchTheme.textMuted,
                                      ),
                                    )
                                    : Column(
                                      children:
                                          payments.map((
                                            Map<String, dynamic> p,
                                          ) {
                                            final bool isPending =
                                                (p['row_type']?.toString() ??
                                                    '') ==
                                                'pending_request';
                                            final bool isDraft =
                                                (p['row_type']?.toString() ??
                                                    '') ==
                                                'create_draft';
                                            return Card(
                                              margin: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: ListTile(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                title: Row(
                                                  children: <Widget>[
                                                    Expanded(
                                                      child: Text(
                                                        _money(p['amount']),
                                                      ),
                                                    ),
                                                    if (isPending || isDraft)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              isDraft
                                                                  ? StitchTheme
                                                                      .primarySoft
                                                                  : StitchTheme
                                                                      .warningSoft,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          border: Border.all(
                                                            color: (isDraft
                                                                    ? StitchTheme
                                                                        .primary
                                                                    : StitchTheme
                                                                        .warning)
                                                                .withValues(
                                                                  alpha: 0.24,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          isDraft
                                                              ? 'Gửi kèm khi tạo HĐ'
                                                              : 'Chờ duyệt',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                isDraft
                                                                    ? StitchTheme
                                                                        .primaryStrong
                                                                    : StitchTheme
                                                                        .warningStrong,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                subtitle: Text(
                                                  'Ngày thu: ${_safeDate(p['paid_at'])} • ${p['method'] ?? '—'}${isDraft ? ' • Sẽ gửi duyệt khi tạo hợp đồng' : (isPending ? ' • Phiếu chờ kế toán duyệt' : '')}',
                                                ),
                                                trailing:
                                                    (isPending ||
                                                            (!isDraft &&
                                                                !widget
                                                                    .canEditContractFinanceLines))
                                                        ? null
                                                        : Wrap(
                                                          spacing: 6,
                                                          children: <Widget>[
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.edit,
                                                                size: 18,
                                                              ),
                                                              onPressed:
                                                                  () =>
                                                                      _openPaymentSheet(
                                                                        payment:
                                                                            p,
                                                                      ),
                                                            ),
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                size: 18,
                                                                color:
                                                                    StitchTheme
                                                                        .danger,
                                                              ),
                                                              onPressed:
                                                                  () =>
                                                                      _deletePayment(
                                                                        p['id'],
                                                                      ),
                                                            ),
                                                          ],
                                                        ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                          ),
                          const SizedBox(height: 14),
                          StitchFilterCard(
                            title: 'Chi phí hợp đồng',
                            subtitle:
                                'Quản lý các khoản chi đi kèm hợp đồng và các phiếu đang chờ duyệt.',
                            trailing:
                                widget.canCreateContractFinanceLines
                                    ? TextButton.icon(
                                      onPressed: () => _openCostSheet(),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Thêm'),
                                    )
                                    : null,
                            padding: const EdgeInsets.all(16),
                            child:
                                costs.isEmpty
                                    ? const Text(
                                      'Chưa có chi phí.',
                                      style: TextStyle(
                                        color: StitchTheme.textMuted,
                                      ),
                                    )
                                    : Column(
                                      children:
                                          costs.map((Map<String, dynamic> c) {
                                            final bool isPending =
                                                (c['row_type']?.toString() ??
                                                    '') ==
                                                'pending_request';
                                            final bool isDraft =
                                                (c['row_type']?.toString() ??
                                                    '') ==
                                                'create_draft';
                                            return Card(
                                              margin: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: ListTile(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                title: Row(
                                                  children: <Widget>[
                                                    Expanded(
                                                      child: Text(
                                                        _money(c['amount']),
                                                      ),
                                                    ),
                                                    if (isPending || isDraft)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              isDraft
                                                                  ? StitchTheme
                                                                      .primarySoft
                                                                  : StitchTheme
                                                                      .warningSoft,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          border: Border.all(
                                                            color: (isDraft
                                                                    ? StitchTheme
                                                                        .primary
                                                                    : StitchTheme
                                                                        .warning)
                                                                .withValues(
                                                                  alpha: 0.24,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          isDraft
                                                              ? 'Gửi kèm khi tạo HĐ'
                                                              : 'Chờ duyệt',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                isDraft
                                                                    ? StitchTheme
                                                                        .primaryStrong
                                                                    : StitchTheme
                                                                        .warningStrong,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                subtitle: Text(
                                                  '${c['cost_type'] ?? 'Chi phí'} • ${_safeDate(c['cost_date'])}${isDraft ? ' • Sẽ gửi duyệt khi tạo hợp đồng' : (isPending ? ' • Phiếu chờ kế toán duyệt' : '')}',
                                                ),
                                                trailing:
                                                    (isPending ||
                                                            (!isDraft &&
                                                                !widget
                                                                    .canEditContractFinanceLines))
                                                        ? null
                                                        : Wrap(
                                                          spacing: 6,
                                                          children: <Widget>[
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.edit,
                                                                size: 18,
                                                              ),
                                                              onPressed:
                                                                  () =>
                                                                      _openCostSheet(
                                                                        cost: c,
                                                                      ),
                                                            ),
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                size: 18,
                                                                color:
                                                                    StitchTheme
                                                                        .danger,
                                                              ),
                                                              onPressed:
                                                                  () =>
                                                                      _deleteCost(
                                                                        c['id'],
                                                                      ),
                                                            ),
                                                          ],
                                                        ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                          ),
                          if (message.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 14),
                            StitchFeedbackBanner(
                              message: message,
                              isError: !message.contains('thành công'),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    children: <Widget>[
                      StitchFormSheetActions(
                        primaryLoading: _savingContractForm,
                        primaryLabel:
                            _savingContractForm
                                ? (editingId == null
                                    ? 'Đang tạo...'
                                    : 'Đang cập nhật...')
                                : (editingId == null
                                    ? 'Lưu hợp đồng'
                                    : 'Cập nhật'),
                        onPrimary:
                            _savingContractForm
                                ? null
                                : () async {
                                  final NavigatorState navigator = Navigator.of(
                                    context,
                                  );
                                  final bool ok = await _save();
                                  if (!mounted) return;
                                  if (ok) {
                                    navigator.pop();
                                  } else {
                                    setSheetState(() {});
                                  }
                                },
                        onCancel:
                            _savingContractForm
                                ? null
                                : () => Navigator.of(context).pop(),
                        secondaryLabel: 'Hủy',
                      ),
                      if (editingId == null &&
                          widget.canCreate &&
                          widget.canApprove)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed:
                                  _savingContractForm
                                      ? null
                                      : () async {
                                        final NavigatorState navigator =
                                            Navigator.of(context);
                                        final bool ok = await _save(
                                          createAndApprove: true,
                                        );
                                        if (!mounted) return;
                                        if (ok) {
                                          navigator.pop();
                                        } else {
                                          setSheetState(() {});
                                        }
                                      },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _savingContractForm
                                    ? 'Đang tạo...'
                                    : 'Tạo và duyệt',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
      _savingContractForm = false;
      _resetForm();
    });
  }

  Future<void> _openPaymentSheet({Map<String, dynamic>? payment}) async {
    if (payment != null &&
        (payment['row_type']?.toString() ?? '') == 'pending_request') {
      setState(
        () =>
            message =
                'Dòng đang chờ duyệt — duyệt qua mục phiếu tài chính trong chi tiết hợp đồng.',
      );
      return;
    }
    final bool isDraftRow =
        payment != null &&
        (payment['row_type']?.toString() ?? '') == 'create_draft';
    final bool allowed =
        payment == null || isDraftRow
            ? widget.canCreateContractFinanceLines
            : widget.canEditContractFinanceLines;
    if (!allowed) {
      setState(
        () =>
            message =
                payment == null
                    ? 'Bạn không có quyền thêm dòng thu (theo API).'
                    : 'Chỉ Admin/Kế toán được sửa/xóa dòng thu đã ghi nhận.',
      );
      return;
    }
    final TextEditingController amountCtrl = TextEditingController(
      text: payment != null ? _formatMoneyInput(payment['amount']) : '',
    );
    final TextEditingController dateCtrl = TextEditingController(
      text: payment != null ? _safeDate(payment['paid_at']) : _todayInputDate(),
    );
    final TextEditingController methodCtrl = TextEditingController(
      text: payment != null ? (payment['method'] ?? '').toString() : '',
    );
    final TextEditingController noteCtrl = TextEditingController(
      text: payment != null ? (payment['note'] ?? '').toString() : '',
    );
    String localMessage = '';
    bool submitting = false;

    double contractTotal() {
      return _currentContractTotal();
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
            final double currentAmount = _parseNumberInput(
              amountCtrl.text.trim(),
            );
            final double remaining = math.max(0, total - basePaid);
            final double projected = basePaid + currentAmount;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: stitchFormSheetSurfaceDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    StitchFormSheetTitleBar(
                      title:
                          payment == null
                              ? 'Thêm thanh toán'
                              : 'Sửa thanh toán',
                      subtitle:
                          'Theo đúng nghiệp vụ web: số thu không được vượt giá trị hợp đồng còn lại.',
                      icon: Icons.payments_rounded,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: StitchTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: StitchTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Giá trị hợp đồng: ${_money(total)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Số tiền còn cần thu: ${_money(remaining)}',
                                    style: TextStyle(
                                      color:
                                          remaining > 0
                                              ? StitchTheme.successStrong
                                              : StitchTheme.dangerStrong,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (projected > total + 0.0001)
                                    Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Số tiền đang nhập vượt tổng giá trị hợp đồng.',
                                        style: TextStyle(
                                          color: StitchTheme.dangerStrong,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (localMessage.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              StitchFeedbackBanner(
                                message: localMessage,
                                isError: true,
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: amountCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: const <TextInputFormatter>[
                                _VnCurrencyInputFormatter(),
                              ],
                              onChanged: (_) => setModalState(() {}),
                              decoration: stitchSheetInputDecoration(
                                context,
                                label: 'Số tiền (VNĐ)',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: dateCtrl,
                              readOnly: true,
                              onTap: () => _pickDate(dateCtrl),
                              decoration: stitchSheetInputDecoration(
                                context,
                                label: 'Ngày thu',
                              ).copyWith(suffixIcon: const Icon(Icons.event)),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: methodCtrl,
                              decoration: stitchSheetInputDecoration(
                                context,
                                label: 'Phương thức',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: noteCtrl,
                              maxLines: 2,
                              decoration: stitchSheetInputDecoration(
                                context,
                                label: 'Ghi chú',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    StitchFormSheetActions(
                      primaryLoading: submitting,
                      primaryLabel:
                          submitting
                              ? (payment == null
                                  ? 'Đang tạo...'
                                  : 'Đang cập nhật...')
                              : (payment == null
                                  ? 'Tạo phiếu thu'
                                  : 'Cập nhật phiếu thu'),
                      onPrimary:
                          submitting
                              ? null
                              : () async {
                                final NavigatorState navigator = Navigator.of(
                                  context,
                                );
                                final double amount = _parseNumberInput(
                                  amountCtrl.text.trim(),
                                );
                                if (amount <= 0) {
                                  setModalState(
                                    () =>
                                        localMessage = 'Số tiền không hợp lệ.',
                                  );
                                  return;
                                }
                                if (amount > remaining + 0.0001) {
                                  setModalState(
                                    () =>
                                        localMessage =
                                            'Số tiền thanh toán vượt giá trị hợp đồng.',
                                  );
                                  return;
                                }
                                setModalState(() => submitting = true);
                                late final Map<String, dynamic> result;
                                if (editingId == null) {
                                  final String localId =
                                      isDraftRow
                                          ? (payment['id'] ?? '').toString()
                                          : 'local-pay-${DateTime.now().microsecondsSinceEpoch}';
                                  setState(() {
                                    final Map<String, dynamic> nextRow =
                                        <String, dynamic>{
                                          'id': localId,
                                          'row_type': 'create_draft',
                                          'amount': amountCtrl.text.trim(),
                                          'paid_at':
                                              dateCtrl.text.trim().isEmpty
                                                  ? null
                                                  : dateCtrl.text.trim(),
                                          'method':
                                              methodCtrl.text.trim().isEmpty
                                                  ? null
                                                  : methodCtrl.text.trim(),
                                          'note':
                                              noteCtrl.text.trim().isEmpty
                                                  ? null
                                                  : noteCtrl.text.trim(),
                                        };
                                    if (isDraftRow) {
                                      payments =
                                          payments.map((
                                            Map<String, dynamic> row,
                                          ) {
                                            return row['id'] == localId
                                                ? nextRow
                                                : row;
                                          }).toList();
                                    } else {
                                      payments = <Map<String, dynamic>>[
                                        ...payments,
                                        nextRow,
                                      ];
                                    }
                                    message =
                                        isDraftRow
                                            ? 'Đã cập nhật phiếu thu nháp.'
                                            : 'Đã thêm phiếu thu nháp.';
                                  });
                                  if (!mounted) return;
                                  navigator.pop();
                                  return;
                                } else if (payment == null) {
                                  result = await widget.apiService
                                      .createContractPaymentWithMeta(
                                        widget.token,
                                        editingId!,
                                        amount: amount,
                                        paidAt:
                                            dateCtrl.text.trim().isEmpty
                                                ? null
                                                : dateCtrl.text.trim(),
                                        method:
                                            methodCtrl.text.trim().isEmpty
                                                ? null
                                                : methodCtrl.text.trim(),
                                        note:
                                            noteCtrl.text.trim().isEmpty
                                                ? null
                                                : noteCtrl.text.trim(),
                                      );
                                } else {
                                  final bool updated = await widget.apiService
                                      .updateContractPayment(
                                        widget.token,
                                        editingId!,
                                        _readInt(payment['id']) ?? 0,
                                        amount: amount,
                                        paidAt:
                                            dateCtrl.text.trim().isEmpty
                                                ? null
                                                : dateCtrl.text.trim(),
                                        method:
                                            methodCtrl.text.trim().isEmpty
                                                ? null
                                                : methodCtrl.text.trim(),
                                        note:
                                            noteCtrl.text.trim().isEmpty
                                                ? null
                                                : noteCtrl.text.trim(),
                                      );
                                  result = <String, dynamic>{
                                    'ok': updated,
                                    'message':
                                        updated
                                            ? 'Đã cập nhật thanh toán.'
                                            : 'Cập nhật thanh toán thất bại.',
                                  };
                                }
                                if (!mounted) return;
                                final bool ok = result['ok'] == true;
                                final String apiMessage =
                                    (result['message'] ?? '').toString();
                                setState(() {
                                  message =
                                      ok
                                          ? (apiMessage.isNotEmpty
                                              ? apiMessage
                                              : 'Đã lưu thanh toán.')
                                          : (apiMessage.isNotEmpty
                                              ? apiMessage
                                              : 'Lưu thanh toán thất bại.');
                                });
                                if (ok) {
                                  await _reloadContractFinanceFromServer();
                                  if (!mounted) return;
                                  navigator.pop();
                                }
                                if (mounted) {
                                  setModalState(() => submitting = false);
                                }
                              },
                      onCancel:
                          submitting ? null : () => Navigator.of(context).pop(),
                      secondaryLabel: 'Hủy',
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
    await _fetch();
  }

  Future<void> _deletePayment(dynamic paymentId) async {
    if (editingId == null) {
      final String localId = paymentId?.toString() ?? '';
      if (localId.isEmpty) return;
      setState(() {
        payments =
            payments.where((Map<String, dynamic> row) {
              return row['id']?.toString() != localId;
            }).toList();
        message = 'Đã xóa phiếu thu nháp.';
      });
      return;
    }
    if (!widget.canEditContractFinanceLines) return;
    final int id =
        paymentId is int
            ? paymentId
            : int.tryParse(paymentId?.toString() ?? '') ?? 0;
    if (id <= 0) {
      setState(
        () =>
            message =
                'Không xóa được phiếu chờ duyệt — hãy duyệt/từ chối phiếu.',
      );
      return;
    }
    final bool ok = await widget.apiService.deleteContractPayment(
      widget.token,
      editingId!,
      id,
    );
    if (!mounted) return;
    setState(() {
      message = ok ? 'Đã xóa thanh toán.' : 'Xóa thanh toán thất bại.';
    });
    if (ok) await _reloadContractFinanceFromServer();
  }

  Future<void> _openCostSheet({Map<String, dynamic>? cost}) async {
    if (cost != null &&
        (cost['row_type']?.toString() ?? '') == 'pending_request') {
      setState(
        () =>
            message =
                'Dòng đang chờ duyệt — duyệt qua mục phiếu tài chính trong chi tiết hợp đồng.',
      );
      return;
    }
    final bool isDraftRow =
        cost != null && (cost['row_type']?.toString() ?? '') == 'create_draft';
    final bool allowed =
        cost == null || isDraftRow
            ? widget.canCreateContractFinanceLines
            : widget.canEditContractFinanceLines;
    if (!allowed) {
      setState(
        () =>
            message =
                cost == null
                    ? 'Bạn không có quyền thêm dòng chi (theo API).'
                    : 'Chỉ Admin/Kế toán được sửa/xóa dòng chi đã ghi nhận.',
      );
      return;
    }
    final TextEditingController amountCtrl = TextEditingController(
      text: cost != null ? _formatMoneyInput(cost['amount']) : '',
    );
    final TextEditingController dateCtrl = TextEditingController(
      text: cost != null ? _safeDate(cost['cost_date']) : _todayInputDate(),
    );
    final TextEditingController typeCtrl = TextEditingController(
      text: cost != null ? (cost['cost_type'] ?? '').toString() : '',
    );
    final TextEditingController noteCtrl = TextEditingController(
      text: cost != null ? (cost['note'] ?? '').toString() : '',
    );
    String localMessage = '';
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: stitchFormSheetSurfaceDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    StitchFormSheetTitleBar(
                      title: cost == null ? 'Thêm chi phí' : 'Sửa chi phí',
                      subtitle:
                          'Phiếu chi tuân theo cùng quy tắc duyệt và lưu vết như trên web.',
                      icon: Icons.payments_outlined,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (localMessage.isNotEmpty) ...<Widget>[
                              StitchFeedbackBanner(
                                message: localMessage,
                                isError: true,
                              ),
                              const SizedBox(height: 10),
                            ],
                            TextField(
                              controller: amountCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: const <TextInputFormatter>[
                                _VnCurrencyInputFormatter(),
                              ],
                              decoration: stitchSheetInputDecoration(
                                context,
                                label: 'Số tiền (VNĐ)',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: dateCtrl,
                              readOnly: true,
                              onTap: () => _pickDate(dateCtrl),
                              decoration: stitchSheetInputDecoration(
                                context,
                                label: 'Ngày chi',
                              ).copyWith(suffixIcon: const Icon(Icons.event)),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: typeCtrl,
                              decoration: stitchSheetInputDecoration(
                                context,
                                label: 'Loại chi phí',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: noteCtrl,
                              maxLines: 2,
                              decoration: stitchSheetInputDecoration(
                                context,
                                label: 'Ghi chú',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    StitchFormSheetActions(
                      primaryLoading: submitting,
                      primaryLabel:
                          submitting
                              ? (cost == null
                                  ? 'Đang tạo...'
                                  : 'Đang cập nhật...')
                              : (cost == null
                                  ? 'Tạo phiếu chi'
                                  : 'Cập nhật phiếu chi'),
                      onPrimary:
                          submitting
                              ? null
                              : () async {
                                final NavigatorState navigator = Navigator.of(
                                  context,
                                );
                                final double amount = _parseNumberInput(
                                  amountCtrl.text.trim(),
                                );
                                if (amount <= 0) {
                                  setModalState(
                                    () =>
                                        localMessage = 'Số tiền không hợp lệ.',
                                  );
                                  return;
                                }
                                setModalState(() => submitting = true);
                                late final Map<String, dynamic> result;
                                if (editingId == null) {
                                  final String localId =
                                      isDraftRow
                                          ? (cost['id'] ?? '').toString()
                                          : 'local-cost-${DateTime.now().microsecondsSinceEpoch}';
                                  setState(() {
                                    final Map<String, dynamic> nextRow =
                                        <String, dynamic>{
                                          'id': localId,
                                          'row_type': 'create_draft',
                                          'amount': amountCtrl.text.trim(),
                                          'cost_date':
                                              dateCtrl.text.trim().isEmpty
                                                  ? null
                                                  : dateCtrl.text.trim(),
                                          'cost_type':
                                              typeCtrl.text.trim().isEmpty
                                                  ? null
                                                  : typeCtrl.text.trim(),
                                          'note':
                                              noteCtrl.text.trim().isEmpty
                                                  ? null
                                                  : noteCtrl.text.trim(),
                                        };
                                    if (isDraftRow) {
                                      costs =
                                          costs.map((Map<String, dynamic> row) {
                                            return row['id'] == localId
                                                ? nextRow
                                                : row;
                                          }).toList();
                                    } else {
                                      costs = <Map<String, dynamic>>[
                                        ...costs,
                                        nextRow,
                                      ];
                                    }
                                    message =
                                        isDraftRow
                                            ? 'Đã cập nhật phiếu chi nháp.'
                                            : 'Đã thêm phiếu chi nháp.';
                                  });
                                  if (!mounted) return;
                                  navigator.pop();
                                  return;
                                } else if (cost == null) {
                                  result = await widget.apiService
                                      .createContractCostWithMeta(
                                        widget.token,
                                        editingId!,
                                        amount: amount,
                                        costDate:
                                            dateCtrl.text.trim().isEmpty
                                                ? null
                                                : dateCtrl.text.trim(),
                                        costType:
                                            typeCtrl.text.trim().isEmpty
                                                ? null
                                                : typeCtrl.text.trim(),
                                        note:
                                            noteCtrl.text.trim().isEmpty
                                                ? null
                                                : noteCtrl.text.trim(),
                                      );
                                } else {
                                  final bool updated = await widget.apiService
                                      .updateContractCost(
                                        widget.token,
                                        editingId!,
                                        _readInt(cost['id']) ?? 0,
                                        amount: amount,
                                        costDate:
                                            dateCtrl.text.trim().isEmpty
                                                ? null
                                                : dateCtrl.text.trim(),
                                        costType:
                                            typeCtrl.text.trim().isEmpty
                                                ? null
                                                : typeCtrl.text.trim(),
                                        note:
                                            noteCtrl.text.trim().isEmpty
                                                ? null
                                                : noteCtrl.text.trim(),
                                      );
                                  result = <String, dynamic>{
                                    'ok': updated,
                                    'message':
                                        updated
                                            ? 'Đã cập nhật chi phí.'
                                            : 'Cập nhật chi phí thất bại.',
                                  };
                                }
                                if (!mounted) return;
                                final bool ok = result['ok'] == true;
                                final String apiMessage =
                                    (result['message'] ?? '').toString();
                                setState(() {
                                  message =
                                      ok
                                          ? (apiMessage.isNotEmpty
                                              ? apiMessage
                                              : 'Đã lưu chi phí.')
                                          : (apiMessage.isNotEmpty
                                              ? apiMessage
                                              : 'Lưu chi phí thất bại.');
                                });
                                if (ok) {
                                  await _reloadContractFinanceFromServer();
                                  if (!mounted) return;
                                  navigator.pop();
                                }
                                if (mounted) {
                                  setModalState(() => submitting = false);
                                }
                              },
                      onCancel:
                          submitting ? null : () => Navigator.of(context).pop(),
                      secondaryLabel: 'Hủy',
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

  Future<void> _deleteCost(dynamic costId) async {
    if (editingId == null) {
      final String localId = costId?.toString() ?? '';
      if (localId.isEmpty) return;
      setState(() {
        costs =
            costs.where((Map<String, dynamic> row) {
              return row['id']?.toString() != localId;
            }).toList();
        message = 'Đã xóa phiếu chi nháp.';
      });
      return;
    }
    if (!widget.canEditContractFinanceLines) return;
    final int id =
        costId is int ? costId : int.tryParse(costId?.toString() ?? '') ?? 0;
    if (id <= 0) {
      setState(
        () =>
            message =
                'Không xóa được phiếu chờ duyệt — hãy duyệt/từ chối phiếu.',
      );
      return;
    }
    final bool ok = await widget.apiService.deleteContractCost(
      widget.token,
      editingId!,
      id,
    );
    if (!mounted) return;
    setState(() {
      message = ok ? 'Đã xóa chi phí.' : 'Xóa chi phí thất bại.';
    });
    if (ok) await _reloadContractFinanceFromServer();
  }

  Future<void> _reloadContractFinanceFromServer() async {
    if (editingId == null) return;
    final Map<String, dynamic> d = await widget.apiService.getContractDetail(
      widget.token,
      editingId!,
    );
    if (!mounted || d.isEmpty) return;
    setState(() {
      payments = _normalizePaymentDisplayRows(
        d['payments_display'] ?? d['payments'],
      );
      costs = _normalizeCostDisplayRows(d['costs_display'] ?? d['costs']);
    });
  }

  void _resetForm() {
    editingId = null;
    editingCanManage = true;
    formClientId = null;
    formOpportunityId = null;
    linkableOpportunities = <Map<String, dynamic>>[];
    collectorUserId = _defaultCollectorUserId;
    careStaffIds = <int>[];
    status = 'draft';
    titleCtrl.clear();
    valueCtrl.clear();
    paymentTimesCtrl.text = '1';
    final String today = _fmtDate(DateTime.now());
    signedCtrl.text = today;
    startCtrl.text = today;
    endCtrl.clear();
    notesCtrl.clear();
    items = <Map<String, dynamic>>[];
    payments = <Map<String, dynamic>>[];
    costs = <Map<String, dynamic>>[];
  }

  Future<void> _openDetail({
    required Map<String, dynamic> contract,
    int? focusFinanceRequestId,
    bool focusPendingContractApproval = false,
  }) async {
    final int id = _readInt(contract['id']) ?? 0;
    if (id <= 0) {
      setState(() => message = 'Không tải được chi tiết hợp đồng.');
      return;
    }

    final Map<String, dynamic> detail = await widget.apiService
        .getContractDetail(widget.token, id);
    if (!mounted) return;
    if (detail.isEmpty) {
      setState(() => message = 'Không tải được chi tiết hợp đồng.');
      return;
    }

    final List<Map<String, dynamic>> financeRequestRows = await widget
        .apiService
        .getContractFinanceRequests(widget.token, id);
    if (!mounted) return;
    if (financeRequestRows.isNotEmpty) {
      detail['finance_requests'] = financeRequestRows;
    }

    careNoteTitleCtrl.clear();
    careNoteDetailCtrl.clear();

    Map<String, dynamic> detailData = Map<String, dynamic>.from(detail);
    bool savingCareNote = false;

    final GlobalKey contractApprovalScrollKey = GlobalKey();
    final GlobalKey? financeScrollKey =
        (focusFinanceRequestId != null && focusFinanceRequestId > 0)
            ? GlobalKey()
            : null;
    bool scheduledDetailScroll = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            if (!scheduledDetailScroll) {
              scheduledDetailScroll = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) {
                  return;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) {
                    return;
                  }
                  final BuildContext? ac =
                      contractApprovalScrollKey.currentContext;
                  final BuildContext? fc = financeScrollKey?.currentContext;
                  if (focusPendingContractApproval && ac != null) {
                    Scrollable.ensureVisible(
                      ac,
                      alignment: 0.12,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                    );
                  } else if (fc != null) {
                    Scrollable.ensureVisible(
                      fc,
                      alignment: 0.12,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                    );
                  }
                });
              });
            }
            final List<Map<String, dynamic>> careNotes =
                ((detailData['care_notes'] ?? <dynamic>[]) as List<dynamic>)
                    .map(
                      (dynamic row) => Map<String, dynamic>.from(
                        row as Map<String, dynamic>,
                      ),
                    )
                    .toList();
            final List<Map<String, dynamic>> financeRequests =
                (((detailData['finance_requests'] ??
                                detailData['financeRequests']) ??
                            <dynamic>[])
                        as List<dynamic>)
                    .map(
                      (dynamic row) => Map<String, dynamic>.from(
                        row as Map<String, dynamic>,
                      ),
                    )
                    .toList();
            final bool canAddCareNote =
                _readBool(detailData['can_add_care_note']) ?? false;
            final bool canReviewFinanceRequest =
                _readBool(detailData['can_review_finance_request']) ??
                widget.canApprove;

            final bool canCreateProject =
                _readBool(detailData['can_create_project']) ?? false;
            final bool showCreateProjectBtn =
                canCreateProject &&
                detailData['approval_status'] == 'approved' &&
                (detailData['project_id'] == null ||
                    detailData['project_id'].toString().isEmpty ||
                    detailData['project_id'].toString() == 'null');

            Future<void> reviewFinanceRequest(
              Map<String, dynamic> requestRow,
              bool approve,
            ) async {
              final int requestId = _readInt(requestRow['id']) ?? 0;
              if (requestId <= 0) {
                return;
              }

              final TextEditingController noteCtrl = TextEditingController();
              bool confirmed = false;
              if (approve) {
                confirmed =
                    await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('Duyệt phiếu tài chính'),
                          content: Text(
                            'Xác nhận duyệt ${_financeTypeLabel((requestRow['request_type'] ?? '').toString()).toLowerCase()} này?',
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(false),
                              child: const Text('Hủy'),
                            ),
                            FilledButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(true),
                              child: const Text('Duyệt'),
                            ),
                          ],
                        );
                      },
                    ) ??
                    false;
              } else {
                confirmed =
                    await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('Từ chối phiếu tài chính'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Nhập lý do từ chối (bắt buộc):',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: noteCtrl,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Ví dụ: thiếu chứng từ, sai số tiền...',
                                ),
                              ),
                            ],
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(false),
                              child: const Text('Hủy'),
                            ),
                            FilledButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(true),
                              child: const Text('Từ chối'),
                            ),
                          ],
                        );
                      },
                    ) ??
                    false;
              }

              if (!confirmed) {
                return;
              }

              final String reviewNote = noteCtrl.text.trim();
              if (!approve && reviewNote.isEmpty) {
                if (!context.mounted) return;
                AppTagMessage.show(
                  'Vui lòng nhập lý do từ chối.',
                  isError: true,
                );
                return;
              }

              final Map<String, dynamic> result =
                  approve
                      ? await widget.apiService.approveContractFinanceRequest(
                        widget.token,
                        id,
                        requestId,
                        reviewNote: reviewNote.isEmpty ? null : reviewNote,
                      )
                      : await widget.apiService.rejectContractFinanceRequest(
                        widget.token,
                        id,
                        requestId,
                        reviewNote: reviewNote,
                      );

              if (!context.mounted) return;
              final bool ok = result['ok'] == true;
              final String resultMessage = (result['message'] ?? '').toString();
              if (!ok) {
                AppTagMessage.show(
                  resultMessage.isNotEmpty
                      ? resultMessage
                      : 'Xử lý phiếu thất bại.',
                  isError: true,
                );
                return;
              }

              final Map<String, dynamic> refreshedDetail = await widget
                  .apiService
                  .getContractDetail(widget.token, id);
              final List<Map<String, dynamic>> refreshedFinanceRequests =
                  await widget.apiService.getContractFinanceRequests(
                    widget.token,
                    id,
                  );

              if (!context.mounted) return;

              setSheetState(() {
                if (refreshedDetail.isNotEmpty) {
                  detailData = Map<String, dynamic>.from(refreshedDetail);
                }
                detailData['finance_requests'] = refreshedFinanceRequests;
              });

              setState(() {
                if (refreshedDetail.isNotEmpty) {
                  payments = _normalizePaymentDisplayRows(
                    refreshedDetail['payments_display'] ??
                        refreshedDetail['payments'],
                  );
                  costs = _normalizeCostDisplayRows(
                    refreshedDetail['costs_display'] ??
                        refreshedDetail['costs'],
                  );
                }
                message =
                    resultMessage.isNotEmpty
                        ? resultMessage
                        : 'Đã cập nhật phiếu tài chính.';
              });

              AppTagMessage.show(
                resultMessage.isNotEmpty
                    ? resultMessage
                    : 'Đã cập nhật phiếu tài chính.',
              );
            }

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
                                  color: StitchTheme.textMain.withValues(
                                    alpha: 0.04,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: StitchTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (detailData['title'] ?? 'Chi tiết hợp đồng')
                                      .toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.business_center_outlined,
                                      size: 16,
                                      color: StitchTheme.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${(detailData['code'] ?? '').toString()} • ${((detailData['client'] as Map<String, dynamic>?)?['name'] ?? 'Khách hàng').toString()}',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 13,
                                        ),
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
                                      _statusLabel(
                                        (detailData['status'] ?? 'draft')
                                            .toString(),
                                      ),
                                      _statusColor(
                                        (detailData['status'] ?? 'draft')
                                            .toString(),
                                      ),
                                    ),
                                    _buildBadge(
                                      _approvalLabel(
                                        (detailData['approval_status'] ??
                                                'pending')
                                            .toString(),
                                      ),
                                      detailData['approval_status'] ==
                                              'approved'
                                          ? StitchTheme.success
                                          : StitchTheme.warning,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Hợp đồng bản mềm: ${detailData['contract_files_count'] ?? 0} file',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await _openContractSoftCopyModal(
                                      context: context,
                                      contractId: id,
                                      canManage:
                                          _readBool(detailData['can_manage']) ??
                                          false,
                                      onChanged: () async {
                                        final Map<String, dynamic> refreshed =
                                            await widget.apiService
                                                .getContractDetail(
                                                  widget.token,
                                                  id,
                                                );
                                        final List<Map<String, dynamic>>
                                        refreshedFr = await widget.apiService
                                            .getContractFinanceRequests(
                                              widget.token,
                                              id,
                                            );
                                        if (!context.mounted) {
                                          return;
                                        }
                                        setSheetState(() {
                                          if (refreshed.isNotEmpty) {
                                            detailData =
                                                Map<String, dynamic>.from(
                                                  refreshed,
                                                );
                                            detailData['finance_requests'] =
                                                refreshedFr;
                                          }
                                        });
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.folder_copy_outlined),
                                  label: const Text('Hợp đồng bản mềm'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if ((detailData['approval_status']?.toString() ==
                                  'pending') &&
                              widget.canApprove) ...<Widget>[
                            KeyedSubtree(
                              key: contractApprovalScrollKey,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      focusPendingContractApproval
                                          ? StitchTheme.warning.withValues(
                                            alpha: 0.07,
                                          )
                                          : StitchTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        focusPendingContractApproval
                                            ? StitchTheme.warning.withValues(
                                              alpha: 0.45,
                                            )
                                            : StitchTheme.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.verified_user_outlined,
                                          size: 18,
                                          color:
                                              focusPendingContractApproval
                                                  ? StitchTheme.warning
                                                  : StitchTheme.textMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Duyệt hợp đồng',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Hợp đồng đang chờ duyệt. Sau khi duyệt, dữ liệu tài chính mới được khóa theo hợp đồng.',
                                      style: TextStyle(
                                        color: StitchTheme.textMuted,
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Mã: ${(detailData['code'] ?? '').toString()}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: StitchTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tiêu đề: ${(detailData['title'] ?? '').toString()}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: StitchTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () async {
                                              final bool ok =
                                                  await _rejectContract(
                                                    id,
                                                    context,
                                                  );
                                              if (!context.mounted || !ok) {
                                                return;
                                              }
                                              final Map<String, dynamic>
                                              refreshed = await widget
                                                  .apiService
                                                  .getContractDetail(
                                                    widget.token,
                                                    id,
                                                  );
                                              final List<Map<String, dynamic>>
                                              refreshedFr = await widget
                                                  .apiService
                                                  .getContractFinanceRequests(
                                                    widget.token,
                                                    id,
                                                  );
                                              if (!context.mounted) {
                                                return;
                                              }
                                              setSheetState(() {
                                                if (refreshed.isNotEmpty) {
                                                  detailData =
                                                      Map<String, dynamic>.from(
                                                        refreshed,
                                                      );
                                                  detailData['finance_requests'] =
                                                      refreshedFr;
                                                }
                                              });
                                              AppTagMessage.show(
                                                'Đã không duyệt hợp đồng.',
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: StitchTheme.danger,
                                              ),
                                              foregroundColor:
                                                  StitchTheme.danger,
                                            ),
                                            child: const Text('Không duyệt'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () async {
                                              final bool ok = await widget
                                                  .apiService
                                                  .approveContract(
                                                    widget.token,
                                                    id,
                                                  );
                                              if (!context.mounted) {
                                                return;
                                              }
                                              if (!ok) {
                                                AppTagMessage.show(
                                                  'Duyệt hợp đồng thất bại.',
                                                  isError: true,
                                                );
                                                return;
                                              }
                                              final Map<String, dynamic>
                                              refreshed = await widget
                                                  .apiService
                                                  .getContractDetail(
                                                    widget.token,
                                                    id,
                                                  );
                                              final List<Map<String, dynamic>>
                                              refreshedFr = await widget
                                                  .apiService
                                                  .getContractFinanceRequests(
                                                    widget.token,
                                                    id,
                                                  );
                                              if (!context.mounted) {
                                                return;
                                              }
                                              setSheetState(() {
                                                if (refreshed.isNotEmpty) {
                                                  detailData =
                                                      Map<String, dynamic>.from(
                                                        refreshed,
                                                      );
                                                  detailData['finance_requests'] =
                                                      refreshedFr;
                                                }
                                              });
                                              setState(() {
                                                message = 'Đã duyệt hợp đồng.';
                                              });
                                              await _fetch();
                                              if (!context.mounted) {
                                                return;
                                              }
                                              AppTagMessage.show(
                                                'Đã duyệt hợp đồng.',
                                              );
                                            },
                                            child: const Text('Duyệt hợp đồng'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          const Text(
                            'Thông tin Tài chính',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
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
                                _buildDetailRow(
                                  'Giá trị trước VAT',
                                  _money(detailData['subtotal_value']),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                _buildDetailRow(
                                  'VAT',
                                  _money(detailData['vat_amount']),
                                  textColor: StitchTheme.warningStrong,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                _buildDetailRow(
                                  'Giá trị hợp đồng',
                                  _money(detailData['value']),
                                  bold: true,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                _buildDetailRow(
                                  'Đã thu',
                                  _money(detailData['payments_total']),
                                  textColor: StitchTheme.successStrong,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                _buildDetailRow(
                                  'Công nợ',
                                  _money(detailData['debt_outstanding']),
                                  textColor: StitchTheme.dangerStrong,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                _buildDetailRow(
                                  'Chi phí',
                                  _money(detailData['costs_total']),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'Phiếu duyệt thu/chi hợp đồng',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (financeRequests.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: StitchTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: StitchTheme.border),
                              ),
                              child: const Text(
                                'Chưa có phiếu duyệt tài chính nào.',
                                style: TextStyle(color: StitchTheme.textMuted),
                              ),
                            )
                          else
                            ...financeRequests.map((Map<String, dynamic> row) {
                              final String status =
                                  (row['status'] ?? 'pending').toString();
                              final bool isPending = status == 'pending';
                              final int requestId = _readInt(row['id']) ?? 0;
                              final bool isFocused =
                                  focusFinanceRequestId != null &&
                                  focusFinanceRequestId > 0 &&
                                  requestId == focusFinanceRequestId;
                              final Map<String, dynamic>? submitter =
                                  row['submitter'] as Map<String, dynamic>?;
                              final Map<String, dynamic>? reviewer =
                                  row['reviewer'] as Map<String, dynamic>?;

                              return Container(
                                key:
                                    isFocused && financeScrollKey != null
                                        ? financeScrollKey
                                        : ValueKey<String>('fr_$requestId'),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color:
                                      isFocused
                                          ? StitchTheme.primary.withValues(
                                            alpha: 0.07,
                                          )
                                          : StitchTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        isFocused
                                            ? StitchTheme.primary.withValues(
                                              alpha: 0.4,
                                            )
                                            : StitchTheme.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            _financeTypeLabel(
                                              (row['request_type'] ?? '')
                                                  .toString(),
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        _buildBadge(
                                          _financeStatusLabel(status),
                                          _financeStatusColor(status),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Số tiền: ${_money(row['amount'])}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ngày: ${_safeDate(row['transaction_date'])}',
                                      style: const TextStyle(
                                        color: StitchTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Người gửi: ${(submitter?['name'] ?? '—').toString()}',
                                      style: const TextStyle(
                                        color: StitchTheme.textMuted,
                                      ),
                                    ),
                                    if ((row['note'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 6),
                                      Text(
                                        (row['note'] ?? '').toString(),
                                        style: const TextStyle(
                                          color: StitchTheme.textMain,
                                        ),
                                      ),
                                    ],
                                    if (status != 'pending') ...<Widget>[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Người duyệt: ${(reviewer?['name'] ?? '—').toString()}',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if ((row['review_note'] ?? '')
                                          .toString()
                                          .trim()
                                          .isNotEmpty)
                                        Text(
                                          'Ghi chú duyệt: ${(row['review_note'] ?? '').toString()}',
                                          style: const TextStyle(
                                            color: StitchTheme.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                    if (isPending &&
                                        canReviewFinanceRequest) ...<Widget>[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed:
                                                  () => reviewFinanceRequest(
                                                    row,
                                                    false,
                                                  ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    StitchTheme.danger,
                                                side: BorderSide(
                                                  color: StitchTheme.danger,
                                                ),
                                              ),
                                              child: const Text('Từ chối'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: FilledButton(
                                              onPressed:
                                                  () => reviewFinanceRequest(
                                                    row,
                                                    true,
                                                  ),
                                              child: const Text('Duyệt'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 20),

                          const Text(
                            'Thông tin Chung',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
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
                                _buildDetailRow(
                                  'Nhân viên thu',
                                  ((detailData['collector']
                                              as Map<
                                                String,
                                                dynamic
                                              >?)?['name'] ??
                                          '—')
                                      .toString(),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                _buildDetailRow(
                                  'Dự án',
                                  ((detailData['project']
                                              as Map<
                                                String,
                                                dynamic
                                              >?)?['name'] ??
                                          'Chưa liên kết')
                                      .toString(),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                _buildDetailRow(
                                  'Ngày ký',
                                  _safeDate(detailData['signed_at']),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                _buildDetailRow(
                                  'Thời gian',
                                  '${_safeDate(detailData['start_date'])} → ${_safeDate(detailData['end_date'])}',
                                ),
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
                                      builder:
                                          (_) => CreateProjectScreen(
                                            token: widget.token,
                                            apiService: widget.apiService,
                                            initialContractId:
                                                detailData['id'].toString(),
                                            initialContractTitle:
                                                detailData['title']?.toString(),
                                          ),
                                    ),
                                  ).then((_) => _fetch());
                                },
                                icon: const Icon(Icons.rocket_launch, size: 18),
                                label: const Text('Tạo Dự án Triển khai'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          const Text(
                            'Nhật ký chăm sóc',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Ghi lại các tương tác, tiến độ và yêu cầu để nhóm cùng nắm được.',
                            style: TextStyle(
                              color: StitchTheme.textMuted,
                              fontSize: 13,
                            ),
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
                                      onPressed:
                                          savingCareNote
                                              ? null
                                              : () async {
                                                final String title =
                                                    careNoteTitleCtrl.text
                                                        .trim();
                                                final String detailText =
                                                    careNoteDetailCtrl.text
                                                        .trim();
                                                if (title.isEmpty ||
                                                    detailText.isEmpty) {
                                                  AppTagMessage.show(
                                                    'Vui lòng nhập tiêu đề và nội dung.',
                                                    isError: true,
                                                  );
                                                  return;
                                                }
                                                setSheetState(
                                                  () => savingCareNote = true,
                                                );
                                                final Map<String, dynamic>?
                                                note = await widget.apiService
                                                    .createContractCareNote(
                                                      widget.token,
                                                      id,
                                                      title: title,
                                                      detail: detailText,
                                                    );
                                                if (!context.mounted) return;
                                                setSheetState(
                                                  () => savingCareNote = false,
                                                );
                                                if (note == null) {
                                                  AppTagMessage.show(
                                                    'Lưu thất bại.',
                                                    isError: true,
                                                  );
                                                  return;
                                                }
                                                setSheetState(() {
                                                  final List<dynamic>
                                                  nextNotes = List<
                                                    dynamic
                                                  >.from(
                                                    (detailData['care_notes'] ??
                                                            <dynamic>[])
                                                        as List<dynamic>,
                                                  );
                                                  nextNotes.insert(0, note);
                                                  detailData['care_notes'] =
                                                      nextNotes;
                                                });
                                                careNoteTitleCtrl.clear();
                                                careNoteDetailCtrl.clear();
                                                AppTagMessage.show(
                                                  'Đã cập nhật nhật ký.',
                                                );
                                              },
                                      child: Text(
                                        savingCareNote
                                            ? 'Đang lưu...'
                                            : 'Gửi nhật ký',
                                      ),
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
                                child: Text(
                                  'Chưa có lịch sử chăm sóc.',
                                  style: TextStyle(
                                    color: StitchTheme.textSubtle,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...careNotes.map((Map<String, dynamic> note) {
                              final Map<String, dynamic>? user =
                                  note['user'] as Map<String, dynamic>?;
                              final String uName =
                                  (user?['name'] ?? 'Ẩn danh').toString();
                              final String initial =
                                  uName.isNotEmpty
                                      ? uName.substring(0, 1).toUpperCase()
                                      : '?';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: StitchTheme.primary
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          color: StitchTheme.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                                          border: Border.all(
                                            color: StitchTheme.border,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    uName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  _safeDateTime(
                                                    note['created_at'],
                                                  ),
                                                  style: const TextStyle(
                                                    color:
                                                        StitchTheme.textSubtle,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              (note['title'] ?? '').toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (note['detail'] ?? '').toString(),
                                              style: const TextStyle(
                                                color: StitchTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ..._contractActivityLogSection(detailData),
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
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool bold = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: StitchTheme.textMuted)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: textColor ?? StitchTheme.textMain,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final int active =
        contracts
            .where((Map<String, dynamic> c) => c['status'] == 'active')
            .length;
    final int signed =
        contracts
            .where((Map<String, dynamic> c) => c['status'] == 'signed')
            .length;
    final int expired =
        contracts
            .where((Map<String, dynamic> c) => c['status'] == 'expired')
            .length;

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
      body: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          CupertinoSliverRefreshControl(onRefresh: _fetch),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                if (_listRefreshing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
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
                            ...<String>[
                              'draft',
                              'signed',
                              'success',
                              'active',
                              'expired',
                              'cancelled',
                            ].map(
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
                              (Map<String, dynamic> c) =>
                                  DropdownMenuItem<int?>(
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
                      const SizedBox(height: 12),
                      StaffMultiFilterRow(
                        users: collectors,
                        selectedIds: contractListStaffFilterIds,
                        title: 'Nhân sự (thu tiền / tạo HĐ / chăm sóc / KH)',
                        onChanged: (List<int> ids) {
                          setState(() => contractListStaffFilterIds = ids);
                        },
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
                if (!loading && totalContracts > 0) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: StitchTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: StitchTheme.border.withValues(alpha: 0.85),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Tổng theo bộ lọc (tất cả trang)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.08,
                            color: StitchTheme.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _buildMetricCol(
                                Icons.monetization_on_outlined,
                                'Giá trị',
                                _money(aggregateRevenueTotal),
                              ),
                            ),
                            Expanded(
                              child: _buildMetricCol(
                                Icons.account_balance_wallet_outlined,
                                'Đã thu',
                                _money(aggregateCashflowTotal),
                                highlight: true,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1),
                        ),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _buildMetricCol(
                                Icons.warning_amber_rounded,
                                'Công nợ',
                                _money(aggregateDebtTotal),
                                color: StitchTheme.danger,
                              ),
                            ),
                            Expanded(
                              child: _buildMetricCol(
                                Icons.receipt_long_outlined,
                                'Chi phí',
                                _money(aggregateCostsTotal),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (loading && contracts.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (contracts.isEmpty)
                  const Text(
                    'Chưa có hợp đồng.',
                    style: TextStyle(color: StitchTheme.textMuted),
                  )
                else
                  ...contracts.map(
                    (Map<String, dynamic> c) => _buildContractItem(c),
                  ),
                if (loadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!loadingMore &&
                    currentPage >= lastPage &&
                    contracts.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Đã hiển thị toàn bộ hợp đồng.',
                        style: TextStyle(
                          color: StitchTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
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
                  onTap:
                      () =>
                          _openDetail(contract: c), // Bấm cả thẻ để Xem details
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
                            if (widget.canManage ||
                                _canDeleteContract(c)) ...<Widget>[
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 32,
                                width: 32,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    size: 20,
                                    color: StitchTheme.textMuted,
                                  ),
                                  padding: EdgeInsets.zero,
                                  position: PopupMenuPosition.under,
                                  onSelected: (String val) {
                                    if (val == 'edit') {
                                      _openForm(contract: c);
                                    }
                                    if (val == 'delete') {
                                      _delete((c['id'] ?? 0) as int);
                                    }
                                  },
                                  itemBuilder:
                                      (BuildContext context) =>
                                          <PopupMenuEntry<String>>[
                                            if (widget.canManage)
                                              const PopupMenuItem<String>(
                                                value: 'edit',
                                                child: Text('Sửa hợp đồng'),
                                              ),
                                            if (_canDeleteContract(c))
                                              PopupMenuItem<String>(
                                                value: 'delete',
                                                child: Text(
                                                  'Xóa',
                                                  style: TextStyle(
                                                    color: StitchTheme.danger,
                                                  ),
                                                ),
                                              ),
                                          ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.2),
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: StitchTheme.warning.withValues(
                                    alpha: 0.1,
                                  ),
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
                            border: Border.all(
                              color: StitchTheme.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _buildMetricCol(
                                      Icons.monetization_on_outlined,
                                      'Giá trị',
                                      _money(c['value']),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildMetricCol(
                                      Icons.account_balance_wallet_outlined,
                                      'Đã thu',
                                      _money(c['payments_total']),
                                      highlight: true,
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1),
                              ),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _buildMetricCol(
                                      Icons.warning_amber_rounded,
                                      'Công nợ',
                                      _money(c['debt_outstanding']),
                                      color: StitchTheme.danger,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildMetricCol(
                                      Icons.calendar_month_outlined,
                                      'Hiệu lực',
                                      '${_safeDate(c['start_date'])} -> ${_safeDate(c['end_date'])}',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: StitchTheme.textSubtle,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Thu tiền: ${((c['collector'] as Map<String, dynamic>?)?['name'] ?? '—').toString()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: StitchTheme.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (c['approval_status'] == 'pending' &&
                            widget.canApprove) ...<Widget>[
                          const SizedBox(height: 14),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final bool ok = await _rejectContract(
                                      (c['id'] ?? 0) as int,
                                      context,
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      message =
                                          ok
                                              ? 'Đã không duyệt hợp đồng.'
                                              : 'Không duyệt hợp đồng thất bại.';
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: StitchTheme.danger),
                                    foregroundColor: StitchTheme.danger,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Không duyệt'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final bool ok = await widget.apiService
                                        .approveContract(
                                          widget.token,
                                          (c['id'] ?? 0) as int,
                                        );
                                    if (!mounted) return;
                                    setState(() {
                                      message =
                                          ok
                                              ? 'Đã duyệt hợp đồng.'
                                              : 'Duyệt hợp đồng thất bại.';
                                    });
                                    if (ok) await _fetch();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: StitchTheme.success,
                                    ),
                                    foregroundColor: StitchTheme.success,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Duyệt ngang'),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildMetricCol(
    IconData icon,
    String label,
    String value, {
    bool highlight = false,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 12, color: color ?? StitchTheme.textSubtle),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color ?? StitchTheme.textMuted,
              ),
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

class _ContractSoftCopySheet extends StatefulWidget {
  const _ContractSoftCopySheet({
    required this.token,
    required this.api,
    required this.contractId,
    required this.canManage,
    required this.onChanged,
  });

  final String token;
  final MobileApiService api;
  final int contractId;
  final bool canManage;
  final Future<void> Function() onChanged;

  @override
  State<_ContractSoftCopySheet> createState() => _ContractSoftCopySheetState();
}

class _ContractSoftCopySheetState extends State<_ContractSoftCopySheet> {
  List<Map<String, dynamic>> files = <Map<String, dynamic>>[];
  bool loading = true;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> list = await widget.api.getContractFiles(
      widget.token,
      widget.contractId,
    );
    if (!mounted) return;
    setState(() {
      files = list;
      loading = false;
    });
  }

  String _bytesLabel(dynamic raw) {
    final int n = int.tryParse('${raw ?? 0}') ?? 0;
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickAndUpload() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => uploading = true);
    try {
      for (final PlatformFile pf in result.files) {
        final String? path = pf.path;
        if (path == null || path.isEmpty) continue;
        await widget.api.uploadContractFile(
          widget.token,
          widget.contractId,
          path,
        );
      }
      await widget.onChanged();
      await _load();
      if (mounted) {
        AppTagMessage.show('Đã tải file lên.');
      }
    } catch (e) {
      if (mounted) {
        AppTagMessage.show(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _download(Map<String, dynamic> row) async {
    final int fid = int.tryParse('${row['id']}') ?? 0;
    if (fid <= 0) return;
    try {
      final Uint8List bytes = await widget.api.downloadContractFile(
        widget.token,
        widget.contractId,
        fid,
      );
      final Directory dir = await getTemporaryDirectory();
      final String name = (row['original_name'] ?? 'file').toString();
      final File file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(<XFile>[XFile(file.path)], text: name);
    } catch (_) {
      if (mounted) {
        AppTagMessage.show('Không tải được file.', isError: true);
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final int fid = int.tryParse('${row['id']}') ?? 0;
    if (fid <= 0) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext c) => AlertDialog(
            title: const Text('Xóa file?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    final bool deleted = await widget.api.deleteContractFile(
      widget.token,
      widget.contractId,
      fid,
    );
    if (!mounted) return;
    if (deleted) {
      await widget.onChanged();
      await _load();
      if (!mounted) return;
      AppTagMessage.show('Đã xóa file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Hợp đồng bản mềm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Tải lên và tải xuống file đính kèm (tối đa 50 MB mỗi file).',
              style: TextStyle(color: StitchTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (widget.canManage)
              FilledButton.icon(
                onPressed: uploading ? null : _pickAndUpload,
                icon:
                    uploading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.upload_file),
                label: Text(uploading ? 'Đang tải lên…' : 'Tải file lên'),
              ),
            if (!widget.canManage)
              const Text(
                'Bạn chỉ có quyền xem và tải xuống.',
                style: TextStyle(color: StitchTheme.textMuted, fontSize: 12),
              ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  loading
                      ? const Center(child: CircularProgressIndicator())
                      : files.isEmpty
                      ? const Center(
                        child: Text(
                          'Chưa có file nào.',
                          style: TextStyle(color: StitchTheme.textMuted),
                        ),
                      )
                      : ListView.separated(
                        itemCount: files.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext _, int i) {
                          final Map<String, dynamic> f = files[i];
                          final dynamic up = f['uploader'];
                          final String who =
                              up is Map ? (up['name'] ?? '—').toString() : '—';
                          return ListTile(
                            title: Text(
                              (f['original_name'] ?? '').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text('${_bytesLabel(f['size'])} • $who'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _download(f),
                                ),
                                if (widget.canManage)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(f),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

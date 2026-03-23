import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
    required this.canDelete,
    required this.canApprove,
    required this.currentUserRole,
    required this.currentUserId,
  });

  final String token;
  final MobileApiService apiService;
  final bool canManage;
  final bool canDelete;
  final bool canApprove;
  final String currentUserRole;
  final int? currentUserId;

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController valueCtrl = TextEditingController();
  final TextEditingController paymentTimesCtrl = TextEditingController(text: '1');
  final TextEditingController signedCtrl = TextEditingController();
  final TextEditingController startCtrl = TextEditingController();
  final TextEditingController endCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  bool loading = false;
  String message = '';
  String filterStatus = '';
  int? filterClientId;
  int? formClientId;
  int? editingId;
  String status = 'draft';

  List<Map<String, dynamic>> contracts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> products = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> collectors = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> payments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> costs = <Map<String, dynamic>>[];
  int? collectorUserId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    codeCtrl.dispose();
    titleCtrl.dispose();
    valueCtrl.dispose();
    paymentTimesCtrl.dispose();
    signedCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> clientRows =
        await widget.apiService.getClients(widget.token);
    final List<Map<String, dynamic>> productRows =
        await widget.apiService.getProducts(widget.token);
    final List<Map<String, dynamic>> collectorRows =
        await widget.apiService.getUsersLookup(
      widget.token,
      purpose: 'contract_collector',
    );
    final List<Map<String, dynamic>> contractRows =
        await widget.apiService.getContracts(
      widget.token,
      perPage: 100,
      search: searchCtrl.text.trim(),
      status: filterStatus,
      clientId: filterClientId,
      withItems: true,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      clients = clientRows;
      products = productRows;
      collectors = collectorRows;
      contracts = contractRows;
    });
  }

  Future<void> _importContracts() async {
    if (!widget.canManage) {
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
    if (!widget.canManage) {
      setState(() => message = 'Bạn không có quyền quản lý hợp đồng.');
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
            code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
            title: titleCtrl.text.trim(),
            clientId: formClientId!,
            collectorUserId: collectorUserId,
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
            code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
            title: titleCtrl.text.trim(),
            clientId: formClientId!,
            collectorUserId: collectorUserId,
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
    setState(() {
      message = '';
      if (contract == null) {
        _resetForm();
      } else {
        editingId = _readInt(contract['id']) ?? 0;
        codeCtrl.text = (contract['code'] ?? '').toString();
        titleCtrl.text = (contract['title'] ?? '').toString();
        valueCtrl.text = (contract['value'] ?? '').toString();
        paymentTimesCtrl.text =
            (contract['payment_times'] ?? 1).toString();
        signedCtrl.text = _safeDate(contract['signed_at']);
        startCtrl.text = _safeDate(contract['start_date']);
        endCtrl.text = _safeDate(contract['end_date']);
        notesCtrl.text = (contract['notes'] ?? '').toString();
        status = (contract['status'] ?? 'draft').toString();
        formClientId = _readInt(contract['client_id']);
        collectorUserId = _readInt(contract['collector_user_id']);
        items = ((contract['items'] ?? <dynamic>[]) as List<dynamic>)
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
                      editingId == null ? 'Tạo hợp đồng' : 'Sửa hợp đồng',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mã hợp đồng (tự sinh nếu để trống)',
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
                            child: Text(editingId == null ? 'Lưu hợp đồng' : 'Cập nhật'),
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
                            final bool ok =
                                await _save(createAndApprove: true);
                            if (!mounted) return;
                            if (ok) {
                              navigator.pop();
                            } else {
                              setSheetState(() {});
                            }
                          },
                          child: const Text('Tạo và duyệt'),
                        ),
                      ),
                    ],
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
    formClientId = null;
    collectorUserId = _defaultCollectorUserId;
    status = 'draft';
    codeCtrl.clear();
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

  @override
  Widget build(BuildContext context) {
    final int total = contracts.length;
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
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: _importContracts,
            ),
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: ListView(
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
                value: total.toString(),
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
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Danh sách hợp đồng',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (widget.canManage)
                ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm'),
                ),
            ],
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
            ...contracts.map((Map<String, dynamic> c) {
              final Color statusColor = _statusColor((c['status'] ?? '').toString());
              final Map<String, dynamic>? client =
                  c['client'] as Map<String, dynamic>?;
              final Map<String, dynamic>? project =
                  c['project'] as Map<String, dynamic>?;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusLabel((c['status'] ?? 'draft').toString()),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if ((c['approval_status'] ?? '').toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (c['approval_status'] == 'approved'
                                  ? StitchTheme.success
                                  : StitchTheme.warning)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _approvalLabel(
                                  (c['approval_status'] ?? 'pending').toString(),
                                ),
                                style: TextStyle(
                                  color: c['approval_status'] == 'approved'
                                      ? StitchTheme.success
                                      : StitchTheme.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _openForm(contract: c),
                            child: const Text('Sửa'),
                          ),
                          if (widget.canApprove &&
                              (c['approval_status'] ?? '') != 'approved')
                            TextButton(
                              onPressed: () => widget.apiService
                                  .approveContract(widget.token, _readInt(c['id']) ?? 0)
                                  .then((bool ok) async {
                                if (!mounted) return;
                                setState(() {
                                  message = ok
                                      ? 'Đã duyệt hợp đồng.'
                                      : 'Duyệt hợp đồng thất bại.';
                                });
                                if (ok) await _fetch();
                              }),
                              child: Text(
                                'Duyệt',
                                style: TextStyle(color: StitchTheme.success),
                              ),
                            ),
                          if (widget.canDelete)
                            TextButton(
                              onPressed: () => _delete(_readInt(c['id']) ?? 0),
                              child: Text(
                                'Xóa',
                                style: TextStyle(color: StitchTheme.danger),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (c['title'] ?? 'Hợp đồng').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${c['code'] ?? ''} • ${(client?['name'] ?? 'Khách hàng').toString()}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      Text(
                        'Nhân viên thu: ${((c['collector'] as Map<String, dynamic>?)?['name'] ?? '—').toString()}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dự án: ${(project?['name'] ?? 'Chưa liên kết').toString()}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      Text(
                        'Giá trị: ${_money(c['value'])}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      Text(
                        'Đã thu: ${_money(c['payments_total'])}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      Text(
                        'Công nợ: ${_money(c['debt_outstanding'])}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      Text(
                        'Chi phí: ${_money(c['costs_total'])}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      Text(
                        'Thanh toán: ${(c['payments_count'] ?? 0)}/${c['payment_times'] ?? 1}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      Text(
                        'Ký: ${_safeDate(c['signed_at'])}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      Text(
                        'Hiệu lực: ${_safeDate(c['start_date'])} → ${_safeDate(c['end_date'])}',
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      if ((c['notes'] ?? '').toString().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          'Ghi chú: ${(c['notes'] ?? '').toString()}',
                          style: const TextStyle(color: StitchTheme.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

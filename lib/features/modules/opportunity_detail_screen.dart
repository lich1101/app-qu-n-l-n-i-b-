import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class OpportunityDetailScreen extends StatefulWidget {
  const OpportunityDetailScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.opportunityId,
    this.canManage = false,
    this.canDelete = false,
  });

  final String token;
  final MobileApiService apiService;
  final int opportunityId;
  final bool canManage;
  final bool canDelete;

  @override
  State<OpportunityDetailScreen> createState() => _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  bool _loading = true;
  bool _saving = false;
  String _message = '';
  Map<String, dynamic>? _opportunity;
  List<Map<String, dynamic>> _statuses = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _clients = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final List<dynamic> responses = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.apiService.getOpportunityDetail(widget.token, widget.opportunityId),
        widget.apiService.getOpportunityStatuses(widget.token),
        widget.apiService.getClients(widget.token, perPage: 300),
      ]);
      final Map<String, dynamic>? detail = responses[0] as Map<String, dynamic>?;
      final List<Map<String, dynamic>> statuses =
          responses[1] as List<Map<String, dynamic>>;
      final Map<String, dynamic> clientsPayload =
          responses[2] as Map<String, dynamic>;
      final List<dynamic> clientRows =
          (clientsPayload['data'] as List<dynamic>?) ?? <dynamic>[];

      if (!mounted) return;
      setState(() {
        _opportunity = detail;
        _statuses = statuses;
        _clients =
            clientRows
                .whereType<Map>()
                .map((Map row) => row.cast<String, dynamic>())
                .toList();
        _loading = false;
        if (detail == null || detail.isEmpty) {
          _message = 'Cơ hội không tồn tại.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Không tải được chi tiết cơ hội.';
      });
    }
  }

  String _formatCurrency(dynamic value) {
    final num amount = value is num ? value : num.tryParse('${value ?? 0}') ?? 0;
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'), (Match m) => '.')}đ';
  }

  Color _statusColor() {
    final String rawHex = (_opportunity?['statusConfig']?['color_hex'] ?? '')
        .toString()
        .trim();
    if (rawHex.isEmpty) return StitchTheme.primary;
    String hex = rawHex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return StitchTheme.primary;
    }
  }

  String _statusName() {
    return (_opportunity?['statusConfig']?['name'] ??
            _opportunity?['status'] ??
            '—')
        .toString();
  }

  Future<void> _openEditSheet() async {
    final Map<String, dynamic>? opportunity = _opportunity;
    if (opportunity == null) return;

    final TextEditingController titleCtrl = TextEditingController(
      text: (opportunity['title'] ?? '').toString(),
    );
    final TextEditingController amountCtrl = TextEditingController(
      text: (opportunity['amount'] ?? '').toString(),
    );
    final TextEditingController sourceCtrl = TextEditingController(
      text: (opportunity['source'] ?? '').toString(),
    );
    final TextEditingController notesCtrl = TextEditingController(
      text: (opportunity['notes'] ?? '').toString(),
    );
    final TextEditingController typeCtrl = TextEditingController(
      text: (opportunity['opportunity_type'] ?? '').toString(),
    );
    final TextEditingController probabilityCtrl = TextEditingController(
      text: (opportunity['success_probability'] ?? '').toString(),
    );
    final TextEditingController expectedDateCtrl = TextEditingController(
      text: (opportunity['expected_close_date'] ?? '').toString(),
    );
    int? clientId = _toInt(opportunity['client_id']);
    String? statusCode = (opportunity['status'] ?? '').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Sửa cơ hội',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _FieldLabel('Tên cơ hội *'),
                    TextField(controller: titleCtrl),
                    const SizedBox(height: 12),
                    _FieldLabel('Khách hàng *'),
                    DropdownButtonFormField<int>(
                      value: clientId,
                      decoration: const InputDecoration(hintText: 'Chọn khách hàng'),
                      items: _clients
                          .map(
                            (Map<String, dynamic> client) => DropdownMenuItem<int>(
                              value: _toInt(client['id']),
                              child: Text(
                                '${client['name'] ?? '—'}${(client['company'] ?? '').toString().trim().isNotEmpty ? ' • ${client['company']}' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (int? next) => setModalState(() => clientId = next),
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel('Trạng thái'),
                    DropdownButtonFormField<String>(
                      value: statusCode == null || statusCode!.isEmpty ? null : statusCode,
                      decoration: const InputDecoration(hintText: 'Chọn trạng thái'),
                      items: _statuses
                          .map(
                            (Map<String, dynamic> status) => DropdownMenuItem<String>(
                              value: (status['code'] ?? '').toString(),
                              child: Text((status['name'] ?? '—').toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (String? next) => setModalState(() => statusCode = next),
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel('Doanh số dự kiến (VNĐ) *'),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel('Nguồn cơ hội'),
                    TextField(controller: sourceCtrl),
                    const SizedBox(height: 12),
                    _FieldLabel('Loại cơ hội'),
                    TextField(controller: typeCtrl),
                    const SizedBox(height: 12),
                    _FieldLabel('Tỷ lệ thành công (%) *'),
                    TextField(
                      controller: probabilityCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel('Ngày kết thúc dự kiến'),
                    TextField(
                      controller: expectedDateCtrl,
                      decoration: const InputDecoration(
                        hintText: 'YYYY-MM-DD',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel('Ghi chú'),
                    TextField(controller: notesCtrl, minLines: 3, maxLines: 4),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                if (titleCtrl.text.trim().isEmpty || clientId == null || clientId == 0) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Vui lòng nhập tên cơ hội và chọn khách hàng.'),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() {});
                                final bool saved = await _submitEdit(
                                  title: titleCtrl.text.trim(),
                                  clientId: clientId!,
                                  status: statusCode,
                                  amount: amountCtrl.text.trim(),
                                  source: sourceCtrl.text.trim(),
                                  notes: notesCtrl.text.trim(),
                                  opportunityType: typeCtrl.text.trim(),
                                  successProbability: probabilityCtrl.text.trim(),
                                  expectedCloseDate: expectedDateCtrl.text.trim(),
                                );
                                if (!mounted || !context.mounted) return;
                                if (saved) {
                                  Navigator.of(context).pop();
                                }
                              },
                        child: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                      ),
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

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  double? _toDouble(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  int? _toProbability(String value) {
    if (value.trim().isEmpty) return null;
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null) return null;
    if (parsed < 0 || parsed > 100) return null;
    return parsed;
  }

  Future<bool> _submitEdit({
    required String title,
    required int clientId,
    String? status,
    required String amount,
    required String source,
    required String notes,
    required String opportunityType,
    required String successProbability,
    required String expectedCloseDate,
  }) async {
    setState(() => _saving = true);
    try {
      final double? amt = _toDouble(amount);
      if (amt == null || amt < 0) {
        if (mounted) {
          setState(() {
            _message = 'Vui lòng nhập doanh số dự kiến (số ≥ 0).';
          });
        }
        return false;
      }
      final int? prob = _toProbability(successProbability);
      if (prob == null) {
        if (mounted) {
          setState(() {
            _message = 'Vui lòng nhập tỷ lệ thành công (0–100%).';
          });
        }
        return false;
      }
      final bool ok = await widget.apiService.updateOpportunity(
        widget.token,
        widget.opportunityId,
        title: title,
        clientId: clientId,
        status: (status ?? '').trim().isEmpty ? null : status,
        amount: amt,
        source: source.trim().isEmpty ? null : source.trim(),
        notes: notes.trim().isEmpty ? null : notes.trim(),
        opportunityType:
            opportunityType.trim().isEmpty ? null : opportunityType.trim(),
        successProbability: prob,
        expectedCloseDate:
            expectedCloseDate.trim().isEmpty ? null : expectedCloseDate.trim(),
      );
      if (!mounted) return false;
      setState(() {
        _message = ok ? 'Đã cập nhật cơ hội.' : 'Không cập nhật được cơ hội.';
      });
      if (ok) {
        await _fetch();
      }
      return ok;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? opportunity = _opportunity;
    final Map<String, dynamic>? client =
        opportunity?['client'] as Map<String, dynamic>?;
    final Map<String, dynamic>? assignee =
        opportunity?['assignee'] as Map<String, dynamic>?;
    final Map<String, dynamic>? creator =
        opportunity?['creator'] as Map<String, dynamic>?;
    final Color statusColor = _statusColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Chi tiết cơ hội'),
        actions: <Widget>[
          if (widget.canManage && opportunity != null)
            IconButton(
              tooltip: 'Sửa cơ hội',
              onPressed: _openEditSheet,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetch,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: <Widget>[
                    if (_message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _message,
                          style: const TextStyle(
                            color: StitchTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (opportunity == null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: StitchTheme.border),
                        ),
                        child: const Text(
                          'Cơ hội không tồn tại hoặc bạn không có quyền truy cập.',
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: StitchTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              (opportunity['title'] ?? '—').toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _statusName(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if ((opportunity['opportunity_type'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: StitchTheme.primarySoft,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: StitchTheme.primaryStrong
                                            .withValues(alpha: 0.22),
                                      ),
                                    ),
                                    child: Text(
                                      (opportunity['opportunity_type'] ?? '')
                                          .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: StitchTheme.textMain,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _InfoRow(
                              icon: Icons.business_outlined,
                              label: 'Khách hàng',
                              value:
                                  '${client?['name'] ?? '—'}${(client?['company'] ?? '').toString().trim().isNotEmpty ? ' • ${client?['company']}' : ''}',
                            ),
                            _InfoRow(
                              icon: Icons.person_outline,
                              label: 'Phụ trách',
                              value:
                                  (assignee?['name'] ??
                                          creator?['name'] ??
                                          '—')
                                      .toString(),
                            ),
                            _InfoRow(
                              icon: Icons.attach_money,
                              label: 'Doanh số',
                              value: _formatCurrency(opportunity['amount']),
                            ),
                            _InfoRow(
                              icon: Icons.percent,
                              label: 'Khả năng thành công',
                              value:
                                  '${opportunity['success_probability'] ?? 0}%',
                            ),
                            _InfoRow(
                              icon: Icons.event_outlined,
                              label: 'Ngày kết thúc dự kiến',
                              value: (opportunity['expected_close_date'] ?? '—')
                                  .toString(),
                            ),
                            _InfoRow(
                              icon: Icons.source_outlined,
                              label: 'Nguồn cơ hội',
                              value: (opportunity['source'] ?? '—').toString(),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Ghi chú',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: StitchTheme.textSubtle,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (opportunity['notes'] ?? 'Chưa có ghi chú.')
                                  .toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: StitchTheme.textMain,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: StitchTheme.textSubtle,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: StitchTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: StitchTheme.textSubtle,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: StitchTheme.textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

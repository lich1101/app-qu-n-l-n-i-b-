import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';
import 'opportunity_detail_edit_screen.dart';

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
    final bool? ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => OpportunityDetailEditScreen(
              token: widget.token,
              apiService: widget.apiService,
              opportunityId: widget.opportunityId,
              opportunity: Map<String, dynamic>.from(opportunity),
              clients: _clients,
              statuses: _statuses,
            ),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      await _fetch();
      if (mounted) {
        setState(() => _message = 'Đã cập nhật cơ hội.');
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

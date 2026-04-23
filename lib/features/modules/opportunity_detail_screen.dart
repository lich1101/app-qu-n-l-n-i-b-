import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
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
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  bool _loading = true;
  String _message = '';
  Map<String, dynamic>? _opportunity;
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
      final List<dynamic> responses =
          await Future.wait<dynamic>(<Future<dynamic>>[
            widget.apiService.getOpportunityDetail(
              widget.token,
              widget.opportunityId,
            ),
            widget.apiService.getClients(widget.token, perPage: 300),
          ]);
      final Map<String, dynamic>? detail =
          responses[0] as Map<String, dynamic>?;
      final Map<String, dynamic> clientsPayload =
          responses[1] as Map<String, dynamic>;
      final List<dynamic> clientRows =
          (clientsPayload['data'] as List<dynamic>?) ?? <dynamic>[];

      if (!mounted) return;
      setState(() {
        _opportunity = detail;
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
    final num amount =
        value is num ? value : num.tryParse('${value ?? 0}') ?? 0;
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'), (Match m) => '.')}đ';
  }

  Color _statusColorByCode(String code) {
    switch (code) {
      case 'undetermined':
        return const Color(0xFF64748B);
      case 'open':
        return const Color(0xFF0EA5E9);
      case 'overdue':
        return const Color(0xFFF59E0B);
      case 'won':
      case 'success':
        return const Color(0xFF10B981);
      case 'lost':
        return const Color(0xFFEF4444);
      default:
        return StitchTheme.primary;
    }
  }

  Color _statusColor() {
    final String code =
        (_opportunity?['status'] ?? _opportunity?['computed_status'] ?? '')
            .toString()
            .toLowerCase();
    final Color fallback = _statusColorByCode(code);
    final String hex =
        (_opportunity?['status_color_hex'] ?? '').toString().trim();
    if (hex.isEmpty) return fallback;
    final String normalized = hex.replaceAll('#', '');
    final String argb = normalized.length == 6 ? 'FF$normalized' : normalized;
    if (argb.length != 8) return fallback;
    final int? value = int.tryParse(argb, radix: 16);
    if (value == null) return fallback;
    return Color(value);
  }

  String _statusName() {
    return (_opportunity?['status_label'] ??
            _opportunity?['computed_status_label'] ??
            _opportunity?['status'] ??
            _opportunity?['computed_status'] ??
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
        child:
            _loading
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
                          child: StitchFeedbackBanner(
                            message: _message,
                            isError:
                                _message.toLowerCase().contains('không') ||
                                _message.toLowerCase().contains('không tải'),
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
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            gradient: const LinearGradient(
                              colors: <Color>[
                                Colors.white,
                                Color(0xFFF8FAFC),
                                Color(0xFFECFEFF),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: StitchTheme.border),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x120F172A),
                                blurRadius: 24,
                                offset: Offset(0, 12),
                              ),
                            ],
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
                                      color: statusColor.withValues(
                                        alpha: 0.15,
                                      ),
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
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                              const SizedBox(height: 14),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _OpportunityMetricTile(
                                      icon: Icons.attach_money_rounded,
                                      label: 'Doanh số',
                                      value: _formatCurrency(
                                        opportunity['amount'],
                                      ),
                                      accent: const Color(0xFF0EA5E9),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _OpportunityMetricTile(
                                      icon: Icons.percent_rounded,
                                      label: 'Khả năng thành công',
                                      value:
                                          '${opportunity['success_probability'] ?? 0}%',
                                      accent: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _DetailSection(
                                title: 'Thông tin chính',
                                children: <Widget>[
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
                                    icon: Icons.event_outlined,
                                    label: 'Ngày kết thúc dự kiến',
                                    value:
                                        (opportunity['expected_close_date'] ??
                                                '—')
                                            .toString(),
                                  ),
                                  _InfoRow(
                                    icon: Icons.source_outlined,
                                    label: 'Nguồn cơ hội',
                                    value:
                                        (opportunity['source'] ?? '—')
                                            .toString(),
                                  ),
                                  if (opportunity['contract'] != null &&
                                      opportunity['contract'] is Map)
                                    _InfoRow(
                                      icon: Icons.description_outlined,
                                      label: 'Hợp đồng liên kết',
                                      value:
                                          '${(opportunity['contract'] as Map)['code'] ?? '—'}',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _DetailSection(
                                title: 'Ghi chú',
                                children: <Widget>[
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

class _OpportunityMetricTile extends StatelessWidget {
  const _OpportunityMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: StitchTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: StitchTheme.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: StitchTheme.textSubtle,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

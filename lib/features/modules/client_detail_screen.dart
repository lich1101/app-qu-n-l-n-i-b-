import 'package:flutter/material.dart';
import '../../core/messaging/app_tag_message.dart';
import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';
import 'contracts_screen.dart';
import 'opportunity_detail_screen.dart';

Color _computedStatusColor(String code) {
  switch (code) {
    case 'undetermined':
      return const Color(0xFF64748B);
    case 'open':
      return const Color(0xFF0EA5E9);
    case 'overdue':
      return const Color(0xFFF59E0B);
    case 'success':
      return const Color(0xFF10B981);
    default:
      return StitchTheme.primary;
  }
}

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.clientId,
    this.currentUserId,
  });

  final String token;
  final MobileApiService apiService;
  final int clientId;
  final int? currentUserId;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  bool loading = true;
  Map<String, dynamic>? data;
  final TextEditingController noteTitleCtrl = TextEditingController();
  final TextEditingController noteDetailCtrl = TextEditingController();
  bool savingNote = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    noteTitleCtrl.dispose();
    noteDetailCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final result = await widget.apiService.getClientFlow(
      widget.token,
      widget.clientId,
    );
    if (mounted) {
      setState(() {
        data = result;
        loading = false;
      });
    }
  }

  Future<void> _addCareNote() async {
    if (noteTitleCtrl.text.trim().isEmpty ||
        noteDetailCtrl.text.trim().isEmpty) {
      AppTagMessage.show('Vui lòng nhập đầy đủ tiêu đề và nội dung.');
      return;
    }

    setState(() => savingNote = true);
    final ok = await widget.apiService.storeClientCareNote(
      widget.token,
      widget.clientId,
      title: noteTitleCtrl.text.trim(),
      detail: noteDetailCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => savingNote = false);
      if (ok) {
        noteTitleCtrl.clear();
        noteDetailCtrl.clear();
        Navigator.of(context).pop();
        _fetch();
      } else {
        AppTagMessage.show('Không thể thêm ghi chú chăm sóc.', isError: true);
      }
    }
  }

  void _showAddNoteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  decoration: const BoxDecoration(
                    color: StitchTheme.bg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thêm ghi chú chăm sóc',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: noteTitleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề',
                          hintText: 'VD: Gọi điện tư vấn, Gặp mặt trực tiếp...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteDetailCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung chi tiết',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: savingNote ? null : _addCareNote,
                              child:
                                  savingNote
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Text('Lưu ghi chú'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết khách hàng')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (data == null || data!['client'] == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết khách hàng')),
        body: const Center(child: Text('Không tìm thấy thông tin khách hàng.')),
      );
    }

    final client = data!['client'];
    final opportunities = (data!['opportunities'] as List? ?? []);
    final contracts = (data!['contracts'] as List? ?? []);
    final projects = (data!['projects'] as List? ?? []);
    final careNotes = (data!['care_notes'] as List? ?? []);
    final permissions = data!['permissions'] as Map? ?? {};
    final rotation = data!['client_rotation'] as Map? ?? <String, dynamic>{};
    final rotationHistory = (data!['rotation_history'] as List? ?? []);

    return Scaffold(
      backgroundColor: StitchTheme.surfaceAlt,
      appBar: AppBar(
        title: Text(client['name'] ?? 'Chi tiết khách hàng'),
        elevation: 0,
      ),
      floatingActionButton:
          permissions['can_add_care_note'] == true
              ? Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(28),
                color: StitchTheme.primary,
                child: InkWell(
                  onTap: _showAddNoteSheet,
                  borderRadius: BorderRadius.circular(28),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Text(
                      'Chăm sóc',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildClientHeaderCard(client),
            const SizedBox(height: 16),
            _buildSectionCard('Liên hệ', [
              _buildInfoRow(
                Icons.phone_iphone_rounded,
                'Điện thoại',
                _displayStr(client['phone']),
              ),
              _buildInfoRow(
                Icons.alternate_email_rounded,
                'Email',
                _displayStr(client['email']),
              ),
            ]),
            _buildSectionCard('Phân loại & kênh', [
              _buildInfoRow(
                Icons.campaign_rounded,
                'Nguồn lead',
                _displayStr(client['lead_source']),
              ),
              _buildInfoRow(
                Icons.hub_rounded,
                'Kênh',
                _displayStr(client['lead_channel']),
              ),
              _buildInfoRow(
                Icons.label_outline_rounded,
                'Loại lead',
                _nestedName(client['lead_type']),
              ),
              _buildInfoRow(
                Icons.star_outline_rounded,
                'Cấp KH',
                _displayStr(client['customer_level']),
              ),
              _buildInfoRow(
                Icons.flag_outlined,
                'Trạng thái',
                _displayStr(client['customer_status_label']),
              ),
              if (_hasText(client['lead_message']))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tin nhắn / ghi chú lead',
                          style: TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${client['lead_message']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
            _buildSectionCard('Tổ chức', [
              _buildInfoRow(
                Icons.business_rounded,
                'Công ty',
                _displayStr(client['company']),
              ),
              _buildInfoRow(
                Icons.groups_2_outlined,
                'Quy mô',
                _displayStr(client['company_size']),
              ),
              _buildInfoRow(
                Icons.tag_rounded,
                'Mã ngoài',
                _displayStr(client['external_code']),
              ),
              _buildInfoRow(
                Icons.apartment_rounded,
                'Phòng ban',
                _nestedName(client['assigned_department']),
              ),
            ]),
            _buildSectionCard('Tài chính tổng quan', [
              _buildInfoRow(
                Icons.payments_rounded,
                'Doanh thu',
                _formatMoney(client['total_revenue']),
              ),
              _buildInfoRow(
                Icons.account_balance_wallet_outlined,
                'Dòng tiền',
                _formatMoney(client['total_cash_flow']),
              ),
              _buildInfoRow(
                Icons.receipt_long_rounded,
                'Công nợ',
                _formatMoney(client['total_debt_amount']),
              ),
              _buildInfoRow(
                Icons.history_rounded,
                'Nợ cũ',
                _formatMoney(client['legacy_debt_amount']),
              ),
              _buildInfoRow(
                Icons.layers_outlined,
                'Hạng doanh thu',
                _nestedName(client['revenue_tier']),
              ),
              _buildInfoRow(
                Icons.shopping_bag_outlined,
                'Đã mua hàng',
                _formatBool(client['has_purchased']),
              ),
            ]),
            if (_hasText(client['notes']))
              _buildSectionCard('Ghi chú nội bộ', [
                Text(
                  '${client['notes']}',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: StitchTheme.textMain,
                  ),
                ),
              ]),
            _buildSectionCard('Nhân sự', [
              _buildStaffRow('Phụ trách', client['assigned_staff']),
              const SizedBox(height: 10),
              _buildStaffRow('Người sở hữu', client['sales_owner']),
              if ((client['care_staff_users'] as List?)?.isNotEmpty ==
                  true) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chăm sóc',
                    style: TextStyle(
                      fontSize: 12,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      (client['care_staff_users'] as List)
                          .map<Widget>(
                            (dynamic u) =>
                                _staffChip((u as Map)['name'] ?? '—'),
                          )
                          .toList(),
                ),
              ],
            ]),
            if (rotation.isNotEmpty)
              _buildRotationCard(
                Map<String, dynamic>.from(rotation),
                rotationHistory,
                permissions,
              ),
            if (careNotes.isNotEmpty) ...[
              _buildSectionTitle('Nhật ký chăm sóc'),
              ...careNotes.map((note) => _buildCareNoteItem(note)),
              const SizedBox(height: 16),
            ],
            if (opportunities.isNotEmpty) ...[
              _buildSectionTitle('Cơ hội kinh doanh'),
              ...opportunities.map((opp) => _buildOpportunityItem(opp)),
              const SizedBox(height: 16),
            ],
            if (contracts.isNotEmpty) ...[
              _buildSectionTitle('Hợp đồng'),
              ...contracts.map((contract) => _buildContractItem(contract)),
              const SizedBox(height: 16),
            ],
            if (projects.isNotEmpty) ...[
              _buildSectionTitle('Dự án'),
              ...projects.map((project) => _buildProjectItem(project)),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: StitchTheme.textMain,
        ),
      ),
    );
  }

  Widget _buildClientHeaderCard(Map<String, dynamic> client) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StitchTheme.border),
        boxShadow: [
          BoxShadow(
            color: StitchTheme.textMain.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: StitchTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              size: 32,
              color: StitchTheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client['name'] ?? '—',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (client['company'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${client['company']}',
                      style: const TextStyle(color: StitchTheme.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: StitchTheme.border),
          boxShadow: [
            BoxShadow(
              color: StitchTheme.textMain.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: StitchTheme.textMain,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  bool _hasText(dynamic v) {
    if (v == null) return false;
    final s = '$v'.trim();
    return s.isNotEmpty;
  }

  String _displayStr(dynamic v) {
    if (v == null) return '—';
    final s = '$v'.trim();
    return s.isEmpty ? '—' : s;
  }

  String _nestedName(dynamic obj) {
    if (obj is Map && obj['name'] != null) return _displayStr(obj['name']);
    return '—';
  }

  String _formatMoney(dynamic v) {
    if (v == null) return '—';
    final num? n = v is num ? v : num.tryParse('$v');
    if (n == null) return '$v đ';
    final raw = n.round().abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buf.write('.');
      buf.write(raw[i]);
    }
    final prefix = n < 0 ? '-' : '';
    return '$prefix${buf.toString()} đ';
  }

  String _formatBool(dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Có' : 'Chưa';
    final s = '$v'.toLowerCase();
    if (s == '1' || s == 'true') return 'Có';
    if (s == '0' || s == 'false') return 'Chưa';
    return _displayStr(v);
  }

  Widget _buildStaffRow(String label, Map<String, dynamic>? staff) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: StitchTheme.textMuted),
          ),
        ),
        Expanded(child: _staffChip(staff?['name'] ?? '—')),
      ],
    );
  }

  Widget _staffChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: StitchTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: StitchTheme.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: StitchTheme.textMuted),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(color: StitchTheme.textMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationCard(
    Map<String, dynamic> rotation,
    List<dynamic> history,
    Map permissions,
  ) {
    final bool eligible = rotation['eligible_for_auto_rotation'] == true;
    final bool warningDue = rotation['warning_due'] == true;
    final bool inScope = rotation['in_scope'] == true;
    final Color statusColor =
        eligible
            ? StitchTheme.danger
            : warningDue
            ? const Color(0xFFF59E0B)
            : inScope
            ? StitchTheme.success
            : StitchTheme.textMuted;
    final String statusLabel =
        (rotation['status_label'] ?? 'Chưa có trạng thái').toString();
    final String protectingLabel =
        (rotation['trigger_label'] ?? rotation['protecting_label'] ?? '')
            .toString()
            .trim();
    final Map thresholds =
        rotation['thresholds'] is Map
            ? rotation['thresholds'] as Map
            : <String, dynamic>{};

    return _buildSectionCard('Theo dõi xoay khách hàng', <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  statusLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (protectingLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      protectingLabel,
                      style: const TextStyle(
                        color: StitchTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              eligible
                  ? 'Đến hạn xoay'
                  : warningDue
                  ? 'Sắp đến hạn'
                  : inScope
                  ? 'Đang theo dõi'
                  : 'Ngoài phạm vi',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: <Widget>[
          Expanded(
            child: _buildRotationMetric(
              'Bình luận / ghi chú',
              '${rotation['days_since_comment'] ?? '—'} ngày',
              'Mốc: ${thresholds['comment_stale_days'] ?? '—'} ngày • từ ${_formatDate(rotation['effective_comment_at']?.toString())}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildRotationMetric(
              'Cơ hội mới',
              '${rotation['days_since_opportunity'] ?? '—'} ngày',
              'Mốc: ${thresholds['opportunity_stale_days'] ?? '—'} ngày • từ ${_formatDate(rotation['effective_opportunity_at']?.toString())}',
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: <Widget>[
          Expanded(
            child: _buildRotationMetric(
              'Hợp đồng mới',
              '${rotation['days_since_contract'] ?? '—'} ngày',
              'Mốc: ${thresholds['contract_stale_days'] ?? '—'} ngày • từ ${_formatDate(rotation['effective_contract_at']?.toString())}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildRotationMetric(
              'Mốc reset chung',
              eligible
                  ? 'Đã đủ điều kiện'
                  : '${rotation['days_until_rotation'] ?? 0} ngày',
              'Mốc đếm: ${_formatDate(rotation['rotation_anchor_at']?.toString())}',
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: StitchTheme.border),
        ),
        child: Text(
          [
            (rotation['rotation_anchor_label'] ?? '').toString().trim(),
            'Ưu tiên điều chuyển: ${(rotation['priority_label'] ?? _priorityLabel(rotation['priority_bucket'])).toString().trim()}.',
            (rotation['priority_rule_label'] ?? '').toString().trim(),
            'Nhịp nhắc: chăm sóc còn 2 ngày nhắc mỗi ngày, cơ hội còn 14 ngày nhắc mỗi 3 ngày, hợp đồng còn 45 ngày nhắc mỗi 7 ngày.',
            'Giới hạn nhận/ngày: ${thresholds['daily_receive_limit'] ?? '—'}.',
          ].where((String value) => value.isNotEmpty).join(' '),
          style: const TextStyle(color: Color(0xFF475569), height: 1.45),
        ),
      ),
      if (permissions['can_view_rotation_history'] == true) ...<Widget>[
        const SizedBox(height: 16),
        const Text(
          'Lịch sử điều chuyển',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (history.isEmpty)
          const Text(
            'Khách hàng này chưa có lịch sử điều chuyển.',
            style: TextStyle(color: StitchTheme.textMuted),
          )
        else
          ...history.take(8).map((dynamic row) {
            return _buildRotationHistoryItem(
              Map<String, dynamic>.from(row as Map),
            );
          }),
      ],
    ]);
  }

  Widget _buildRotationMetric(String title, String value, String note) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationHistoryItem(Map<String, dynamic> row) {
    final String fromName =
        ((row['from_staff'] as Map?)?['name'] ?? 'Chưa rõ').toString();
    final String toName =
        ((row['to_staff'] as Map?)?['name'] ?? 'Chưa rõ').toString();
    final String actionLabel =
        (row['action_label'] ?? 'Điều chuyển').toString();
    final String note = (row['note'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('$fromName → $toName', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            _formatDate(row['transferred_at']?.toString()),
            style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
          ),
          if (note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              note,
              style: const TextStyle(
                fontSize: 12,
                color: StitchTheme.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _priorityLabel(dynamic bucket) {
    switch ('$bucket') {
      case 'contract':
        return 'Nhóm khách đã có hợp đồng';
      case 'opportunity':
        return 'Nhóm khách đã có cơ hội';
      default:
        return 'Khách tiềm năng thuần';
    }
  }

  Widget _buildCareNoteItem(Map<String, dynamic> note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  note['title'] ?? 'Ghi chú',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _formatDate(note['created_at']),
                style: const TextStyle(
                  fontSize: 11,
                  color: StitchTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note['detail'] ?? '',
            style: const TextStyle(fontSize: 13, color: StitchTheme.textMain),
          ),
          if (note['user'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 12,
                  color: StitchTheme.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  note['user']['name'] ?? '—',
                  style: const TextStyle(
                    fontSize: 11,
                    color: StitchTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpportunityItem(Map<String, dynamic> opp) {
    final int oppId = int.tryParse('${opp['id'] ?? 0}') ?? 0;
    final bool canManageOpportunity =
        ((data?['permissions'] as Map?)?['can_manage_client'] == true);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: ListTile(
        onTap:
            oppId > 0
                ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => OpportunityDetailScreen(
                            token: widget.token,
                            apiService: widget.apiService,
                            opportunityId: oppId,
                            canManage: canManageOpportunity,
                            canDelete: false,
                          ),
                    ),
                  );
                }
                : null,
        title: Text(
          opp['title'] ?? 'Cơ hội',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${opp['amount'] ?? 0} VNĐ • XS: ${opp['success_probability'] ?? 0}%',
        ),
        trailing: () {
          final String code = (opp['computed_status'] ?? '').toString();
          final String label =
              (opp['computed_status_label'] ?? opp['computed_status'] ?? '—')
                  .toString();
          final Color chipColor = _computedStatusColor(code);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: chipColor,
              ),
            ),
          );
        }(),
      ),
    );
  }

  Widget _buildContractItem(Map<String, dynamic> contract) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => ContractsScreen(
                    token: widget.token,
                    apiService: widget.apiService,
                    canManage: false,
                    canCreate: false,
                    canDelete: false,
                    canApprove: false,
                    canCreateContractFinanceLines: false,
                    canEditContractFinanceLines: false,
                    currentUserRole: '',
                    currentUserId: widget.currentUserId,
                    // Ideally, pass a filter for this client
                  ),
            ),
          );
        },
        title: Text(
          contract['title'] ?? 'Hợp đồng',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Số: ${contract['code'] ?? '—'} • ${contract['value'] ?? 0} VNĐ',
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: StitchTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildProjectItem(Map<String, dynamic> project) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: ListTile(
        title: Text(
          project['name'] ?? 'Dự án',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (project['progress_percent'] ?? 0) / 100,
                  backgroundColor: StitchTheme.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    StitchTheme.progressPercentFillColor(
                      ((project['progress_percent'] ?? 0) as num).round(),
                    ),
                  ),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${project['progress_percent'] ?? 0}%',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: StitchTheme.textMuted,
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

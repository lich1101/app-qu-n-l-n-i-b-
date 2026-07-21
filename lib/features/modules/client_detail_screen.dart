import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/api_role_access.dart';
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
    this.currentUserRole,
  });

  final String token;
  final MobileApiService apiService;
  final int clientId;
  final int? currentUserId;
  final String? currentUserRole;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  bool loading = true;
  Map<String, dynamic>? data;
  final TextEditingController commentTitleCtrl = TextEditingController();
  final TextEditingController commentDetailCtrl = TextEditingController();
  bool submittingComment = false;
  String deletingCommentId = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    commentTitleCtrl.dispose();
    commentDetailCtrl.dispose();
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

  Future<void> _submitComment() async {
    if (commentTitleCtrl.text.trim().isEmpty ||
        commentDetailCtrl.text.trim().isEmpty) {
      AppTagMessage.show('Vui lòng nhập đầy đủ tiêu đề và nội dung bình luận.');
      return;
    }

    setState(() => submittingComment = true);
    final bool ok = await widget.apiService.storeClientComment(
      widget.token,
      widget.clientId,
      title: commentTitleCtrl.text.trim(),
      detail: commentDetailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => submittingComment = false);
    if (ok) {
      commentTitleCtrl.clear();
      commentDetailCtrl.clear();
      AppTagMessage.show('Đã thêm bình luận.');
      _fetch();
      return;
    }

    AppTagMessage.show('Không thể thêm bình luận.', isError: true);
  }

  Future<void> _deleteComment(String commentId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa bình luận'),
          content: const Text('Bạn có chắc muốn xóa bình luận này không?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => deletingCommentId = commentId);
    final bool ok = await widget.apiService.deleteClientComment(
      widget.token,
      widget.clientId,
      commentId,
    );

    if (!mounted) return;
    setState(() => deletingCommentId = '');
    if (ok) {
      AppTagMessage.show('Đã xóa bình luận.');
      _fetch();
      return;
    }

    AppTagMessage.show('Không thể xóa bình luận.', isError: true);
  }

  Future<void> _copyPhoneNumber(dynamic phone) async {
    final String value = '$phone'.trim();
    if (value.isEmpty) {
      AppTagMessage.show('Khách hàng chưa có số điện thoại.', isError: true);
      return;
    }

    await Clipboard.setData(ClipboardData(text: value));
    AppTagMessage.show('Đã copy số điện thoại.');
  }

  Future<void> _showCommentFullSheet({
    required String title,
    required String detail,
    required String authorMeta,
    required String createdAt,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: StitchTheme.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: StitchTheme.textMain,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          if (authorMeta.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              authorMeta,
                              style: const TextStyle(
                                fontSize: 13,
                                color: StitchTheme.textMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            createdAt,
                            style: const TextStyle(
                              fontSize: 12,
                              color: StitchTheme.textSubtle,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: StitchTheme.border),
                            ),
                            child: SelectableText(
                              detail,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: StitchTheme.textMain,
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
    final commentsHistory = _normalizedComments(
      (data!['comments_history'] as List? ?? []),
    );
    final permissions = data!['permissions'] as Map? ?? {};
    final rotation = data!['client_rotation'] as Map? ?? <String, dynamic>{};
    final rotationHistory = (data!['rotation_history'] as List? ?? []);

    return Scaffold(
      backgroundColor: StitchTheme.surfaceAlt,
      appBar: AppBar(
        title: Text(client['name'] ?? 'Chi tiết khách hàng'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildClientHeaderCard(client),
            const SizedBox(height: 16),
            _buildCommentsSection(commentsHistory, permissions),
            const SizedBox(height: 16),
            _buildSectionCard('Liên hệ', [
              _buildInfoRow(
                Icons.phone_iphone_rounded,
                'Điện thoại',
                _displayStr(client['phone']),
                onTap:
                    _hasText(client['phone'])
                        ? () => _copyPhoneNumber(client['phone'])
                        : null,
              ),
              _buildInfoRow(
                Icons.alternate_email_rounded,
                'Email',
                _displayStr(client['email']),
              ),
            ], icon: Icons.contact_phone_rounded),
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
            ], icon: Icons.hub_rounded),
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
            ], icon: Icons.apartment_rounded),
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
            ], icon: Icons.account_balance_wallet_rounded),
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
              ], icon: Icons.sticky_note_2_outlined),
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
            ], icon: Icons.groups_rounded),
            if (rotation.isNotEmpty)
              _buildRotationCard(
                Map<String, dynamic>.from(rotation),
                rotationHistory,
                permissions,
              ),
            if (careNotes.isNotEmpty) ...[
              _buildSectionTitle('Ghi chú chăm sóc'),
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
            const SizedBox(height: 24),
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
          fontWeight: FontWeight.w500,
          color: StitchTheme.textMain,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _normalizedComments(List<dynamic> rawRows) {
    final List<Map<String, dynamic>> rows =
        rawRows
            .whereType<Map>()
            .map(
              (Map row) => Map<String, dynamic>.from(
                row.map((key, value) => MapEntry('$key', value)),
              ),
            )
            .where(
              (Map<String, dynamic> row) =>
                  _hasText(row['detail']) || _hasText(row['title']),
            )
            .toList();

    rows.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int timeA =
          DateTime.tryParse(
            '${a['created_at'] ?? ''}',
          )?.millisecondsSinceEpoch ??
          0;
      final int timeB =
          DateTime.tryParse(
            '${b['created_at'] ?? ''}',
          )?.millisecondsSinceEpoch ??
          0;
      if (timeA != timeB) return timeA.compareTo(timeB);
      return '${a['id'] ?? ''}'.compareTo('${b['id'] ?? ''}');
    });

    return rows;
  }

  Widget _buildClientHeaderCard(Map<String, dynamic> client) {
    final bool inRotationPool = client['is_in_rotation_pool'] == true;
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
                    fontWeight: FontWeight.w500,
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _buildHeaderChip(
                      Icons.phone_rounded,
                      _displayStr(client['phone']),
                      onTap:
                          _hasText(client['phone'])
                              ? () => _copyPhoneNumber(client['phone'])
                              : null,
                    ),
                    _buildHeaderChip(
                      Icons.label_outline_rounded,
                      _nestedName(client['lead_type']),
                    ),
                    _buildHeaderChip(
                      Icons.flag_outlined,
                      _displayStr(client['customer_status_label']),
                    ),
                    if (inRotationPool)
                      _buildHeaderChip(
                        Icons.inventory_2_outlined,
                        'Đang ở kho số',
                        accent: const Color(0xFFF59E0B),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(
    IconData icon,
    String label, {
    Color? accent,
    VoidCallback? onTap,
  }) {
    final Color chipAccent = accent ?? StitchTheme.primary;
    final Widget child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipAccent.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: chipAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: chipAccent,
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: 6),
            Icon(Icons.copy_rounded, size: 13, color: chipAccent),
          ],
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    List<Widget> children, {
    IconData? icon,
  }) {
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
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: StitchTheme.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: StitchTheme.primaryStrong,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: StitchTheme.textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection(
    List<Map<String, dynamic>> commentsHistory,
    Map permissions,
  ) {
    final bool canAddComment = permissions['can_add_comment'] == true;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: StitchTheme.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: StitchTheme.primaryStrong,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Bình luận nội bộ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: StitchTheme.textMain,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lịch sử trao đổi nội bộ để theo dõi chăm sóc khách hàng.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: StitchTheme.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: StitchTheme.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${commentsHistory.length} bình luận',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: StitchTheme.primaryStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (canAddComment) _buildCommentComposer(),
          if (canAddComment) const SizedBox(height: 16),
          if (commentsHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                children: const <Widget>[
                  Icon(
                    Icons.forum_outlined,
                    size: 24,
                    color: StitchTheme.textSubtle,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Chưa có bình luận nào',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: StitchTheme.textMain,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Thêm bình luận đầu tiên để lưu lịch sử phối hợp nội bộ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: StitchTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            ...commentsHistory.map(
              (Map<String, dynamic> note) => _buildCommentItem(note),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Thêm bình luận mới',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: StitchTheme.textMain,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ghi ngắn gọn, rõ hành động và kết quả để người sau nắm bối cảnh nhanh.',
            style: TextStyle(
              fontSize: 12.5,
              color: StitchTheme.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: commentTitleCtrl,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Tiêu đề bình luận',
              hintText: 'Ví dụ: Cập nhật sau buổi gọi sáng nay',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentDetailCtrl,
            maxLines: 5,
            minLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nội dung',
              hintText:
                  'Nhập nội dung bình luận, vấn đề cần follow-up hoặc người chịu trách nhiệm...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${commentDetailCtrl.text.trim().length} ký tự',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: StitchTheme.textSubtle,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    submittingComment
                        ? null
                        : () {
                          commentTitleCtrl.clear();
                          commentDetailCtrl.clear();
                          setState(() {});
                        },
                child: const Text('Xóa nội dung'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: submittingComment ? null : _submitComment,
                icon:
                    submittingComment
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  submittingComment ? 'Đang gửi...' : 'Gửi bình luận',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> note) {
    final Map<String, dynamic>? user =
        note['user'] is Map
            ? Map<String, dynamic>.from(note['user'] as Map)
            : null;
    final bool canDelete = note['can_delete'] == true;
    final String commentId = '${note['id'] ?? ''}';
    final bool deleting = deletingCommentId == commentId;
    final String title = _displayStr(note['title']);
    final String detail = _displayStr(note['detail']);
    final String authorMeta = [
      _displayStr(user?['name']),
      if (_hasText(user?['email'])) _displayStr(user?['email']),
    ].join(' • ');
    final String createdAt = _formatDate(note['created_at']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.border),
        boxShadow: [
          BoxShadow(
            color: StitchTheme.textMain.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: StitchTheme.primarySoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: StitchTheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _userInitials(user),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: StitchTheme.primaryStrong,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: StitchTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authorMeta,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StitchTheme.border),
                    ),
                    child: Text(
                      createdAt,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ),
                  if (canDelete) ...<Widget>[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: deleting ? null : () => _deleteComment(commentId),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: StitchTheme.dangerSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          deleting ? 'Đang xóa...' : 'Xóa',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: StitchTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText(
                  detail,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: StitchTheme.textMain,
                  ),
                ),
                if (detail != '—') ...<Widget>[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          () => _showCommentFullSheet(
                            title: title,
                            detail: detail,
                            authorMeta: authorMeta,
                            createdAt: createdAt,
                          ),
                      icon: const Icon(Icons.open_in_full_rounded, size: 16),
                      label: const Text('Mở full'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _userInitials(Map<String, dynamic>? user) {
    final String source = '${user?['name'] ?? user?['email'] ?? 'NS'}'.trim();
    if (source.isEmpty) return 'NS';
    final List<String> parts = source.split(RegExp(r'\s+'));
    return parts
        .where((String part) => part.isNotEmpty)
        .map((String part) => part.substring(0, 1).toUpperCase())
        .take(2)
        .join();
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
          fontWeight: FontWeight.w500,
          color: StitchTheme.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final Widget row = Padding(
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
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: onTap != null ? StitchTheme.primaryStrong : null,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: 8),
            Icon(
              Icons.copy_rounded,
              size: 16,
              color: StitchTheme.primaryStrong,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: row,
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
    final bool hasCommentActivity = rotation['comment_has_activity'] == true;
    final bool hasOpportunityActivity =
        rotation['opportunity_has_activity'] == true;
    final bool hasContractActivity = rotation['contract_has_activity'] == true;

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
                    fontWeight: FontWeight.w500,
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
                fontWeight: FontWeight.w500,
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
              hasCommentActivity
                  ? '${rotation['days_since_comment'] ?? 0} ngày'
                  : 'Chưa có',
              hasCommentActivity
                  ? 'Mốc: ${thresholds['comment_stale_days'] ?? '—'} ngày • từ ${_formatDate(rotation['effective_comment_at']?.toString())}'
                  : 'Fallback: ${thresholds['comment_stale_days'] ?? '—'} ngày • theo mốc reset ${_formatDate(rotation['rotation_anchor_at']?.toString())}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildRotationMetric(
              'Cơ hội mới',
              hasOpportunityActivity
                  ? '${rotation['days_since_opportunity'] ?? 0} ngày'
                  : 'Chưa có',
              hasOpportunityActivity
                  ? 'Mốc: ${thresholds['opportunity_stale_days'] ?? '—'} ngày • từ ${_formatDate(rotation['effective_opportunity_at']?.toString())}'
                  : 'Mốc: ${thresholds['opportunity_stale_days'] ?? '—'} ngày • chưa có cơ hội để gia hạn',
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
              hasContractActivity
                  ? '${rotation['days_since_contract'] ?? 0} ngày'
                  : 'Chưa có',
              hasContractActivity
                  ? 'Mốc: ${thresholds['contract_stale_days'] ?? '—'} ngày • từ ${_formatDate(rotation['effective_contract_at']?.toString())}'
                  : 'Mốc: ${thresholds['contract_stale_days'] ?? '—'} ngày • chưa có hợp đồng để gia hạn',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildRotationMetric(
              'Còn tới khi vào diện xoay',
              eligible
                  ? 'Đã đủ điều kiện'
                  : '${rotation['days_until_rotation'] ?? 0} ngày',
              'Mốc đang giữ: ${(rotation['active_rule_label'] ?? 'Mốc reset / tạo khách').toString()} • còn ${rotation['active_stage_remaining_days'] ?? 0} ngày • ngày xoay ${_formatDate(rotation['projected_rotation_at']?.toString())}',
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
            'Mốc đang giữ ngày xoay: ${(rotation['active_rule_label'] ?? 'Mốc reset / tạo khách').toString().trim()}.',
            'Ưu tiên điều chuyển: ${(rotation['priority_label'] ?? _priorityLabel(rotation['priority_bucket'])).toString().trim()}.',
            (rotation['priority_rule_label'] ?? '').toString().trim(),
            'Nhịp nhắc: chăm sóc còn 2 ngày nhắc mỗi ngày, cơ hội còn 14 ngày nhắc mỗi 3 ngày, hợp đồng còn 45 ngày nhắc mỗi 7 ngày.',
            'Giới hạn cron/ngày: ${thresholds['daily_receive_limit'] ?? '—'}.',
            'Giới hạn nhận kho số/ngày: ${thresholds['pool_claim_daily_limit'] ?? '—'}.',
          ].where((String value) => value.isNotEmpty).join(' '),
          style: const TextStyle(color: Color(0xFF475569), height: 1.45),
        ),
      ),
      if (permissions['can_view_rotation_history'] == true) ...<Widget>[
        const SizedBox(height: 16),
        const Text(
          'Lịch sử điều chuyển',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
            style: const TextStyle(fontWeight: FontWeight.w500),
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
                  style: const TextStyle(fontWeight: FontWeight.w500),
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                fontWeight: FontWeight.w500,
                color: chipColor,
              ),
            ),
          );
        }(),
      ),
    );
  }

  Widget _buildContractItem(Map<String, dynamic> contract) {
    final int contractId = int.tryParse('${contract['id'] ?? 0}') ?? 0;
    final String role = (widget.currentUserRole ?? '').toLowerCase();
    final bool canViewContract = apiRoleMatches(role, kApiContractReadCreate);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: ListTile(
        onTap:
            canViewContract && contractId > 0
                ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => ContractsScreen(
                            token: widget.token,
                            apiService: widget.apiService,
                            canManage: apiRoleMatches(
                              role,
                              kApiContractUpdateDelete,
                            ),
                            canCreate: canViewContract,
                            canDelete: false,
                            canApprove: apiRoleMatches(
                              role,
                              kApiContractApprove,
                            ),
                            canCreateContractFinanceLines: apiRoleMatches(
                              role,
                              kApiContractPaymentLineCreate,
                            ),
                            canEditContractFinanceLines: apiRoleMatches(
                              role,
                              kApiContractPaymentLineMutate,
                            ),
                            currentUserRole: role,
                            currentUserId: widget.currentUserId,
                            initialContractId: contractId,
                          ),
                    ),
                  );
                }
                : null,
        title: Text(
          contract['title'] ?? 'Hợp đồng',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Số: ${contract['code'] ?? '—'} • ${contract['value'] ?? 0} VNĐ',
        ),
        trailing:
            canViewContract && contractId > 0
                ? const Icon(
                  Icons.chevron_right_rounded,
                  color: StitchTheme.textMuted,
                )
                : null,
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

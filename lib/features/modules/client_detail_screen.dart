import 'package:flutter/material.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';
import 'contracts_screen.dart';
import 'chat_screen.dart';

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
    final result = await widget.apiService.getClientFlow(widget.token, widget.clientId);
    if (mounted) {
      setState(() {
        data = result;
        loading = false;
      });
    }
  }

  Future<void> _addCareNote() async {
    if (noteTitleCtrl.text.trim().isEmpty || noteDetailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ tiêu đề và nội dung.')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể thêm ghi chú chăm sóc.')),
        );
      }
    }
  }

  void _showAddNoteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thêm ghi chú chăm sóc',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      child: savingNote
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

    return Scaffold(
      backgroundColor: StitchTheme.surfaceAlt,
      appBar: AppBar(
        title: Text(client['name'] ?? 'Chi tiết khách hàng'),
        elevation: 0,
      ),
      floatingActionButton: permissions['can_add_care_note'] == true
          ? FloatingActionButton.extended(
              onPressed: _showAddNoteSheet,
              backgroundColor: StitchTheme.primary,
              icon: const Icon(Icons.edit_note, color: Colors.white),
              label: const Text('Chăm sóc', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(client),
            const SizedBox(height: 16),
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

  Widget _buildInfoCard(Map<String, dynamic> client) {
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
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: StitchTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, size: 32, color: StitchTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client['name'] ?? '—',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (client['company'] != null)
                      Text(
                        client['company'],
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildInfoRow(Icons.phone_iphone_rounded, 'Điện thoại', client['phone'] ?? '—'),
          _buildInfoRow(Icons.alternate_email_rounded, 'Email', client['email'] ?? '—'),
          _buildInfoRow(Icons.campaign_rounded, 'Nguồn', client['lead_source'] ?? '—'),
          _buildInfoRow(Icons.payments_rounded, 'Doanh thu', 
            client['total_revenue'] != null ? '${client['total_revenue']} VNĐ' : '0 VNĐ'),
          const Divider(height: 32),
          _buildStaffInfo('Phụ trách:', client['assigned_staff']),
          const SizedBox(height: 8),
          _buildStaffInfo('Người sở hữu:', client['sales_owner']),
        ],
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
          Text('$label: ', style: const TextStyle(color: StitchTheme.textMuted)),
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

  Widget _buildStaffInfo(String label, Map<String, dynamic>? staff) {
    if (staff == null) return const SizedBox.shrink();
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: StitchTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            staff['name'] ?? '—',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StitchTheme.primary),
          ),
        ),
      ],
    );
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
                style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted),
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
                const Icon(Icons.person_outline, size: 12, color: StitchTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  note['user']['name'] ?? '—',
                  style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpportunityItem(Map<String, dynamic> opp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: ListTile(
        title: Text(opp['title'] ?? 'Cơ hội', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text('${opp['amount'] ?? 0} VNĐ • XS: ${opp['success_probability'] ?? 0}%'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getColorFromHex(opp['statusConfig']?['color_hex'] ?? '#CCCCCC').withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            opp['statusConfig']?['name'] ?? '—',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _getColorFromHex(opp['statusConfig']?['color_hex'] ?? '#666666'),
            ),
          ),
        ),
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
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ContractsScreen(
              token: widget.token,
              apiService: widget.apiService,
              canManage: false,
              canCreate: false,
              canDelete: false,
              canApprove: false,
              currentUserRole: '',
              currentUserId: widget.currentUserId,
              // Ideally, pass a filter for this client
            ),
          ));
        },
        title: Text(contract['title'] ?? 'Hợp đồng', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text('Số: ${contract['code'] ?? '—'} • ${contract['value'] ?? 0} VNĐ'),
        trailing: const Icon(Icons.chevron_right_rounded, color: StitchTheme.textMuted),
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
        title: Text(project['name'] ?? 'Dự án', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (project['progress_percent'] ?? 0) / 100,
                  backgroundColor: StitchTheme.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(StitchTheme.primary),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${project['progress_percent'] ?? 0}%', style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: StitchTheme.textMuted),
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

  Color _getColorFromHex(String hex) {
    try {
      if (hex.startsWith('#')) hex = hex.substring(1);
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

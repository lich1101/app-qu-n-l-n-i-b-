import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/staff_multi_filter_row.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';
import 'opportunity_detail_screen.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
    this.canDelete = false,
  });

  final String token;
  final MobileApiService apiService;
  final bool canManage;
  final bool canDelete;

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  bool loading = false;
  String message = '';
  String search = '';
  String? selectedStatus;
  List<Map<String, dynamic>> opportunities = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> statuses = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
  List<int> staffFilterIds = <int>[];
  List<Map<String, dynamic>> staffLookupUsers = <Map<String, dynamic>>[];
  
  int currentPage = 1;
  int lastPage = 1;
  int totalOpportunities = 0;
  bool loadingMore = false;
  final ScrollController scrollController = ScrollController();

  /// Tổng doanh số (amount) theo bộ lọc, mọi trang.
  double aggregateRevenueTotal = 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    _loadStaffLookup();
    _fetch();
  }

  Future<void> _loadStaffLookup() async {
    final List<Map<String, dynamic>> rows =
        await widget.apiService.getUsersLookup(widget.token);
    if (!mounted) return;
    setState(() => staffLookupUsers = rows);
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
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      currentPage = 1;
    });
    final List<Map<String, dynamic>> statusRows =
        await widget.apiService.getOpportunityStatuses(widget.token);
    
    final Map<String, dynamic> oppPayload =
        await widget.apiService.getOpportunities(
      widget.token,
      page: 1,
      perPage: 20,
      search: search,
      status: selectedStatus,
      staffIds: staffFilterIds.isEmpty ? null : staffFilterIds,
    );
    
    final Map<String, dynamic> clientPayload =
        await widget.apiService.getClients(widget.token, perPage: 100);
    
    if (!mounted) return;
    
    final List<dynamic> oppData = (oppPayload['data'] ?? []) as List<dynamic>;
    final List<dynamic> clientData = (clientPayload['data'] ?? []) as List<dynamic>;

    _applyOpportunityAggregates(oppPayload['aggregates']);

    setState(() {
      loading = false;
      statuses = statusRows;
      opportunities = oppData.map((e) => e as Map<String, dynamic>).toList();
      clients = clientData.map((e) => e as Map<String, dynamic>).toList();
      lastPage = (oppPayload['last_page'] ?? 1) as int;
      totalOpportunities = (oppPayload['total'] ?? 0) as int;
    });
  }

  void _applyOpportunityAggregates(dynamic raw) {
    if (raw is! Map) {
      aggregateRevenueTotal = 0;
      return;
    }
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    final dynamic v = m['revenue_total'];
    if (v == null) {
      aggregateRevenueTotal = 0;
      return;
    }
    aggregateRevenueTotal =
        v is num ? v.toDouble() : (double.tryParse(v.toString()) ?? 0);
  }

  Future<void> _fetchMore() async {
    if (loadingMore || currentPage >= lastPage) return;
    setState(() => loadingMore = true);

    final int nextPage = currentPage + 1;
    final Map<String, dynamic> payload = await widget.apiService.getOpportunities(
      widget.token,
      page: nextPage,
      perPage: 20,
      search: search,
      status: selectedStatus,
      staffIds: staffFilterIds.isEmpty ? null : staffFilterIds,
    );

    if (mounted) {
      final List<dynamic> newData = (payload['data'] ?? []) as List<dynamic>;
      _applyOpportunityAggregates(payload['aggregates']);
      setState(() {
        loadingMore = false;
        opportunities.addAll(newData.map((e) => e as Map<String, dynamic>).toList());
        currentPage = nextPage;
        lastPage = (payload['last_page'] ?? 1) as int;
        totalOpportunities = (payload['total'] ?? 0) as int;
      });
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '—';
    final double v =
        value is double ? value : double.tryParse(value.toString()) ?? 0;
    if (v == 0) return '—';
    return _formatVndDigits(v);
  }

  /// Luôn hiển thị số (kể cả 0) — dùng cho dòng tổng theo bộ lọc.
  String _formatVndDigits(double v) {
    final String s = v.toStringAsFixed(0);
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) sb.write('.');
      sb.write(s[i]);
    }
    return '$sbđ';
  }

  Future<void> _delete(int id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa cơ hội này?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final bool ok =
        await widget.apiService.deleteOpportunity(widget.token, id);
    if (!mounted) return;
    setState(() => message = ok ? 'Đã xóa.' : 'Xóa thất bại.');
    if (ok) await _fetch();
  }

  Future<void> _openForm({Map<String, dynamic>? opp}) async {
    final TextEditingController titleCtrl = TextEditingController(
      text: opp != null ? (opp['title'] ?? '').toString() : '',
    );
    final TextEditingController amountCtrl = TextEditingController(
      text:
          opp != null && opp['amount'] != null
              ? opp['amount'].toString()
              : '',
    );
    final TextEditingController notesCtrl = TextEditingController(
      text: opp != null ? (opp['notes'] ?? '').toString() : '',
    );
    final TextEditingController sourceCtrl = TextEditingController(
      text: opp != null ? (opp['source'] ?? '').toString() : '',
    );
    int? clientId = opp?['client_id'] as int?;
    String? status = opp?['status']?.toString();
    String sheetMessage = '';
    int? successProbability = opp == null
        ? null
        : int.tryParse(opp['success_probability']?.toString() ?? '');
    if (successProbability != null &&
        (successProbability < 0 || successProbability > 100)) {
      successProbability = null;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: StitchTheme.surface,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: StitchTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                            Text(opp == null ? 'Tạo Cơ Hội Mới' : 'Cập Nhật Cơ Hội', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: StitchTheme.border)),
                            child: Column(
                              children: [
                                TextField(
                                  controller: titleCtrl,
                                  decoration: const InputDecoration(labelText: 'Tên cơ hội *', prefixIcon: Icon(Icons.stars_outlined, size: 20, color: StitchTheme.textMuted)),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  value: clientId,
                                  decoration: const InputDecoration(labelText: 'Khách hàng *', prefixIcon: Icon(Icons.business_center_outlined, size: 20, color: StitchTheme.textMuted)),
                                  items: clients.map((c) => DropdownMenuItem<int>(
                                    value: c['id'] as int,
                                    child: Text('${c['name'] ?? ''}${(c['company'] ?? '').toString().isNotEmpty ? ' — ${c['company']}' : ''}', overflow: TextOverflow.ellipsis),
                                  )).toList(),
                                  onChanged: (v) => setSheetState(() => clientId = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: StitchTheme.border)),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: status,
                                  decoration: const InputDecoration(labelText: 'Trạng thái', prefixIcon: Icon(Icons.flag_outlined, size: 20, color: StitchTheme.textMuted)),
                                  items: statuses.map((s) => DropdownMenuItem<String>(
                                    value: (s['code'] ?? '').toString(),
                                    child: Text((s['name'] ?? '').toString()),
                                  )).toList(),
                                  onChanged: (v) => setSheetState(() => status = v),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: amountCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Doanh số dự kiến (VNĐ) *', prefixIcon: Icon(Icons.attach_money, size: 20, color: StitchTheme.textMuted)),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  value: successProbability,
                                  decoration: const InputDecoration(labelText: 'Tỷ lệ thành công (%) *', prefixIcon: Icon(Icons.percent_outlined, size: 20, color: StitchTheme.textMuted)),
                                  items: <int>[0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
                                      .map(
                                        (int v) => DropdownMenuItem<int>(
                                          value: v,
                                          child: Text('$v%'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (int? v) => setSheetState(() => successProbability = v),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: sourceCtrl,
                                  decoration: const InputDecoration(labelText: 'Nguồn', prefixIcon: Icon(Icons.language, size: 20, color: StitchTheme.textMuted)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: StitchTheme.border)),
                            child: TextField(
                              controller: notesCtrl,
                              decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.notes, size: 20, color: StitchTheme.textMuted)),
                              maxLines: 3,
                            ),
                          ),
                          if (sheetMessage.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(sheetMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
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
                    child: Row(
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
                              if (titleCtrl.text.trim().isEmpty ||
                                  clientId == null) {
                                setSheetState(() {
                                  sheetMessage =
                                      'Vui lòng nhập tên và chọn khách hàng.';
                                });
                                return;
                              }
                              final double? amt = amountCtrl.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(amountCtrl.text.trim());
                              if (amt == null || amt < 0) {
                                setSheetState(() {
                                  sheetMessage =
                                      'Vui lòng nhập doanh số dự kiến (số ≥ 0).';
                                });
                                return;
                              }
                              if (successProbability == null) {
                                setSheetState(() {
                                  sheetMessage =
                                      'Vui lòng chọn tỷ lệ thành công.';
                                });
                                return;
                              }
                              final bool ok;
                              if (opp == null) {
                                ok = await widget.apiService.createOpportunity(
                                  widget.token,
                                  title: titleCtrl.text.trim(),
                                  clientId: clientId!,
                                  amount: amt,
                                  successProbability: successProbability!,
                                  status: status,
                                  source: sourceCtrl.text.trim().isEmpty
                                      ? null
                                      : sourceCtrl.text.trim(),
                                  notes: notesCtrl.text.trim().isEmpty
                                      ? null
                                      : notesCtrl.text.trim(),
                                );
                              } else {
                                ok = await widget.apiService.updateOpportunity(
                                  widget.token,
                                  opp['id'] as int,
                                  title: titleCtrl.text.trim(),
                                  clientId: clientId!,
                                  amount: amt,
                                  successProbability: successProbability!,
                                  status: status,
                                  source: sourceCtrl.text.trim().isEmpty
                                      ? null
                                      : sourceCtrl.text.trim(),
                                  notes: notesCtrl.text.trim().isEmpty
                                      ? null
                                      : notesCtrl.text.trim(),
                                );
                              }
                              if (!mounted || !context.mounted) return;
                              if (ok) {
                                Navigator.of(context).pop();
                                await _fetch();
                                setState(
                                  () => message = opp == null
                                      ? 'Đã tạo cơ hội mới.'
                                      : 'Đã cập nhật cơ hội.',
                                );
                              } else {
                                setSheetState(
                                  () => sheetMessage = 'Lưu thất bại.',
                                );
                              }
                            },
                            child: Text(
                              opp == null ? 'Tạo mới' : 'Cập nhật',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
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
    titleCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
    sourceCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cơ hội bán hàng'),
        actions: <Widget>[
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              StitchFilterCard(
                title: 'Bộ lọc cơ hội',
                subtitle: 'Tìm và lọc cơ hội bán hàng theo trạng thái.',
                trailing: null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    StitchFilterField(
                      label: 'Từ khóa',
                      hint: 'Tìm theo tên cơ hội hoặc khách hàng',
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Tìm kiếm...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (String value) => search = value,
                        onSubmitted: (_) => _fetch(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Đang hiển thị ${opportunities.length} trên tổng số $totalOpportunities cơ hội.',
                      style: const TextStyle(
                        color: StitchTheme.textMuted,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StitchFilterField(
                      label: 'Trạng thái',
                      child: DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          hintText: 'Tất cả',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          ...statuses.map(
                            (s) => DropdownMenuItem<String>(
                              value: (s['code'] ?? '').toString(),
                              child: Text((s['name'] ?? '').toString()),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => selectedStatus = value);
                          _fetch();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    StaffMultiFilterRow(
                      users: staffLookupUsers,
                      selectedIds: staffFilterIds,
                      title: 'Nhân sự (phụ trách / chăm sóc KH)',
                      onChanged: (List<int> ids) {
                        setState(() => staffFilterIds = ids);
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: loading ? null : _fetch,
                        icon: const Icon(Icons.filter_alt_outlined, size: 18),
                        label: const Text('Áp dụng lọc nhân sự & tìm kiếm'),
                      ),
                    ),
                  ],
                ),
              ),
              if (message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    message,
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                ),
              if (!loading && totalOpportunities > 0) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: StitchTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.summarize_outlined,
                        size: 18,
                        color: StitchTheme.textSubtle,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tổng doanh số theo bộ lọc (tất cả trang): ${_formatVndDigits(aggregateRevenueTotal)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: StitchTheme.textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (opportunities.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Chưa có cơ hội nào.',
                      style: TextStyle(color: StitchTheme.textMuted),
                    ),
                  ),
                )
              else
                ...opportunities.map((opp) {
                  final Map<String, dynamic>? client =
                      opp['client'] as Map<String, dynamic>?;
                  final Map<String, dynamic>? statusConfig =
                      opp['status_config'] as Map<String, dynamic>?;
                  final Map<String, dynamic>? assignee =
                      opp['assignee'] as Map<String, dynamic>?;
                  final String statusName =
                      (statusConfig?['name'] ?? opp['status'] ?? '—')
                          .toString();
                  final String colorHex =
                      (statusConfig?['color_hex'] ?? '').toString();
                  Color chipColor = StitchTheme.primary;
                  if (colorHex.length >= 6) {
                    final String hex = colorHex.replaceFirst('#', '');
                    chipColor =
                        Color(int.parse('FF$hex', radix: 16));
                  }

                  return GestureDetector(
                    onTap: () async {
                      final int id = (opp['id'] as int?) ?? 0;
                      if (id <= 0) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OpportunityDetailScreen(
                            token: widget.token,
                            apiService: widget.apiService,
                            opportunityId: id,
                            canManage: widget.canManage,
                            canDelete: widget.canDelete,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      _fetch();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: StitchTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: StitchTheme.textMain.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: StitchTheme.border),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 6,
                              decoration: BoxDecoration(
                                color: chipColor,
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
                                      Expanded(
                                        child: Text(
                                          (opp['title'] ?? 'Cơ hội').toString(),
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text(statusName, style: TextStyle(color: chipColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                      if (widget.canManage || widget.canDelete)
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 20, color: StitchTheme.textMuted),
                                          padding: EdgeInsets.zero,
                                          offset: const Offset(0, 40),
                                          onSelected: (val) {
                                            if (val == 'edit' && widget.canManage) _openForm(opp: opp);
                                            if (val == 'delete' && widget.canDelete) _delete(opp['id'] as int);
                                          },
                                          itemBuilder: (context) => [
                                            if (widget.canManage) const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 8), Text('Sửa')])),
                                            if (widget.canDelete) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 8), Text('Xóa', style: TextStyle(color: Colors.red))])),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (client != null) ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.business_center_outlined, size: 14, color: StitchTheme.textMuted),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${client['name'] ?? ''}${(client['company'] ?? '').toString().isNotEmpty ? ' — ${client['company']}' : ''}',
                                            style: const TextStyle(color: StitchTheme.textSubtle, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Row(
                                    children: [
                                      const Icon(Icons.attach_money, size: 16, color: StitchTheme.textSubtle),
                                      const SizedBox(width: 4),
                                      Text(_formatCurrency(opp['amount']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      const SizedBox(width: 16),
                                      if (assignee != null) ...[
                                        const Icon(Icons.person_outline, size: 16, color: StitchTheme.textSubtle),
                                        const SizedBox(width: 4),
                                        Text((assignee['name'] ?? '').toString(), style: const TextStyle(color: StitchTheme.textSubtle, fontSize: 13, fontWeight: FontWeight.w600)),
                                      ],
                                    ],
                                  ),
                                  if ((opp['notes'] ?? '').toString().isNotEmpty) ...[
                                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                                    Text((opp['notes'] ?? '').toString(), style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              if (loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (!loadingMore && currentPage >= lastPage && opportunities.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Đã hiển thị toàn bộ cơ hội.',
                      style: TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

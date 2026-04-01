import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> statusRows =
        await widget.apiService.getOpportunityStatuses(widget.token);
    final List<Map<String, dynamic>> oppRows =
        await widget.apiService.getOpportunities(
      widget.token,
      perPage: 100,
      search: search,
      status: selectedStatus,
    );
    final List<Map<String, dynamic>> clientRows =
        await widget.apiService.getClients(widget.token, perPage: 200);
    if (!mounted) return;
    setState(() {
      loading = false;
      statuses = statusRows;
      opportunities = oppRows;
      clients = clientRows;
    });
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '—';
    final double v =
        value is double ? value : double.tryParse(value.toString()) ?? 0;
    if (v == 0) return '—';
    final String s = v.toStringAsFixed(0);
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) sb.write('.');
      sb.write(s[i]);
    }
    return '${sb}đ';
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
                      opp == null ? 'Tạo cơ hội mới' : 'Sửa cơ hội',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tên cơ hội *'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: clientId,
                      decoration: const InputDecoration(
                        labelText: 'Khách hàng *',
                      ),
                      items: clients
                          .map(
                            (c) => DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(
                                '${c['name'] ?? ''}'
                                '${(c['company'] ?? '').toString().isNotEmpty ? ' — ${c['company']}' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSheetState(() => clientId = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration:
                          const InputDecoration(labelText: 'Trạng thái'),
                      items: statuses
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: (s['code'] ?? '').toString(),
                              child: Text((s['name'] ?? '').toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSheetState(() => status = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá trị (VNĐ)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: sourceCtrl,
                      decoration: const InputDecoration(labelText: 'Nguồn'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                      maxLines: 2,
                    ),
                    if (sheetMessage.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        sheetMessage,
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                    ],
                    const SizedBox(height: 14),
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
                              final bool ok;
                              if (opp == null) {
                                ok = await widget.apiService.createOpportunity(
                                  widget.token,
                                  title: titleCtrl.text.trim(),
                                  clientId: clientId!,
                                  status: status,
                                  amount: amt,
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
                                  status: status,
                                  amount: amt,
                                  source: sourceCtrl.text.trim().isEmpty
                                      ? null
                                      : sourceCtrl.text.trim(),
                                  notes: notesCtrl.text.trim().isEmpty
                                      ? null
                                      : notesCtrl.text.trim(),
                                );
                              }
                              if (!mounted) return;
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
                            ),
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
                        onChanged: (value) {
                          search = value;
                          _fetch();
                        },
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

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  (opp['title'] ?? 'Cơ hội').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: chipColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusName,
                                  style: TextStyle(
                                    color: chipColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (client != null)
                            Text(
                              '${client['name'] ?? ''}${(client['company'] ?? '').toString().isNotEmpty ? ' — ${client['company']}' : ''}',
                              style: const TextStyle(
                                color: StitchTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.attach_money,
                                size: 16,
                                color: StitchTheme.textMuted,
                              ),
                              Text(
                                _formatCurrency(opp['amount']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              if (assignee != null) ...<Widget>[
                                const Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: StitchTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (assignee['name'] ?? '').toString(),
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if ((opp['notes'] ?? '').toString().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              (opp['notes'] ?? '').toString(),
                              style: const TextStyle(
                                color: StitchTheme.textMuted,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (widget.canManage || widget.canDelete) ...<Widget>[
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                if (widget.canManage)
                                  TextButton.icon(
                                    onPressed: () => _openForm(opp: opp),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Sửa'),
                                  ),
                                if (widget.canDelete)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _delete(opp['id'] as int),
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

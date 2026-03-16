import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
  });

  final String token;
  final MobileApiService apiService;
  final bool canManage;

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  bool loading = false;
  String message = '';
  String search = '';
  int? selectedLeadTypeId;
  List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> leadTypes = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> types =
        await widget.apiService.getLeadTypes(widget.token);
    final List<Map<String, dynamic>> rows = await widget.apiService.getClients(
      widget.token,
      perPage: 200,
      leadOnly: true,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      leadTypes = types;
      clients = rows;
    });
  }

  Future<void> _updateLeadType(
    Map<String, dynamic> client,
    int leadTypeId,
  ) async {
    if (!widget.canManage) return;
    final bool ok = await widget.apiService.updateClient(
      widget.token,
      (client['id'] ?? 0) as int,
      name: (client['name'] ?? '').toString(),
      company: (client['company'] ?? '').toString().isEmpty
          ? null
          : (client['company'] ?? '').toString(),
      email: (client['email'] ?? '').toString().isEmpty
          ? null
          : (client['email'] ?? '').toString(),
      phone: (client['phone'] ?? '').toString().isEmpty
          ? null
          : (client['phone'] ?? '').toString(),
      notes: (client['notes'] ?? '').toString().isEmpty
          ? null
          : (client['notes'] ?? '').toString(),
      leadTypeId: leadTypeId,
      leadSource: (client['lead_source'] ?? '').toString().isEmpty
          ? null
          : (client['lead_source'] ?? '').toString(),
      leadChannel: (client['lead_channel'] ?? '').toString().isEmpty
          ? null
          : (client['lead_channel'] ?? '').toString(),
      leadMessage: (client['lead_message'] ?? '').toString().isEmpty
          ? null
          : (client['lead_message'] ?? '').toString(),
      salesOwnerId: client['sales_owner_id'] as int?,
    );
    if (!mounted) return;
    setState(() {
      message = ok ? 'Đã cập nhật trạng thái.' : 'Cập nhật thất bại.';
    });
    if (ok) await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filtered = clients.where((client) {
      if (selectedLeadTypeId != null &&
          (client['lead_type_id'] ?? 0) != selectedLeadTypeId) {
        return false;
      }
      if (search.trim().isEmpty) return true;
      final String keyword = search.trim().toLowerCase();
      return (client['name'] ?? '').toString().toLowerCase().contains(keyword) ||
          (client['company'] ?? '').toString().toLowerCase().contains(keyword) ||
          (client['email'] ?? '').toString().toLowerCase().contains(keyword);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cơ hội bán hàng'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Phễu khách hàng',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tìm kiếm khách hàng',
                    ),
                    onChanged: (value) => setState(() => search = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedLeadTypeId,
                    decoration:
                        const InputDecoration(
                            labelText: 'Trạng thái khách hàng tiềm năng'),
                    items: <DropdownMenuItem<int>>[
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Tất cả trạng thái'),
                      ),
                      ...leadTypes.map(
                        (type) => DropdownMenuItem<int>(
                          value: type['id'] as int,
                          child: Text((type['name'] ?? '').toString()),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => selectedLeadTypeId = value);
                    },
                  ),
                  if (message.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(message, style: const TextStyle(color: StitchTheme.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else ...filtered.map((client) {
              final Map<String, dynamic>? leadType =
                  client['lead_type'] as Map<String, dynamic>?;
              final Map<String, dynamic>? tier =
                  client['revenue_tier'] as Map<String, dynamic>?;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        (client['name'] ?? 'Khách hàng').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if ((client['company'] ?? '').toString().isNotEmpty)
                        Text(
                          (client['company'] ?? '').toString(),
                          style: const TextStyle(color: StitchTheme.textMuted),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          if (leadType != null)
                            Chip(
                              label: Text((leadType['name'] ?? '').toString()),
                            ),
                          if (tier != null)
                            Chip(
                              label: Text((tier['label'] ?? '').toString()),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (client['lead_message'] ?? 'Chưa có ghi chú')
                            .toString(),
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                      if (widget.canManage) ...<Widget>[
                        const Divider(height: 24),
                        DropdownButtonFormField<int>(
                          value: client['lead_type_id'] as int?,
                          decoration: const InputDecoration(
                            labelText: 'Cập nhật trạng thái',
                          ),
                          items: leadTypes
                              .map(
                                (type) => DropdownMenuItem<int>(
                                  value: type['id'] as int,
                                  child: Text((type['name'] ?? '').toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _updateLeadType(client, value);
                          },
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
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class RevenueTiersScreen extends StatefulWidget {
  const RevenueTiersScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<RevenueTiersScreen> createState() => _RevenueTiersScreenState();
}

class _RevenueTiersScreenState extends State<RevenueTiersScreen> {
  bool loading = false;
  String message = '';
  List<Map<String, dynamic>> tiers = <Map<String, dynamic>>[];
  int? editingId;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController labelCtrl = TextEditingController();
  final TextEditingController colorCtrl = TextEditingController(text: '#9CA3AF');
  final TextEditingController minCtrl = TextEditingController(text: '0');
  final TextEditingController orderCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    labelCtrl.dispose();
    colorCtrl.dispose();
    minCtrl.dispose();
    orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> rows =
        await widget.apiService.getRevenueTiers(widget.token);
    if (!mounted) return;
    setState(() {
      loading = false;
      tiers = rows;
    });
  }

  void _resetForm() {
    editingId = null;
    nameCtrl.clear();
    labelCtrl.clear();
    colorCtrl.text = '#9CA3AF';
    minCtrl.text = '0';
    orderCtrl.text = '1';
  }

  Future<bool> _save() async {
    if (nameCtrl.text.trim().isEmpty || labelCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập tên và nhãn.');
      return false;
    }
    final double? minAmount = double.tryParse(minCtrl.text.trim());
    final int? order = int.tryParse(orderCtrl.text.trim());
    final bool ok = editingId == null
        ? await widget.apiService.createRevenueTier(
            widget.token,
            name: nameCtrl.text.trim(),
            label: labelCtrl.text.trim(),
            colorHex: colorCtrl.text.trim(),
            minAmount: minAmount,
            sortOrder: order,
          )
        : await widget.apiService.updateRevenueTier(
            widget.token,
            editingId!,
            name: nameCtrl.text.trim(),
            label: labelCtrl.text.trim(),
            colorHex: colorCtrl.text.trim(),
            minAmount: minAmount,
            sortOrder: order,
          );
    if (!mounted) return false;
    setState(() => message = ok ? 'Đã lưu hạng.' : 'Lưu hạng thất bại.');
    if (ok) {
      _resetForm();
      await _fetch();
    }
    return ok;
  }

  Future<void> _delete(int id) async {
    final bool ok = await widget.apiService.deleteRevenueTier(widget.token, id);
    if (!mounted) return;
    setState(() => message = ok ? 'Đã xóa hạng.' : 'Xóa hạng thất bại.');
    if (ok) await _fetch();
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    setState(() {
      message = '';
      if (item == null) {
        _resetForm();
      } else {
        editingId = item['id'] as int;
        nameCtrl.text = (item['name'] ?? '').toString();
        labelCtrl.text = (item['label'] ?? '').toString();
        colorCtrl.text = (item['color_hex'] ?? '#9CA3AF').toString();
        minCtrl.text = (item['min_amount'] ?? 0).toString();
        orderCtrl.text = (item['sort_order'] ?? 0).toString();
      }
    });

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
                      editingId == null ? 'Tạo hạng' : 'Sửa hạng',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tên hệ thống'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: labelCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nhãn hiển thị'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: colorCtrl,
                      decoration: const InputDecoration(labelText: 'Màu (hex)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: minCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Mốc doanh thu'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: orderCtrl,
                      decoration: const InputDecoration(labelText: 'Thứ tự'),
                      keyboardType: TextInputType.number,
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
                              final bool ok = await _save();
                              if (!mounted) return;
                              if (ok) {
                                Navigator.of(context).pop();
                              } else {
                                setSheetState(() {});
                              }
                            },
                            child: Text(editingId == null ? 'Tạo mới' : 'Cập nhật'),
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
    if (!mounted) return;
    setState(() => _resetForm());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hạng doanh thu'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Danh sách hạng doanh thu',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm mới'),
                ),
              ],
            ),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message,
                    style: const TextStyle(color: StitchTheme.textMuted)),
              ),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else ...tiers.map((item) {
              return Card(
                child: ListTile(
                  title: Text((item['label'] ?? '').toString()),
                  subtitle: Text(
                    '≥ ${(item['min_amount'] ?? 0).toString()}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _openForm(item: item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () => _delete(item['id'] as int),
                      ),
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

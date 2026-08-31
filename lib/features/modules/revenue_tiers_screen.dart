import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_widgets.dart';
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
  final TextEditingController colorCtrl = TextEditingController(
    text: '#9CA3AF',
  );
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
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getRevenueTiers(widget.token);
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
    final bool ok =
        editingId == null
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

  bool get _messageIsError =>
      message.contains('thất bại') ||
      message.startsWith('Vui lòng') ||
      message.contains('không');

  Color _hexColor(dynamic value) {
    final String raw =
        (value ?? '').toString().trim().replaceFirst('#', '').toUpperCase();
    if (raw.length != 6) return StitchTheme.warningStrong;
    final int? parsed = int.tryParse('FF$raw', radix: 16);
    return parsed == null ? StitchTheme.warningStrong : Color(parsed);
  }

  String _formatMoney(dynamic value) {
    final double amount = double.tryParse((value ?? 0).toString()) ?? 0;
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)} tỷ';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} triệu';
    }
    return amount.toStringAsFixed(0);
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
              decoration: stitchFormSheetSurfaceDecoration(),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    StitchFormSheetTitleBar(
                      title: editingId == null ? 'Tạo hạng' : 'Sửa hạng',
                      subtitle:
                          'Cấu hình mốc doanh thu để phân hạng khách hàng hoặc nhân sự.',
                      icon: Icons.workspace_premium_rounded,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Column(
                        children: <Widget>[
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tên hệ thống',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: labelCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nhãn hiển thị',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: colorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Màu (hex)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: minCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Mốc doanh thu',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: orderCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Thứ tự',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          if (message.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            StitchFeedbackBanner(
                              message: message,
                              isError: _messageIsError,
                            ),
                          ],
                        ],
                      ),
                    ),
                    StitchFormSheetActions(
                      primaryLabel: editingId == null ? 'Tạo mới' : 'Cập nhật',
                      onPrimary: () async {
                        final bool ok = await _save();
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.of(context).pop();
                        } else {
                          setSheetState(() {});
                        }
                      },
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
      appBar: AppBar(title: const Text('Hạng doanh thu')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              StitchAdminHeader(
                title: 'Danh sách hạng doanh thu',
                subtitle:
                    'Thiết lập mốc phân hạng, nhãn hiển thị và màu badge cho báo cáo doanh thu.',
                icon: Icons.workspace_premium_rounded,
                actionLabel: 'Thêm mới',
                onAction: () => _openForm(),
              ),
              if (message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: StitchFeedbackBanner(
                    message: message,
                    isError: _messageIsError,
                  ),
                ),
              const SizedBox(height: 14),
              if (loading)
                const StitchLoadingState(label: 'Đang tải hạng doanh thu...')
              else if (tiers.isEmpty)
                const StitchEmptyState(
                  title: 'Chưa có hạng doanh thu',
                  subtitle:
                      'Tạo hạng đầu tiên để hệ thống phân nhóm doanh thu rõ ràng hơn.',
                  icon: Icons.workspace_premium_outlined,
                )
              else
                ...tiers.map((item) {
                  return StitchAdminListItem(
                    title: (item['label'] ?? '').toString(),
                    subtitle:
                        'Tên hệ thống: ${(item['name'] ?? '').toString()}',
                    meta: <String>[
                      'Từ ${_formatMoney(item['min_amount'])}',
                      'Thứ tự ${item['sort_order'] ?? '—'}',
                    ],
                    icon: Icons.workspace_premium_rounded,
                    accent: _hexColor(item['color_hex']),
                    trailing: Wrap(
                      spacing: 2,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Sửa',
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          onPressed: () => _openForm(item: item),
                        ),
                        IconButton(
                          tooltip: 'Xóa',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          onPressed: () => _delete(item['id'] as int),
                        ),
                      ],
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

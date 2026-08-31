import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class LeadTypesScreen extends StatefulWidget {
  const LeadTypesScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<LeadTypesScreen> createState() => _LeadTypesScreenState();
}

class _LeadTypesScreenState extends State<LeadTypesScreen> {
  bool loading = false;
  String message = '';
  List<Map<String, dynamic>> leadTypes = <Map<String, dynamic>>[];
  int? editingId;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController colorCtrl = TextEditingController(
    text: '#4B5563',
  );
  final TextEditingController orderCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    colorCtrl.dispose();
    orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getLeadTypes(widget.token);
    if (!mounted) return;
    setState(() {
      loading = false;
      leadTypes = rows;
    });
  }

  void _resetForm() {
    editingId = null;
    nameCtrl.clear();
    colorCtrl.text = '#4B5563';
    orderCtrl.text = '1';
  }

  Future<bool> _save() async {
    if (nameCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập tên trạng thái.');
      return false;
    }
    final int? order = int.tryParse(orderCtrl.text.trim());
    final bool ok =
        editingId == null
            ? await widget.apiService.createLeadType(
              widget.token,
              name: nameCtrl.text.trim(),
              colorHex: colorCtrl.text.trim(),
              sortOrder: order,
            )
            : await widget.apiService.updateLeadType(
              widget.token,
              editingId!,
              name: nameCtrl.text.trim(),
              colorHex: colorCtrl.text.trim(),
              sortOrder: order,
            );
    if (!mounted) return false;
    setState(() => message = ok ? 'Đã lưu trạng thái.' : 'Lưu thất bại.');
    if (ok) {
      _resetForm();
      await _fetch();
    }
    return ok;
  }

  Future<void> _delete(int id) async {
    final bool ok = await widget.apiService.deleteLeadType(widget.token, id);
    if (!mounted) return;
    setState(() => message = ok ? 'Đã xóa trạng thái.' : 'Xóa thất bại.');
    if (ok) await _fetch();
  }

  bool get _messageIsError =>
      message.contains('thất bại') ||
      message.startsWith('Vui lòng') ||
      message.contains('không');

  Color _hexColor(dynamic value) {
    final String raw =
        (value ?? '').toString().trim().replaceFirst('#', '').toUpperCase();
    if (raw.length != 6) return StitchTheme.primaryStrong;
    final int? parsed = int.tryParse('FF$raw', radix: 16);
    return parsed == null ? StitchTheme.primaryStrong : Color(parsed);
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    setState(() {
      message = '';
      if (item == null) {
        _resetForm();
      } else {
        editingId = item['id'] as int;
        nameCtrl.text = (item['name'] ?? '').toString();
        colorCtrl.text = (item['color_hex'] ?? '#4B5563').toString();
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
                      title:
                          editingId == null
                              ? 'Tạo trạng thái'
                              : 'Sửa trạng thái',
                      subtitle:
                          'Dùng để phân loại khách hàng tiềm năng trên CRM.',
                      icon: Icons.flag_rounded,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Column(
                        children: <Widget>[
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tên trạng thái',
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
      appBar: AppBar(title: const Text('Trạng thái khách hàng tiềm năng')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              StitchAdminHeader(
                title: 'Danh sách trạng thái',
                subtitle:
                    'Quản lý các nhãn phân loại khách hàng tiềm năng, màu sắc và thứ tự hiển thị.',
                icon: Icons.flag_rounded,
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
                const StitchLoadingState(label: 'Đang tải trạng thái...')
              else if (leadTypes.isEmpty)
                const StitchEmptyState(
                  title: 'Chưa có trạng thái',
                  subtitle: 'Tạo trạng thái đầu tiên để CRM dễ phân loại lead.',
                  icon: Icons.flag_outlined,
                )
              else
                ...leadTypes.map((item) {
                  return StitchAdminListItem(
                    title: (item['name'] ?? '').toString(),
                    subtitle: 'Màu ${(item['color_hex'] ?? '').toString()}',
                    meta: <String>['Thứ tự ${item['sort_order'] ?? '—'}'],
                    icon: Icons.flag_rounded,
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

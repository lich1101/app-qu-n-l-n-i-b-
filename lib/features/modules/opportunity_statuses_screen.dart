import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class OpportunityStatusesScreen extends StatefulWidget {
  const OpportunityStatusesScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<OpportunityStatusesScreen> createState() =>
      _OpportunityStatusesScreenState();
}

class _OpportunityStatusesScreenState extends State<OpportunityStatusesScreen> {
  bool loading = false;
  String message = '';
  List<Map<String, dynamic>> statuses = <Map<String, dynamic>>[];
  int? editingId;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController colorCtrl = TextEditingController(
    text: '#0EA5A6',
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
        .getOpportunityStatuses(widget.token);
    if (!mounted) return;
    setState(() {
      loading = false;
      statuses = rows;
    });
  }

  void _resetForm() {
    editingId = null;
    nameCtrl.clear();
    colorCtrl.text = '#0EA5A6';
    orderCtrl.text = '1';
  }

  Future<bool> _save() async {
    if (nameCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập tên trạng thái cơ hội.');
      return false;
    }
    final int? order = int.tryParse(orderCtrl.text.trim());
    final bool ok =
        editingId == null
            ? await widget.apiService.createOpportunityStatus(
              widget.token,
              name: nameCtrl.text.trim(),
              colorHex: colorCtrl.text.trim(),
              sortOrder: order,
            )
            : await widget.apiService.updateOpportunityStatus(
              widget.token,
              editingId!,
              name: nameCtrl.text.trim(),
              colorHex: colorCtrl.text.trim(),
              sortOrder: order,
            );
    if (!mounted) return false;
    setState(
      () => message = ok ? 'Đã lưu trạng thái cơ hội.' : 'Lưu thất bại.',
    );
    if (ok) {
      _resetForm();
      await _fetch();
    }
    return ok;
  }

  Future<void> _delete(int id) async {
    final bool ok = await widget.apiService.deleteOpportunityStatus(
      widget.token,
      id,
    );
    if (!mounted) return;
    setState(
      () => message = ok ? 'Đã xóa trạng thái cơ hội.' : 'Xóa thất bại.',
    );
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
        colorCtrl.text = (item['color_hex'] ?? '#0EA5A6').toString();
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
                              ? 'Tạo trạng thái cơ hội'
                              : 'Sửa trạng thái cơ hội',
                      subtitle:
                          'Dùng để chuẩn hóa pipeline bán hàng và màu sắc kanban.',
                      icon: Icons.timeline_rounded,
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
      appBar: AppBar(
        title: const Text('Trạng thái cơ hội'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.add), onPressed: () => _openForm()),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              StitchAdminHeader(
                title: 'Danh sách trạng thái cơ hội',
                subtitle:
                    'Sắp xếp pipeline cơ hội bán hàng, màu badge và thứ tự hiển thị.',
                icon: Icons.timeline_rounded,
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
                const StitchLoadingState(label: 'Đang tải trạng thái cơ hội...')
              else if (statuses.isEmpty)
                const StitchEmptyState(
                  title: 'Chưa có trạng thái cơ hội',
                  subtitle:
                      'Tạo trạng thái để pipeline cơ hội rõ ràng và dễ theo dõi.',
                  icon: Icons.timeline_outlined,
                )
              else
                ...statuses.map((item) {
                  return StitchAdminListItem(
                    title: (item['name'] ?? '').toString(),
                    subtitle: 'Màu ${(item['color_hex'] ?? '').toString()}',
                    meta: <String>['Thứ tự ${item['sort_order'] ?? '—'}'],
                    icon: Icons.timeline_rounded,
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

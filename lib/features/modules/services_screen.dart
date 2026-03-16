import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
    required this.canDelete,
  });

  final String token;
  final MobileApiService apiService;
  final bool canManage;
  final bool canDelete;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  static const List<_ServiceOption> fallbackOptions = <_ServiceOption>[
    _ServiceOption('backlinks', 'Backlinks', Icons.link),
    _ServiceOption('viet_content', 'Content', Icons.edit_note),
    _ServiceOption('audit_content', 'Audit Content', Icons.fact_check),
    _ServiceOption('cham_soc_website_tong_the', 'Website Care', Icons.public),
  ];

  List<_ServiceOption> serviceOptions = fallbackOptions;
  String selectedType = fallbackOptions.first.value;
  bool loading = false;
  String message = '';
  int? editingId;
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

  final TextEditingController projectIdCtrl = TextEditingController();
  final TextEditingController taskIdCtrl = TextEditingController();
  final TextEditingController f1Ctrl = TextEditingController();
  final TextEditingController f2Ctrl = TextEditingController();
  final TextEditingController f3Ctrl = TextEditingController();
  final TextEditingController f4Ctrl = TextEditingController();
  final TextEditingController f5Ctrl = TextEditingController();
  final TextEditingController f6Ctrl = TextEditingController();
  final TextEditingController f7Ctrl = TextEditingController();
  final TextEditingController f8Ctrl = TextEditingController();

  String _fmtDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (date == null) return;
    if (!mounted) return;
    setState(() => controller.text = _fmtDate(date));
  }

  String _normalizeType(String type) {
    switch (type) {
      case 'viet_content':
        return 'content';
      case 'audit_content':
        return 'audit';
      case 'cham_soc_website_tong_the':
        return 'website-care';
      default:
        return type;
    }
  }

  String _serviceLabel(String value) {
    switch (value) {
      case 'backlinks':
        return 'Backlinks';
      case 'viet_content':
        return 'Content';
      case 'audit_content':
        return 'Audit Content';
      case 'cham_soc_website_tong_the':
        return 'Website Care';
      case 'khac':
        return 'Khác';
      default:
        return value.replaceAll('_', ' ');
    }
  }

  IconData _serviceIcon(String value) {
    switch (value) {
      case 'backlinks':
        return Icons.link;
      case 'viet_content':
        return Icons.edit_note;
      case 'audit_content':
        return Icons.fact_check;
      case 'cham_soc_website_tong_the':
        return Icons.public;
      case 'khac':
        return Icons.more_horiz;
      default:
        return Icons.work_outline;
    }
  }

  bool _isDateField(int index) {
    final String resolved = _normalizeType(selectedType);
    if (resolved == 'backlinks' && index == 4) return true;
    if (resolved == 'website-care' && index == 0) return true;
    return false;
  }

  Color _statusColor(String status) {
    final String s = status.toLowerCase();
    if (s.contains('done') || s.contains('paid') || s.contains('hoan_tat')) {
      return const Color(0xFF16A34A);
    }
    if (s.contains('pending') || s.contains('open') || s.contains('cho')) {
      return const Color(0xFFD97706);
    }
    if (s.contains('overdue') || s.contains('cancel') || s.contains('that_bai')) {
      return const Color(0xFFDC2626);
    }
    return StitchTheme.primary;
  }

  String _itemTitle(Map<String, dynamic> item) {
    switch (_normalizeType(selectedType)) {
      case 'backlinks':
        return (item['domain'] ?? item['target_url'] ?? 'Backlink').toString();
      case 'content':
        return (item['main_keyword'] ?? 'Content').toString();
      case 'audit':
        return (item['url'] ?? 'Audit').toString();
      case 'website-care':
        return (item['technical_issue'] ?? 'Website Care').toString();
      default:
        return 'Item';
    }
  }

  String _itemSubtitle(Map<String, dynamic> item) {
    switch (_normalizeType(selectedType)) {
      case 'backlinks':
        return 'Anchor text: ${item['anchor_text'] ?? '-'} • Report: ${item['report_date'] ?? '-'}';
      case 'content':
        return 'Outline: ${item['outline_status'] ?? '-'} • SEO: ${item['seo_score'] ?? '-'}';
      case 'audit':
        return 'Issue: ${item['issue_type'] ?? '-'} • Priority: ${item['priority'] ?? '-'}';
      case 'website-care':
        return 'Check date: ${item['check_date'] ?? '-'} • Index: ${item['index_status'] ?? '-'}';
      default:
        return '';
    }
  }

  String _statusLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'pending':
        return 'Đang chờ';
      case 'live':
        return 'Đã lên';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      case 'open':
        return 'Đang mở';
      case 'done':
        return 'Hoàn tất';
      default:
        return raw;
    }
  }

  String _itemStatus(Map<String, dynamic> item) {
    switch (_normalizeType(selectedType)) {
      case 'backlinks':
        return _statusLabel((item['status'] ?? 'pending').toString());
      case 'content':
        return _statusLabel((item['approval_status'] ?? 'pending').toString());
      case 'audit':
        return _statusLabel((item['status'] ?? 'open').toString());
      case 'website-care':
        return _statusLabel((item['index_status'] ?? 'unknown').toString());
      default:
        return 'Không rõ';
    }
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    projectIdCtrl.dispose();
    taskIdCtrl.dispose();
    f1Ctrl.dispose();
    f2Ctrl.dispose();
    f3Ctrl.dispose();
    f4Ctrl.dispose();
    f5Ctrl.dispose();
    f6Ctrl.dispose();
    f7Ctrl.dispose();
    f8Ctrl.dispose();
    super.dispose();
  }

  void _clearForm() {
    editingId = null;
    projectIdCtrl.clear();
    taskIdCtrl.clear();
    f1Ctrl.clear();
    f2Ctrl.clear();
    f3Ctrl.clear();
    f4Ctrl.clear();
    f5Ctrl.clear();
    f6Ctrl.clear();
    f7Ctrl.clear();
    f8Ctrl.clear();
  }

  Future<void> _bootstrap() async {
    await _loadMeta();
    await _fetch();
  }

  Future<void> _loadMeta() async {
    final Map<String, dynamic> meta = await widget.apiService.getMeta();
    final List<dynamic> services = (meta['service_types'] ?? <dynamic>[]) as List<dynamic>;
    if (services.isEmpty) return;
    final List<_ServiceOption> mapped = services.map((dynamic e) {
      final String value = e.toString();
      return _ServiceOption(value, _serviceLabel(value), _serviceIcon(value));
    }).toList();
    if (!mounted) return;
    setState(() {
      serviceOptions = mapped;
      if (mapped.isNotEmpty && !mapped.any((option) => option.value == selectedType)) {
        selectedType = mapped.first.value;
      }
    });
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> data = await widget.apiService.getServiceItems(
      widget.token,
      selectedType,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      rows = data;
    });
  }

  Map<String, dynamic>? _buildPayload() {
    final int? projectId = int.tryParse(projectIdCtrl.text.trim());
    if (projectId == null) {
      setState(() => message = 'Mã dự án là bắt buộc và phải là số.');
      return null;
    }
    final int? taskId = taskIdCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(taskIdCtrl.text.trim());
    if (taskIdCtrl.text.trim().isNotEmpty && taskId == null) {
      setState(() => message = 'Mã công việc phải là số.');
      return null;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'project_id': projectId,
      'task_id': taskId,
    };

    final String resolved = _normalizeType(selectedType);
    switch (resolved) {
      case 'backlinks':
        payload.addAll(<String, dynamic>{
          'target_url': f1Ctrl.text.trim(),
          'domain': f2Ctrl.text.trim(),
          'anchor_text': f3Ctrl.text.trim(),
          'status': f4Ctrl.text.trim().isEmpty ? 'pending' : f4Ctrl.text.trim(),
          'report_date': f5Ctrl.text.trim().isEmpty ? null : f5Ctrl.text.trim(),
          'note': f6Ctrl.text.trim().isEmpty ? null : f6Ctrl.text.trim(),
        });
        break;
      case 'content':
        payload.addAll(<String, dynamic>{
          'main_keyword': f1Ctrl.text.trim(),
          'secondary_keywords': f2Ctrl.text.trim().isEmpty ? null : f2Ctrl.text.trim(),
          'outline_status': f3Ctrl.text.trim().isEmpty ? 'pending' : f3Ctrl.text.trim(),
          'required_words': f4Ctrl.text.trim().isEmpty ? null : int.tryParse(f4Ctrl.text.trim()),
          'seo_score': f5Ctrl.text.trim().isEmpty ? null : int.tryParse(f5Ctrl.text.trim()),
          'approval_status': f6Ctrl.text.trim().isEmpty ? 'pending' : f6Ctrl.text.trim(),
          'actual_words': f7Ctrl.text.trim().isEmpty ? null : int.tryParse(f7Ctrl.text.trim()),
          'duplicate_percent': f8Ctrl.text.trim().isEmpty ? null : int.tryParse(f8Ctrl.text.trim()),
        });
        break;
      case 'audit':
        payload.addAll(<String, dynamic>{
          'url': f1Ctrl.text.trim(),
          'issue_type': f2Ctrl.text.trim().isEmpty ? null : f2Ctrl.text.trim(),
          'issue_description': f3Ctrl.text.trim().isEmpty ? null : f3Ctrl.text.trim(),
          'suggestion': f4Ctrl.text.trim().isEmpty ? null : f4Ctrl.text.trim(),
          'priority': f5Ctrl.text.trim().isEmpty ? 'medium' : f5Ctrl.text.trim(),
          'status': f6Ctrl.text.trim().isEmpty ? 'open' : f6Ctrl.text.trim(),
        });
        break;
      case 'website-care':
        payload.addAll(<String, dynamic>{
          'check_date': f1Ctrl.text.trim().isEmpty ? null : f1Ctrl.text.trim(),
          'technical_issue': f2Ctrl.text.trim().isEmpty ? null : f2Ctrl.text.trim(),
          'index_status': f3Ctrl.text.trim().isEmpty ? null : f3Ctrl.text.trim(),
          'traffic': f4Ctrl.text.trim().isEmpty ? null : int.tryParse(f4Ctrl.text.trim()),
          'ranking_delta': f5Ctrl.text.trim().isEmpty ? null : int.tryParse(f5Ctrl.text.trim()),
          'monthly_report': f6Ctrl.text.trim().isEmpty ? null : f6Ctrl.text.trim(),
        });
        break;
      default:
        break;
    }
    return payload;
  }

  Future<bool> _save() async {
    if (!widget.canManage) {
      setState(() => message = 'Bạn không có quyền quản lý quy trình dịch vụ.');
      return false;
    }
    final Map<String, dynamic>? payload = _buildPayload();
    if (payload == null) return false;
    final bool ok = editingId == null
        ? await widget.apiService.createServiceItem(widget.token, selectedType, payload)
        : await widget.apiService.updateServiceItem(
            widget.token,
            selectedType,
            editingId!,
            payload,
          );
    if (!mounted) return false;
    setState(() {
      message = ok
          ? (editingId == null
              ? 'Tạo bản ghi thành công.'
              : 'Cập nhật bản ghi thành công.')
          : 'Lưu thất bại.';
      if (ok) _clearForm();
    });
    if (ok) await _fetch();
    return ok;
  }

  Future<void> _delete(int id) async {
    if (!widget.canDelete) {
      setState(() => message = 'Ban khong co quyen xoa ban ghi dich vu.');
      return;
    }
    final bool ok = await widget.apiService.deleteServiceItem(
      widget.token,
      selectedType,
      id,
    );
    if (!mounted) return;
    setState(() {
      message = ok ? 'Xoa thanh cong.' : 'Xoa that bai.';
    });
    if (ok) await _fetch();
  }

  Future<void> _openForm({Map<String, dynamic>? item}) async {
    setState(() {
      message = '';
      if (item == null) {
        _clearForm();
      } else {
        editingId = (item['id'] ?? 0) as int;
        projectIdCtrl.text = (item['project_id'] ?? '').toString();
        taskIdCtrl.text = (item['task_id'] ?? '').toString();
        switch (_normalizeType(selectedType)) {
          case 'backlinks':
            f1Ctrl.text = (item['target_url'] ?? '').toString();
            f2Ctrl.text = (item['domain'] ?? '').toString();
            f3Ctrl.text = (item['anchor_text'] ?? '').toString();
            f4Ctrl.text = (item['status'] ?? '').toString();
            f5Ctrl.text = (item['report_date'] ?? '').toString();
            f6Ctrl.text = (item['note'] ?? '').toString();
            break;
          case 'content':
            f1Ctrl.text = (item['main_keyword'] ?? '').toString();
            f2Ctrl.text = (item['secondary_keywords'] ?? '').toString();
            f3Ctrl.text = (item['outline_status'] ?? '').toString();
            f4Ctrl.text = (item['required_words'] ?? '').toString();
            f5Ctrl.text = (item['seo_score'] ?? '').toString();
            f6Ctrl.text = (item['approval_status'] ?? '').toString();
            f7Ctrl.text = (item['actual_words'] ?? '').toString();
            f8Ctrl.text = (item['duplicate_percent'] ?? '').toString();
            break;
          case 'audit':
            f1Ctrl.text = (item['url'] ?? '').toString();
            f2Ctrl.text = (item['issue_type'] ?? '').toString();
            f3Ctrl.text = (item['issue_description'] ?? '').toString();
            f4Ctrl.text = (item['suggestion'] ?? '').toString();
            f5Ctrl.text = (item['priority'] ?? '').toString();
            f6Ctrl.text = (item['status'] ?? '').toString();
            break;
          case 'website-care':
            f1Ctrl.text = (item['check_date'] ?? '').toString();
            f2Ctrl.text = (item['technical_issue'] ?? '').toString();
            f3Ctrl.text = (item['index_status'] ?? '').toString();
            f4Ctrl.text = (item['traffic'] ?? '').toString();
            f5Ctrl.text = (item['ranking_delta'] ?? '').toString();
            f6Ctrl.text = (item['monthly_report'] ?? '').toString();
            break;
          default:
            break;
        }
      }
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final List<String> labels = _labels();
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      editingId == null ? 'Tạo bản ghi' : 'Cập nhật bản ghi',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: projectIdCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Mã dự án *'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskIdCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Mã công việc (tuỳ chọn)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: f1Ctrl,
                      decoration: InputDecoration(
                        labelText: labels[0],
                        suffixIcon: _isDateField(0)
                            ? IconButton(
                                onPressed: () => _pickDate(f1Ctrl),
                                icon:
                                    const Icon(Icons.calendar_month_outlined),
                              )
                            : null,
                      ),
                      readOnly: _isDateField(0),
                      onTap: _isDateField(0) ? () => _pickDate(f1Ctrl) : null,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: f2Ctrl,
                      decoration: InputDecoration(labelText: labels[1]),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: f3Ctrl,
                      decoration: InputDecoration(labelText: labels[2]),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: f4Ctrl,
                      decoration: InputDecoration(labelText: labels[3]),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: f5Ctrl,
                      decoration: InputDecoration(
                        labelText: labels[4],
                        suffixIcon: _isDateField(4)
                            ? IconButton(
                                onPressed: () => _pickDate(f5Ctrl),
                                icon:
                                    const Icon(Icons.calendar_month_outlined),
                              )
                            : null,
                      ),
                      readOnly: _isDateField(4),
                      onTap: _isDateField(4) ? () => _pickDate(f5Ctrl) : null,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: f6Ctrl,
                      decoration: InputDecoration(labelText: labels[5]),
                    ),
                    if (_normalizeType(selectedType) == 'content') ...<Widget>[
                      const SizedBox(height: 8),
                      TextField(
                        controller: f7Ctrl,
                        decoration:
                            const InputDecoration(labelText: 'Actual words'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: f8Ctrl,
                        decoration:
                            const InputDecoration(labelText: 'Duplicate (%)'),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(message),
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
                            onPressed: widget.canManage
                                ? () async {
                                    final bool ok = await _save();
                                    if (!mounted) return;
                                    if (ok) {
                                      Navigator.of(context).pop();
                                    } else {
                                      setSheetState(() {});
                                    }
                                  }
                                : null,
                            child: Text(
                              editingId == null ? 'Tạo bản ghi' : 'Cập nhật',
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
    if (!mounted) return;
    setState(() => _clearForm());
  }

  List<String> _labels() {
    switch (_normalizeType(selectedType)) {
      case 'backlinks':
        return <String>[
          'Target URL',
          'Domain',
          'Anchor text',
          'Status',
          'Report date (YYYY-MM-DD)',
          'Notes',
        ];
      case 'content':
        return <String>[
          'Main keyword',
          'Secondary keywords',
          'Outline status',
          'Required words',
          'SEO score',
          'Approval status',
        ];
      case 'audit':
        return <String>[
          'URL',
          'Issue type',
          'Issue description',
          'Suggestion',
          'Priority',
          'Status',
        ];
      default:
        return <String>[
          'Check date (YYYY-MM-DD)',
          'Technical issue',
          'Index status',
          'Traffic',
          'Ranking delta',
          'Monthly report',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quy trình dịch vụ'),
        actions: <Widget>[
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const StitchHeroCard(
              title: 'Quy trình dịch vụ',
              subtitle: 'Quản lý quy trình chi tiết theo từng loại dịch vụ.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Loại dịch vụ'),
              items: serviceOptions
                  .map(
                    (_ServiceOption e) => DropdownMenuItem<String>(
                      value: e.value,
                      child: Text(e.label),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  selectedType = value;
                  _clearForm();
                });
                _fetch();
              },
            ),
            const SizedBox(height: 10),
            if (message.isNotEmpty) Text(message),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Danh sách bản ghi ${_serviceLabel(selectedType)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.canManage)
                  ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading) const Center(child: CircularProgressIndicator()),
            ...rows.map(
              (Map<String, dynamic> item) => Card(
                child: ListTile(
                  title: Text(_itemTitle(item)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_itemSubtitle(item)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(_itemStatus(item)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _itemStatus(item),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(_itemStatus(item)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.canManage)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openForm(item: item),
                        ),
                      if (widget.canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _delete((item['id'] ?? 0) as int),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOption {
  const _ServiceOption(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

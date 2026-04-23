import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class LeadFormsScreen extends StatefulWidget {
  const LeadFormsScreen({
    super.key,
    required this.token,
    required this.apiService,
    this.canManage = true,

    /// Mở form chỉnh sửa sau khi tải danh sách (push / thông báo trong app).
    this.initialLeadFormId,
  });

  final String token;
  final MobileApiService apiService;

  /// POST/PUT/DELETE /lead-forms — API: admin
  final bool canManage;
  final int? initialLeadFormId;

  @override
  State<LeadFormsScreen> createState() => _LeadFormsScreenState();
}

class _LeadFormsScreenState extends State<LeadFormsScreen> {
  bool loading = false;
  bool _listRefreshing = false;
  String message = '';
  List<Map<String, dynamic>> forms = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> leadTypes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> departments = <Map<String, dynamic>>[];
  int? editingId;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController slugCtrl = TextEditingController();
  final TextEditingController redirectCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  int? leadTypeId;
  int? departmentId;
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    _fetch().then((_) => _maybeOpenInitialLeadForm());
  }

  Future<void> _maybeOpenInitialLeadForm() async {
    final int? targetId = widget.initialLeadFormId;
    if (!widget.canManage || targetId == null || targetId <= 0) {
      return;
    }
    Map<String, dynamic>? match;
    for (final Map<String, dynamic> row in forms) {
      final int? id = _parseFormId(row['id']);
      if (id == targetId) {
        match = row;
        break;
      }
    }
    if (match == null || !mounted) {
      return;
    }
    await _openForm(form: match);
  }

  int? _parseFormId(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    slugCtrl.dispose();
    redirectCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      if (forms.isEmpty) {
        loading = true;
        _listRefreshing = false;
      } else {
        loading = false;
        _listRefreshing = true;
      }
    });
    try {
      final List<Map<String, dynamic>> formRows = await widget.apiService
          .getLeadForms(widget.token);
      final List<Map<String, dynamic>> types = await widget.apiService
          .getLeadTypes(widget.token);
      final List<Map<String, dynamic>> deptRows = await widget.apiService
          .getDepartments(widget.token);
      if (!mounted) return;
      setState(() {
        loading = false;
        _listRefreshing = false;
        forms = formRows;
        leadTypes = types;
        departments = deptRows;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          _listRefreshing = false;
        });
      }
    }
  }

  void _resetForm() {
    editingId = null;
    nameCtrl.clear();
    slugCtrl.clear();
    redirectCtrl.clear();
    descCtrl.clear();
    leadTypeId = null;
    departmentId = null;
    isActive = true;
  }

  Future<bool> _save() async {
    if (nameCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập tên form.');
      return false;
    }
    final bool ok =
        editingId == null
            ? await widget.apiService.createLeadForm(
              widget.token,
              name: nameCtrl.text.trim(),
              slug: slugCtrl.text.trim().isEmpty ? null : slugCtrl.text.trim(),
              leadTypeId: leadTypeId,
              departmentId: departmentId,
              redirectUrl:
                  redirectCtrl.text.trim().isEmpty
                      ? null
                      : redirectCtrl.text.trim(),
              description:
                  descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              isActive: isActive,
            )
            : await widget.apiService.updateLeadForm(
              widget.token,
              editingId!,
              name: nameCtrl.text.trim(),
              leadTypeId: leadTypeId,
              departmentId: departmentId,
              redirectUrl:
                  redirectCtrl.text.trim().isEmpty
                      ? null
                      : redirectCtrl.text.trim(),
              description:
                  descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              isActive: isActive,
            );
    if (!mounted) return false;
    setState(() => message = ok ? 'Đã lưu form.' : 'Lưu form thất bại.');
    if (ok) {
      _resetForm();
      await _fetch();
    }
    return ok;
  }

  Future<void> _delete(int id) async {
    if (!widget.canManage) return;
    final bool ok = await widget.apiService.deleteLeadForm(widget.token, id);
    if (!mounted) return;
    setState(() => message = ok ? 'Đã xóa form.' : 'Xóa form thất bại.');
    if (ok) await _fetch();
  }

  Future<void> _duplicate(int id) async {
    if (!widget.canManage) return;
    final bool ok = await widget.apiService.duplicateLeadForm(widget.token, id);
    if (!mounted) return;
    setState(
      () => message = ok ? 'Đã sao chép form.' : 'Sao chép form thất bại.',
    );
    if (ok) await _fetch();
  }

  Future<void> _openForm({Map<String, dynamic>? form}) async {
    if (!widget.canManage) return;
    setState(() {
      message = '';
      if (form == null) {
        _resetForm();
      } else {
        editingId = _parseFormId(form['id']);
        nameCtrl.text = (form['name'] ?? '').toString();
        slugCtrl.text = (form['slug'] ?? '').toString();
        redirectCtrl.text = (form['redirect_url'] ?? '').toString();
        descCtrl.text = (form['description'] ?? '').toString();
        leadTypeId = form['lead_type_id'] as int?;
        departmentId = form['department_id'] as int?;
        isActive = (form['is_active'] ?? true) == true;
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
                      editingId == null ? 'Tạo form' : 'Sửa form',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Tên form'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: slugCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Slug (không dấu)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: leadTypeId,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái khách hàng tiềm năng',
                      ),
                      items:
                          leadTypes
                              .map(
                                (type) => DropdownMenuItem<int>(
                                  value: type['id'] as int,
                                  child: Text((type['name'] ?? '').toString()),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setSheetState(() => leadTypeId = value),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: departmentId,
                      decoration: const InputDecoration(
                        labelText: 'Phòng ban nhận khách hàng tiềm năng',
                      ),
                      items:
                          departments
                              .map(
                                (dept) => DropdownMenuItem<int>(
                                  value: dept['id'] as int,
                                  child: Text((dept['name'] ?? '').toString()),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setSheetState(() => departmentId = value),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: redirectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Redirect URL',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Kích hoạt form'),
                      value: isActive,
                      onChanged:
                          (value) => setSheetState(() => isActive = value),
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
                              if (!context.mounted) {
                                return;
                              }
                              if (ok) {
                                Navigator.of(context).pop();
                              } else {
                                setSheetState(() {});
                              }
                            },
                            child: Text(
                              editingId == null ? 'Tạo mới' : 'Cập nhật',
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
    setState(() => _resetForm());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form tư vấn'),
        actions: <Widget>[
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            CupertinoSliverRefreshControl(onRefresh: _fetch),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  if (_listRefreshing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Danh sách form',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (widget.canManage)
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
                      child: Text(
                        message,
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (loading && forms.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    ...forms.map((form) {
                      return Card(
                        child: ListTile(
                          title: Text((form['name'] ?? '').toString()),
                          subtitle: Text(
                            'Slug: ${(form['slug'] ?? '').toString()}',
                          ),
                          trailing:
                              widget.canManage
                                  ? Wrap(
                                    spacing: 4,
                                    children: <Widget>[
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => _openForm(form: form),
                                        tooltip: 'Sửa',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 18),
                                        onPressed:
                                            () => _duplicate(form['id'] as int),
                                        tooltip: 'Sao chép',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 18,
                                        ),
                                        onPressed:
                                            () => _delete(form['id'] as int),
                                        tooltip: 'Xóa',
                                      ),
                                    ],
                                  )
                                  : null,
                        ),
                      );
                    }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

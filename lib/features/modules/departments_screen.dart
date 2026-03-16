import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
  });

  final String token;
  final MobileApiService apiService;
  final bool canManage;

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  bool loading = false;
  String message = '';
  List<Map<String, dynamic>> departments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> users = <Map<String, dynamic>>[];
  int? editingId;
  final TextEditingController nameCtrl = TextEditingController();
  int? managerId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> rows =
        await widget.apiService.getDepartments(widget.token);
    final List<Map<String, dynamic>> userRows =
        await widget.apiService.getUsersAccounts(widget.token);
    if (!mounted) return;
    setState(() {
      loading = false;
      departments = rows;
      users = userRows;
    });
  }

  void _resetForm() {
    editingId = null;
    nameCtrl.clear();
    managerId = null;
  }

  Future<bool> _save() async {
    if (!widget.canManage) {
      setState(() => message = 'Bạn không có quyền quản lý phòng ban.');
      return false;
    }
    if (nameCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập tên phòng ban.');
      return false;
    }
    final bool ok = editingId == null
        ? await widget.apiService.createDepartment(
            widget.token,
            name: nameCtrl.text.trim(),
            managerId: managerId,
          )
        : await widget.apiService.updateDepartment(
            widget.token,
            editingId!,
            name: nameCtrl.text.trim(),
            managerId: managerId,
          );
    if (!mounted) return false;
    setState(() => message = ok ? 'Đã lưu phòng ban.' : 'Lưu phòng ban thất bại.');
    if (ok) {
      _resetForm();
      await _fetch();
    }
    return ok;
  }

  Future<void> _delete(int id) async {
    final bool ok = await widget.apiService.deleteDepartment(widget.token, id);
    if (!mounted) return;
    setState(() => message = ok ? 'Đã xóa phòng ban.' : 'Xóa phòng ban thất bại.');
    if (ok) await _fetch();
  }

  Future<void> _openForm({Map<String, dynamic>? dept}) async {
    setState(() {
      message = '';
      if (dept == null) {
        _resetForm();
      } else {
        editingId = dept['id'] as int;
        nameCtrl.text = (dept['name'] ?? '').toString();
        managerId = dept['manager_id'] as int?;
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
                      editingId == null ? 'Tạo phòng ban' : 'Sửa phòng ban',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tên phòng ban'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: managerId,
                      decoration: const InputDecoration(labelText: 'Quản lý'),
                      items: users
                          .map((user) => DropdownMenuItem<int>(
                                value: user['id'] as int,
                                child:
                                    Text((user['name'] ?? '').toString()),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setSheetState(() => managerId = value),
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
        title: const Text('Phòng ban'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
          if (widget.canManage)
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
                    'Danh sách phòng ban',
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
                child: Text(message,
                    style: const TextStyle(color: StitchTheme.textMuted)),
              ),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else ...departments.map((dept) {
              final List<dynamic> staff =
                  (dept['staff'] ?? <dynamic>[]) as List<dynamic>;
              return Card(
                child: ListTile(
                  title: Text((dept['name'] ?? '').toString()),
                  subtitle: Text(
                    'Quản lý: ${(dept['manager'] ?? const <String, dynamic>{})['name'] ?? '—'} • Nhân sự: ${staff.length}',
                  ),
                  trailing: widget.canManage
                      ? Wrap(
                          spacing: 8,
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _openForm(dept: dept),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () => _delete(dept['id'] as int),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

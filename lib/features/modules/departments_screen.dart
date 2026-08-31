import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_widgets.dart';
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
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getDepartments(widget.token);
    final List<Map<String, dynamic>> userRows = await widget.apiService
        .getUsersAccounts(widget.token);
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
    final bool ok =
        editingId == null
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
    setState(
      () => message = ok ? 'Đã lưu phòng ban.' : 'Lưu phòng ban thất bại.',
    );
    if (ok) {
      _resetForm();
      await _fetch();
    }
    return ok;
  }

  Future<void> _delete(int id) async {
    final bool ok = await widget.apiService.deleteDepartment(widget.token, id);
    if (!mounted) return;
    setState(
      () => message = ok ? 'Đã xóa phòng ban.' : 'Xóa phòng ban thất bại.',
    );
    if (ok) await _fetch();
  }

  bool get _messageIsError =>
      message.contains('thất bại') ||
      message.startsWith('Vui lòng') ||
      message.contains('không');

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
                          editingId == null ? 'Tạo phòng ban' : 'Sửa phòng ban',
                      subtitle:
                          'Gán quản lý phụ trách để phân quyền và tổng hợp dữ liệu theo phòng.',
                      icon: Icons.apartment_rounded,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Column(
                        children: <Widget>[
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tên phòng ban',
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            value: managerId,
                            decoration: const InputDecoration(
                              labelText: 'Quản lý',
                            ),
                            items:
                                users
                                    .map(
                                      (user) => DropdownMenuItem<int>(
                                        value: user['id'] as int,
                                        child: Text(
                                          (user['name'] ?? '').toString(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) =>
                                    setSheetState(() => managerId = value),
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
        title: const Text('Phòng ban'),
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
              StitchAdminHeader(
                title: 'Danh sách phòng ban',
                subtitle:
                    'Quản lý phòng ban, trưởng nhóm và số nhân sự đang thuộc từng đơn vị.',
                icon: Icons.apartment_rounded,
                actionLabel: widget.canManage ? 'Thêm mới' : null,
                onAction: widget.canManage ? () => _openForm() : null,
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
                const StitchLoadingState(label: 'Đang tải phòng ban...')
              else if (departments.isEmpty)
                const StitchEmptyState(
                  title: 'Chưa có phòng ban',
                  subtitle:
                      'Tạo phòng ban để quản lý nhân sự, CRM và báo cáo theo đơn vị.',
                  icon: Icons.apartment_outlined,
                )
              else
                ...departments.map((dept) {
                  final List<dynamic> staff =
                      (dept['staff'] ?? <dynamic>[]) as List<dynamic>;
                  return StitchAdminListItem(
                    title: (dept['name'] ?? '').toString(),
                    subtitle:
                        'Quản lý: ${(dept['manager'] ?? const <String, dynamic>{})['name'] ?? '—'}',
                    meta: <String>['${staff.length} nhân sự'],
                    icon: Icons.apartment_rounded,
                    accent: StitchTheme.primaryStrong,
                    trailing:
                        widget.canManage
                            ? Wrap(
                              spacing: 2,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Sửa',
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () => _openForm(dept: dept),
                                ),
                                IconButton(
                                  tooltip: 'Xóa',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () => _delete(dept['id'] as int),
                                ),
                              ],
                            )
                            : null,
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

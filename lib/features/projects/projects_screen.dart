import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/staff_multi_filter_row.dart';
import '../../data/services/mobile_api_service.dart';
import 'create_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.token,
    required this.apiService,
    this.canView = true,
    this.canCreate = false,
  });

  final String token;
  final MobileApiService apiService;
  final bool canView;
  final bool canCreate;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool loading = true;
  bool actionLoading = false;
  String message = '';
  List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];
  final TextEditingController _searchCtrl = TextEditingController();
  List<int> _ownerFilterIds = <int>[];
  List<Map<String, dynamic>> _ownerLookupUsers = <Map<String, dynamic>>[];
  /// Ban đầu thu gọn; mở rộng để chỉnh lọc (danh sách owner theo phạm vi API users/lookup?purpose=project_owner).
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    if (!widget.canView) {
      loading = false;
      message = 'Bạn không có quyền xem dự án.';
      return;
    }
    _loadOwnerOptions();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerOptions() async {
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getUsersLookup(widget.token, purpose: 'project_owner');
    if (!mounted) return;
    setState(() => _ownerLookupUsers = rows);
  }

  Future<void> _fetch() async {
    if (!widget.canView) return;
    setState(() {
      loading = true;
      message = '';
    });
    final List<Map<String, dynamic>> rows = await widget.apiService.getProjects(
      widget.token,
      perPage: 200,
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      ownerIds: _ownerFilterIds.isEmpty ? null : _ownerFilterIds,
    );
    if (!mounted) return;
    setState(() {
      projects = rows;
      loading = false;
      message = rows.isEmpty ? 'Chưa có dự án nào.' : '';
    });
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'moi_tao':
        return 'Mới tạo';
      case 'dang_trien_khai':
        return 'Đang triển khai';
      case 'cho_duyet':
        return 'Chờ duyệt';
      case 'hoan_thanh':
        return 'Hoàn thành';
      case 'tam_dung':
        return 'Tạm dừng';
      default:
        return value;
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'dang_trien_khai':
        return StitchTheme.primary;
      case 'cho_duyet':
        return const Color(0xFFF59E0B);
      case 'hoan_thanh':
        return const Color(0xFF16A34A);
      case 'tam_dung':
        return const Color(0xFFEF4444);
      case 'moi_tao':
      default:
        return const Color(0xFF64748B);
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
        return value;
    }
  }

  bool _projectPermission(
    Map<String, dynamic> project,
    String key, {
    bool fallback = false,
  }) {
    final dynamic permissions = project['permissions'];
    if (permissions is Map) {
      final dynamic value = permissions[key];
      if (value is bool) return value;
      final String normalized = (value ?? '').toString().toLowerCase();
      if (normalized == '1' || normalized == 'true') return true;
      if (normalized == '0' || normalized == 'false') return false;
    }
    return fallback;
  }

  Future<void> _openEdit(Map<String, dynamic> project) async {
    final int projectId = int.tryParse('${project['id'] ?? 0}') ?? 0;
    if (projectId <= 0) return;
    if (!_projectPermission(project, 'can_edit')) return;

    setState(() {
      actionLoading = true;
      message = '';
    });
    final Map<String, dynamic>? detail = await widget.apiService.getProject(
      widget.token,
      projectId,
    );
    if (!mounted) return;
    setState(() => actionLoading = false);

    await Navigator.of(context).push(
      MaterialPageRoute<Widget>(
        builder:
            (_) => CreateProjectScreen(
              token: widget.token,
              apiService: widget.apiService,
              projectId: projectId,
              initialProject: detail ?? project,
            ),
      ),
    );
    if (!mounted) return;
    await _fetch();
  }

  Future<void> _deleteProject(Map<String, dynamic> project) async {
    final int projectId = int.tryParse('${project['id'] ?? 0}') ?? 0;
    if (projectId <= 0) return;
    if (!_projectPermission(project, 'can_delete')) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa dự án'),
          content: Text(
            'Bạn có chắc muốn xóa dự án "${(project['name'] ?? 'Dự án').toString()}"?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: StitchTheme.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() {
      actionLoading = true;
      message = '';
    });
    final bool ok = await widget.apiService.deleteProject(
      widget.token,
      projectId,
    );
    if (!mounted) return;
    setState(() {
      actionLoading = false;
      message = ok ? 'Đã xóa dự án.' : 'Không thể xóa dự án.';
    });
    if (ok) {
      await _fetch();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Xóa dự án thất bại.')));
  }

  void _openDetail(int projectId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<Widget>(
            builder:
                (_) => ProjectDetailScreen(
                  token: widget.token,
                  apiService: widget.apiService,
                  projectId: projectId,
                ),
          ),
        )
        .then((_) => _fetch());
  }

  int _countProjectsByStatus(String status) {
    return projects
        .where((Map<String, dynamic> project) => project['status'] == status)
        .length;
  }

  Map<String, dynamic>? _linkedContract(Map<String, dynamic> project) {
    final dynamic c = project['contract'];
    if (c is Map<String, dynamic>) {
      return c;
    }
    final dynamic lc = project['linked_contract'];
    if (lc is Map<String, dynamic>) {
      return lc;
    }
    return null;
  }

  String _contractCollectorName(Map<String, dynamic> project) {
    final Map<String, dynamic>? c = _linkedContract(project);
    if (c == null) {
      return '—';
    }
    final dynamic col = c['collector'];
    if (col is Map<String, dynamic>) {
      return (col['name'] ?? col['email'] ?? '—').toString();
    }
    return '—';
  }

  String? _stringField(Map<String, dynamic> project, String key) {
    final dynamic v = project[key];
    if (v is String && v.trim().isNotEmpty) {
      return v.trim();
    }
    return null;
  }

  Future<void> _openExternal(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool ok =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được liên kết.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý dự án'),
      ),
      body: SafeArea(
        child:
            !widget.canView
                ? Center(
                  child: Text(
                    message,
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                )
                : loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: StitchTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap:
                                    () => setState(
                                      () =>
                                          _filtersExpanded = !_filtersExpanded,
                                    ),
                                borderRadius: BorderRadius.circular(18),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.tune,
                                        size: 22,
                                        color: StitchTheme.primaryStrong,
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Bộ lọc dự án',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (_ownerFilterIds.isNotEmpty ||
                                          _searchCtrl.text.trim().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Text(
                                            'đang lọc',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: StitchTheme.primaryStrong,
                                            ),
                                          ),
                                        ),
                                      Icon(
                                        _filtersExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: StitchTheme.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_filtersExpanded) ...<Widget>[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    TextField(
                                      controller: _searchCtrl,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Tên, mã, link repo/website, NV phụ trách HĐ...',
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          size: 20,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        isDense: true,
                                      ),
                                      onSubmitted: (_) => _fetch(),
                                    ),
                                    const SizedBox(height: 12),
                                    StaffMultiFilterRow(
                                      users: _ownerLookupUsers,
                                      selectedIds: _ownerFilterIds,
                                      title: 'Phụ trách dự án (owner)',
                                      onChanged: (List<int> ids) {
                                        setState(() => _ownerFilterIds = ids);
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.icon(
                                        onPressed: loading ? null : _fetch,
                                        icon: const Icon(
                                          Icons.filter_alt_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Áp dụng bộ lọc'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: StitchTheme.border),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: _ProjectSummaryTile(
                                label: 'Tổng dự án',
                                value: projects.length.toString(),
                              ),
                            ),
                            Expanded(
                              child: _ProjectSummaryTile(
                                label: 'Đang triển khai',
                                value:
                                    _countProjectsByStatus(
                                      'dang_trien_khai',
                                    ).toString(),
                                color: StitchTheme.primary,
                              ),
                            ),
                            Expanded(
                              child: _ProjectSummaryTile(
                                label: 'Chờ duyệt',
                                value:
                                    _countProjectsByStatus(
                                      'cho_duyet',
                                    ).toString(),
                                color: StitchTheme.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          style: const TextStyle(color: StitchTheme.textMuted),
                        ),
                      ...projects.map((Map<String, dynamic> project) {
                        final String name =
                            (project['name'] ?? 'Dự án').toString();
                        final String code = (project['code'] ?? '').toString();
                        final String status =
                            (project['status'] ?? '').toString();
                        final String serviceType =
                            (project['service_type'] ?? '').toString();
                        final String serviceOther =
                            (project['service_type_other'] ?? '').toString();
                        final String deadline =
                            (project['deadline'] ?? '').toString();
                        final String ownerName =
                            ((project['owner'] ??
                                        const <String, dynamic>{})['name'] ??
                                    'Chưa phân công')
                                .toString();
                        final String serviceLabel =
                            serviceType == 'khac'
                                ? (serviceOther.isEmpty ? 'Khác' : serviceOther)
                                : _serviceLabel(serviceType);
                        final int projectId =
                            int.tryParse('${project['id'] ?? 0}') ?? 0;
                        final bool canEdit = _projectPermission(
                          project,
                          'can_edit',
                        );
                        final bool canDelete = _projectPermission(
                          project,
                          'can_delete',
                        );
                        final int progress =
                            (project['progress_percent'] ?? 0) is int
                                ? project['progress_percent'] as int
                                : int.tryParse(
                                      '${project['progress_percent'] ?? 0}',
                                    ) ??
                                    0;
                        return InkWell(
                          onTap:
                              projectId > 0
                                  ? () => _openDetail(projectId)
                                  : null,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: StitchTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          status,
                                        ).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _statusColor(
                                            status,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  code.isEmpty
                                      ? serviceLabel
                                      : '$code • $serviceLabel',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tiến độ: $progress%',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0, 100) / 100,
                                    minHeight: 6,
                                    color: _statusColor(status),
                                    backgroundColor: StitchTheme.surfaceAlt,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: StitchTheme.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Phụ trách dự án: $ownerName',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.badge_outlined,
                                      size: 16,
                                      color: StitchTheme.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'NV phụ trách HĐ: ${_contractCollectorName(project)}',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_stringField(project, 'website_url') !=
                                    null) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.language,
                                        size: 16,
                                        color: StitchTheme.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _openExternal(
                                            _stringField(project, 'website_url')!,
                                          ),
                                          child: Text(
                                            _stringField(project, 'website_url')!,
                                            style: TextStyle(
                                              color: StitchTheme.primary,
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (_stringField(project, 'repo_url') !=
                                    null) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.link,
                                        size: 16,
                                        color: StitchTheme.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _openExternal(
                                            _stringField(project, 'repo_url')!,
                                          ),
                                          child: Text(
                                            _stringField(project, 'repo_url')!,
                                            style: TextStyle(
                                              color: StitchTheme.primary,
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (deadline.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.timer_outlined,
                                        size: 16,
                                        color: StitchTheme.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Hạn chót: $deadline',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    TextButton.icon(
                                      onPressed:
                                          projectId > 0
                                              ? () => _openDetail(projectId)
                                              : null,
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      label: const Text('Chi tiết'),
                                    ),
                                    if (canEdit) ...<Widget>[
                                      const SizedBox(width: 6),
                                      TextButton.icon(
                                        onPressed:
                                            actionLoading
                                                ? null
                                                : () => _openEdit(project),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Sửa'),
                                      ),
                                    ],
                                    if (canDelete) ...<Widget>[
                                      const SizedBox(width: 6),
                                      TextButton.icon(
                                        onPressed:
                                            actionLoading
                                                ? null
                                                : () => _deleteProject(project),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Xóa'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: StitchTheme.danger,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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

class _ProjectSummaryTile extends StatelessWidget {
  const _ProjectSummaryTile({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color resolvedColor = color ?? StitchTheme.textMain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: StitchTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: resolvedColor,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';
import 'create_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.token,
    required this.apiService,
    this.canCreate = false,
  });

  final String token;
  final MobileApiService apiService;
  final bool canCreate;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool loading = true;
  String message = '';
  List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      message = '';
    });
    final List<Map<String, dynamic>> rows = await widget.apiService.getProjects(
      widget.token,
      perPage: 200,
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

  void _openCreate() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<Widget>(
            builder:
                (_) => CreateProjectScreen(
                  token: widget.token,
                  apiService: widget.apiService,
                ),
          ),
        )
        .then((_) => _fetch());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý dự án'),
        actions: <Widget>[
          if (widget.canCreate)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _openCreate,
            ),
        ],
      ),
      body: SafeArea(
        child:
            loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: <Widget>[
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
                                        'Phụ trách: $ownerName',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
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
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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

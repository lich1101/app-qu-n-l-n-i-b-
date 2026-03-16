import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';
import 'create_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool loading = true;
  String message = '';
  String _statusFilter = '';
  String _serviceFilter = '';
  String _searchQuery = '';
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
    final List<Map<String, dynamic>> rows =
        await widget.apiService.getProjects(widget.token, perPage: 200);
    if (!mounted) return;
    setState(() {
      projects = rows;
      loading = false;
      message = rows.isEmpty ? 'Chưa có dự án nào.' : '';
    });
  }

  List<Map<String, dynamic>> get _filteredProjects {
    final String keyword = _searchQuery.trim().toLowerCase();
    return projects.where((Map<String, dynamic> project) {
      final String status = (project['status'] ?? '').toString();
      final String serviceType = (project['service_type'] ?? '').toString();
      final String name = (project['name'] ?? '').toString().toLowerCase();
      final String code = (project['code'] ?? '').toString().toLowerCase();
      final String ownerName =
          ((project['owner'] ?? const <String, dynamic>{})['name'] ?? '')
              .toString()
              .toLowerCase();

      final bool matchStatus =
          _statusFilter.isEmpty || status == _statusFilter;
      final bool matchService =
          _serviceFilter.isEmpty || serviceType == _serviceFilter;
      final bool matchKeyword = keyword.isEmpty ||
          name.contains(keyword) ||
          code.contains(keyword) ||
          ownerName.contains(keyword);

      return matchStatus && matchService && matchKeyword;
    }).toList();
  }

  List<String> get _serviceFilters {
    final Set<String> values = projects
        .map((Map<String, dynamic> project) => (project['service_type'] ?? '').toString())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final List<String> list = values.toList()..sort();
    return list;
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
        return value.isEmpty ? 'Tất cả trạng thái' : value;
    }
  }

  IconData _statusIcon(String value) {
    switch (value) {
      case 'moi_tao':
        return Icons.fiber_new_outlined;
      case 'dang_trien_khai':
        return Icons.play_circle_outline;
      case 'cho_duyet':
        return Icons.fact_check_outlined;
      case 'hoan_thanh':
        return Icons.verified_outlined;
      case 'tam_dung':
        return Icons.pause_circle_outline;
      default:
        return Icons.grid_view_outlined;
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'dang_trien_khai':
        return StitchTheme.primary;
      case 'cho_duyet':
        return StitchTheme.warning;
      case 'hoan_thanh':
        return StitchTheme.success;
      case 'tam_dung':
        return StitchTheme.danger;
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
        return value.isEmpty ? 'Tất cả dịch vụ' : value;
    }
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int _countByStatus(String status) {
    return projects
        .where((Map<String, dynamic> project) => project['status'] == status)
        .length;
  }

  void _openCreate() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<Widget>(
            builder: (_) => CreateProjectScreen(
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
            builder: (_) => ProjectDetailScreen(
              token: widget.token,
              apiService: widget.apiService,
              projectId: projectId,
            ),
          ),
        )
        .then((_) => _fetch());
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filteredProjects = _filteredProjects;
    final int total = projects.length;
    final int active = _countByStatus('dang_trien_khai');
    final int review = _countByStatus('cho_duyet');
    final int done = _countByStatus('hoan_thanh');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dự án'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _openCreate,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: <Widget>[
              StitchPageHeader(
                title: 'Quản trị dự án',
                subtitle:
                    'Theo dõi tiến độ, phụ trách, hợp đồng và hạn chót của từng dự án trong một màn hình gọn và rõ.',
                icon: Icons.account_tree_outlined,
                stats: <StitchHeaderStat>[
                  StitchHeaderStat(label: 'Tổng dự án', value: '$total'),
                  StitchHeaderStat(
                    label: 'Đang triển khai',
                    value: '$active',
                    accent: StitchTheme.primary,
                  ),
                  StitchHeaderStat(
                    label: 'Chờ duyệt',
                    value: '$review',
                    accent: StitchTheme.warning,
                  ),
                  StitchHeaderStat(
                    label: 'Hoàn thành',
                    value: '$done',
                    accent: StitchTheme.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StitchSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      onChanged: (String value) {
                        setState(() => _searchQuery = value);
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Tìm theo tên dự án, mã dự án hoặc người phụ trách',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Trạng thái dự án',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: StitchTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _FilterChipButton(
                          label: 'Tất cả',
                          icon: Icons.grid_view_outlined,
                          selected: _statusFilter.isEmpty,
                          onTap: () => setState(() => _statusFilter = ''),
                        ),
                        ...<String>[
                          'moi_tao',
                          'dang_trien_khai',
                          'cho_duyet',
                          'hoan_thanh',
                          'tam_dung',
                        ].map(
                          (String status) => _FilterChipButton(
                            label: _statusLabel(status),
                            icon: _statusIcon(status),
                            selected: _statusFilter == status,
                            onTap: () => setState(() => _statusFilter = status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Loại dịch vụ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: StitchTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _FilterChipButton(
                          label: 'Tất cả',
                          icon: Icons.tune_outlined,
                          selected: _serviceFilter.isEmpty,
                          onTap: () => setState(() => _serviceFilter = ''),
                        ),
                        ..._serviceFilters.map(
                          (String service) => _FilterChipButton(
                            label: _serviceLabel(service),
                            icon: Icons.design_services_outlined,
                            selected: _serviceFilter == service,
                            onTap: () => setState(() => _serviceFilter = service),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (message.isNotEmpty && projects.isEmpty)
                StitchEmptyStateCard(
                  title: 'Chưa có dự án',
                  message: message,
                  icon: Icons.account_tree_outlined,
                )
              else if (filteredProjects.isEmpty)
                const StitchEmptyStateCard(
                  title: 'Không có dự án phù hợp',
                  message:
                      'Hãy nới bộ lọc hoặc thay đổi từ khóa tìm kiếm để xem thêm dự án.',
                  icon: Icons.filter_alt_off_outlined,
                )
              else ...filteredProjects.map(_buildProjectCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final String name = (project['name'] ?? 'Dự án').toString();
    final String code = (project['code'] ?? '').toString();
    final String status = (project['status'] ?? '').toString();
    final String serviceType = (project['service_type'] ?? '').toString();
    final String serviceOther = (project['service_type_other'] ?? '').toString();
    final String deadline = (project['deadline'] ?? '').toString();
    final String ownerName =
        ((project['owner'] ?? const <String, dynamic>{})['name'] ?? 'Chưa phân công')
            .toString();
    final int projectId = int.tryParse('${project['id'] ?? 0}') ?? 0;
    final int progress = _readInt(project['progress_percent']).clamp(0, 100);
    final bool hasContract =
        project['contract_id'] != null || project['contract'] != null;
    final String serviceLabel = serviceType == 'khac'
        ? (serviceOther.isEmpty ? 'Khác' : serviceOther)
        : _serviceLabel(serviceType);
    final Color statusAccent = _statusColor(status);

    return InkWell(
      onTap: projectId > 0 ? () => _openDetail(projectId) : null,
      borderRadius: BorderRadius.circular(22),
      child: StitchSurfaceCard(
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (code.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          code,
                          style: const TextStyle(
                            color: StitchTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusAccent.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: statusAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                StitchInfoPill(
                  label: 'Dịch vụ',
                  value: serviceLabel,
                ),
                StitchInfoPill(
                  label: 'Hợp đồng',
                  value: hasContract ? 'Đã liên kết' : 'Chưa có',
                  accent: hasContract ? StitchTheme.success : StitchTheme.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ProjectMetaItem(
                    icon: Icons.person_outline,
                    label: 'Phụ trách',
                    value: ownerName,
                  ),
                ),
                Expanded(
                  child: _ProjectMetaItem(
                    icon: Icons.event_outlined,
                    label: 'Hạn chót',
                    value: deadline.isEmpty ? 'Chưa cập nhật' : deadline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'Tiến độ triển khai',
                  style: TextStyle(
                    color: StitchTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$progress%',
                  style: TextStyle(
                    color: statusAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8,
                color: statusAccent,
                backgroundColor: StitchTheme.surfaceAlt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? StitchTheme.primary : StitchTheme.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? StitchTheme.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? StitchTheme.primary.withValues(alpha: 0.22)
                : StitchTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectMetaItem extends StatelessWidget {
  const _ProjectMetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: StitchTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: StitchTheme.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
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
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

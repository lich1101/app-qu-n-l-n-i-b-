import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';
import '../tasks/task_detail_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.projectId,
  });

  final String token;
  final MobileApiService apiService;
  final int projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool loading = true;
  Map<String, dynamic>? project;
  List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];
  String message = '';

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
    final Map<String, dynamic>? proj = await widget.apiService.getProject(
      widget.token,
      widget.projectId,
    );
    final List<Map<String, dynamic>> rows = await widget.apiService.getTasks(
      widget.token,
      projectId: widget.projectId,
      perPage: 200,
    );
    if (!mounted) return;
    setState(() {
      project = proj;
      tasks = rows;
      loading = false;
      message = proj == null ? 'Không tìm thấy dự án.' : '';
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

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết dự án'),
        actions: <Widget>[
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: <Widget>[
                  if (message.isNotEmpty)
                    Text(
                      message,
                      style: const TextStyle(color: StitchTheme.textMuted),
                    ),
                  if (project != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: StitchTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (project?['name'] ?? 'Dự án').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Trạng thái: ${_statusLabel((project?['status'] ?? '').toString())}',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tiến độ: ${(project?['progress_percent'] ?? 0)}%',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hạn chót: ${_formatDate((project?['deadline'] ?? '').toString())}',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Phụ trách: ${(project?['owner']?['name'] ?? '—').toString()}',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Công việc trong dự án',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    ...tasks.map((Map<String, dynamic> task) {
                      final String title = (task['title'] ?? 'Công việc').toString();
                      final String status = (task['status'] ?? '').toString();
                      final int progress = (task['progress_percent'] ?? 0) is int
                          ? task['progress_percent'] as int
                          : int.tryParse('${task['progress_percent'] ?? 0}') ?? 0;
                      final String deadline = (task['deadline'] ?? '').toString();
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<Widget>(
                              builder: (_) => TaskDetailScreen(
                                token: widget.token,
                                apiService: widget.apiService,
                                taskId: (task['id'] ?? 0) as int,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: StitchTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Trạng thái: ${_statusLabel(status)} • Tiến độ: $progress%',
                                style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
                              ),
                              if (deadline.isNotEmpty)
                                Text(
                                  'Deadline: ${_formatDate(deadline)}',
                                  style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    if (tasks.isEmpty)
                      const Text(
                        'Chưa có công việc nào.',
                        style: TextStyle(color: StitchTheme.textMuted),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.taskId,
  });

  final String token;
  final MobileApiService apiService;
  final int taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool loading = true;
  Map<String, dynamic>? task;
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
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
    final Map<String, dynamic>? detail =
        await widget.apiService.getTaskDetail(widget.token, widget.taskId);
    final List<Map<String, dynamic>> rows =
        await widget.apiService.getTaskItems(widget.token, widget.taskId);
    if (!mounted) return;
    setState(() {
      task = detail;
      items = rows;
      loading = false;
      message = detail == null ? 'Không tìm thấy công việc.' : '';
    });
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'todo':
        return 'Cần làm';
      case 'doing':
        return 'Đang làm';
      case 'done':
        return 'Hoàn tất';
      case 'blocked':
        return 'Bị chặn';
      default:
        return value;
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    final DateTime? dt = DateTime.tryParse(raw);
    if (dt == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
    final DateTime local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final String title = (item['title'] ?? 'Đầu việc').toString();
    final String status = (item['status'] ?? '').toString();
    final int progress = (item['progress_percent'] ?? 0) is int
        ? item['progress_percent'] as int
        : int.tryParse('${item['progress_percent'] ?? 0}') ?? 0;
    final String start = (item['start_date'] ?? '').toString();
    final String deadline = (item['deadline'] ?? '').toString();
    final String assignee =
        (item['assignee']?['name'] ?? item['assignee']?['email'] ?? '—')
            .toString();

    return Container(
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
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Trạng thái: ${_statusLabel(status)} • Tiến độ: $progress%',
            style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Phụ trách: $assignee',
            style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Bắt đầu: ${_formatDate(start)} • Deadline: ${_formatDate(deadline)}',
            style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (progress.clamp(0, 100)) / 100,
              minHeight: 6,
              backgroundColor: StitchTheme.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(StitchTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
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
                  if (task != null) ...<Widget>[
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
                            (task?['title'] ?? 'Công việc').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Trạng thái: ${_statusLabel((task?['status'] ?? '').toString())}',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tiến độ: ${(task?['progress_percent'] ?? 0)}%',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Deadline: ${_formatDate((task?['deadline'] ?? '').toString())}',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Phòng ban: ${(task?['department']?['name'] ?? '—').toString()}',
                            style: const TextStyle(color: StitchTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Danh sách đầu việc',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const Text(
                        'Chưa có đầu việc nào.',
                        style: TextStyle(color: StitchTheme.textMuted),
                      )
                    else
                      ...items.map(_buildItemCard).toList(),
                  ],
                ],
              ),
      ),
    );
  }
}

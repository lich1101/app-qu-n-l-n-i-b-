import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/staff_multi_filter_row.dart';
import '../../data/services/mobile_api_service.dart';
import 'task_detail_screen.dart';

/// Danh sách công việc toàn hệ thống (theo scope API), có lọc tìm kiếm + nhiều nhân sự phụ trách.
class TasksListScreen extends StatefulWidget {
  const TasksListScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;

  /// Giữ danh sách khi tải lại — tránh thay toàn bộ bằng spinner làm nhảy scroll.
  bool _listRefreshing = false;
  String _message = '';
  List<Map<String, dynamic>> _tasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _assigneeUsers = <Map<String, dynamic>>[];
  List<int> _assigneeFilterIds = <int>[];
  String _status = '';

  static const Map<String, String> _statusLabels = <String, String>{
    'todo': 'Cần làm',
    'doing': 'Đang làm',
    'done': 'Hoàn tất',
    'blocked': 'Bị chặn',
  };

  @override
  void initState() {
    super.initState();
    _loadAssignees();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAssignees() async {
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getUsersLookup(widget.token, purpose: 'operational_assignee');
    if (!mounted) return;
    setState(() => _assigneeUsers = rows);
  }

  Future<void> _load() async {
    setState(() {
      if (_tasks.isEmpty) {
        _loading = true;
        _listRefreshing = false;
      } else {
        _loading = false;
        _listRefreshing = true;
      }
      _message = '';
    });
    try {
      final List<Map<String, dynamic>> rows = await widget.apiService.getTasks(
        widget.token,
        perPage: 100,
        status: _status,
        search:
            _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        assigneeIds: _assigneeFilterIds.isEmpty ? null : _assigneeFilterIds,
      );
      if (!mounted) return;
      setState(() {
        _tasks = rows;
        _loading = false;
        _listRefreshing = false;
        _message = rows.isEmpty ? 'Không có công việc phù hợp bộ lọc.' : '';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _listRefreshing = false;
        });
      }
    }
  }

  String _statusLabel(String value) {
    return _statusLabels[value] ?? value;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'done':
        return StitchTheme.successStrong;
      case 'doing':
        return StitchTheme.primaryStrong;
      case 'blocked':
        return StitchTheme.danger;
      case 'todo':
      default:
        return StitchTheme.warningStrong;
    }
  }

  Future<void> _openTask(int taskId) async {
    if (taskId <= 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => TaskDetailScreen(
              token: widget.token,
              apiService: widget.apiService,
              taskId: taskId,
            ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.bg,
      appBar: AppBar(
        title: const Text('Danh sách công việc'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            CupertinoSliverRefreshControl(onRefresh: _load),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  if (_listRefreshing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: StitchTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Bộ lọc',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText:
                                'Tiêu đề, mô tả, dự án, người phụ trách...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _load(),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            ChoiceChip(
                              label: const Text('Tất cả'),
                              selected: _status.isEmpty,
                              onSelected: (_) {
                                setState(() => _status = '');
                                _load();
                              },
                            ),
                            for (final String key in _statusLabels.keys)
                              ChoiceChip(
                                label: Text(_statusLabels[key] ?? key),
                                selected: _status == key,
                                onSelected: (_) {
                                  setState(() => _status = key);
                                  _load();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StaffMultiFilterRow(
                          users: _assigneeUsers,
                          selectedIds: _assigneeFilterIds,
                          title: 'Phụ trách công việc',
                          onChanged: (List<int> ids) {
                            setState(() => _assigneeFilterIds = ids);
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _load,
                            icon: const Icon(
                              Icons.filter_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('Áp dụng lọc'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_loading && _tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _message,
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                    )
                  else
                    ..._tasks.map((Map<String, dynamic> task) {
                      final int id = int.tryParse('${task['id'] ?? 0}') ?? 0;
                      final String title =
                          (task['title'] ?? 'Công việc').toString();
                      final String st = (task['status'] ?? '').toString();
                      final Map<String, dynamic>? project =
                          task['project'] is Map<String, dynamic>
                              ? task['project'] as Map<String, dynamic>
                              : null;
                      final Map<String, dynamic>? assignee =
                          task['assignee'] is Map<String, dynamic>
                              ? task['assignee'] as Map<String, dynamic>
                              : null;
                      final String deadlineYmd = VietnamTime.toYmdInput(
                        task['deadline'],
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: StitchTheme.border),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openTask(id),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          st,
                                        ).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _statusLabel(st),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _statusColor(st),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Dự án: ${(project?['name'] ?? '—').toString()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: StitchTheme.textMuted,
                                  ),
                                ),
                                Text(
                                  'Phụ trách: ${(assignee?['name'] ?? assignee?['email'] ?? '—').toString()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: StitchTheme.textMuted,
                                  ),
                                ),
                                if (deadlineYmd.isNotEmpty)
                                  Text(
                                    'Hạn: $deadlineYmd',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: StitchTheme.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
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

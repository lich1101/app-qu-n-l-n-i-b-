import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';
import 'task_item_detail_screen.dart';

class TaskItemsScreen extends StatefulWidget {
  const TaskItemsScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<TaskItemsScreen> createState() => _TaskItemsScreenState();
}

class _TaskItemsScreenState extends State<TaskItemsScreen> {
  static const Map<String, String> _statusLabels = <String, String>{
    'todo': 'Cần làm',
    'doing': 'Đang làm',
    'done': 'Hoàn tất',
    'blocked': 'Bị chặn',
  };

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String _message = '';
  String _status = '';
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  final int _perPage = 30;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _message = '';
    });

    final int nextPage = page ?? _page;
    final Map<String, dynamic> response = await widget.apiService
        .getTaskItemsGlobal(
          widget.token,
          perPage: _perPage,
          page: nextPage,
          status: _status,
          search: _searchController.text,
        );

    if (!mounted) return;

    if (response.isEmpty) {
      setState(() {
        _loading = false;
        _items = <Map<String, dynamic>>[];
        _message = 'Không tải được danh sách đầu việc.';
      });
      return;
    }

    final List<Map<String, dynamic>> rows =
        ((response['data'] ?? <dynamic>[]) as List<dynamic>)
            .whereType<Map>()
            .map((Map<dynamic, dynamic> row) => row.cast<String, dynamic>())
            .toList();

    setState(() {
      _items = rows;
      _page = ((response['current_page'] as num?) ?? nextPage).toInt();
      _lastPage = ((response['last_page'] as num?) ?? 1).toInt();
      _total = ((response['total'] as num?) ?? rows.length).toInt();
      _loading = false;
      _message = rows.isEmpty ? 'Không có đầu việc phù hợp bộ lọc.' : '';
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  String _statusLabel(String value) {
    return _statusLabels[value] ?? (value.isEmpty ? '—' : value);
  }

  String _formatDate(dynamic value) {
    final String raw = '${value ?? ''}';
    if (raw.isEmpty) return '—';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
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

  Future<void> _openItem(Map<String, dynamic> item) async {
    final int itemId = _toInt(item['id']);
    final dynamic rawTask = item['task'];
    final Map<String, dynamic>? task =
        rawTask is Map ? rawTask.cast<String, dynamic>() : null;
    final int taskId = _toInt(task?['id'] ?? item['task_id']);
    if (itemId <= 0 || taskId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được chi tiết đầu việc.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<Widget>(
        builder: (_) => TaskItemDetailScreen(
          token: widget.token,
          apiService: widget.apiService,
          taskId: taskId,
          itemId: itemId,
        ),
      ),
    );
    await _load(page: _page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Danh sách đầu việc'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : () => _load(page: _page),
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(page: _page),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: <Widget>[
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
                      'Bộ lọc đầu việc',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: StitchTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tiêu đề, công việc, dự án...',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _loading ? null : () => _load(page: 1),
                        ),
                      ),
                      onSubmitted: (_) => _load(page: 1),
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
                            _load(page: 1);
                          },
                        ),
                        for (final String key in _statusLabels.keys)
                          ChoiceChip(
                            label: Text(_statusLabels[key] ?? key),
                            selected: _status == key,
                            onSelected: (_) {
                              setState(() => _status = key);
                              _load(page: 1);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tổng: $_total đầu việc',
                      style: const TextStyle(
                        fontSize: 12,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_message.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Text(
                    _message,
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                )
              else
                ..._items.map((Map<String, dynamic> item) {
                  final dynamic rawTask = item['task'];
                  final Map<String, dynamic>? task =
                      rawTask is Map ? rawTask.cast<String, dynamic>() : null;
                  final dynamic rawProject = task?['project'];
                  final Map<String, dynamic>? project =
                      rawProject is Map
                          ? rawProject.cast<String, dynamic>()
                          : null;
                  final dynamic rawAssignee = item['assignee'];
                  final Map<String, dynamic>? assignee =
                      rawAssignee is Map
                          ? rawAssignee.cast<String, dynamic>()
                          : null;
                  final String status = (item['status'] ?? '').toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: StitchTheme.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openItem(item),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              (item['title'] ?? 'Đầu việc').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: StitchTheme.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Công việc: ${(task?['title'] ?? '—').toString()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: StitchTheme.textMuted,
                              ),
                            ),
                            Text(
                              'Dự án: ${(project?['name'] ?? '—').toString()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: StitchTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _MiniPill(
                                  label: _statusLabel(status),
                                  color: _statusColor(status),
                                ),
                                _MiniPill(
                                  label:
                                      'Tiến độ ${_toInt(item['progress_percent'])}%',
                                  color: StitchTheme.primaryStrong,
                                ),
                                _MiniPill(
                                  label:
                                      'Tỷ trọng ${_toInt(item['weight_percent'])}%',
                                  color: StitchTheme.warningStrong,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Phụ trách: ${(assignee?['name'] ?? '—').toString()} • Deadline: ${_formatDate(item['deadline'])}',
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
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _loading || _page <= 1
                              ? null
                              : () => _load(page: _page - 1),
                      child: const Text('Trang trước'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _loading || _page >= _lastPage
                              ? null
                              : () => _load(page: _page + 1),
                      child: const Text('Trang sau'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Trang $_page / $_lastPage',
                textAlign: TextAlign.center,
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
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

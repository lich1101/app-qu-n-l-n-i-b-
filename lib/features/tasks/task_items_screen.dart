import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/task_item_linear_pace.dart';
import '../../core/widgets/staff_multi_filter_row.dart';
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
  List<int> _assigneeFilterIds = <int>[];
  List<Map<String, dynamic>> _assigneeLookupUsers = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadAssignees();
    _load();
  }

  Future<void> _loadAssignees() async {
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getUsersLookup(widget.token, purpose: 'operational_assignee');
    if (!mounted) return;
    setState(() => _assigneeLookupUsers = rows);
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
          assigneeIds:
              _assigneeFilterIds.isEmpty ? null : _assigneeFilterIds,
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
                    const SizedBox(height: 12),
                    StaffMultiFilterRow(
                      users: _assigneeLookupUsers,
                      selectedIds: _assigneeFilterIds,
                      title: 'Phụ trách đầu việc',
                      onChanged: (List<int> ids) {
                        setState(() => _assigneeFilterIds = ids);
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : () => _load(page: 1),
                        icon: const Icon(Icons.filter_alt_outlined, size: 18),
                        label: const Text('Áp dụng lọc'),
                      ),
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
                  final String status = (item['status'] ?? '').toString();
                  final Color tone = _statusColor(status);
                  final int pct = _toInt(item['progress_percent']);
                  final Map<String, dynamic>? reviewer =
                      item['reviewer'] is Map<String, dynamic>
                          ? item['reviewer'] as Map<String, dynamic>
                          : null;
                  final String reviewerName =
                      (reviewer?['name'] ?? reviewer?['email'] ?? '')
                          .toString()
                          .trim();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: StitchTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        InkWell(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          onTap: () => _openItem(item),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        (item['title'] ?? 'Đầu việc')
                                            .toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: StitchTheme.textMain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tone.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          16,
                                        ),
                                        border: Border.all(
                                          color: tone.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          color: tone,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
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
                                const SizedBox(height: 10),
                                Text(
                                  'Tiến độ: $pct%',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: pct.clamp(0, 100) / 100,
                                    minHeight: 6,
                                    color: tone,
                                    backgroundColor: StitchTheme.surfaceAlt,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: taskItemPaceStatusLine(
                                    computeTaskItemLinearPace(item),
                                  ),
                                ),
                                if (reviewerName.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.fact_check_outlined,
                                        size: 16,
                                        color: StitchTheme.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Người duyệt: $reviewerName',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: StitchTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: TextButton.icon(
                            onPressed: () => _openItem(item),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: const Text('Chi tiết'),
                          ),
                        ),
                      ],
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

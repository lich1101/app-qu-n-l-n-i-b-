import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class DeadlineRemindersScreen extends StatefulWidget {
  const DeadlineRemindersScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<DeadlineRemindersScreen> createState() =>
      _DeadlineRemindersScreenState();
}

class _DeadlineRemindersScreenState extends State<DeadlineRemindersScreen> {
  bool loading = false;
  String message = '';
  List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> data = await widget.apiService.getTasks(
      widget.token,
      perPage: 50,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      tasks = data;
    });
  }

  bool _isDone(String status) {
    return status == 'done';
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return VietnamTime.parse(raw);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final String hh = date.hour.toString().padLeft(2, '0');
    final String mm = date.minute.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '$hh:$mm:00';
  }

  Future<void> _openReminderSheet(Map<String, dynamic> task) async {
    final int taskId = (task['id'] ?? 0) as int;
    if (taskId <= 0) return;

    String channel = 'in_app';
    DateTime scheduledAt = VietnamTime.now().add(const Duration(hours: 2));
    final DateTime? deadline = _parseDate((task['deadline'] ?? '').toString());
    if (deadline != null) {
      scheduledAt = DateTime(
        deadline.year,
        deadline.month,
        deadline.day,
        9,
        0,
      ).subtract(const Duration(days: 1));
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final BuildContext sheetContext = context;
            Future<void> pickSchedule() async {
              final DateTime now = VietnamTime.now();
              final DateTime? date = await showDatePicker(
                context: sheetContext,
                firstDate: now,
                lastDate: DateTime(now.year + 2),
                initialDate: scheduledAt.isAfter(now) ? scheduledAt : now,
              );
              if (date == null) return;
              if (!sheetContext.mounted) return;
              final TimeOfDay? time = await showTimePicker(
                context: sheetContext,
                initialTime: TimeOfDay.fromDateTime(scheduledAt),
              );
              if (time == null) return;
              if (!sheetContext.mounted) return;
              setSheetState(() {
                scheduledAt = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            }

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tạo nhắc hạn chót',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (task['title'] ?? 'Công việc').toString(),
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: channel,
                    decoration: const InputDecoration(labelText: 'Kênh nhắc'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'in_app',
                        child: Text('Trong ứng dụng'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'push',
                        child: Text('Thông báo đẩy'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'email',
                        child: Text('Email'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'telegram',
                        child: Text('Telegram/Zalo'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value == null) return;
                      setSheetState(() => channel = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Thời gian gửi nhắc',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: pickSchedule,
                    icon: const Icon(Icons.schedule),
                    label: Text(_formatDateTime(scheduledAt)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final bool ok = await widget.apiService
                            .createTaskReminder(
                              widget.token,
                              taskId,
                              channel: channel,
                              triggerType: 'custom',
                              scheduledAt: _formatDateTime(scheduledAt),
                            );
                        if (!mounted) return;
                        setState(() {
                          message =
                              ok
                                  ? 'Đã tạo nhắc hạn chót.'
                                  : 'Tạo nhắc hạn chót thất bại.';
                        });
                        if (ok) {
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Tạo nhắc'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, DateTime now) {
    final String title = (task['title'] ?? 'Công việc').toString();
    final String projectName =
        ((task['project'] as Map<String, dynamic>?)?['name'] ?? 'Dự án')
            .toString();
    final DateTime? deadline = _parseDate((task['deadline'] ?? '').toString());
    final String status = (task['status'] ?? '').toString();
    String deadlineLabel = 'Chưa có hạn chót';
    String tagLabel = 'Chưa rõ';
    Color tagColor = StitchTheme.textSubtle;

    if (deadline != null) {
      final Duration diff = deadline.difference(now);
      if (diff.isNegative) {
        tagLabel = 'Quá hạn ${diff.inDays.abs()} ngày';
        tagColor = StitchTheme.danger;
      } else if (diff.inHours <= 24) {
        tagLabel = 'Còn ${diff.inHours}h';
        tagColor = StitchTheme.warning;
      } else {
        tagLabel = 'Còn ${diff.inDays} ngày';
        tagColor = StitchTheme.primary;
      }
      deadlineLabel = _formatDate(deadline);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tagLabel,
                  style: TextStyle(
                    color: tagColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$projectName • $deadlineLabel',
            style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: StitchTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: StitchTheme.textMuted,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openReminderSheet(task),
                child: const Text('Tạo nhắc'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> items,
    DateTime now,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StitchSectionHeader(title: title),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text(
            'Không có công việc phù hợp.',
            style: TextStyle(color: StitchTheme.textMuted),
          )
        else
          ...items.map(
            (Map<String, dynamic> task) => _buildTaskCard(task, now),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<Map<String, dynamic>> overdue = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> dueSoon = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> dueToday = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> task in tasks) {
      final String status = (task['status'] ?? '').toString();
      if (_isDone(status)) continue;
      final DateTime? deadline = _parseDate(
        (task['deadline'] ?? '').toString(),
      );
      if (deadline == null) continue;
      final Duration diff = deadline.difference(now);
      if (diff.isNegative) {
        overdue.add(task);
      } else if (diff.inHours <= 24) {
        dueToday.add(task);
      } else if (diff.inHours <= 72) {
        dueSoon.add(task);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nhắc nhở hạn chót')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            const StitchHeroCard(
              title: 'Theo dõi hạn chót',
              subtitle: 'Tổng hợp các mốc quan trọng và lịch nhắc tự động.',
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.35,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                StitchMetricCard(
                  icon: Icons.alarm,
                  label: 'Còn 3 ngày',
                  value: dueSoon.length.toString(),
                  accent: StitchTheme.primary,
                ),
                StitchMetricCard(
                  icon: Icons.warning_amber,
                  label: 'Còn 24h',
                  value: dueToday.length.toString(),
                  accent: StitchTheme.warning,
                ),
                StitchMetricCard(
                  icon: Icons.error_outline,
                  label: 'Quá hạn',
                  value: overdue.length.toString(),
                  accent: StitchTheme.danger,
                ),
                StitchMetricCard(
                  icon: Icons.playlist_add_check,
                  label: 'Đang theo dõi',
                  value:
                      (dueSoon.length + dueToday.length + overdue.length)
                          .toString(),
                  accent: StitchTheme.success,
                ),
              ],
            ),
            if (message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: StitchTheme.textMuted),
              ),
            ],
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 8),
            _buildSection('Quá hạn', overdue, now),
            _buildSection('Còn 24 giờ', dueToday, now),
            _buildSection('Còn 3 ngày', dueSoon, now),
          ],
        ),
      ),
    );
  }
}

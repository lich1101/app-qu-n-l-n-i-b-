import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  bool loading = false;
  String message = '';
  List<Map<String, dynamic>> logs = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final Map<String, dynamic> data = await widget.apiService.getActivityLogs(
      widget.token,
      perPage: 30,
    );
    if (!mounted) return;
    final int statusCode = (data['statusCode'] ?? 500) as int;
    if (statusCode != 200) {
      setState(() {
        loading = false;
        message =
            statusCode == 403
                ? 'Bạn không có quyền xem nhật ký hệ thống.'
                : 'Không thể tải nhật ký hệ thống.';
        logs = <Map<String, dynamic>>[];
      });
      return;
    }
    setState(() {
      loading = false;
      logs =
          (data['data'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .toList();
      message = '';
    });
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final DateTime? date = VietnamTime.parse(raw);
    if (date == null) return raw;
    return '${VietnamTime.formatTime(date)} ${VietnamTime.formatDate(date)}';
  }

  String _subjectLabel(String subjectType, String subjectId) {
    final String type = subjectType.trim();
    final String id = subjectId.trim();
    if (type.isEmpty && id.isEmpty) return 'Không có đối tượng';
    if (type.isEmpty) return '#$id';
    if (id.isEmpty) return type;
    return '$type #$id';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký hệ thống')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            const StitchAdminHeader(
              title: 'Nhật ký hệ thống',
              subtitle:
                  'Theo dõi lịch sử thao tác, thay đổi trạng thái và hoạt động upload trong hệ thống.',
              icon: Icons.history_toggle_off_outlined,
            ),
            const SizedBox(height: 12),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StitchFeedbackBanner(message: message),
              ),
            if (loading)
              const StitchLoadingState(label: 'Đang tải nhật ký hệ thống...')
            else if (logs.isEmpty && message.isEmpty)
              const StitchEmptyState(
                title: 'Chưa có activity log',
                subtitle:
                    'Khi có thao tác tạo, sửa, đổi trạng thái hoặc upload, lịch sử sẽ hiển thị tại đây.',
                icon: Icons.manage_history_outlined,
              ),
            ...logs.map((Map<String, dynamic> log) {
              final Map<String, dynamic>? user =
                  log['user'] as Map<String, dynamic>?;
              final String actor =
                  (user?['name'] ?? user?['email'] ?? 'System').toString();
              final String action = (log['action'] ?? 'activity').toString();
              final String subjectType = (log['subject_type'] ?? '').toString();
              final String subjectId = (log['subject_id'] ?? '').toString();
              final String time = _formatTime(
                (log['created_at'] ?? '').toString(),
              );
              return StitchAdminListItem(
                title: action.replaceAll('_', ' '),
                subtitle: _subjectLabel(subjectType, subjectId),
                meta: <String>[actor, time],
                icon: Icons.bolt_outlined,
                accent: StitchTheme.primaryStrong,
              );
            }),
          ],
        ),
      ),
    );
  }
}

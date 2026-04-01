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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký hệ thống')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            const StitchHeroCard(
              title: 'System log',
              subtitle:
                  'Theo dõi lịch sử thao tác, thay đổi trạng thái, upload.',
            ),
            const SizedBox(height: 12),
            if (message.isNotEmpty)
              Text(
                message,
                style: const TextStyle(color: StitchTheme.textMuted),
              ),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!loading && logs.isEmpty && message.isEmpty)
              const Text(
                'Chưa có activity log.',
                style: TextStyle(color: StitchTheme.textMuted),
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
                            action.replaceAll('_', ' '),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: StitchTheme.textSubtle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$subjectType #$subjectId • $actor',
                      style: const TextStyle(
                        fontSize: 12,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

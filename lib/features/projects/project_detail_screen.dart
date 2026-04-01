import 'dart:math' as math;

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
  bool submittingHandover = false;
  bool gscLoading = false;
  bool gscSyncing = false;
  Map<String, dynamic>? project;
  Map<String, dynamic>? gsc;
  List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];
  String message = '';
  String gscMessage = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      message = '';
      gscMessage = '';
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
    Map<String, dynamic>? gscPayload;
    String gscError = '';
    final String websiteUrl = (proj?['website_url'] ?? '').toString().trim();
    if (proj != null && websiteUrl.isNotEmpty) {
      final Map<String, dynamic> gscRes = await widget.apiService
          .getProjectSearchConsole(widget.token, widget.projectId);
      if (gscRes['error'] == true) {
        gscError = (gscRes['message'] ?? '').toString();
        gscPayload = _appendSyncError(null, gscError);
      } else {
        gscPayload =
            ((gscRes['body'] ?? <String, dynamic>{}) as Map<String, dynamic>)
                .cast<String, dynamic>();
      }
    }
    if (!mounted) return;
    setState(() {
      project = proj;
      tasks = rows;
      gsc = gscPayload;
      gscMessage = gscError;
      loading = false;
      message = proj == null ? 'Không tìm thấy dự án.' : '';
    });
  }

  Future<void> _fetchGsc({bool force = false, bool refresh = true}) async {
    final Map<String, dynamic>? currentProject = project;
    if (currentProject == null) return;
    final String websiteUrl =
        (currentProject['website_url'] ?? '').toString().trim();
    if (websiteUrl.isEmpty) {
      setState(() {
        gsc = null;
        gscMessage = '';
      });
      return;
    }

    setState(() => gscLoading = true);
    final Map<String, dynamic> gscRes = await widget.apiService
        .getProjectSearchConsole(
          widget.token,
          widget.projectId,
          refresh: refresh,
          force: force,
          days: 21,
        );
    if (!mounted) return;

    if (gscRes['error'] == true) {
      final String errorMessage = (gscRes['message'] ?? '').toString().trim();
      setState(() {
        gscLoading = false;
        gscMessage = errorMessage;
        gsc = _appendSyncError(gsc, errorMessage);
      });
      return;
    }

    final Map<String, dynamic> payload =
        ((gscRes['body'] ?? <String, dynamic>{}) as Map<String, dynamic>)
            .cast<String, dynamic>();
    setState(() {
      gscLoading = false;
      gscMessage = '';
      gsc = payload;
    });
  }

  Future<void> _syncGscNow() async {
    if (gscSyncing) return;
    final String websiteUrl = (project?['website_url'] ?? '').toString().trim();
    if (websiteUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dự án chưa có website để đồng bộ Search Console.'),
        ),
      );
      return;
    }

    setState(() => gscSyncing = true);
    final Map<String, dynamic> syncRes = await widget.apiService
        .syncProjectSearchConsole(widget.token, widget.projectId);
    if (!mounted) return;

    if (syncRes['error'] == true) {
      final String err = (syncRes['message'] ?? 'Đồng bộ thất bại.').toString();
      setState(() {
        gscSyncing = false;
        gscMessage = err;
        gsc = _appendSyncError(gsc, err);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    await _fetchGsc(force: true, refresh: true);
    if (!mounted) return;
    setState(() => gscSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đồng bộ dữ liệu Search Console.')),
    );
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

  String _formatShortDate(String raw) {
    if (raw.isEmpty) return '—';
    if (raw.length >= 10) {
      return raw.substring(5, 10);
    }
    return raw;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  String _formatNumber(dynamic value) {
    final int number = _toInt(value);
    final String sign = number < 0 ? '-' : '';
    final String digits = number.abs().toString();
    final String grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$sign$grouped';
  }

  String _formatSigned(dynamic value) {
    final int number = _toInt(value);
    if (number > 0) return '+${_formatNumber(number)}';
    return _formatNumber(number);
  }

  String _formatPercent(dynamic value, {int digits = 2}) {
    final double? parsed = _toDoubleOrNull(value);
    if (parsed == null) return '—';
    return '${parsed.toStringAsFixed(digits)}%';
  }

  Map<String, dynamic> _appendSyncError(
    Map<String, dynamic>? source,
    String error,
  ) {
    final Map<String, dynamic> base = <String, dynamic>{
      ...(source ?? <String, dynamic>{}),
    };
    final Map<String, dynamic> status = <String, dynamic>{
      ...((base['status'] is Map)
          ? (base['status'] as Map).cast<String, dynamic>()
          : <String, dynamic>{}),
      'sync_error': error,
    };
    base['status'] = status;
    return base;
  }

  String _handoverLabel(String value) {
    switch (value) {
      case 'pending':
        return 'Đang chờ duyệt bàn giao';
      case 'approved':
        return 'Đã duyệt bàn giao';
      case 'rejected':
        return 'Bị từ chối bàn giao';
      default:
        return 'Chưa bàn giao';
    }
  }

  Future<void> _submitHandover() async {
    final Map<String, dynamic>? currentProject = project;
    if (currentProject == null || submittingHandover) return;
    setState(() => submittingHandover = true);
    final bool ok = await widget.apiService.submitProjectHandover(
      widget.token,
      widget.projectId,
    );
    if (!mounted) return;
    setState(() => submittingHandover = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã gửi duyệt bàn giao dự án.'
              : 'Gửi duyệt bàn giao thất bại. Kiểm tra tiến độ tối thiểu hoặc quyền thao tác.',
        ),
      ),
    );
    if (ok) {
      await _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String websiteUrl = (project?['website_url'] ?? '').toString().trim();
    final Map<String, dynamic> gscStatus = <String, dynamic>{
      ...((gsc?['status'] is Map)
          ? (gsc?['status'] as Map).cast<String, dynamic>()
          : <String, dynamic>{}),
    };
    final Map<String, dynamic>? gscLatest =
        gsc?['latest'] is Map
            ? (gsc?['latest'] as Map).cast<String, dynamic>()
            : null;
    final List<Map<String, dynamic>> gscTrend =
        gsc?['trend'] is List
            ? (gsc?['trend'] as List)
                .whereType<Map>()
                .map((Map row) => row.cast<String, dynamic>())
                .toList()
            : <Map<String, dynamic>>[];
    final Map<String, dynamic>? gscSummary =
        gsc?['summary'] is Map
            ? (gsc?['summary'] as Map).cast<String, dynamic>()
            : null;
    final int gscMaxClicks = gscTrend.fold<int>(
      1,
      (int prev, Map<String, dynamic> row) =>
          math.max(prev, _toInt(row['clicks'])),
    );
    final String syncError =
        (gscStatus['sync_error'] ?? gscMessage).toString().trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết dự án')),
      body: SafeArea(
        child:
            loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tiến độ: ${(project?['progress_percent'] ?? 0)}%',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Hạn chót: ${_formatDate((project?['deadline'] ?? '').toString())}',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Phụ trách: ${(project?['owner']?['name'] ?? '—').toString()}',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Bàn giao: ${_handoverLabel((project?['handover_status'] ?? '').toString())}',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Website: ${websiteUrl.isEmpty ? '—' : websiteUrl}',
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                              if (((project?['handover_review_note'] ?? '')
                                      .toString()
                                      .trim())
                                  .isNotEmpty) ...<Widget>[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.warning.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'Ghi chú phản hồi: ${(project?['handover_review_note'] ?? '').toString()}',
                                    style: const TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if ((project?['permissions']?['can_submit_handover'] ==
                                  true)) ...<Widget>[
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        submittingHandover
                                            ? null
                                            : _submitHandover,
                                    icon: const Icon(
                                      Icons.assignment_turned_in_outlined,
                                    ),
                                    label: Text(
                                      submittingHandover
                                          ? 'Đang gửi duyệt...'
                                          : 'Gửi duyệt bàn giao dự án',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Nút này chỉ hoạt động khi tiến độ dự án đạt từ ${(project?['handover_min_progress_percent'] ?? 90)}% trở lên.',
                                  style: const TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              Row(
                                children: <Widget>[
                                  const Expanded(
                                    child: Text(
                                      'Google Search Console',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (websiteUrl.isNotEmpty)
                                    TextButton(
                                      onPressed:
                                          gscSyncing || gscLoading
                                              ? null
                                              : _syncGscNow,
                                      child: Text(
                                        gscSyncing
                                            ? 'Đang sync...'
                                            : 'Đồng bộ ngay',
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tự cập nhật theo ngày và hiển thị so sánh clicks/impressions trong chi tiết dự án.',
                                style: TextStyle(
                                  color: StitchTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              if (websiteUrl.isEmpty) ...<Widget>[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.warning.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'Dự án chưa có website_url. Hãy cập nhật URL website để bật thống kê Search Console.',
                                    style: TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  gscStatus['can_sync'] == false) ...<Widget>[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.warning.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'Chưa thể đồng bộ Search Console. Kiểm tra cấu hình GSC trong Cài đặt hệ thống.',
                                    style: TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  syncError.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: StitchTheme.danger.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'Lỗi đồng bộ gần nhất: $syncError',
                                    style: const TextStyle(
                                      color: StitchTheme.textMain,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  gscLoading) ...<Widget>[
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(minHeight: 4),
                                const SizedBox(height: 8),
                                const Text(
                                  'Đang tải dữ liệu Search Console...',
                                  style: TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  !gscLoading &&
                                  gscLatest != null) ...<Widget>[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    _GscMetricCard(
                                      label: 'Ngày thống kê',
                                      value: _formatDate(
                                        (gscLatest['metric_date'] ?? '')
                                            .toString(),
                                      ),
                                      subLabel:
                                          'So với ${_formatDate((gscLatest['prior_date'] ?? '').toString())}',
                                    ),
                                    _GscMetricCard(
                                      label: 'Clicks',
                                      value: _formatNumber(
                                        gscLatest['last_clicks'],
                                      ),
                                      subLabel:
                                          '${_formatSigned(gscLatest['delta_clicks'])} (${_formatPercent(gscLatest['delta_clicks_percent'])})',
                                      positive:
                                          _toInt(gscLatest['delta_clicks']) >=
                                          0,
                                    ),
                                    _GscMetricCard(
                                      label: 'Impressions',
                                      value: _formatNumber(
                                        gscLatest['last_impressions'],
                                      ),
                                      subLabel: _formatSigned(
                                        gscLatest['delta_impressions'],
                                      ),
                                      positive:
                                          _toInt(
                                            gscLatest['delta_impressions'],
                                          ) >=
                                          0,
                                    ),
                                    _GscMetricCard(
                                      label: 'Alerts',
                                      value: _formatNumber(
                                        gscLatest['alerts_total'],
                                      ),
                                      subLabel:
                                          'Brand ${_toInt(gscLatest['alerts_brand'])} • Recipes ${_toInt(gscLatest['alerts_recipes'])}',
                                    ),
                                  ],
                                ),
                                if (gscTrend.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          'Biểu đồ cột clicks (${_toInt(gscSummary?['days'] ?? gscTrend.length)} ngày)',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'TB/ngày: ${_formatNumber(gscSummary?['avg_clicks_per_day'] ?? 0)}',
                                        style: const TextStyle(
                                          color: StitchTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children:
                                          gscTrend.map((
                                            Map<String, dynamic> item,
                                          ) {
                                            final int clicks = _toInt(
                                              item['clicks'],
                                            );
                                            final int delta = _toInt(
                                              item['delta_clicks'],
                                            );
                                            final double ratio =
                                                gscMaxClicks <= 0
                                                    ? 0
                                                    : clicks / gscMaxClicks;
                                            final double normalized = math.max(
                                              0.04,
                                              ratio,
                                            );
                                            final double barHeight =
                                                clicks <= 0
                                                    ? 6
                                                    : 18 + (normalized * 110);
                                            return Container(
                                              width: 44,
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: <Widget>[
                                                  SizedBox(
                                                    height: 148,
                                                    child: Align(
                                                      alignment:
                                                          Alignment
                                                              .bottomCenter,
                                                      child: Container(
                                                        width: 24,
                                                        height: barHeight,
                                                        decoration: BoxDecoration(
                                                          color: (delta >= 0
                                                                  ? StitchTheme
                                                                      .success
                                                                  : StitchTheme
                                                                      .danger)
                                                              .withValues(
                                                                alpha: 0.85,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _formatShortDate(
                                                      (item['date'] ?? '')
                                                          .toString(),
                                                    ),
                                                    style: const TextStyle(
                                                      color:
                                                          StitchTheme.textMuted,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatNumber(clicks),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                              if (websiteUrl.isNotEmpty &&
                                  !gscLoading &&
                                  gscLatest == null) ...<Widget>[
                                const SizedBox(height: 12),
                                const Text(
                                  'Chưa có dữ liệu Search Console cho dự án này.',
                                  style: TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Công việc trong dự án',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...tasks.map((Map<String, dynamic> task) {
                          final String title =
                              (task['title'] ?? 'Công việc').toString();
                          final String status =
                              (task['status'] ?? '').toString();
                          final int progress =
                              (task['progress_percent'] ?? 0) is int
                                  ? task['progress_percent'] as int
                                  : int.tryParse(
                                        '${task['progress_percent'] ?? 0}',
                                      ) ??
                                      0;
                          final String deadline =
                              (task['deadline'] ?? '').toString();
                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<Widget>(
                                  builder:
                                      (_) => TaskDetailScreen(
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
                                    style: const TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (deadline.isNotEmpty)
                                    Text(
                                      'Deadline: ${_formatDate(deadline)}',
                                      style: const TextStyle(
                                        color: StitchTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (tasks.isEmpty)
                          const Text(
                            'Chưa có công việc nào.',
                            style: TextStyle(color: StitchTheme.textMuted),
                          ),
                      ],
                    ],
                  ),
                ),
      ),
    );
  }
}

class _GscMetricCard extends StatelessWidget {
  const _GscMetricCard({
    required this.label,
    required this.value,
    this.subLabel,
    this.positive,
  });

  final String label;
  final String value;
  final String? subLabel;
  final bool? positive;

  @override
  Widget build(BuildContext context) {
    Color subColor = StitchTheme.textMuted;
    if (positive != null) {
      subColor = positive == true ? StitchTheme.success : StitchTheme.danger;
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if ((subLabel ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(subLabel!, style: TextStyle(color: subColor, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

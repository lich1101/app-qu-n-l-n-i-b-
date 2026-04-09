import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';
import '../projects/project_detail_screen.dart';

class HandoverCenterScreen extends StatefulWidget {
  const HandoverCenterScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<HandoverCenterScreen> createState() => _HandoverCenterScreenState();
}

class _HandoverCenterScreenState extends State<HandoverCenterScreen> {
  bool _loading = true;
  String _message = '';
  String _search = '';
  bool _ownerOnly = false;
  int? _currentUserId;
  String _currentUserRole = '';
  List<Map<String, dynamic>> _projects = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    final List<dynamic> responses =
        await Future.wait<dynamic>(<Future<dynamic>>[
          widget.apiService.getProjectHandovers(widget.token, perPage: 100),
          widget.apiService.me(widget.token),
        ]);
    final List<Map<String, dynamic>> rows =
        responses[0] as List<Map<String, dynamic>>;
    final Map<String, dynamic> mePayload = responses[1] as Map<String, dynamic>;
    final Map<String, dynamic> meBody =
        (mePayload['body'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    if (!mounted) return;
    final dynamic rawUserId = meBody['id'];
    final int? resolvedUserId =
        rawUserId is int ? rawUserId : int.tryParse('${rawUserId ?? ''}');
    final String role = (meBody['role'] ?? '').toString();
    setState(() {
      _projects = rows;
      _currentUserId = resolvedUserId;
      _currentUserRole = role;
      _ownerOnly = role == 'nhan_vien';
      _loading = false;
      _message =
          rows.isEmpty ? 'Hiện chưa có dự án nào đang chờ duyệt bàn giao.' : '';
    });
  }

  List<Map<String, dynamic>> get _filteredProjects {
    final String keyword = _search.trim().toLowerCase();
    return _projects.where((Map<String, dynamic> project) {
      if (_ownerOnly &&
          NumberParser.toInt(project['owner_id']) != (_currentUserId ?? 0)) {
        return false;
      }
      if (keyword.isEmpty) return true;
      return <Object?>[
        project['name'],
        project['code'],
        (project['owner'] as Map<String, dynamic>?)?['name'],
        (project['contract'] as Map<String, dynamic>?)?['code'],
        (project['contract'] as Map<String, dynamic>?)?['title'],
        (project['handoverRequester'] as Map<String, dynamic>?)?['name'],
        project['handover_review_note'],
      ].whereType<Object>().join(' ').toLowerCase().contains(keyword);
    }).toList();
  }

  String _handoverLabel(String value) {
    switch (value) {
      case 'pending':
        return 'Chờ duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return 'Chưa gửi duyệt';
    }
  }

  Color _handoverColor(String value) {
    switch (value) {
      case 'approved':
        return StitchTheme.success;
      case 'rejected':
        return StitchTheme.danger;
      case 'pending':
      default:
        return StitchTheme.warning;
    }
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty) return '—';
    final DateTime? dt = VietnamTime.parse(raw);
    if (dt == null) return raw;
    return VietnamTime.formatDateTime(dt);
  }

  Future<void> _openProject(Map<String, dynamic> project) async {
    final int projectId = NumberParser.toInt(project['id']);
    if (projectId <= 0) return;
    await Navigator.of(context).push(
      MaterialPageRoute<Widget>(
        builder:
            (_) => ProjectDetailScreen(
              token: widget.token,
              apiService: widget.apiService,
              projectId: projectId,
            ),
      ),
    );
    await _fetch();
  }

  Future<void> _openReviewSheet(
    Map<String, dynamic> project,
    String decision,
  ) async {
    final TextEditingController reasonCtrl = TextEditingController();
    bool saving = false;
    String localMessage = '';
    final bool approve = decision == 'approved';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final double bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> submit() async {
              if (saving) return;
              final String reason = reasonCtrl.text.trim();
              if (!approve && reason.isEmpty) {
                setModalState(() {
                  localMessage = 'Vui lòng nhập lý do từ chối bàn giao.';
                });
                return;
              }
              setModalState(() {
                saving = true;
                localMessage = '';
              });
              final bool ok = await widget.apiService.reviewProjectHandover(
                widget.token,
                NumberParser.toInt(project['id']),
                decision: decision,
                reason: reason,
              );
              if (!mounted || !ctx.mounted) return;
              if (ok) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      approve
                          ? 'Đã duyệt bàn giao dự án.'
                          : 'Đã từ chối bàn giao dự án.',
                    ),
                  ),
                );
                await _fetch();
              } else {
                setModalState(() {
                  saving = false;
                  localMessage =
                      approve
                          ? 'Duyệt bàn giao thất bại.'
                          : 'Từ chối bàn giao thất bại.';
                });
              }
            }

            return Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
              decoration: BoxDecoration(
                color: StitchTheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: StitchTheme.textMain.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: StitchTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: approve
                                ? StitchTheme.successSoft
                                : StitchTheme.dangerSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            approve
                                ? Icons.verified_outlined
                                : Icons.cancel_outlined,
                            color: approve
                                ? StitchTheme.successStrong
                                : StitchTheme.dangerStrong,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                approve
                                    ? 'Duyệt phiếu bàn giao'
                                    : 'Từ chối phiếu bàn giao',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: StitchTheme.textMain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (project['name'] ?? 'Dự án').toString(),
                                style: const TextStyle(
                                  color: StitchTheme.textMuted,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ReviewInfoRow(
                      label: 'Người gửi duyệt',
                      value:
                          ((project['handoverRequester'] as Map?)?['name'] ??
                                  (project['owner'] as Map?)?['name'] ??
                                  '—')
                              .toString(),
                    ),
                    const SizedBox(height: 10),
                    _ReviewInfoRow(
                      label: 'Tiến độ hiện tại',
                      value:
                          '${NumberParser.toInt(project['progress_percent'])}%',
                    ),
                    const SizedBox(height: 10),
                    _ReviewInfoRow(
                      label: 'Thời gian gửi',
                      value: _formatDateTime(
                        (project['handover_requested_at'] ?? '').toString(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Lý do / ghi chú phản hồi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: stitchSheetInputDecoration(
                        context,
                        label:
                            approve
                                ? 'Ghi chú duyệt (tuỳ chọn)'
                                : 'Lý do từ chối duyệt *',
                        hint:
                            approve
                                ? 'Nhập ghi chú duyệt (nếu cần)'
                                : 'Nhập lý do từ chối để gửi về phụ trách dự án',
                      ),
                    ),
                    if (localMessage.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      StitchFeedbackBanner(
                        message: localMessage,
                        isError: true,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton(
                            onPressed: saving ? null : submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: approve
                                  ? StitchTheme.successStrong
                                  : StitchTheme.dangerStrong,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              saving
                                  ? 'Đang xử lý...'
                                  : (approve
                                      ? 'Xác nhận duyệt'
                                      : 'Gửi từ chối'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                saving ? null : () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: StitchTheme.border),
                              foregroundColor: StitchTheme.textMain,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Đóng'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rows = _filteredProjects;
    Map<String, dynamic> readPermissions(Map<String, dynamic> project) =>
        project['permissions'] is Map<String, dynamic>
            ? project['permissions'] as Map<String, dynamic>
            : <String, dynamic>{};
    final int canReviewCount =
        _projects
            .where(
              (Map<String, dynamic> project) =>
                  readPermissions(project)['can_review_handover'] == true,
            )
            .length;
    final int ownerQueueCount =
        _projects
            .where(
              (Map<String, dynamic> project) =>
                  NumberParser.toInt(project['owner_id']) ==
                  (_currentUserId ?? 0),
            )
            .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Bàn giao dự án')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
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
                    const Text(
                      'Hàng đợi duyệt bàn giao',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chỉ các dự án đã gửi duyệt bàn giao mới hiển thị ở đây. Admin và nhân viên lên hợp đồng của dự án có quyền phản hồi duyệt hoặc từ chối.',
                      style: TextStyle(
                        color: StitchTheme.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _SummaryChip(
                            label: 'Phiếu chờ duyệt',
                            value: _projects.length.toString(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryChip(
                            label: 'Bạn có thể duyệt',
                            value: canReviewCount.toString(),
                            tone: StitchTheme.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryChip(
                            label: 'Dự án bạn phụ trách',
                            value: ownerQueueCount.toString(),
                            tone: StitchTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StitchFilterCard(
                      title: 'Bộ lọc bàn giao',
                      subtitle:
                          'Tìm nhanh theo dự án, hợp đồng hoặc người gửi phiếu bàn giao.',
                      trailing: null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          StitchFilterField(
                            label: 'Từ khóa',
                            child: TextField(
                              onChanged:
                                  (String value) =>
                                      setState(() => _search = value),
                              decoration: const InputDecoration(
                                hintText: 'Tìm dự án / hợp đồng / người gửi',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          if (_currentUserRole == 'nhan_vien') ...<Widget>[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: StitchTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SwitchListTile.adaptive(
                                value: _ownerOnly,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Chỉ dự án tôi phụ trách'),
                                subtitle: const Text(
                                  'Ẩn các phiếu bàn giao ngoài phạm vi dự án bạn đang phụ trách.',
                                ),
                                onChanged:
                                    (bool value) =>
                                        setState(() => _ownerOnly = value),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_message.isNotEmpty || rows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Text(
                    _message.isNotEmpty
                        ? _message
                        : 'Không có phiếu bàn giao phù hợp với bộ lọc.',
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                )
              else
                ...rows.map((Map<String, dynamic> project) {
                  final String handoverStatus =
                      (project['handover_status'] ?? '').toString();
                  final Color statusColor = _handoverColor(handoverStatus);
                  final Map<String, dynamic> permissions = readPermissions(
                    project,
                  );
                  final bool canReview =
                      permissions['can_review_handover'] == true;
                  final Map<String, dynamic>? contract =
                      project['contract'] is Map<String, dynamic>
                          ? project['contract'] as Map<String, dynamic>
                          : null;
                  final dynamic collectorRaw =
                      contract == null ? null : contract['collector'];
                  final Map<String, dynamic>? collector =
                      collectorRaw is Map<String, dynamic>
                          ? collectorRaw
                          : null;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    (project['name'] ?? 'Dự án').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mã dự án: ${(project['code'] ?? '—').toString()}',
                                    style: const TextStyle(
                                      color: StitchTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.24),
                                ),
                              ),
                              child: Text(
                                _handoverLabel(handoverStatus),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _ReviewInfoRow(
                          label: 'Phụ trách dự án',
                          value:
                              ((project['owner'] as Map?)?['name'] ?? '—')
                                  .toString(),
                        ),
                        const SizedBox(height: 8),
                        _ReviewInfoRow(
                          label: 'Nhân viên lên hợp đồng',
                          value: (collector?['name'] ?? '—').toString(),
                        ),
                        const SizedBox(height: 8),
                        _ReviewInfoRow(
                          label: 'Hợp đồng',
                          value: (contract?['code'] ?? '—').toString(),
                        ),
                        const SizedBox(height: 8),
                        _ReviewInfoRow(
                          label: 'Người gửi phiếu',
                          value:
                              ((project['handoverRequester']
                                          as Map?)?['name'] ??
                                      (project['owner'] as Map?)?['name'] ??
                                      '—')
                                  .toString(),
                        ),
                        const SizedBox(height: 8),
                        _ReviewInfoRow(
                          label: 'Thời gian gửi',
                          value: _formatDateTime(
                            (project['handover_requested_at'] ?? '').toString(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ReviewInfoRow(
                          label: 'Tiến độ hiện tại',
                          value:
                              '${NumberParser.toInt(project['progress_percent'])}%',
                        ),
                        if ((project['handover_review_note'] ?? '')
                            .toString()
                            .trim()
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'Ghi chú phản hồi gần nhất',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: StitchTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (project['handover_review_note'] ?? '')
                                      .toString(),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openProject(project),
                                child: const Text('Xem dự án'),
                              ),
                            ),
                            if (canReview) ...<Widget>[
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      () =>
                                          _openReviewSheet(project, 'approved'),
                                  child: const Text('Duyệt'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      () =>
                                          _openReviewSheet(project, 'rejected'),
                                  child: const Text('Từ chối'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    this.tone = StitchTheme.textMain,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: StitchTheme.labelEmphasis,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewInfoRow extends StatelessWidget {
  const _ReviewInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class NumberParser {
  static int toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('${value ?? 0}') ?? 0;
  }
}

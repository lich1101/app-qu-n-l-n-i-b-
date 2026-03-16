import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

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
    final List<Map<String, dynamic>> data =
        await widget.apiService.getTasks(widget.token, perPage: 50);
    if (!mounted) return;
    setState(() {
      loading = false;
      tasks = data;
    });
  }

  IconData _attachmentIcon(String type) {
    final String t = type.toLowerCase();
    if (t.contains('youtube')) return Icons.play_circle_outline;
    if (t.contains('drive')) return Icons.cloud_outlined;
    if (t.contains('file')) return Icons.insert_drive_file_outlined;
    return Icons.link;
  }

  Future<void> _openHandoverSheet(Map<String, dynamic> task) async {
    final int taskId = (task['id'] ?? 0) as int;
    if (taskId <= 0) return;

    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController urlCtrl = TextEditingController();
    final TextEditingController fileCtrl = TextEditingController();
    final TextEditingController versionCtrl = TextEditingController();
    final TextEditingController noteCtrl = TextEditingController();
    String type = 'link';
    List<Map<String, dynamic>> attachments = <Map<String, dynamic>>[];
    bool sheetLoading = true;
    String sheetMessage = '';

    Future<void> refresh(StateSetter setSheetState) async {
      setSheetState(() => sheetLoading = true);
      final List<Map<String, dynamic>> data =
          await widget.apiService.getTaskAttachments(widget.token, taskId);
      setSheetState(() {
        attachments = data;
        sheetLoading = false;
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            if (sheetLoading && attachments.isEmpty) {
              refresh(setSheetState);
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
                    'Bàn giao tài liệu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (task['title'] ?? 'Công việc').toString(),
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  if (sheetLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Tài liệu đã nộp',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (attachments.isEmpty)
                          const Text(
                            'Chưa có tài liệu bàn giao.',
                            style: TextStyle(color: StitchTheme.textMuted),
                          )
                        else
                          ...attachments.map((Map<String, dynamic> a) {
                            final bool isHandover = a['is_handover'] == true;
                            final String version =
                                (a['version'] ?? '').toString();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: StitchTheme.border),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    _attachmentIcon((a['type'] ?? '').toString()),
                                    color: StitchTheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          (a['title'] ?? a['external_url'] ?? 'Tài liệu')
                                              .toString(),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          (a['external_url'] ?? a['file_path'] ?? '')
                                              .toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: StitchTheme.textMuted,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (version.isNotEmpty)
                                          Text(
                                            'v$version',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: StitchTheme.textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isHandover
                                          ? StitchTheme.success.withValues(alpha: 0.12)
                                          : StitchTheme.surfaceAlt,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isHandover ? 'Bàn giao' : 'Tham khảo',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isHandover
                                            ? StitchTheme.success
                                            : StitchTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 12),
                        const Text(
                          'Nộp tài liệu mới',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: type,
                          decoration: const InputDecoration(labelText: 'Loại liên kết'),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'link',
                              child: Text('Liên kết tài liệu'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'drive',
                              child: Text('Google Drive'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'youtube',
                              child: Text('YouTube'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'file',
                              child: Text('File nội bộ'),
                            ),
                          ],
                          onChanged: (String? value) {
                            if (value == null) return;
                            setSheetState(() => type = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(labelText: 'Tiêu đề'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: urlCtrl,
                          decoration: const InputDecoration(labelText: 'Liên kết/URL'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: fileCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Đường dẫn tệp nội bộ (tuỳ chọn)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final FilePickerResult? result =
                                await FilePicker.platform.pickFiles();
                            final String? path = result?.files.single.path;
                            if (path != null) {
                              setSheetState(() => fileCtrl.text = path);
                            }
                          },
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Chọn file từ thiết bị'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: versionCtrl,
                          decoration: const InputDecoration(labelText: 'Phiên bản (vd: 2)'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteCtrl,
                          decoration: const InputDecoration(labelText: 'Ghi chú'),
                        ),
                        const SizedBox(height: 10),
                        if (sheetMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(sheetMessage),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (urlCtrl.text.trim().isEmpty &&
                                  fileCtrl.text.trim().isEmpty) {
                                setSheetState(() {
                                  sheetMessage =
                                      'Vui lòng nhập liên kết hoặc đường dẫn tệp.';
                                });
                                return;
                              }
                              final int? version = versionCtrl.text.trim().isEmpty
                                  ? null
                                  : int.tryParse(versionCtrl.text.trim());
                              final String filePath = fileCtrl.text.trim();
                              final String externalUrl = urlCtrl.text.trim();
                              final String effectiveType =
                                  filePath.isNotEmpty ? 'file' : type;
                              final bool ok =
                                  await widget.apiService.createTaskAttachment(
                                widget.token,
                                taskId,
                                type: effectiveType,
                                title: titleCtrl.text.trim().isEmpty
                                    ? null
                                    : titleCtrl.text.trim(),
                                externalUrl:
                                    externalUrl.isEmpty ? null : externalUrl,
                                filePath: filePath.isEmpty ? null : filePath,
                                version: version,
                                note: noteCtrl.text.trim().isEmpty
                                    ? null
                                    : noteCtrl.text.trim(),
                                isHandover: true,
                              );
                              if (!mounted) return;
                              setSheetState(() {
                                sheetMessage = ok
                                    ? 'Đã nộp tài liệu bàn giao.'
                                    : 'Nộp tài liệu thất bại.';
                              });
                              if (ok) {
                                titleCtrl.clear();
                                urlCtrl.clear();
                                fileCtrl.clear();
                                versionCtrl.clear();
                                noteCtrl.clear();
                                refresh(setSheetState);
                              }
                            },
                            child: const Text('Nộp bàn giao'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    urlCtrl.dispose();
    fileCtrl.dispose();
    versionCtrl.dispose();
    noteCtrl.dispose();
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final String title = (task['title'] ?? 'Công việc').toString();
    final String projectName =
        ((task['project'] as Map<String, dynamic>?)?['name'] ?? 'Dự án')
            .toString();
    final int attachments = (task['attachments_count'] ?? 0) is int
        ? task['attachments_count'] as int
        : int.tryParse('${task['attachments_count'] ?? 0}') ?? 0;
    final String status = (task['status'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '$projectName • $status',
                  style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                ),
              ],
            ),
          ),
          Column(
            children: <Widget>[
              Text(
                attachments.toString(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Text(
                'Tài liệu',
                style: TextStyle(fontSize: 10, color: StitchTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => _openHandoverSheet(task),
            child: const Text('Bàn giao'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> withFiles = tasks
        .where((Map<String, dynamic> t) {
          final int attachments = (t['attachments_count'] ?? 0) is int
              ? t['attachments_count'] as int
              : int.tryParse('${t['attachments_count'] ?? 0}') ?? 0;
          return attachments > 0;
        })
        .toList();

    final List<Map<String, dynamic>> withoutFiles = tasks
        .where((Map<String, dynamic> t) {
          final int attachments = (t['attachments_count'] ?? 0) is int
              ? t['attachments_count'] as int
              : int.tryParse('${t['attachments_count'] ?? 0}') ?? 0;
          return attachments == 0;
        })
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bàn giao & tài liệu')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            const StitchHeroCard(
              title: 'Bàn giao nội dung',
              subtitle: 'Lưu trữ liên kết/video và lịch sử bàn giao theo công việc.',
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
                  icon: Icons.cloud_upload_outlined,
                  label: 'Đã nộp',
                  value: withFiles.length.toString(),
                  accent: StitchTheme.success,
                ),
                StitchMetricCard(
                  icon: Icons.pending_actions,
                  label: 'Chờ bàn giao',
                  value: withoutFiles.length.toString(),
                  accent: StitchTheme.warning,
                ),
              ],
            ),
            if (message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(message, style: const TextStyle(color: StitchTheme.textMuted)),
            ],
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 12),
            const StitchSectionHeader(title: 'Đã nộp tài liệu'),
            const SizedBox(height: 8),
            if (withFiles.isEmpty)
              const Text(
                'Chưa có công việc bàn giao.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              ...withFiles.map(_buildTaskCard),
            const SizedBox(height: 12),
            const StitchSectionHeader(title: 'Chưa nộp'),
            const SizedBox(height: 8),
            if (withoutFiles.isEmpty)
              const Text(
                'Tất cả công việc đã có tài liệu.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              ...withoutFiles.take(8).map(_buildTaskCard),
          ],
        ),
      ),
    );
  }
}

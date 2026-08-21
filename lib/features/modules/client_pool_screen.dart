import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/app_firebase.dart';
import '../../core/messaging/app_tag_message.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_list_pagination.dart';
import '../../data/services/mobile_api_service.dart';

class ClientPoolScreen extends StatefulWidget {
  const ClientPoolScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.currentUserRole,
  });

  final String token;
  final MobileApiService apiService;
  final String currentUserRole;

  @override
  State<ClientPoolScreen> createState() => _ClientPoolScreenState();
}

class _ClientPoolScreenState extends State<ClientPoolScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool loading = false;
  bool importing = false;
  String message = '';
  List<Map<String, dynamic>> clients = <Map<String, dynamic>>[];
  int currentPage = 1;
  int lastPage = 1;
  int total = 0;
  int pageSize = 20;
  int? claimingClientId;
  Timer? importPollTimer;
  StreamSubscription<DatabaseEvent>? rotationPoolRealtimeSub;
  int? importingJobId;
  String? lastRotationPoolSignalNonce;

  bool get canClaim {
    final String role = widget.currentUserRole.toLowerCase();
    return role == 'quan_ly' || role == 'nhan_vien';
  }

  bool get canManagePoolEntries {
    final String role = widget.currentUserRole.toLowerCase();
    return role == 'admin' ||
        role == 'administrator' ||
        role == 'quan_ly' ||
        role == 'nhan_vien';
  }

  @override
  void initState() {
    super.initState();
    _bindRealtime();
    _fetch();
  }

  @override
  void dispose() {
    importPollTimer?.cancel();
    rotationPoolRealtimeSub?.cancel();
    searchCtrl.dispose();
    scrollController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  Future<void> _bindRealtime() async {
    if (!AppFirebase.isConfigured) {
      return;
    }
    try {
      await AppFirebase.ensureInitialized();
      final String? firebaseToken = await widget.apiService.getFirebaseToken(
        widget.token,
      );
      if (firebaseToken == null || firebaseToken.isEmpty) {
        return;
      }
      final bool authed = await AppFirebase.signInWithCustomToken(
        firebaseToken,
      );
      if (!authed) {
        return;
      }
      await rotationPoolRealtimeSub?.cancel();
      rotationPoolRealtimeSub = AppFirebase.rotationPoolSignalStream()?.listen((
        DatabaseEvent event,
      ) async {
        if (!mounted || importing || claimingClientId != null) {
          return;
        }
        final dynamic raw = event.snapshot.value;
        if (raw is! Map) {
          return;
        }
        final String nonce = (raw['nonce'] ?? '').toString().trim();
        if (nonce.isEmpty) {
          return;
        }
        if (lastRotationPoolSignalNonce == null) {
          lastRotationPoolSignalNonce = nonce;
          return;
        }
        if (lastRotationPoolSignalNonce == nonce) {
          return;
        }
        lastRotationPoolSignalNonce = nonce;
        await _fetch(page: currentPage, search: searchCtrl.text.trim());
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _loadPoolPayload({
    required int page,
    required String search,
  }) async {
    if (pageSize > 0) {
      return widget.apiService.getRotationPoolClients(
        widget.token,
        page: page,
        perPage: pageSize,
        search: search,
      );
    }

    // Chế độ "Tất cả": đọc nhiều trang nhỏ để không phụ thuộc giới hạn
    // per_page phía API và tránh một request quá lớn.
    const int chunkSize = 100;
    final Map<String, dynamic> first = await widget.apiService
        .getRotationPoolClients(
          widget.token,
          page: 1,
          perPage: chunkSize,
          search: search,
        );
    final List<Map<String, dynamic>> allRows =
        ((first['data'] ?? <dynamic>[]) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
            .toList();
    final int remoteLastPage = _toInt(first['last_page'], 1);

    for (int remotePage = 2; remotePage <= remoteLastPage; remotePage++) {
      final Map<String, dynamic> next = await widget.apiService
          .getRotationPoolClients(
            widget.token,
            page: remotePage,
            perPage: chunkSize,
            search: search,
          );
      final List<dynamic> rows =
          (next['data'] ?? <dynamic>[]) as List<dynamic>;
      allRows.addAll(
        rows
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row)),
      );
    }

    return <String, dynamic>{
      ...first,
      'data': allRows,
      'current_page': 1,
      'last_page': 1,
      'total': _toInt(first['total'], allRows.length),
    };
  }

  Future<void> _fetch({int page = 1, String? search}) async {
    setState(() => loading = true);

    final String normalizedSearch = (search ?? searchCtrl.text).trim();
    final int requestedPage = pageSize == 0 ? 1 : page;
    final Map<String, dynamic> payload = await _loadPoolPayload(
      page: requestedPage,
      search: normalizedSearch,
    );

    if (!mounted) return;

    final List<dynamic> rows =
        (payload['data'] ?? <dynamic>[]) as List<dynamic>;
    final int rawLastPage = _toInt(payload['last_page'], 1);
    final int safeLastPage = rawLastPage < 1 ? 1 : rawLastPage;
    final int rawCurrentPage = _toInt(payload['current_page'], requestedPage);
    final int safeCurrentPage =
        rawCurrentPage < 1
            ? 1
            : (rawCurrentPage > safeLastPage
                ? safeLastPage
                : rawCurrentPage);
    final List<Map<String, dynamic>> normalizedRows =
        rows
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
            .toList();

    setState(() {
      clients = normalizedRows;
      currentPage = safeCurrentPage;
      lastPage = safeLastPage;
      total = _toInt(payload['total'], normalizedRows.length);
      loading = false;
    });
  }

  Future<void> _changePage(int page) async {
    if (loading || pageSize == 0 || page < 1 || page > lastPage) return;
    await _fetch(page: page);
  }

  Future<void> _changePageSize(int value) async {
    if (loading || value == pageSize) return;
    setState(() {
      pageSize = value;
      currentPage = 1;
    });
    await _fetch(page: 1);
  }

  Future<void> _claimClient(Map<String, dynamic> client) async {
    final int clientId = int.tryParse('${client['id'] ?? 0}') ?? 0;
    if (clientId <= 0 || claimingClientId == clientId) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext c) => AlertDialog(
            title: const Text('Nhận khách hàng?'),
            content: Text(
              'Khi nhận "${(client['name'] ?? 'Khách hàng').toString()}", hệ thống sẽ reset lại mốc xoay và dọn nhóm chăm sóc cũ để chỉ còn bạn là người phụ trách/chăm sóc chính.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Nhận khách'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => claimingClientId = clientId);
    final Map<String, dynamic> result = await widget.apiService
        .claimRotationPoolClient(widget.token, clientId);

    if (!mounted) {
      return;
    }

    if (result['ok'] == true) {
      AppTagMessage.show(
        'Đã nhận khách hàng từ kho số và reset lại mốc xoay.',
        duration: const Duration(seconds: 4),
      );
      setState(() => message = 'Đã nhận khách hàng từ kho số.');
      await _fetch(page: currentPage);
    } else {
      final String errorMessage =
          (result['message'] ?? 'Không thể nhận khách từ kho số.').toString();
      AppTagMessage.show(
        errorMessage,
        duration: const Duration(seconds: 5),
        isError: true,
      );
      setState(() => message = errorMessage);
      await _fetch(page: currentPage, search: searchCtrl.text.trim());
    }

    if (!mounted) {
      return;
    }
    setState(() => claimingClientId = null);
  }

  Future<void> _downloadTemplate() async {
    try {
      final Uint8List bytes = await widget.apiService
          .downloadRotationPoolTemplate(widget.token);
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/mau-import-kho-so.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(<XFile>[
        XFile(file.path),
      ], text: 'Mẫu import kho số');
    } catch (_) {
      if (!mounted) return;
      AppTagMessage.show('Không tải được file mẫu kho số.', isError: true);
    }
  }

  Future<void> _importPoolClients() async {
    if (!canManagePoolEntries) {
      setState(() => message = 'Bạn không có quyền import khách vào kho số.');
      return;
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xls', 'xlsx', 'xlsm', 'csv', 'tsv', 'ods'],
    );
    if (result == null || result.files.single.path == null) return;

    final File file = File(result.files.single.path!);
    setState(() {
      importing = true;
      message = 'Đã đưa file import kho số vào hàng đợi xử lý.';
    });

    final Map<String, dynamic> response = await widget.apiService
        .importRotationPoolClients(widget.token, file);

    if (!mounted) return;

    if (response['ok'] != true) {
      final String errorMessage =
          (response['message'] ?? 'Import kho số thất bại.').toString();
      AppTagMessage.show(errorMessage, isError: true);
      setState(() {
        importing = false;
        message = errorMessage;
      });
      return;
    }

    final dynamic job = response['job'];
    final int jobId = job is Map ? int.tryParse('${job['id'] ?? 0}') ?? 0 : 0;
    if (jobId <= 0) {
      setState(() => importing = false);
      await _fetch();
      return;
    }

    AppTagMessage.show(
      'Đã đưa file import kho số vào hàng đợi xử lý.',
      duration: const Duration(seconds: 4),
    );
    _startImportPolling(jobId);
  }

  void _startImportPolling(int jobId) {
    importPollTimer?.cancel();
    importingJobId = jobId;
    importPollTimer = Timer.periodic(const Duration(seconds: 2), (
      Timer timer,
    ) async {
      final Map<String, dynamic> payload = await widget.apiService.getImportJob(
        widget.token,
        jobId,
      );
      if (!mounted) {
        timer.cancel();
        return;
      }

      final String status = (payload['status'] ?? '').toString();
      if (status == 'completed') {
        timer.cancel();
        importingJobId = null;
        final Map<String, dynamic> report =
            (payload['report'] is Map<String, dynamic>)
                ? payload['report'] as Map<String, dynamic>
                : <String, dynamic>{};
        final String summary =
            'Import kho số hoàn tất: ${report['created'] ?? 0} tạo mới, ${report['updated'] ?? 0} cập nhật, ${report['skipped'] ?? 0} bỏ qua.';
        AppTagMessage.show(summary, duration: const Duration(seconds: 5));
        setState(() {
          importing = false;
          message = summary;
        });
        await _fetch();
      } else if (status == 'failed') {
        timer.cancel();
        importingJobId = null;
        final String errorMessage =
            (payload['error_message'] ?? 'Import kho số thất bại.').toString();
        AppTagMessage.show(errorMessage, isError: true);
        setState(() {
          importing = false;
          message = errorMessage;
        });
      }
    });
  }

  Future<void> _openCreatePoolDialog() async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController codeCtrl = TextEditingController();
    final TextEditingController companyCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController notesCtrl = TextEditingController();
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder:
          (BuildContext dialogContext) => StatefulBuilder(
            builder: (
              BuildContext context,
              void Function(void Function()) setModalState,
            ) {
              Future<void> submit() async {
                if (saving) return;
                if (nameCtrl.text.trim().isEmpty) {
                  AppTagMessage.show(
                    'Vui lòng nhập tên khách hàng.',
                    isError: true,
                  );
                  return;
                }
                setModalState(() => saving = true);
                final Map<String, dynamic> response = await widget.apiService
                    .createRotationPoolClientWithMeta(
                      widget.token,
                      name: nameCtrl.text.trim(),
                      externalCode:
                          codeCtrl.text.trim().isEmpty
                              ? null
                              : codeCtrl.text.trim(),
                      company:
                          companyCtrl.text.trim().isEmpty
                              ? null
                              : companyCtrl.text.trim(),
                      email:
                          emailCtrl.text.trim().isEmpty
                              ? null
                              : emailCtrl.text.trim(),
                      phone:
                          phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                      notes:
                          notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                    );
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                if (response['ok'] == true) {
                  Navigator.of(dialogContext).pop();
                  AppTagMessage.show(
                    'Đã thêm khách hàng vào kho số.',
                    duration: const Duration(seconds: 4),
                  );
                  setState(() => message = 'Đã thêm khách hàng vào kho số.');
                  await _fetch();
                  return;
                }

                final String errorMessage =
                    (response['message'] ?? 'Không thể thêm khách vào kho số.')
                        .toString();
                AppTagMessage.show(errorMessage, isError: true);
                setModalState(() => saving = false);
              }

              return AlertDialog(
                title: const Text('Thêm khách hàng vào kho số'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tên khách hàng *',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mã khách hàng',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: companyCtrl,
                        decoration: const InputDecoration(labelText: 'Công ty'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Ghi chú'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Khách tạo tại đây sẽ vào thẳng kho số. Khi có người nhận, hệ thống sẽ reset lại mốc xoay và chỉ giữ người đó là phụ trách/chăm sóc chính.',
                        style: TextStyle(
                          fontSize: 12,
                          color: StitchTheme.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed:
                        saving ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: saving ? null : submit,
                    child: Text(saving ? 'Đang lưu...' : 'Thêm vào kho số'),
                  ),
                ],
              );
            },
          ),
    );

    nameCtrl.dispose();
    codeCtrl.dispose();
    companyCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    notesCtrl.dispose();
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: StitchTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: StitchTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: StitchTheme.primaryStrong),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required int value,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(color: tint, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    final double amount = double.tryParse('${value ?? 0}') ?? 0;
    final int rounded = amount.round();
    final String digits = rounded.abs().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final String prefix = rounded < 0 ? '-' : '';
    return '$prefix$digits VNĐ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.bg,
      appBar: AppBar(title: const Text('Kho số')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetch(page: currentPage),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: StitchTheme.border),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Khách chờ nhận thủ công',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Kho số chỉ hiển thị tên khách hàng cùng số cơ hội, số bình luận và doanh thu tích lũy tổng hợp. Khi nhân sự còn quota nhận kho số bấm nhận, hệ thống reset lại mốc xoay, dọn nhóm chăm sóc cũ và đưa khách quay lại CRM thường cho người vừa nhận.',
                                style: TextStyle(
                                  color: StitchTheme.textMuted,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: StitchTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: StitchTheme.border),
                          ),
                          child: Text(
                            '$total khách',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    if (canManagePoolEntries) ...<Widget>[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _openCreatePoolDialog,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Thêm khách'),
                          ),
                          OutlinedButton.icon(
                            onPressed: importing ? null : _importPoolClients,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: Text(
                              importing ? 'Đang import...' : 'Import kho số',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _downloadTemplate,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Tải mẫu XLSX'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (message.isNotEmpty) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        message.startsWith('Đã')
                            ? const Color(0xFFEFFCF5)
                            : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          message.startsWith('Đã')
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFDA4AF),
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color:
                          message.startsWith('Đã')
                              ? const Color(0xFF166534)
                              : const Color(0xFFBE123C),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      textInputAction: TextInputAction.search,
                      decoration: _inputDecoration(
                        'Tìm nhanh tên khách trong kho số',
                      ),
                      onSubmitted: (_) => _fetch(page: 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: loading ? null : () => _fetch(page: 1),
                    child: Text(loading ? 'Đang tải...' : 'Lọc'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (loading && clients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (clients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: const Text(
                    'Kho số hiện chưa có khách hàng chờ nhận.',
                    style: TextStyle(color: StitchTheme.textMuted),
                  ),
                )
              else
                ...clients.map((Map<String, dynamic> client) {
                  final int clientId =
                      int.tryParse('${client['id'] ?? 0}') ?? 0;
                  final int opportunitiesCount =
                      int.tryParse('${client['opportunities_count'] ?? 0}') ??
                      0;
                  final int careNotesCount =
                      int.tryParse('${client['care_notes_count'] ?? 0}') ?? 0;
                  final double totalRevenue =
                      double.tryParse('${client['total_revenue'] ?? 0}') ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
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
                              child: Text(
                                (client['name'] ?? 'Khách hàng').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (canClaim)
                              FilledButton(
                                onPressed:
                                    claimingClientId == clientId
                                        ? null
                                        : () => _claimClient(client),
                                child: Text(
                                  claimingClientId == clientId
                                      ? 'Đang nhận...'
                                      : 'Nhận khách',
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: StitchTheme.surfaceAlt,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: StitchTheme.border),
                                ),
                                child: const Text(
                                  'Chỉ xem',
                                  style: TextStyle(
                                    color: StitchTheme.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _buildMetricChip(
                              icon: Icons.trending_up_rounded,
                              label: 'Cơ hội',
                              value: opportunitiesCount,
                              tint: const Color(0xFF2563EB),
                            ),
                            _buildMetricChip(
                              icon: Icons.comment_rounded,
                              label: 'Bình luận',
                              value: careNotesCount,
                              tint: const Color(0xFF0F766E),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFB45309,
                                ).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(
                                    0xFFB45309,
                                  ).withValues(alpha: 0.20),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.paid_rounded,
                                    size: 16,
                                    color: Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Doanh thu: ${_formatCurrency(totalRevenue)}',
                                    style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              StitchListPagination(
                currentPage: currentPage,
                lastPage: lastPage,
                total: total,
                visibleCount: clients.length,
                pageSize: pageSize,
                loading: loading,
                itemLabel: 'khách hàng',
                onPageChanged: _changePage,
                onPageSizeChanged: _changePageSize,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

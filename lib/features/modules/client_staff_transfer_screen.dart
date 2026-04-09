import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

/// Màn xử lý phiếu chuyển phụ trách khách (mở từ push `staff_transfer_request`).
class ClientStaffTransferScreen extends StatefulWidget {
  const ClientStaffTransferScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.transferId,
    this.currentUserId,
  });

  final String token;
  final MobileApiService apiService;
  final int transferId;
  final int? currentUserId;

  @override
  State<ClientStaffTransferScreen> createState() =>
      _ClientStaffTransferScreenState();
}

class _ClientStaffTransferScreenState extends State<ClientStaffTransferScreen> {
  bool loading = true;
  Map<String, dynamic>? transfer;
  String? error;
  bool acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final raw = await widget.apiService.getStaffTransferRequest(
      widget.token,
      widget.transferId,
    );
    if (!mounted) return;
    final Map<String, dynamic>? t =
        raw['transfer'] is Map
            ? Map<String, dynamic>.from(
              raw['transfer'] as Map<dynamic, dynamic>,
            )
            : null;
    setState(() {
      transfer = t;
      loading = false;
      if (t == null) error = 'Không tải được phiếu chuyển giao.';
    });
  }

  int? _idOf(Map<String, dynamic>? m, String key) {
    if (m == null) return null;
    final v = m[key];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  Future<void> _accept() async {
    setState(() => acting = true);
    final ok = await widget.apiService.acceptStaffTransferRequest(
      widget.token,
      widget.transferId,
    );
    if (!mounted) return;
    setState(() => acting = false);
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã chấp nhận phụ trách.')));
      await _load();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể chấp nhận.')));
    }
  }

  Future<void> _reject() async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Từ chối phiếu'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'Lý do (tuỳ chọn)'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Từ chối'),
            ),
          ],
        );
      },
    );
    if (note == null) return;
    setState(() => acting = true);
    final ok = await widget.apiService.rejectStaffTransferRequest(
      widget.token,
      widget.transferId,
      rejectionNote: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    setState(() => acting = false);
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã từ chối phiếu.')));
      await _load();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể từ chối.')));
    }
  }

  Future<void> _cancel() async {
    final okConfirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Hủy phiếu?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Không'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hủy phiếu'),
              ),
            ],
          ),
    );
    if (okConfirm != true) return;
    setState(() => acting = true);
    final ok = await widget.apiService.cancelStaffTransferRequest(
      widget.token,
      widget.transferId,
    );
    if (!mounted) return;
    setState(() => acting = false);
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã hủy phiếu.')));
      await _load();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể hủy phiếu.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.currentUserId ?? 0;
    final t = transfer;
    final status = (t?['status'] ?? '').toString();
    final pending = status == 'pending';
    final toId = _idOf(
      t?['to_staff'] is Map
          ? Map<String, dynamic>.from(t!['to_staff'] as Map)
          : null,
      'id',
    );
    final fromId = _idOf(
      t?['from_staff'] is Map
          ? Map<String, dynamic>.from(t!['from_staff'] as Map)
          : null,
      'id',
    );
    final reqId = _idOf(
      t?['requested_by'] is Map
          ? Map<String, dynamic>.from(t!['requested_by'] as Map)
          : null,
      'id',
    );

    final iAmReceiver = pending && toId != null && toId == uid;
    final iAmRequesterSide =
        pending &&
        ((fromId != null && fromId == uid) || (reqId != null && reqId == uid));
    final Map<String, dynamic> permissions =
        t?['permissions'] is Map
            ? Map<String, dynamic>.from(t!['permissions'] as Map)
            : <String, dynamic>{};
    final bool canAccept = pending && permissions['can_accept'] == true;
    final bool canReject = pending && permissions['can_reject'] == true;
    final bool canCancel = pending && permissions['can_cancel'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Phiếu chuyển phụ trách')),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(child: Text(error!))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t?['client'] is Map
                          ? (t!['client']['name']?.toString() ?? 'Khách hàng')
                          : 'Khách hàng',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Trạng thái: $status'),
                    const SizedBox(height: 16),
                    if (t?['from_staff'] is Map)
                      Text('Từ: ${(t!['from_staff'] as Map)['name']}'),
                    if (t?['to_staff'] is Map)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Đến: ${(t!['to_staff'] as Map)['name']}'),
                      ),
                    if ((t?['note'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Ghi chú: ${t!['note']}'),
                    ],
                    if (pending) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (canAccept)
                            FilledButton(
                              onPressed: acting ? null : _accept,
                              child: const Text('Chấp nhận'),
                            ),
                          if (canReject)
                            OutlinedButton(
                              onPressed: acting ? null : _reject,
                              child: const Text('Từ chối'),
                            ),
                          if (canCancel)
                            OutlinedButton(
                              onPressed: acting ? null : _cancel,
                              child: const Text('Hủy phiếu'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (iAmReceiver)
                        Text(
                          'Trước khi chấp nhận, bạn chưa thể thao tác đầy đủ trên khách hàng này trong CRM.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                      if (!iAmReceiver && iAmRequesterSide && !canCancel)
                        const Text(
                          'Phiếu đang chờ xử lý bởi nhân sự nhận hoặc người có thẩm quyền.',
                          style: TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
    );
  }
}

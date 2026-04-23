import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_form_layout.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_searchable_select.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

/// Tạo / sửa cơ hội từ danh sách (full-screen).
class OpportunityListFormScreen extends StatefulWidget {
  const OpportunityListFormScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.clients,
    this.initialOpportunity,
  });

  final String token;
  final MobileApiService apiService;
  final List<Map<String, dynamic>> clients;
  final Map<String, dynamic>? initialOpportunity;

  bool get isEdit => initialOpportunity != null;

  @override
  State<OpportunityListFormScreen> createState() =>
      _OpportunityListFormScreenState();
}

class _OpportunityListFormScreenState extends State<OpportunityListFormScreen> {
  late final TextEditingController titleCtrl;
  late final TextEditingController amountCtrl;
  late final TextEditingController notesCtrl;
  late final TextEditingController sourceCtrl;

  int? clientId;
  int? successProbability;
  String? statusCode;
  List<Map<String, dynamic>> statusOptions = <Map<String, dynamic>>[];
  bool saving = false;
  String sheetMessage = '';

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  List<StitchSelectOption<String>> _statusSelectOptions() {
    final List<StitchSelectOption<String>> options =
        statusOptions
            .map((Map<String, dynamic> row) {
              final String code = (row['code'] ?? '').toString().trim();
              final String name = (row['name'] ?? '').toString().trim();
              if (code.isEmpty) return null;
              return StitchSelectOption<String>(
                value: code,
                label: name.isEmpty ? code : name,
              );
            })
            .whereType<StitchSelectOption<String>>()
            .toList();
    final String current = (statusCode ?? '').trim();
    if (current.isNotEmpty &&
        !options.any(
          (StitchSelectOption<String> item) => item.value == current,
        )) {
      final String label =
          (widget.initialOpportunity?['status_label'] ??
                  widget.initialOpportunity?['computed_status_label'] ??
                  current)
              .toString();
      options.insert(
        0,
        StitchSelectOption<String>(value: current, label: label),
      );
    }
    if (options.isEmpty) {
      return const <StitchSelectOption<String>>[
        StitchSelectOption<String>(value: 'open', label: 'Đang mở'),
        StitchSelectOption<String>(value: 'won', label: 'Thành công'),
        StitchSelectOption<String>(value: 'lost', label: 'Thất bại'),
      ];
    }
    return options;
  }

  Future<void> _loadStatusOptions() async {
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getOpportunityStatuses(widget.token);
    if (!mounted) return;
    setState(() => statusOptions = rows);
  }

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? opp = widget.initialOpportunity;
    titleCtrl = TextEditingController(
      text: opp != null ? (opp['title'] ?? '').toString() : '',
    );
    amountCtrl = TextEditingController(
      text:
          opp != null && opp['amount'] != null ? opp['amount'].toString() : '',
    );
    notesCtrl = TextEditingController(
      text: opp != null ? (opp['notes'] ?? '').toString() : '',
    );
    sourceCtrl = TextEditingController(
      text: opp != null ? (opp['source'] ?? '').toString() : '',
    );
    clientId = _toInt(opp?['client_id']);
    successProbability =
        opp == null
            ? null
            : int.tryParse(opp['success_probability']?.toString() ?? '');
    statusCode = (opp?['status'] ?? opp?['computed_status'])?.toString();
    if (successProbability != null &&
        (successProbability! < 0 || successProbability! > 100)) {
      successProbability = null;
    }
    _loadStatusOptions();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
    sourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (titleCtrl.text.trim().isEmpty || clientId == null) {
      setState(() {
        sheetMessage = 'Vui lòng nhập tên và chọn khách hàng.';
      });
      return;
    }
    final double? amt =
        amountCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(amountCtrl.text.trim());
    if (amt == null || amt < 0) {
      setState(() {
        sheetMessage = 'Vui lòng nhập doanh số dự kiến (số ≥ 0).';
      });
      return;
    }
    if (successProbability == null) {
      setState(() {
        sheetMessage = 'Vui lòng chọn tỷ lệ thành công.';
      });
      return;
    }
    setState(() {
      saving = true;
      sheetMessage = '';
    });
    final bool ok;
    if (!widget.isEdit) {
      ok = await widget.apiService.createOpportunity(
        widget.token,
        title: titleCtrl.text.trim(),
        clientId: clientId!,
        amount: amt,
        successProbability: successProbability!,
        status:
            (statusCode ?? '').trim().isEmpty
                ? null
                : (statusCode ?? '').trim(),
        source: sourceCtrl.text.trim().isEmpty ? null : sourceCtrl.text.trim(),
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
    } else {
      ok = await widget.apiService.updateOpportunity(
        widget.token,
        widget.initialOpportunity!['id'] as int,
        title: titleCtrl.text.trim(),
        clientId: clientId!,
        amount: amt,
        successProbability: successProbability!,
        status:
            (statusCode ?? '').trim().isEmpty
                ? null
                : (statusCode ?? '').trim(),
        source: sourceCtrl.text.trim().isEmpty ? null : sourceCtrl.text.trim(),
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        saving = false;
        sheetMessage = 'Lưu thất bại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.formPageBackground,
      resizeToAvoidBottomInset: true,
      appBar: stitchFormAppBar(
        context: context,
        title: widget.isEdit ? 'Cập nhật cơ hội' : 'Tạo cơ hội',
        onClose: saving ? () {} : () => Navigator.of(context).maybePop(),
      ),
      bottomNavigationBar: StitchFormBottomBar(
        primaryLoading: saving,
        primaryLabel:
            saving ? 'Đang lưu...' : (widget.isEdit ? 'Cập nhật' : 'Tạo mới'),
        onPrimary: saving ? null : _submit,
        onSecondary: saving ? null : () => Navigator.of(context).maybePop(),
        secondaryLabel: 'Hủy',
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: <Widget>[
            StitchFormSection(
              margin: EdgeInsets.zero,
              child: stitchTaskFormSheetHeader(
                context,
                subtitle:
                    'Liên kết khách hàng và doanh số dự kiến, đồng thời chọn trạng thái xử lý thủ công.',
              ),
            ),
            StitchFormSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const StitchFormSectionHeader(
                    icon: Icons.add_chart_rounded,
                    title: 'Thông tin cơ hội',
                  ),
                  TextField(
                    controller: titleCtrl,
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Tên cơ hội *',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  StitchSearchableSelectField<int>(
                    value: clientId,
                    sheetTitle: 'Chọn khách hàng',
                    label: 'Khách hàng *',
                    searchHint: 'Tìm theo tên hoặc công ty...',
                    options:
                        widget.clients
                            .where(
                              (Map<String, dynamic> c) =>
                                  _toInt(c['id']) != null,
                            )
                            .map(
                              (
                                Map<String, dynamic> c,
                              ) => StitchSelectOption<int>(
                                value: _toInt(c['id'])!,
                                label:
                                    '${c['name'] ?? ''}'
                                    '${(c['company'] ?? '').toString().isNotEmpty ? ' — ${c['company']}' : ''}',
                              ),
                            )
                            .toList(),
                    onChanged: (int? v) => setState(() => clientId = v),
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Khách hàng *',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Doanh số dự kiến (VNĐ) *',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  StitchSearchableSelectField<String>(
                    value:
                        (statusCode ?? '').trim().isEmpty
                            ? null
                            : statusCode!.trim(),
                    nullable: true,
                    nullLabel: 'Mặc định hệ thống',
                    sheetTitle: 'Trạng thái cơ hội',
                    label: 'Trạng thái cơ hội',
                    searchHint: 'Tìm trạng thái...',
                    options: _statusSelectOptions(),
                    onChanged: (String? v) {
                      setState(
                        () =>
                            statusCode =
                                (v ?? '').trim().isEmpty ? null : v!.trim(),
                      );
                    },
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Trạng thái cơ hội',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  StitchSearchableSelectField<int>(
                    value: successProbability,
                    sheetTitle: 'Tỷ lệ thành công',
                    label: 'Tỷ lệ thành công (%) *',
                    searchHint: 'Tìm %...',
                    options:
                        <int>[0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
                            .map(
                              (int v) => StitchSelectOption<int>(
                                value: v,
                                label: '$v%',
                              ),
                            )
                            .toList(),
                    onChanged:
                        (int? v) => setState(() => successProbability = v),
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Tỷ lệ thành công (%) *',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: sourceCtrl,
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Nguồn',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: notesCtrl,
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Ghi chú',
                    ),
                    maxLines: 3,
                  ),
                  if (sheetMessage.isNotEmpty) ...<Widget>[
                    SizedBox(height: kStitchTaskFormGap),
                    StitchFeedbackBanner(
                      message: sheetMessage,
                      isError: !sheetMessage.startsWith('Đã'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

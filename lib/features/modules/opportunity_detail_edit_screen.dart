import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_form_layout.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_searchable_select.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

/// Sửa cơ hội từ màn chi tiết (full-screen).
class OpportunityDetailEditScreen extends StatefulWidget {
  const OpportunityDetailEditScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.opportunityId,
    required this.opportunity,
    required this.clients,
    required this.statuses,
  });

  final String token;
  final MobileApiService apiService;
  final int opportunityId;
  final Map<String, dynamic> opportunity;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> statuses;

  @override
  State<OpportunityDetailEditScreen> createState() =>
      _OpportunityDetailEditScreenState();
}

class _OpportunityDetailEditScreenState
    extends State<OpportunityDetailEditScreen> {
  late final TextEditingController titleCtrl;
  late final TextEditingController amountCtrl;
  late final TextEditingController sourceCtrl;
  late final TextEditingController notesCtrl;
  late final TextEditingController typeCtrl;
  late final TextEditingController probabilityCtrl;
  late final TextEditingController expectedDateCtrl;

  int? clientId;
  String? statusCode;
  bool saving = false;
  String sheetMessage = '';

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  double? _toDouble(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  int? _toProbability(String value) {
    if (value.trim().isEmpty) return null;
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null) return null;
    if (parsed < 0 || parsed > 100) return null;
    return parsed;
  }

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> o = widget.opportunity;
    titleCtrl = TextEditingController(text: (o['title'] ?? '').toString());
    amountCtrl = TextEditingController(text: (o['amount'] ?? '').toString());
    sourceCtrl = TextEditingController(text: (o['source'] ?? '').toString());
    notesCtrl = TextEditingController(text: (o['notes'] ?? '').toString());
    typeCtrl = TextEditingController(
      text: (o['opportunity_type'] ?? '').toString(),
    );
    probabilityCtrl = TextEditingController(
      text: (o['success_probability'] ?? '').toString(),
    );
    expectedDateCtrl = TextEditingController(
      text: (o['expected_close_date'] ?? '').toString(),
    );
    clientId = _toInt(o['client_id']);
    final String rawStatus = (o['status'] ?? '').toString().trim();
    statusCode = rawStatus.isEmpty ? null : rawStatus;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    sourceCtrl.dispose();
    notesCtrl.dispose();
    typeCtrl.dispose();
    probabilityCtrl.dispose();
    expectedDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (titleCtrl.text.trim().isEmpty || clientId == null || clientId == 0) {
      setState(() {
        sheetMessage = 'Vui lòng nhập tên cơ hội và chọn khách hàng.';
      });
      return;
    }
    setState(() {
      sheetMessage = '';
      saving = true;
    });
    final double? amt = _toDouble(amountCtrl.text);
    if (amt == null || amt < 0) {
      setState(() {
        saving = false;
        sheetMessage = 'Vui lòng nhập doanh số dự kiến (số ≥ 0).';
      });
      return;
    }
    final int? prob = _toProbability(probabilityCtrl.text);
    if (prob == null) {
      setState(() {
        saving = false;
        sheetMessage = 'Vui lòng nhập tỷ lệ thành công (0–100%).';
      });
      return;
    }
    final bool ok = await widget.apiService.updateOpportunity(
      widget.token,
      widget.opportunityId,
      title: titleCtrl.text.trim(),
      clientId: clientId!,
      status: (statusCode ?? '').trim().isEmpty ? null : statusCode,
      amount: amt,
      source: sourceCtrl.text.trim().isEmpty ? null : sourceCtrl.text.trim(),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      opportunityType:
          typeCtrl.text.trim().isEmpty ? null : typeCtrl.text.trim(),
      successProbability: prob,
      expectedCloseDate:
          expectedDateCtrl.text.trim().isEmpty
              ? null
              : expectedDateCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        saving = false;
        sheetMessage = 'Không cập nhật được cơ hội.';
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
        title: 'Sửa cơ hội',
        onClose: saving ? () {} : () => Navigator.of(context).maybePop(),
      ),
      bottomNavigationBar: StitchFormBottomBar(
        primaryLoading: saving,
        primaryLabel: saving ? 'Đang lưu...' : 'Lưu thay đổi',
        onPrimary: saving ? null : _submit,
        onSecondary:
            saving ? null : () => Navigator.of(context).maybePop(),
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
                    'Cập nhật thông tin cơ hội kinh doanh theo quy trình CRM.',
              ),
            ),
            StitchFormSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const StitchFormSectionHeader(
                    icon: Icons.query_stats_rounded,
                    title: 'Thông tin',
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
                              (Map<String, dynamic> client) =>
                                  StitchSelectOption<int>(
                                    value: _toInt(client['id'])!,
                                    label:
                                        '${client['name'] ?? '—'}'
                                        '${(client['company'] ?? '').toString().trim().isNotEmpty ? ' • ${client['company']}' : ''}',
                                  ),
                            )
                            .toList(),
                    onChanged: (int? next) => setState(() => clientId = next),
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Khách hàng *',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  StitchSearchableSelectField<String>(
                    value: statusCode,
                    sheetTitle: 'Chọn trạng thái',
                    label: 'Trạng thái',
                    searchHint: 'Tìm trạng thái...',
                    options:
                        widget.statuses
                            .map(
                              (Map<String, dynamic> status) =>
                                  StitchSelectOption<String>(
                                    value: (status['code'] ?? '').toString(),
                                    label: (status['name'] ?? '—').toString(),
                                  ),
                            )
                            .toList(),
                    onChanged:
                        (String? next) => setState(() => statusCode = next),
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Trạng thái',
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
                  TextField(
                    controller: sourceCtrl,
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Nguồn cơ hội',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: typeCtrl,
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Loại cơ hội',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: probabilityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Tỷ lệ thành công (%) *',
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: expectedDateCtrl,
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Ngày kết thúc dự kiến',
                      hint: 'YYYY-MM-DD',
                    ).copyWith(
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(height: kStitchTaskFormGap),
                  TextField(
                    controller: notesCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: stitchSheetInputDecoration(
                      context,
                      label: 'Ghi chú',
                    ),
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

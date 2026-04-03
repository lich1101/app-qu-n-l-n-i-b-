import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({
    super.key,
    required this.token,
    required this.apiService,
    this.initialContractId,
    this.initialContractTitle,
  });

  final String token;
  final MobileApiService apiService;
  final String? initialContractId;
  final String? initialContractTitle;

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController requirementCtrl = TextEditingController();
  final TextEditingController serviceOtherCtrl = TextEditingController();

  String selectedContractId = '';
  List<Map<String, dynamic>> contracts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> owners = <Map<String, dynamic>>[];
  String selectedOwnerId = '';
  List<_ServiceOptionData> serviceOptions = const <_ServiceOptionData>[
    _ServiceOptionData('backlinks', 'Backlinks', Icons.link),
    _ServiceOptionData('viet_content', 'Content', Icons.edit_note),
    _ServiceOptionData('audit_content', 'Audit Content', Icons.fact_check),
    _ServiceOptionData(
      'cham_soc_website_tong_the',
      'Website Care',
      Icons.public,
    ),
    _ServiceOptionData('noi_bo', 'Dự án nội bộ', Icons.corporate_fare),
    _ServiceOptionData('khac', 'Khác', Icons.more_horiz),
  ];
  String selectedService = 'backlinks';
  DateTime? deadline;
  String repoUrl = '';
  bool saving = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    requirementCtrl.dispose();
    serviceOtherCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final Map<String, dynamic> meta = await widget.apiService.getMeta();
    final List<dynamic> services =
        (meta['service_types'] ?? <dynamic>[]) as List<dynamic>;
    List<_ServiceOptionData> mapped = serviceOptions;
    if (services.isNotEmpty) {
      mapped =
          services.map((dynamic e) {
            final String value = e.toString();
            return _ServiceOptionData(
              value,
              _serviceLabel(value),
              _serviceIcon(value),
            );
          }).toList();
    }
    final Map<String, dynamic> contractPayload = await widget.apiService
        .getContracts(widget.token, perPage: 200, availableOnly: true);
    final List<Map<String, dynamic>> ownerRows = await widget.apiService
        .getUsersLookup(widget.token);
    if (!mounted) return;
    final List<dynamic> contractData =
        (contractPayload['data'] ?? []) as List<dynamic>;
    setState(() {
      serviceOptions = mapped;
      if (mapped.isNotEmpty &&
          !mapped.any((item) => item.value == selectedService)) {
        selectedService = mapped.first.value;
      }
      contracts = contractData.map((e) => e as Map<String, dynamic>).toList();

      if (widget.initialContractId != null &&
          widget.initialContractId!.isNotEmpty) {
        if (!contracts.any((c) => '${c['id']}' == widget.initialContractId)) {
          contracts.insert(0, <String, dynamic>{
            'id': int.tryParse(widget.initialContractId!) ?? 0,
            'code': 'CTR',
            'title': widget.initialContractTitle ?? 'Hợp đồng được chọn',
          });
        }
        selectedContractId = widget.initialContractId!;
      }

      owners = ownerRows;
    });
  }

  String _serviceLabel(String value) {
    switch (value) {
      case 'backlinks':
        return 'Backlinks';
      case 'viet_content':
        return 'Content';
      case 'audit_content':
        return 'Audit Content';
      case 'cham_soc_website_tong_the':
        return 'Website Care';
      case 'noi_bo':
        return 'Dự án nội bộ';
      case 'khac':
        return 'Khác';
      default:
        return value.replaceAll('_', ' ');
    }
  }

  IconData _serviceIcon(String value) {
    switch (value) {
      case 'backlinks':
        return Icons.link;
      case 'viet_content':
        return Icons.edit_note;
      case 'audit_content':
        return Icons.fact_check;
      case 'cham_soc_website_tong_the':
        return Icons.public;
      case 'noi_bo':
        return Icons.corporate_fare;
      case 'khac':
        return Icons.more_horiz;
      default:
        return Icons.work_outline;
    }
  }

  Future<void> _pickDeadline() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
      initialDate: deadline ?? now,
    );
    if (date == null) return;
    setState(() => deadline = date);
  }

  Future<void> _submit() async {
    final String name = nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => message = 'Vui lòng nhập tên dự án.');
      return;
    }
    if (selectedService == 'khac' && serviceOtherCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập loại dịch vụ khác.');
      return;
    }
    setState(() {
      saving = true;
      message = '';
    });
    final bool ok = await widget.apiService.createProject(
      widget.token,
      name: name,
      serviceType: selectedService,
      serviceTypeOther:
          selectedService == 'khac' ? serviceOtherCtrl.text.trim() : null,
      contractId: int.tryParse(selectedContractId),
      ownerId: selectedOwnerId.isEmpty ? null : int.tryParse(selectedOwnerId),
      deadline:
          deadline == null
              ? null
              : '${deadline!.year.toString().padLeft(4, '0')}-'
                  '${deadline!.month.toString().padLeft(2, '0')}-'
                  '${deadline!.day.toString().padLeft(2, '0')}',
      customerRequirement:
          requirementCtrl.text.trim().isEmpty
              ? null
              : requirementCtrl.text.trim(),
      repoUrl: repoUrl.trim().isEmpty ? null : repoUrl.trim(),
    );
    if (!mounted) return;
    setState(() {
      saving = false;
      message = ok ? 'Tạo dự án thành công.' : 'Tạo dự án thất bại.';
    });
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tạo dự án thành công.')));
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String deadlineLabel =
        deadline == null
            ? 'Chọn ngày'
            : '${deadline!.day.toString().padLeft(2, '0')}/'
                '${deadline!.month.toString().padLeft(2, '0')}/'
                '${deadline!.year}';
    final ThemeData theme = Theme.of(context);

    InputDecoration fieldDecoration(
      String label, {
      String? hint,
      IconData? prefixIcon,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 18, color: StitchTheme.textSubtle),
        suffixIcon: suffixIcon,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo dự án'),
        actions: <Widget>[
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).maybePop(),
            child: const Text('Đóng'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: <Color>[
                    StitchTheme.primary.withValues(alpha: 0.18),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text(
                    'Khởi tạo dự án triển khai',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Điền thông tin chính xác để hệ thống tự liên kết hợp đồng, nhân sự triển khai và luồng công việc.',
                    style: TextStyle(color: StitchTheme.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Thông tin cơ bản',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: fieldDecoration(
                      'Tên dự án',
                      hint: 'Ví dụ: Chiến dịch SEO Q4',
                      prefixIcon: Icons.work_outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value:
                        contracts.any((c) => '${c['id']}' == selectedContractId)
                            ? selectedContractId
                            : null,
                    decoration: fieldDecoration(
                      'Hợp đồng liên kết',
                      prefixIcon: Icons.description_outlined,
                    ),
                    menuMaxHeight: 360,
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text(
                          'Không liên kết hợp đồng (dự án nội bộ)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...contracts
                          .map(
                            (
                              Map<String, dynamic> c,
                            ) => DropdownMenuItem<String>(
                              value: '${c['id']}',
                              child: Text(
                                '${c['code'] ?? 'CTR'} • ${c['title'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                    ],
                    onChanged: (String? value) {
                      setState(() => selectedContractId = value ?? '');
                    },
                  ),
                  if (contracts.isEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa có hợp đồng để chọn. Bạn vẫn có thể tạo dự án nội bộ.',
                      style: TextStyle(
                        color: StitchTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedOwnerId.isEmpty ? null : selectedOwnerId,
                    decoration: fieldDecoration(
                      'Người phụ trách triển khai',
                      prefixIcon: Icons.person_outline,
                    ),
                    menuMaxHeight: 360,
                    items:
                        owners
                            .map(
                              (Map<String, dynamic> u) =>
                                  DropdownMenuItem<String>(
                                    value: '${u['id']}',
                                    child: Text(
                                      '${u['name'] ?? ''} (${u['role'] ?? ''})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                            )
                            .toList(),
                    onChanged: (String? value) {
                      setState(() => selectedOwnerId = value ?? '');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Loại dịch vụ',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chọn loại dịch vụ chính cho dự án.',
                    style: TextStyle(
                      color: StitchTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.8,
                    children:
                        serviceOptions
                            .map(
                              (option) => _ServiceOption(
                                label: option.label,
                                icon: option.icon,
                                selected: selectedService == option.value,
                                onTap:
                                    () => setState(
                                      () => selectedService = option.value,
                                    ),
                              ),
                            )
                            .toList(),
                  ),
                  if (selectedService == 'khac') ...<Widget>[
                    const SizedBox(height: 10),
                    TextField(
                      controller: serviceOtherCtrl,
                      decoration: fieldDecoration(
                        'Loại dịch vụ khác',
                        hint: 'Nhập tên dịch vụ',
                        prefixIcon: Icons.edit_note_outlined,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                children: <Widget>[
                  GestureDetector(
                    onTap: _pickDeadline,
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: fieldDecoration(
                          'Hạn chót tổng',
                          hint: deadlineLabel,
                          prefixIcon: Icons.event_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: requirementCtrl,
                    maxLines: 4,
                    decoration: fieldDecoration(
                      'Yêu cầu của khách hàng',
                      hint:
                          'Mô tả chi tiết các yêu cầu và mong muốn từ khách hàng...',
                      prefixIcon: Icons.notes_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: fieldDecoration(
                      'Link dự án (tuỳ chọn)',
                      hint: 'https://drive.google.com/...',
                      prefixIcon: Icons.folder_open_outlined,
                    ),
                    onChanged: (value) => repoUrl = value,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                children: <Widget>[
                  const Icon(Icons.attach_file, color: StitchTheme.textMuted),
                  const SizedBox(height: 8),
                  const Text(
                    'Tệp đính kèm dự án',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PDF, DOC, PNG, JPG (Tối đa 10MB)',
                    style: TextStyle(
                      color: StitchTheme.textSubtle,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Chọn file'),
                  ),
                ],
              ),
            ),
            if (message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color:
                      message.contains('thành công')
                          ? StitchTheme.success
                          : StitchTheme.danger,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        saving ? null : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _submit,
                    icon:
                        saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.rocket_launch, size: 18),
                    label: Text(saving ? 'Đang tạo...' : 'Tạo dự án ngay'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOption extends StatelessWidget {
  const _ServiceOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? StitchTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? StitchTheme.primary : StitchTheme.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: selected ? Colors.white : StitchTheme.textSubtle),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: selected ? Colors.white : StitchTheme.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOptionData {
  const _ServiceOptionData(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

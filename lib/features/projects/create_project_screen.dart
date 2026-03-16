import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

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
      mapped = services.map((dynamic e) {
        final String value = e.toString();
        return _ServiceOptionData(
          value,
          _serviceLabel(value),
          _serviceIcon(value),
        );
      }).toList();
    }
    final List<Map<String, dynamic>> contractRows =
        await widget.apiService.getContracts(
      widget.token,
      perPage: 200,
      availableOnly: true,
    );
    final List<Map<String, dynamic>> ownerRows =
        await widget.apiService.getUsersLookup(widget.token);
    if (!mounted) return;
    setState(() {
      serviceOptions = mapped;
      if (mapped.isNotEmpty && !mapped.any((item) => item.value == selectedService)) {
        selectedService = mapped.first.value;
      }
      contracts = contractRows;
      owners = ownerRows;
      if (contractRows.isEmpty) {
        message = 'Chưa có hợp đồng nào. Vui lòng tạo hợp đồng trước.';
      }
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
    if (selectedContractId.isEmpty) {
      setState(() => message = 'Vui lòng chọn hợp đồng trước khi tạo dự án.');
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
      deadline: deadline == null
          ? null
          : '${deadline!.year.toString().padLeft(4, '0')}-'
              '${deadline!.month.toString().padLeft(2, '0')}-'
              '${deadline!.day.toString().padLeft(2, '0')}',
      customerRequirement: requirementCtrl.text.trim().isEmpty
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo dự án thành công.')),
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String deadlineLabel = deadline == null
        ? 'Chọn ngày'
        : '${deadline!.day.toString().padLeft(2, '0')}/'
            '${deadline!.month.toString().padLeft(2, '0')}/'
            '${deadline!.year}';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new),
                ),
                const Expanded(
                  child: Text(
                    'Tạo Dự án',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: StitchTheme.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Thông tin dự án',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Khởi tạo dự án mới cho đội ngũ nội bộ theo quy trình dịch vụ.',
              style: TextStyle(color: StitchTheme.textMuted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên dự án',
                hintText: 'Ví dụ: Chiến dịch SEO Q4',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: selectedContractId.isEmpty ? null : selectedContractId,
              decoration: const InputDecoration(labelText: 'Chọn hợp đồng *'),
              items: contracts
                  .map(
                    (Map<String, dynamic> c) => DropdownMenuItem<String>(
                      value: '${c['id']}',
                      child: Text('${c['code'] ?? 'CTR'} • ${c['title'] ?? ''}'),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) return;
                setState(() => selectedContractId = value);
              },
            ),
            if (contracts.isEmpty) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'Chưa có hợp đồng để chọn. Hãy tạo hợp đồng trước.',
                style: TextStyle(color: StitchTheme.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: selectedOwnerId.isEmpty ? null : selectedOwnerId,
              decoration: const InputDecoration(
                labelText: 'Người phụ trách triển khai',
              ),
              items: owners
                  .map(
                    (Map<String, dynamic> u) => DropdownMenuItem<String>(
                      value: '${u['id']}',
                      child: Text('${u['name'] ?? ''} (${u['role'] ?? ''})'),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                setState(() => selectedOwnerId = value ?? '');
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Loại dịch vụ',
              style: TextStyle(
                fontSize: 12,
                color: StitchTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: serviceOptions
                  .map(
                    (option) => _ServiceOption(
                      label: option.label,
                      icon: option.icon,
                      selected: selectedService == option.value,
                      onTap: () => setState(() => selectedService = option.value),
                    ),
                  )
                  .toList(),
            ),
            if (selectedService == 'khac') ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: serviceOtherCtrl,
                decoration: const InputDecoration(
                  labelText: 'Loại dịch vụ khác',
                  hintText: 'Nhập tên dịch vụ',
                ),
              ),
            ],
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickDeadline,
              child: AbsorbPointer(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Hạn chót tổng',
                    prefixIcon: const Icon(Icons.calendar_today),
                    hintText: deadlineLabel,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: requirementCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Yêu cầu của khách hàng',
                hintText: 'Mô tả chi tiết các yêu cầu và mong muốn từ khách hàng...',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Link kho dự án (tuỳ chọn)',
                hintText: 'https://drive.google.com/...',
              ),
              onChanged: (value) => repoUrl = value,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: StitchTheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.upload_file, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chọn tệp tin để tải lên',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'PDF, DOC, PNG, JPG (Tối đa 10MB)',
                    style: TextStyle(color: StitchTheme.textSubtle, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.attach_file, size: 18),
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
                  color: message.contains('thành công')
                      ? StitchTheme.success
                      : StitchTheme.danger,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: saving ? null : _submit,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rocket_launch, size: 18),
              label: Text(saving ? 'Đang tạo...' : 'Tạo Dự án Ngay'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
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
            Icon(
              icon,
              color: selected ? Colors.white : StitchTheme.textSubtle,
            ),
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

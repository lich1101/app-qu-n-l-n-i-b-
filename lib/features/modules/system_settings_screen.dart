import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final TextEditingController brandCtrl = TextEditingController();
  final TextEditingController colorCtrl = TextEditingController();
  final TextEditingController logoUrlCtrl = TextEditingController();
  final TextEditingController commentDaysCtrl = TextEditingController();
  final TextEditingController opportunityDaysCtrl = TextEditingController();
  final TextEditingController contractDaysCtrl = TextEditingController();
  final TextEditingController warningDaysCtrl = TextEditingController();
  final TextEditingController dailyLimitCtrl = TextEditingController();

  File? logoFile;
  bool saving = false;
  bool loading = true;
  String message = '';
  bool rotationEnabled = false;
  bool rotationSameDepartmentOnly = false;
  List<Map<String, dynamic>> leadTypes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> participants = <Map<String, dynamic>>[];
  List<int> selectedLeadTypeIds = <int>[];
  Set<int> selectedParticipantIds = <int>{};

  static const List<String> _palette = <String>[
    '#0F172A',
    '#1F2937',
    '#334155',
    '#0EA5A6',
    '#2563EB',
    '#10B981',
    '#F59E0B',
    '#F97316',
    '#E11D48',
    '#8B5CF6',
  ];

  @override
  void initState() {
    super.initState();
    final AppSettingsData settings = appSettingsStore.settings;
    brandCtrl.text = settings.brandName;
    colorCtrl.text = settings.primaryColor;
    logoUrlCtrl.text = settings.logoUrl ?? '';
    commentDaysCtrl.text = '3';
    opportunityDaysCtrl.text = '30';
    contractDaysCtrl.text = '90';
    warningDaysCtrl.text = '3';
    dailyLimitCtrl.text = '5';
    _load();
  }

  @override
  void dispose() {
    brandCtrl.dispose();
    colorCtrl.dispose();
    logoUrlCtrl.dispose();
    commentDaysCtrl.dispose();
    opportunityDaysCtrl.dispose();
    contractDaysCtrl.dispose();
    warningDaysCtrl.dispose();
    dailyLimitCtrl.dispose();
    super.dispose();
  }

  Color _colorFromHex(String value, {Color? fallback}) {
    final Color resolvedFallback = fallback ?? StitchTheme.primary;
    final String hex = value.replaceAll('#', '').trim();
    if (hex.length != 6) return resolvedFallback;
    final int? parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return resolvedFallback;
    return Color(0xFF000000 | parsed);
  }

  List<int> _idListFromValue(dynamic value) {
    if (value is! List) return <int>[];
    return value
        .map((dynamic item) => int.tryParse('$item') ?? 0)
        .where((int id) => id > 0)
        .toSet()
        .toList();
  }

  Set<int> _idSetFromValue(dynamic value) {
    return _idListFromValue(value).toSet();
  }

  int _readInt(
    TextEditingController controller,
    int fallback, {
    required int min,
    required int max,
  }) {
    final int parsed = int.tryParse(controller.text.trim()) ?? fallback;
    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  String _errorMessageFromResponse(Map<String, dynamic> response) {
    final dynamic body = response['body'];
    if (body is Map<String, dynamic>) {
      final dynamic errors = body['errors'];
      if (errors is Map) {
        for (final dynamic value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
          if (value != null) {
            return value.toString();
          }
        }
      }
      final String message = (body['message'] ?? '').toString().trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
    return 'Không tải được cài đặt nâng cao.';
  }

  void _applySettings(Map<String, dynamic> settings) {
    brandCtrl.text =
        (settings['brand_name'] ?? appSettingsStore.settings.brandName)
            .toString();
    colorCtrl.text =
        (settings['primary_color'] ?? appSettingsStore.settings.primaryColor)
            .toString();
    logoUrlCtrl.text = (settings['logo_url'] ?? '').toString();
    rotationEnabled = settings['client_rotation_enabled'] == true;
    commentDaysCtrl.text =
        '${settings['client_rotation_comment_stale_days'] ?? 3}';
    opportunityDaysCtrl.text =
        '${settings['client_rotation_opportunity_stale_days'] ?? 30}';
    contractDaysCtrl.text =
        '${settings['client_rotation_contract_stale_days'] ?? 90}';
    warningDaysCtrl.text = '${settings['client_rotation_warning_days'] ?? 3}';
    dailyLimitCtrl.text =
        '${settings['client_rotation_daily_receive_limit'] ?? 5}';
    rotationSameDepartmentOnly =
        settings['client_rotation_same_department_only'] == true;
    selectedLeadTypeIds = _idListFromValue(
      settings['client_rotation_lead_type_ids'],
    );
    selectedParticipantIds = _idSetFromValue(
      settings['client_rotation_participant_user_ids'],
    );
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      message = '';
    });

    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      widget.apiService.getAdminSettings(widget.token),
      widget.apiService.getLeadTypes(widget.token),
      widget.apiService.getUsersLookup(
        widget.token,
        purpose: 'client_rotation_staff',
      ),
    ]);

    if (!mounted) return;

    final Map<String, dynamic> settings = Map<String, dynamic>.from(
      results[0] as Map<String, dynamic>,
    );
    final List<Map<String, dynamic>> loadedLeadTypes =
        List<Map<String, dynamic>>.from(
          results[1] as List<Map<String, dynamic>>,
        );
    final List<Map<String, dynamic>> loadedParticipants =
        List<Map<String, dynamic>>.from(
          results[2] as List<Map<String, dynamic>>,
        );

    setState(() {
      leadTypes = loadedLeadTypes;
      participants = loadedParticipants;
      loading = false;
      if (settings['error'] == true) {
        message = _errorMessageFromResponse(settings);
      } else {
        _applySettings(settings);
      }
    });
  }

  Future<void> _pickLogo() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => logoFile = File(result.files.single.path!));
  }

  void _toggleLeadType(int id) {
    if (id <= 0) return;
    final List<int> next = List<int>.from(selectedLeadTypeIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    setState(() {
      selectedLeadTypeIds = next;
    });
  }

  void _moveLeadTypePriority(int index, int direction) {
    final int nextIndex = index + direction;
    if (index < 0 ||
        nextIndex < 0 ||
        index >= selectedLeadTypeIds.length ||
        nextIndex >= selectedLeadTypeIds.length) {
      return;
    }

    final List<int> next = List<int>.from(selectedLeadTypeIds);
    final int current = next[index];
    next[index] = next[nextIndex];
    next[nextIndex] = current;
    setState(() {
      selectedLeadTypeIds = next;
    });
  }

  void _toggleParticipant(int id) {
    if (id <= 0) return;
    final Set<int> next = Set<int>.from(selectedParticipantIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    setState(() {
      selectedParticipantIds = next;
    });
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      message = '';
    });

    final Map<String, dynamic>
    response = await widget.apiService.updateSettings(
      widget.token,
      brandName: brandCtrl.text.trim().isEmpty ? null : brandCtrl.text.trim(),
      primaryColor:
          colorCtrl.text.trim().isEmpty ? null : colorCtrl.text.trim(),
      logoUrl: logoUrlCtrl.text.trim().isEmpty ? null : logoUrlCtrl.text.trim(),
      logoFile: logoFile,
      extraFields: <String, dynamic>{
        'client_rotation_enabled': rotationEnabled,
        'client_rotation_comment_stale_days': _readInt(
          commentDaysCtrl,
          3,
          min: 1,
          max: 3650,
        ),
        'client_rotation_opportunity_stale_days': _readInt(
          opportunityDaysCtrl,
          30,
          min: 1,
          max: 3650,
        ),
        'client_rotation_contract_stale_days': _readInt(
          contractDaysCtrl,
          90,
          min: 1,
          max: 3650,
        ),
        'client_rotation_warning_days': _readInt(
          warningDaysCtrl,
          3,
          min: 0,
          max: 60,
        ),
        'client_rotation_same_department_only': rotationSameDepartmentOnly,
        'client_rotation_daily_receive_limit': _readInt(
          dailyLimitCtrl,
          5,
          min: 1,
          max: 100,
        ),
        'client_rotation_lead_type_ids': List<int>.from(selectedLeadTypeIds),
        'client_rotation_participant_user_ids':
            selectedParticipantIds.toList()..sort(),
      },
    );

    if (!mounted) return;

    if (response['error'] == true) {
      setState(() {
        saving = false;
        message = 'Cập nhật thất bại.';
      });
      return;
    }

    appSettingsStore.apply(AppSettingsData.fromJson(response));
    setState(() {
      saving = false;
      logoFile = null;
      _applySettings(response);
      message = 'Đã lưu cài đặt.';
    });
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: StitchTheme.textMuted, height: 1.45),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required int selectedCount,
    required List<Map<String, dynamic>> rows,
    required Set<int> selectedIds,
    required void Function(int id) onToggle,
    required String Function(Map<String, dynamic> row) secondaryText,
    String emptyText = 'Chưa có dữ liệu.',
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: StitchTheme.textMuted,
                        height: 1.4,
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
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Đã chọn $selectedCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                emptyText,
                style: const TextStyle(color: StitchTheme.textMuted),
              ),
            )
          else
            Column(
              children:
                  rows.map((Map<String, dynamic> row) {
                    final int id = int.tryParse('${row['id']}') ?? 0;
                    final bool checked = selectedIds.contains(id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color:
                            checked
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              checked
                                  ? StitchTheme.primary.withValues(alpha: 0.25)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: checked,
                        onChanged: (_) => onToggle(id),
                        controlAffinity: ListTileControlAffinity.leading,
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        title: Text(
                          (row['name'] ?? 'Không rõ').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            secondaryText(row),
                            style: const TextStyle(height: 1.35),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLeadTypePriorityCard() {
    final Map<int, Map<String, dynamic>> rowsById = <int, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in leadTypes)
        int.tryParse('${row['id']}') ?? 0: row,
    };
    final List<Map<String, dynamic>> orderedRows =
        selectedLeadTypeIds
            .map((int id) => rowsById[id])
            .whereType<Map<String, dynamic>>()
            .toList();
    final Set<int> selectedSet = selectedLeadTypeIds.toSet();
    final List<Map<String, dynamic>> visibleRows = <Map<String, dynamic>>[
      ...orderedRows,
      ...leadTypes.where((Map<String, dynamic> row) {
        final int id = int.tryParse('${row['id']}') ?? 0;
        return !selectedSet.contains(id);
      }),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    Text(
                      'Loại khách áp dụng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Chỉ những loại khách được chọn mới đi vào cơ chế xoay vòng. Nếu chọn nhiều loại, thứ tự ưu tiên bên dưới sẽ quyết định loại nào được xét trước.',
                      style: TextStyle(
                        color: StitchTheme.textMuted,
                        height: 1.4,
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
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Đã chọn ${selectedLeadTypeIds.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          if (orderedRows.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Thứ tự ưu tiên loại khách',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '#1 là ưu tiên cao nhất. Trong cùng một loại khách, hệ thống vẫn giữ nguyên rule hiện tại: xét loại khách trước, rồi tới số hợp đồng, số cơ hội và các tie-break còn lại.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...orderedRows.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final Map<String, dynamic> row = entry.value;
                    final int id = int.tryParse('${row['id']}') ?? 0;
                    final String colorHex =
                        (row['color_hex'] ?? '').toString().trim();
                    return Container(
                      margin: EdgeInsets.only(
                        bottom: index == orderedRows.length - 1 ? 0 : 10,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            constraints: const BoxConstraints(minWidth: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: StitchTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '#${index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: StitchTheme.primaryStrong,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  (row['name'] ?? 'Không rõ').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  colorHex.isEmpty
                                      ? 'Lead type #$id'
                                      : 'Lead type #$id • $colorHex',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: StitchTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed:
                                index == 0
                                    ? null
                                    : () => _moveLeadTypePriority(index, -1),
                            icon: const Icon(Icons.keyboard_arrow_up_rounded),
                            tooltip: 'Ưu tiên cao hơn',
                          ),
                          IconButton(
                            onPressed:
                                index == orderedRows.length - 1
                                    ? null
                                    : () => _moveLeadTypePriority(index, 1),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            tooltip: 'Ưu tiên thấp hơn',
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (visibleRows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Chưa tải được danh sách loại khách.',
                style: TextStyle(color: StitchTheme.textMuted),
              ),
            )
          else
            Column(
              children:
                  visibleRows.map((Map<String, dynamic> row) {
                    final int id = int.tryParse('${row['id']}') ?? 0;
                    final bool checked = selectedSet.contains(id);
                    final int selectedIndex = selectedLeadTypeIds.indexOf(id);
                    final String colorHex =
                        (row['color_hex'] ?? '').toString().trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color:
                            checked
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              checked
                                  ? StitchTheme.primary.withValues(alpha: 0.25)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: checked,
                        onChanged: (_) => _toggleLeadType(id),
                        controlAffinity: ListTileControlAffinity.leading,
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        title: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                (row['name'] ?? 'Không rõ').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (checked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: StitchTheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Ưu tiên #${selectedIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: StitchTheme.primaryStrong,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            colorHex.isEmpty
                                ? 'Lead type #$id'
                                : 'Lead type #$id • $colorHex',
                            style: const TextStyle(height: 1.35),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.surfaceAlt,
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
        actions: <Widget>[
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: <Widget>[
                  _buildSection(
                    title: 'Cấu hình thương hiệu',
                    subtitle:
                        'Đổi tên hiển thị, màu chủ đạo và logo dùng chung cho app và web.',
                    children: <Widget>[
                      TextField(
                        controller: brandCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tên brand',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: colorCtrl,
                        decoration: InputDecoration(
                          labelText: 'Màu chủ đạo (HEX)',
                          suffixIcon: Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _colorFromHex(colorCtrl.text),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black12),
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chọn nhanh màu gợi ý',
                        style: TextStyle(
                          color: StitchTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            _palette.map((String hex) {
                              final bool selected =
                                  hex.toLowerCase() ==
                                  colorCtrl.text.trim().toLowerCase();
                              return GestureDetector(
                                onTap:
                                    () => setState(() => colorCtrl.text = hex),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _colorFromHex(hex),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          selected
                                              ? StitchTheme.primary
                                              : Colors.black12,
                                      width: selected ? 2 : 1,
                                    ),
                                    boxShadow: const <BoxShadow>[
                                      BoxShadow(
                                        color: Color(0x11000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: logoUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Logo URL',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          logoFile == null ? 'Chọn logo' : 'Đổi logo',
                        ),
                      ),
                      if (logoFile != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            logoFile!.path.split('/').last,
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Xoay vòng khách hàng không được chăm sóc',
                    subtitle:
                        'Cron chạy lúc 12h trưa mỗi ngày để cảnh báo trước hạn và điều chuyển khách theo ưu tiên: nhiều hợp đồng hơn, nếu bằng nhau thì nhiều cơ hội hơn, còn hai khách tiềm năng thuần thì random.',
                    children: <Widget>[
                      SwitchListTile.adaptive(
                        value: rotationEnabled,
                        onChanged:
                            (bool value) =>
                                setState(() => rotationEnabled = value),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Bật tự động xoay khách',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Chạm mốc nào trước thì điều chuyển theo mốc đó: bình luận, cơ hội hoặc hợp đồng đều có thể kích hoạt xoay.',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Bình luận mới chỉ reset mốc chăm sóc. Cơ hội mới reset cả mốc cơ hội và chăm sóc. Hợp đồng mới reset cả 3 mốc.',
                          style: TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Thứ tự đưa khách vào hàng chờ xoay: số hợp đồng giảm dần, nếu bằng nhau thì xét số cơ hội giảm dần; nếu cả hai cùng là khách tiềm năng thuần thì random trong nhóm đồng hạng.',
                          style: TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Nếu chọn nhiều loại khách, hệ thống sẽ ưu tiên theo đúng thứ tự loại khách bạn sắp xếp ở danh sách bên dưới, rồi mới áp dụng các rule xoay còn lại trong từng loại.',
                          style: TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNumberField(
                        'Quá hạn bình luận / ghi chú (ngày)',
                        commentDaysCtrl,
                      ),
                      const SizedBox(height: 12),
                      _buildNumberField(
                        'Quá hạn cơ hội mới (ngày)',
                        opportunityDaysCtrl,
                      ),
                      const SizedBox(height: 12),
                      _buildNumberField(
                        'Quá hạn hợp đồng mới (ngày)',
                        contractDaysCtrl,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: StitchTheme.border),
                        ),
                        child: const Text(
                          'Nhịp cảnh báo cố định:\n- Chăm sóc: còn 2 ngày thì nhắc mỗi ngày.\n- Cơ hội: còn 14 ngày thì nhắc mỗi 3 ngày.\n- Hợp đồng: còn 45 ngày thì nhắc mỗi 7 ngày.',
                          style: TextStyle(
                            color: StitchTheme.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNumberField(
                        'Giới hạn mỗi người nhận / ngày',
                        dailyLimitCtrl,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: rotationSameDepartmentOnly,
                        onChanged:
                            (bool value) => setState(
                              () => rotationSameDepartmentOnly = value,
                            ),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Chỉ xoay trong cùng phòng ban',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          rotationSameDepartmentOnly
                              ? 'Người nhận phải vừa nằm trong danh sách xoay, vừa cùng phòng ban với người đang giữ khách.'
                              : 'Người nhận được phép ở bất kỳ phòng ban nào, miễn là đã được chọn trong danh sách xoay.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          rotationSameDepartmentOnly
                              ? 'Người nhận được chọn trong nhóm cùng phòng ban đã được tick trong setting. Thứ tự ưu tiên là số auto-rotation tích lũy ít nhất, rồi tới số khách đang phụ trách ít nhất, rồi tới số nhận hôm nay ít nhất. Khi bằng nhau thì random.'
                              : 'Người nhận được chọn trên toàn bộ danh sách nhân sự đã tick trong setting. Thứ tự ưu tiên là số auto-rotation tích lũy ít nhất, rồi tới số khách đang phụ trách ít nhất, rồi tới số nhận hôm nay ít nhất. Khi bằng nhau thì random.',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLeadTypePriorityCard(),
                  const SizedBox(height: 16),
                  _buildSelectionCard(
                    title: 'Nhân sự tham gia xoay vòng',
                    subtitle:
                        'Chỉ quản lý/nhân viên đang hoạt động mới hợp lệ.',
                    selectedCount: selectedParticipantIds.length,
                    rows: participants,
                    selectedIds: selectedParticipantIds,
                    onToggle: _toggleParticipant,
                    secondaryText: (Map<String, dynamic> row) {
                      final String role = (row['role'] ?? '').toString();
                      final String email = (row['email'] ?? '').toString();
                      final String dept =
                          (row['department_id'] ?? '').toString();
                      return <String>[
                        if (role.isNotEmpty) role,
                        if (email.isNotEmpty) email,
                        if (dept.isNotEmpty) 'Phòng ban #$dept',
                      ].join(' • ');
                    },
                    emptyText: 'Chưa tải được danh sách nhân sự xoay vòng.',
                  ),
                  if (message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        message,
                        style: TextStyle(
                          color:
                              message.contains('Đã')
                                  ? StitchTheme.success
                                  : StitchTheme.danger,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon:
                        saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save),
                    label: Text(saving ? 'Đang lưu...' : 'Lưu cài đặt'),
                  ),
                ],
              ),
    );
  }
}

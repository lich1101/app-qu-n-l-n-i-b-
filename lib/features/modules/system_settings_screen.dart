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
  final TextEditingController poolClaimDailyLimitCtrl = TextEditingController();
  final TextEditingController rotationRunTimeCtrl = TextEditingController();

  File? logoFile;
  bool saving = false;
  bool loading = true;
  String message = '';
  bool rotationEnabled = false;
  String rotationScopeMode = 'global_staff';
  List<Map<String, dynamic>> leadTypes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> participants = <Map<String, dynamic>>[];
  List<int> selectedLeadTypeIds = <int>[];
  Set<int> selectedParticipantIds = <int>{};
  Map<int, Map<String, bool>> participantModes = <int, Map<String, bool>>{};

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
    poolClaimDailyLimitCtrl.text = '5';
    rotationRunTimeCtrl.text = '12:00';
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
    poolClaimDailyLimitCtrl.dispose();
    rotationRunTimeCtrl.dispose();
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

  String _rotationScopeModeFromSettings(Map<String, dynamic> settings) {
    final String scope =
        (settings['client_rotation_scope_mode'] ?? '').toString().trim();
    if (scope == 'same_department' ||
        scope == 'global_staff' ||
        scope == 'balanced_department') {
      return scope;
    }
    return settings['client_rotation_same_department_only'] == true
        ? 'same_department'
        : 'global_staff';
  }

  Map<int, Map<String, bool>> _participantModesFromValue(
    dynamic value,
    Set<int> selectedIds,
  ) {
    if (value is! Map || selectedIds.isEmpty) {
      return <int, Map<String, bool>>{};
    }

    final Map<int, Map<String, bool>> next = <int, Map<String, bool>>{};
    value.forEach((dynamic rawUserId, dynamic rawMode) {
      final int userId = int.tryParse('$rawUserId') ?? 0;
      if (userId <= 0 || !selectedIds.contains(userId) || rawMode is! Map) {
        return;
      }

      final bool onlyReceive = rawMode['only_receive'] == true;
      final bool onlyGive = rawMode['only_give'] == true;
      if (!onlyReceive && !onlyGive) {
        return;
      }

      next[userId] = <String, bool>{
        'only_receive': onlyReceive,
        'only_give': onlyGive,
      };
    });

    return next;
  }

  Map<String, dynamic> _participantModeMeta(int userId) {
    final Map<String, bool> mode =
        participantModes[userId] ?? const <String, bool>{};
    final bool onlyReceive = mode['only_receive'] == true;
    final bool onlyGive = mode['only_give'] == true;

    if (onlyReceive && !onlyGive) {
      return <String, dynamic>{
        'onlyReceive': true,
        'onlyGive': false,
        'label': 'Chỉ nhận vào',
        'hint':
            'Khách của nhân sự này không bị xoay ra, nhưng vẫn được nhận khách mới.',
      };
    }

    if (onlyGive && !onlyReceive) {
      return <String, dynamic>{
        'onlyReceive': false,
        'onlyGive': true,
        'label': 'Chỉ cho đi',
        'hint':
            'Nhân sự này vẫn có thể mất khách khi quá hạn nhưng sẽ không nhận khách auto-rotation vào.',
      };
    }

    if (onlyReceive && onlyGive) {
      return <String, dynamic>{
        'onlyReceive': true,
        'onlyGive': true,
        'label': 'Đang bật cả 2 nên xử lý như bình thường',
        'hint':
            'Khi bật đồng thời cả 2, hệ thống coi nhân sự này như chế độ bình thường.',
      };
    }

    return <String, dynamic>{
      'onlyReceive': false,
      'onlyGive': false,
      'label': 'Bình thường',
      'hint':
          'Nhân sự này vừa có thể nhận vào, vừa có thể bị xoay khách ra nếu quá hạn.',
    };
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
    poolClaimDailyLimitCtrl.text =
        '${settings['client_rotation_pool_claim_daily_limit'] ?? 5}';
    rotationRunTimeCtrl.text =
        (settings['client_rotation_run_time'] ?? '12:00').toString();
    rotationScopeMode = _rotationScopeModeFromSettings(settings);
    selectedLeadTypeIds = _idListFromValue(
      settings['client_rotation_lead_type_ids'],
    );
    selectedParticipantIds = _idSetFromValue(
      settings['client_rotation_participant_user_ids'],
    );
    participantModes = _participantModesFromValue(
      settings['client_rotation_participant_modes'],
      selectedParticipantIds,
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
      participantModes = _participantModesFromValue(participantModes, next);
    });
  }

  void _toggleParticipantMode(int id, String field) {
    if (id <= 0 || !selectedParticipantIds.contains(id)) return;

    final Map<int, Map<String, bool>> next = <int, Map<String, bool>>{
      for (final MapEntry<int, Map<String, bool>> entry
          in participantModes.entries)
        entry.key: <String, bool>{...entry.value},
    };
    final Map<String, bool> current =
        next[id] ?? <String, bool>{'only_receive': false, 'only_give': false};
    final bool onlyReceive =
        field == 'only_receive'
            ? !(current['only_receive'] == true)
            : (current['only_receive'] == true);
    final bool onlyGive =
        field == 'only_give'
            ? !(current['only_give'] == true)
            : (current['only_give'] == true);

    if (!onlyReceive && !onlyGive) {
      next.remove(id);
    } else {
      next[id] = <String, bool>{
        'only_receive': onlyReceive,
        'only_give': onlyGive,
      };
    }

    setState(() {
      participantModes = next;
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
          min: 0,
          max: 3650,
        ),
        'client_rotation_opportunity_stale_days': _readInt(
          opportunityDaysCtrl,
          30,
          min: 0,
          max: 3650,
        ),
        'client_rotation_contract_stale_days': _readInt(
          contractDaysCtrl,
          90,
          min: 0,
          max: 3650,
        ),
        'client_rotation_warning_days': _readInt(
          warningDaysCtrl,
          3,
          min: 0,
          max: 60,
        ),
        'client_rotation_scope_mode': rotationScopeMode,
        'client_rotation_same_department_only':
            rotationScopeMode == 'same_department',
        'client_rotation_daily_receive_limit': _readInt(
          dailyLimitCtrl,
          5,
          min: 0,
          max: 100,
        ),
        'client_rotation_pool_claim_daily_limit': _readInt(
          poolClaimDailyLimitCtrl,
          5,
          min: 0,
          max: 100,
        ),
        'client_rotation_run_time':
            rotationRunTimeCtrl.text.trim().isEmpty
                ? '12:00'
                : rotationRunTimeCtrl.text.trim(),
        'client_rotation_lead_type_ids': List<int>.from(selectedLeadTypeIds),
        'client_rotation_participant_user_ids':
            selectedParticipantIds.toList()..sort(),
        'client_rotation_participant_modes': <String, dynamic>{
          for (final int userId in (selectedParticipantIds.toList()..sort()))
            if ((participantModes[userId]?['only_receive'] == true) ||
                (participantModes[userId]?['only_give'] == true))
              '$userId': <String, bool>{
                'only_receive':
                    participantModes[userId]?['only_receive'] == true,
                'only_give': participantModes[userId]?['only_give'] == true,
              },
        },
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

  Future<void> _pickRotationRunTime() async {
    final List<String> parts = rotationRunTimeCtrl.text.trim().split(':');
    final int hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 12 : 12;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: hour.clamp(0, 23).toInt(),
        minute: minute.clamp(0, 59).toInt(),
      ),
    );
    if (picked == null) {
      return;
    }
    final String hh = picked.hour.toString().padLeft(2, '0');
    final String mm = picked.minute.toString().padLeft(2, '0');
    setState(() => rotationRunTimeCtrl.text = '$hh:$mm');
  }

  Widget _buildSection({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final String normalizedSubtitle = (subtitle ?? '').trim();
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (normalizedSubtitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              normalizedSubtitle,
              style: const TextStyle(
                color: StitchTheme.textMuted,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildScopeOptionCard({required String value, required String title}) {
    final bool selected = rotationScopeMode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap:
          () => setState(() {
            rotationScopeMode = value;
          }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected
                    ? StitchTheme.primary.withValues(alpha: 0.28)
                    : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantSelectionCard() {
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
              const Expanded(
                child: Text(
                  'Nhân sự tham gia xoay vòng',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
                  'Đã chọn ${selectedParticipantIds.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (participants.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Chưa tải được danh sách nhân sự xoay vòng.',
                style: TextStyle(color: StitchTheme.textMuted),
              ),
            )
          else
            Column(
              children:
                  participants.map((Map<String, dynamic> row) {
                    final int id = int.tryParse('${row['id']}') ?? 0;
                    final bool checked = selectedParticipantIds.contains(id);
                    final Map<String, dynamic> mode = _participantModeMeta(id);
                    final String role = (row['role'] ?? '').toString();
                    final String email = (row['email'] ?? '').toString();
                    final String dept =
                        (row['department_id'] ?? '').toString().trim();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Checkbox(
                            value: checked,
                            onChanged: (_) => _toggleParticipant(id),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      (row['name'] ?? 'Không rõ').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (checked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          mode['label'].toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  <String>[
                                    if (role.isNotEmpty) role,
                                    if (email.isNotEmpty) email,
                                    if (dept.isNotEmpty) 'Phòng ban #$dept',
                                  ].join(' • '),
                                  style: const TextStyle(
                                    height: 1.35,
                                    color: StitchTheme.textMuted,
                                  ),
                                ),
                                if (checked) ...<Widget>[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      FilterChip(
                                        label: const Text('Chỉ nhận vào'),
                                        selected: mode['onlyReceive'] == true,
                                        onSelected:
                                            (_) => _toggleParticipantMode(
                                              id,
                                              'only_receive',
                                            ),
                                        selectedColor: const Color(0xFFD1FAE5),
                                        checkmarkColor: StitchTheme.success,
                                      ),
                                      FilterChip(
                                        label: const Text('Chỉ cho đi'),
                                        selected: mode['onlyGive'] == true,
                                        onSelected:
                                            (_) => _toggleParticipantMode(
                                              id,
                                              'only_give',
                                            ),
                                        selectedColor: const Color(0xFFFEF3C7),
                                        checkmarkColor: StitchTheme.warning,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
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
                child: const Text(
                  'Loại khách áp dụng',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
                    fontWeight: FontWeight.w500,
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
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
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
                                fontWeight: FontWeight.w500,
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
                                    fontWeight: FontWeight.w500,
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
                                  fontWeight: FontWeight.w500,
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
                                    fontWeight: FontWeight.w500,
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

  Widget _buildTimeField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: _pickRotationRunTime,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: IconButton(
          onPressed: _pickRotationRunTime,
          icon: const Icon(Icons.schedule_rounded),
        ),
      ),
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
                    children: <Widget>[
                      SwitchListTile.adaptive(
                        value: rotationEnabled,
                        onChanged:
                            (bool value) =>
                                setState(() => rotationEnabled = value),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Bật tự động xoay khách',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTimeField(
                        'Giờ cron chạy mỗi ngày',
                        rotationRunTimeCtrl,
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
                      _buildNumberField(
                        'Giới hạn nhận từ cron / người / ngày',
                        dailyLimitCtrl,
                      ),
                      const SizedBox(height: 12),
                      _buildNumberField(
                        'Giới hạn nhận kho số / người / ngày',
                        poolClaimDailyLimitCtrl,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Phạm vi nhận khách',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      _buildScopeOptionCard(
                        value: 'same_department',
                        title: 'Chỉ trong cùng phòng ban',
                      ),
                      const SizedBox(height: 10),
                      _buildScopeOptionCard(
                        value: 'global_staff',
                        title: 'Toàn bộ nhân sự đã chọn',
                      ),
                      const SizedBox(height: 10),
                      _buildScopeOptionCard(
                        value: 'balanced_department',
                        title: 'Chia đều theo phòng ban',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLeadTypePriorityCard(),
                  const SizedBox(height: 16),
                  _buildParticipantSelectionCard(),
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

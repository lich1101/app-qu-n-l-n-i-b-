import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/attendance_device_identity_service.dart';
import '../../core/services/attendance_wifi_service.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class AttendanceWifiScreen extends StatefulWidget {
  const AttendanceWifiScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.currentUserRole,
  });

  final String token;
  final MobileApiService apiService;
  final String currentUserRole;

  @override
  State<AttendanceWifiScreen> createState() => _AttendanceWifiScreenState();
}

class _AttendanceWifiScreenState extends State<AttendanceWifiScreen> {
  static const List<String> _managerRoles = <String>[
    'admin',
    'administrator',
    'ke_toan',
  ];

  bool _loading = true;
  bool _submitting = false;
  String _activeTab = 'checkin';
  String _message = '';

  Map<String, dynamic> _dashboard = <String, dynamic>{};
  List<Map<String, dynamic>> _records = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _wifiRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _devices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _holidays = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _staffRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _reportRows = <Map<String, dynamic>>[];
  Map<String, dynamic> _reportSummary = <String, dynamic>{};

  String _recordsFromDate = _monthStartIso();
  String _recordsToDate = _todayIso();
  String _requestStatus = '';
  String _deviceStatus = 'pending';
  String _staffRole = '';
  String _reportStartDate = _monthStartIso();
  String _reportEndDate = _todayIso();

  bool _attendanceEnabled = true;
  String _workStartTime = '08:30';
  String _workEndTime = '17:30';
  String _afternoonStartTime = '13:30';
  int _lateGraceMinutes = 10;
  bool _reminderEnabled = true;
  int _reminderMinutesBefore = 10;

  AttendanceDeviceIdentity? _deviceIdentity;
  AttendanceWifiSnapshot? _wifiSnapshot;
  AttendanceWifiPermissionState? _wifiPermissionState;

  bool get _canManage => _managerRoles.contains(widget.currentUserRole);
  bool get _canViewReport =>
      _canManage ||
      widget.currentUserRole == 'quan_ly' ||
      widget.currentUserRole == 'nhan_vien';
  bool get _canManualAdjust => widget.currentUserRole == 'administrator';
  bool get _canGetCurrentBssid =>
      <String>['admin', 'administrator'].contains(widget.currentUserRole);
  bool get _canTrack => widget.currentUserRole != 'administrator';

  List<_AttendanceTabItem> get _tabs {
    final List<_AttendanceTabItem> tabs = <_AttendanceTabItem>[
      if (_canTrack)
        const _AttendanceTabItem(
          key: 'checkin',
          label: 'Chấm công',
          icon: Icons.how_to_reg_outlined,
        ),
      if (_canTrack)
        const _AttendanceTabItem(
          key: 'timesheet',
          label: 'Bảng công',
          icon: Icons.calendar_month_outlined,
        ),
      const _AttendanceTabItem(
        key: 'requests',
        label: 'Đơn xin phép',
        icon: Icons.receipt_long_outlined,
      ),
    ];
    if (_canViewReport && !_canManage) {
      tabs.add(
        const _AttendanceTabItem(
          key: 'report',
          label: 'Báo cáo',
          icon: Icons.bar_chart_outlined,
        ),
      );
    }
    if (_canManage) {
      tabs.addAll(const <_AttendanceTabItem>[
        _AttendanceTabItem(
          key: 'settings',
          label: 'Cấu hình',
          icon: Icons.schedule_outlined,
        ),
        _AttendanceTabItem(
          key: 'wifi',
          label: 'Wi-Fi',
          icon: Icons.wifi_outlined,
        ),
        _AttendanceTabItem(
          key: 'devices',
          label: 'Thiết bị',
          icon: Icons.phonelink_lock_outlined,
        ),
        _AttendanceTabItem(
          key: 'holidays',
          label: 'Kỳ nghỉ',
          icon: Icons.event_available_outlined,
        ),
        _AttendanceTabItem(
          key: 'staff',
          label: 'Nhân sự',
          icon: Icons.groups_2_outlined,
        ),
        _AttendanceTabItem(
          key: 'report',
          label: 'Báo cáo',
          icon: Icons.bar_chart_outlined,
        ),
      ]);
    }
    return tabs;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  static String _todayIso() {
    return VietnamTime.todayIso();
  }

  static String _monthStartIso() {
    return VietnamTime.monthStartIso();
  }

  static String _formatDate(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _displayDateToIso(String? value) {
    if (value == null || value.trim().isEmpty) return _todayIso();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return value;
    final List<String> parts = value.split('/');
    if (parts.length != 3) return _todayIso();
    final String day = parts[0].padLeft(2, '0');
    final String month = parts[1].padLeft(2, '0');
    final String year = parts[2].padLeft(4, '0');
    return '$year-$month-$day';
  }

  static String _formatDateLabel(String? value) {
    if (value == null || value.isEmpty) return '—';
    final DateTime? parsed = VietnamTime.parse(value);
    if (parsed == null) return value;
    return VietnamTime.formatDate(parsed);
  }

  static String _formatDateTimeLabel(String? value) {
    if (value == null || value.isEmpty) return '—';
    final DateTime? parsed = VietnamTime.parse(value);
    if (parsed == null) return value;
    return VietnamTime.formatDateTime(parsed);
  }

  static String _formatHolidayRangeLabel(Map<String, dynamic> item) {
    final String startDate =
        (item['start_date'] ?? item['holiday_date'] ?? '').toString();
    final String endDate =
        (item['end_date'] ?? item['holiday_date'] ?? '').toString();
    final int dayCount = ((item['day_count'] as num?) ?? 1).toInt();
    final String range =
        startDate.isNotEmpty && endDate.isNotEmpty && startDate != endDate
            ? '${_formatDateLabel(startDate)} - ${_formatDateLabel(endDate)}'
            : _formatDateLabel(startDate);
    return dayCount > 1 ? '$range • $dayCount ngày' : range;
  }

  Future<void> _bootstrap() async {
    await _resolveDeviceIdentity();
    await _refreshWifiSnapshot(silent: true, requestPermissions: false);
    await _refreshAll(showLoader: true);
  }

  Future<void> _resolveDeviceIdentity() async {
    final AttendanceDeviceIdentity identity =
        await AttendanceDeviceIdentityService.resolve();
    if (!mounted) return;
    setState(() => _deviceIdentity = identity);
  }

  Future<void> _refreshWifiSnapshot({
    bool silent = false,
    bool requestPermissions = false,
  }) async {
    if (!silent && mounted) {
      setState(() => _submitting = true);
    }
    final AttendanceWifiPermissionState permissionState =
        requestPermissions
            ? await AttendanceWifiService.requestPermission()
            : await AttendanceWifiService.checkPermissionStatus();
    final AttendanceWifiSnapshot snapshot =
        await AttendanceWifiService.readCurrentWifi(requestPermissions: false);
    if (!mounted) return;
    setState(() {
      _wifiPermissionState = permissionState;
      _wifiSnapshot = snapshot;
      if (!silent) {
        _submitting = false;
      }
    });
  }

  Future<void> _refreshAll({bool showLoader = false}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }
    String errorMessage = '';
    await Future.wait(<Future<void>>[
      _loadDashboard().catchError((_) {
        errorMessage = 'Không tải được dashboard chấm công.';
      }),
      if (_canTrack) _loadRecords().catchError((_) {}),
      _loadRequests().catchError((_) {}),
      if (_canManage) _loadManagerData().catchError((_) {}),
      if (_canViewReport && !_canManage) _loadReportOnly().catchError((_) {}),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = errorMessage;
      if (!_tabs.any((_AttendanceTabItem tab) => tab.key == _activeTab)) {
        _activeTab = _tabs.first.key;
      }
    });
  }

  Future<void> _loadDashboard() async {
    final Map<String, dynamic> response = await widget.apiService
        .getAttendanceDashboard(widget.token);
    if (response['ok'] != true) {
      throw Exception(response['message']);
    }
    if (!mounted) return;
    setState(() {
      _dashboard = response;
      final dynamic settings = response['settings'];
      if (settings is Map) {
        _attendanceEnabled = settings['enabled'] == true;
        _workStartTime = (settings['work_start_time'] ?? '08:30').toString();
        _workEndTime = (settings['work_end_time'] ?? '17:30').toString();
        _afternoonStartTime =
            (settings['afternoon_start_time'] ?? '13:30').toString();
        _lateGraceMinutes =
            ((settings['late_grace_minutes'] as num?) ?? 10).toInt();
        _reminderEnabled = settings['reminder_enabled'] == true;
        _reminderMinutesBefore =
            ((settings['reminder_minutes_before'] as num?) ?? 10).toInt();
      }
    });
  }

  Future<void> _loadRecords() async {
    final Map<String, dynamic> response = await widget.apiService
        .getAttendanceRecords(
          widget.token,
          fromDate: _recordsFromDate,
          toDate: _recordsToDate,
        );
    if (response['ok'] != true) {
      throw Exception(response['message']);
    }
    if (!mounted) return;
    setState(() {
      _records = _extractRows(response['data']);
    });
  }

  Future<void> _loadRequests() async {
    final Map<String, dynamic> response = await widget.apiService
        .getAttendanceRequests(
          widget.token,
          perPage: 100,
          status: _requestStatus,
        );
    if (response['ok'] != true) {
      throw Exception(response['message']);
    }
    if (!mounted) return;
    setState(() {
      _requests = _extractRows(response['data']);
    });
  }

  Future<void> _loadManagerData() async {
    final List<Future<Map<String, dynamic>>> futures =
        <Future<Map<String, dynamic>>>[
          widget.apiService.getAttendanceWifiNetworks(widget.token),
          widget.apiService.getAttendanceDevices(
            widget.token,
            perPage: 100,
            status: _deviceStatus,
          ),
          widget.apiService.getAttendanceHolidays(
            widget.token,
            fromDate: _monthStartIso(),
            toDate: '2099-12-31',
          ),
          widget.apiService.getAttendanceStaff(
            widget.token,
            perPage: 200,
            role: _staffRole,
          ),
          widget.apiService.getAttendanceReport(
            widget.token,
            startDate: _reportStartDate,
            endDate: _reportEndDate,
          ),
        ];
    final List<Map<String, dynamic>> responses = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _wifiRows = _extractRows(responses[0]['data']);
      _devices = _extractRows(responses[1]['data']);
      _holidays = _extractRows(responses[2]['data']);
      _staffRows = _extractRows(responses[3]['data']);
      _reportRows = _extractRows(responses[4]['data']);
      final dynamic summary = responses[4]['summary'];
      _reportSummary =
          summary is Map
              ? Map<String, dynamic>.from(summary)
              : <String, dynamic>{};
    });
  }

  Future<void> _loadReportOnly() async {
    final Map<String, dynamic> response = await widget.apiService
        .getAttendanceReport(
          widget.token,
          startDate: _reportStartDate,
          endDate: _reportEndDate,
        );
    if (response['ok'] != true) {
      throw Exception(response['message']);
    }
    if (!mounted) return;
    setState(() {
      _reportRows = _extractRows(response['data']);
      final dynamic summary = response['summary'];
      _reportSummary =
          summary is Map
              ? Map<String, dynamic>.from(summary)
              : <String, dynamic>{};
    });
  }

  List<Map<String, dynamic>> _extractRows(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((Map item) => item.cast<String, dynamic>())
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  String _statusLabel(String status, {int minutesLate = 0}) {
    switch (status) {
      case 'present':
        return 'Đúng công';
      case 'late_pending':
      case 'late':
        return 'Đi muộn${minutesLate > 0 ? ' $minutesLate phút' : ''}';
      case 'approved_full':
        return 'Duyệt đủ công';
      case 'approved_partial':
        return 'Duyệt công';
      case 'holiday_auto':
        return 'Ngày lễ tự động';
      case 'pending':
        return 'Chờ duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return status;
    }
  }

  String _employmentLabel(String type) {
    switch (type) {
      case 'half_day_morning':
        return 'Mỗi sáng';
      case 'half_day_afternoon':
        return 'Mỗi chiều';
      default:
        return 'Toàn thời gian';
    }
  }

  String _requestTypeLabel(String type) {
    switch (type) {
      case 'leave_request':
        return 'Nghỉ phép';
      default:
        return 'Đi muộn';
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'administrator':
        return 'Quản trị hệ thống';
      case 'admin':
        return 'Admin';
      case 'quan_ly':
        return 'Quản lý';
      case 'nhan_vien':
        return 'Nhân viên';
      case 'ke_toan':
        return 'Kế toán';
      default:
        return role;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
      case 'approved':
      case 'approved_full':
      case 'holiday_auto':
        return StitchTheme.successStrong;
      case 'late_pending':
      case 'late':
      case 'pending':
      case 'approved_partial':
        return StitchTheme.warningStrong;
      case 'rejected':
        return StitchTheme.dangerStrong;
      default:
        return StitchTheme.textMuted;
    }
  }

  Future<void> _pickDate({
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) async {
    final DateTime initial =
        VietnamTime.parse(currentValue) ?? VietnamTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 5),
      initialDate: initial,
    );
    if (picked == null || !mounted) return;
    onChanged(_formatDate(picked));
  }

  Future<void> _showAttendanceExportDialog() async {
    String start = _reportStartDate;
    String end = _reportEndDate;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setLocal,
              ) {
                return AlertDialog(
                  title: const Text('Xuất báo cáo công'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Chọn khoảng ngày để tải file Excel (công và phút trễ theo ngày, tổng hợp kỳ và đơn xin phép).',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _PickerField(
                                value: _formatDateLabel(start),
                                icon: Icons.event_outlined,
                                onTap: () async {
                                  await _pickDate(
                                    currentValue: start,
                                    onChanged: (String value) {
                                      setLocal(() => start = value);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PickerField(
                                value: _formatDateLabel(end),
                                icon: Icons.event_outlined,
                                onTap: () async {
                                  await _pickDate(
                                    currentValue: end,
                                    onChanged: (String value) {
                                      setLocal(() => end = value);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed:
                          _submitting
                              ? null
                              : () async {
                                Navigator.of(context).pop();
                                await _runAttendanceExport(start, end);
                              },
                      child: const Text('Tải file'),
                    ),
                  ],
                );
              },
        );
      },
    );
  }

  Future<void> _runAttendanceExport(String start, String end) async {
    setState(() => _submitting = true);
    try {
      final Uint8List bytes = await widget.apiService.downloadAttendanceExport(
        widget.token,
        startDate: start,
        endDate: end,
      );
      final Directory dir = await getTemporaryDirectory();
      final String name = 'bao-cao-cong-$start-den-$end.xlsx';
      final File file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: 'Báo cáo công',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _pickTime({
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) async {
    final List<String> parts = currentValue.split(':');
    final int initialHour = int.tryParse(parts.first) ?? 8;
    final int initialMinute =
        int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      DateTime selected = DateTime(2026, 1, 1, initialHour, initialMinute);
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (BuildContext context) {
          return Container(
            height: 320,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Hủy'),
                        ),
                        const Expanded(
                          child: Text(
                            'Chọn giờ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final String hour = selected.hour
                                .toString()
                                .padLeft(2, '0');
                            final String minute = selected.minute
                                .toString()
                                .padLeft(2, '0');
                            onChanged('$hour:$minute');
                            Navigator.of(context).pop();
                          },
                          child: const Text('Xong'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      initialDateTime: selected,
                      onDateTimeChanged: (DateTime value) {
                        selected = value;
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFFF97316),
              surface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    final String hour = picked.hour.toString().padLeft(2, '0');
    final String minute = picked.minute.toString().padLeft(2, '0');
    onChanged('$hour:$minute');
  }

  Future<void> _submitDeviceRequest() async {
    final AttendanceDeviceIdentity? identity = _deviceIdentity;
    if (identity == null) return;
    setState(() => _submitting = true);
    final Map<String, dynamic> response = await widget.apiService
        .submitAttendanceDevice(
          widget.token,
          deviceUuid: identity.deviceUuid,
          deviceName: identity.deviceName,
          devicePlatform: identity.devicePlatform,
          deviceModel: identity.deviceModel,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _showSnack(response['message'].toString());
    await _refreshAll();
  }

  Future<void> _performCheckIn() async {
    final AttendanceDeviceIdentity? identity = _deviceIdentity;
    if (identity == null) return;
    final Map<String, dynamic>? todayRecord =
        _dashboard['today_record'] as Map<String, dynamic>?;
    final Map<String, dynamic>? device =
        _dashboard['device'] as Map<String, dynamic>?;
    final String deviceStatus = (device?['status'] ?? '').toString();
    final String registeredDeviceUuid =
        (device?['device_uuid'] ?? '').toString();
    final bool alreadyCheckedIn =
        todayRecord != null &&
        (todayRecord['check_in_at'] ?? '').toString().trim().isNotEmpty;

    if (!_attendanceEnabled) {
      _showSnack('Hệ thống đang tạm tắt chấm công Wi‑Fi.');
      return;
    }
    if (_dashboard['check_in_allowed'] == false) {
      final String reason =
          (_dashboard['check_in_block_reason'] ?? 'Chưa đến giờ hoặc ngoài ca làm.')
              .toString();
      _showSnack(reason);
      return;
    }
    if (alreadyCheckedIn) {
      _showSnack('Bạn đã chấm công hôm nay rồi.');
      return;
    }

    await _refreshWifiSnapshot(requestPermissions: true);
    final AttendanceWifiSnapshot? snapshot = _wifiSnapshot;
    final AttendanceWifiPermissionState? permissionState = _wifiPermissionState;
    if (permissionState != null && !permissionState.permissionGranted) {
      _showSnack(
        permissionState.requiresSettings
            ? 'Quyền vị trí đang bị chặn. Vui lòng mở Cài đặt để cấp quyền rồi thử lại.'
            : 'Ứng dụng cần quyền Vị trí để kiểm tra Wi‑Fi công ty.',
      );
      return;
    }
    if (snapshot == null || !snapshot.hasWifi) {
      _showSnack('Wi‑Fi hiện tại chưa đúng Wi‑Fi công ty.');
      return;
    }

    final bool sameDeviceAsRegistered =
        registeredDeviceUuid.isNotEmpty &&
        registeredDeviceUuid == identity.deviceUuid;
    final bool isNewDevice =
        device != null &&
        registeredDeviceUuid.isNotEmpty &&
        registeredDeviceUuid != identity.deviceUuid;

    if (device == null || isNewDevice) {
      await _submitDeviceRequest();
      return;
    }

    if (!sameDeviceAsRegistered || deviceStatus != 'approved') {
      _showSnack('Thiết bị này chưa được duyệt để chấm công.');
      return;
    }
    setState(() => _submitting = true);
    final Map<String, dynamic> response = await widget.apiService
        .checkInAttendance(
          widget.token,
          deviceUuid: identity.deviceUuid,
          deviceName: identity.deviceName,
          devicePlatform: identity.devicePlatform,
          deviceModel: identity.deviceModel,
          wifiSsid: snapshot.ssid!,
          wifiBssid: snapshot.bssid,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _showSnack(response['message'].toString());
    await _refreshAll();
    final dynamic record = response['record'];
    if (record is Map<String, dynamic>) {
      await _showCheckInSuccessSheet(record);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _submitting = true);
    final Map<String, dynamic> response = await widget.apiService
        .updateAttendanceSettings(
          widget.token,
          attendanceEnabled: _attendanceEnabled,
          workStartTime: _workStartTime,
          workEndTime: _workEndTime,
          afternoonStartTime: _afternoonStartTime,
          lateGraceMinutes: _lateGraceMinutes,
          reminderEnabled: _reminderEnabled,
          reminderMinutesBefore: _reminderMinutesBefore,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _showSnack(response['message'].toString());
    if (response['ok'] == true) {
      await _refreshAll();
    }
  }

  Future<void> _updateStaffEmployment(int userId, String employmentType) async {
    final Map<String, dynamic> response = await widget.apiService
        .updateAttendanceStaff(
          widget.token,
          userId,
          employmentType: employmentType,
        );
    _showSnack(response['message'].toString());
    if (response['ok'] == true) {
      await _loadManagerData();
    }
  }

  Future<void> _showLateRequestSheet() async {
    String requestType = 'late_arrival';
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController contentCtrl = TextEditingController();
    final TextEditingController timeCtrl = TextEditingController();
    String requestDate = _todayIso();
    String requestEndDate = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return _SheetScaffold(
              title: 'Gửi đơn xin phép',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _FieldLabel(label: 'Loại đơn'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _buildChoice(
                        label: 'Đi muộn',
                        selected: requestType == 'late_arrival',
                        onTap: () {
                          setSheetState(() => requestType = 'late_arrival');
                        },
                      ),
                      _buildChoice(
                        label: 'Nghỉ phép',
                        selected: requestType == 'leave_request',
                        onTap: () {
                          setSheetState(() => requestType = 'leave_request');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FieldLabel(
                    label:
                        requestType == 'leave_request'
                            ? 'Từ ngày'
                            : 'Ngày áp dụng',
                  ),
                  _PickerField(
                    value: _formatDateLabel(requestDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                      await _pickDate(
                        currentValue: requestDate,
                        onChanged: (String value) {
                          setSheetState(() => requestDate = value);
                        },
                      );
                    },
                  ),
                  if (requestType == 'leave_request') ...<Widget>[
                    const SizedBox(height: 12),
                    _FieldLabel(label: 'Đến ngày (nghỉ nhiều ngày)'),
                    _PickerField(
                      value:
                          requestEndDate.isEmpty
                              ? 'Trùng ngày bắt đầu'
                              : _formatDateLabel(requestEndDate),
                      icon: Icons.calendar_today_outlined,
                      onTap: () async {
                        await _pickDate(
                          currentValue:
                              requestEndDate.isEmpty
                                  ? requestDate
                                  : requestEndDate,
                          onChanged: (String value) {
                            setSheetState(() => requestEndDate = value);
                          },
                        );
                      },
                    ),
                  ],
                  if (requestType == 'late_arrival') ...<Widget>[
                    const SizedBox(height: 12),
                    _FieldLabel(label: 'Giờ dự kiến vào *'),
                    _PickerField(
                      value:
                          timeCtrl.text.isEmpty
                              ? 'Chọn giờ (bắt buộc)'
                              : timeCtrl.text,
                      icon: Icons.schedule_outlined,
                      onTap: () async {
                        await _pickTime(
                          currentValue:
                              timeCtrl.text.isEmpty
                                  ? _workStartTime
                                  : timeCtrl.text,
                          onChanged: (String value) {
                            setSheetState(() => timeCtrl.text = value);
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Tiêu đề *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          _showSnack('Cần nhập tiêu đề đơn.');
                          return;
                        }
                        if (requestType == 'late_arrival' &&
                            timeCtrl.text.trim().isEmpty) {
                          _showSnack('Đơn đi muộn cần có giờ dự kiến vào làm.');
                          return;
                        }
                        Navigator.of(context).pop();
                        setState(() => _submitting = true);
                        final Map<String, dynamic> response = await widget
                            .apiService
                            .submitAttendanceRequest(
                              widget.token,
                              requestType: requestType,
                              requestDate: requestDate,
                              title: titleCtrl.text.trim(),
                              requestEndDate:
                                  requestType == 'leave_request' &&
                                          requestEndDate.isNotEmpty
                                      ? requestEndDate
                                      : null,
                              expectedCheckInTime:
                                  requestType == 'late_arrival'
                                      ? timeCtrl.text.trim()
                                      : null,
                              content: contentCtrl.text.trim(),
                            );
                        if (!mounted) return;
                        setState(() => _submitting = false);
                        _showSnack(response['message'].toString());
                        await _refreshAll();
                      },
                      child: const Text('Gửi đơn'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRequestReviewSheet(Map<String, dynamic> item) async {
    String reviewStatus = 'approved';
    String approvalMode = 'full_work';
    final TextEditingController noteCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return _SheetScaffold(
              title: 'Duyệt đơn #${item['id']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _FieldLabel(label: 'Ket qua'),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('Duyệt'),
                        selected: reviewStatus == 'approved',
                        onSelected: (_) {
                          setSheetState(() => reviewStatus = 'approved');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Từ chối'),
                        selected: reviewStatus == 'rejected',
                        onSelected: (_) {
                          setSheetState(() => reviewStatus = 'rejected');
                        },
                      ),
                    ],
                  ),
                  if (reviewStatus == 'approved') ...<Widget>[
                    const SizedBox(height: 12),
                    _FieldLabel(label: 'Cách tính công'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          (item['request_type'] ?? '').toString() ==
                                  'leave_request'
                              ? <Widget>[
                                _buildChoice(
                                  label: 'Duyệt tính công',
                                  selected: approvalMode == 'full_work',
                                  onTap: () {
                                    setSheetState(
                                      () => approvalMode = 'full_work',
                                    );
                                  },
                                ),
                                _buildChoice(
                                  label: 'Duyệt không tính công',
                                  selected: approvalMode == 'no_count',
                                  onTap: () {
                                    setSheetState(
                                      () => approvalMode = 'no_count',
                                    );
                                  },
                                ),
                              ]
                              : <Widget>[
                                _buildChoice(
                                  label: 'Đủ công (theo đơn)',
                                  selected: approvalMode == 'full_work',
                                  onTap: () {
                                    setSheetState(
                                      () => approvalMode = 'full_work',
                                    );
                                  },
                                ),
                                _buildChoice(
                                  label: 'Giữ công hiện có',
                                  selected: approvalMode == 'no_change',
                                  onTap: () {
                                    setSheetState(
                                      () => approvalMode = 'no_change',
                                    );
                                  },
                                ),
                              ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú duyệt',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        setState(() => _submitting = true);
                        final Map<String, dynamic> response = await widget
                            .apiService
                            .reviewAttendanceRequest(
                              widget.token,
                              ((item['id'] as num?) ?? 0).toInt(),
                              status: reviewStatus,
                              approvalMode:
                                  reviewStatus == 'approved'
                                      ? approvalMode
                                      : null,
                              approvedWorkUnits: null,
                              decisionNote: noteCtrl.text.trim(),
                            );
                        if (!mounted) return;
                        setState(() => _submitting = false);
                        _showSnack(response['message'].toString());
                        await _refreshAll();
                      },
                      child: Text(
                        reviewStatus == 'approved'
                            ? 'Xác nhận duyệt'
                            : 'Xác nhận từ chối',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showWifiFormSheet({
    Map<String, dynamic>? item,
    AttendanceWifiSnapshot? seedWifi,
  }) async {
    final TextEditingController ssidCtrl = TextEditingController(
      text: (item?['ssid'] ?? seedWifi?.ssid ?? '').toString(),
    );
    final TextEditingController bssidCtrl = TextEditingController(
      text: (item?['bssid'] ?? seedWifi?.bssid ?? '').toString(),
    );
    final TextEditingController noteCtrl = TextEditingController(
      text: (item?['note'] ?? '').toString(),
    );
    bool isActive = item == null ? true : item['is_active'] == true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return _SheetScaffold(
              title: item == null ? 'Thêm Wi‑Fi được phép' : 'Sửa Wi‑Fi',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: ssidCtrl,
                    decoration: const InputDecoration(labelText: 'SSID *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bssidCtrl,
                    decoration: const InputDecoration(labelText: 'BSSID'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Đang bật'),
                    value: isActive,
                    onChanged: (bool value) {
                      setSheetState(() => isActive = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (ssidCtrl.text.trim().isEmpty) {
                          _showSnack('Cần nhập SSID.');
                          return;
                        }
                        Navigator.of(context).pop();
                        setState(() => _submitting = true);
                        final Map<String, dynamic> response =
                            item == null
                                ? await widget.apiService
                                    .createAttendanceWifiNetwork(
                                      widget.token,
                                      ssid: ssidCtrl.text.trim(),
                                      bssid: bssidCtrl.text.trim(),
                                      note: noteCtrl.text.trim(),
                                      isActive: isActive,
                                    )
                                : await widget.apiService
                                    .updateAttendanceWifiNetwork(
                                      widget.token,
                                      ((item['id'] as num?) ?? 0).toInt(),
                                      ssid: ssidCtrl.text.trim(),
                                      bssid: bssidCtrl.text.trim(),
                                      note: noteCtrl.text.trim(),
                                      isActive: isActive,
                                    );
                        if (!mounted) return;
                        setState(() => _submitting = false);
                        _showSnack(response['message'].toString());
                        await _refreshAll();
                      },
                      child: Text(
                        item == null ? 'Thêm Wi‑Fi' : 'Cập nhật Wi‑Fi',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteWifi(Map<String, dynamic> item) async {
    final bool confirmed = await _confirmAction(
      title: 'Xóa Wi‑Fi',
      content: 'Xóa mạng ${item['ssid']} khỏi danh sách được phép?',
      confirmLabel: 'Xóa',
      confirmColor: StitchTheme.dangerStrong,
    );
    if (!confirmed) return;
    setState(() => _submitting = true);
    final Map<String, dynamic> response = await widget.apiService
        .deleteAttendanceWifiNetwork(
          widget.token,
          ((item['id'] as num?) ?? 0).toInt(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _showSnack(response['message'].toString());
    await _refreshAll();
  }

  Future<void> _showHolidayFormSheet({Map<String, dynamic>? item}) async {
    final TextEditingController titleCtrl = TextEditingController(
      text: (item?['title'] ?? '').toString(),
    );
    final TextEditingController noteCtrl = TextEditingController(
      text: (item?['note'] ?? '').toString(),
    );
    String startDate =
        (item?['start_date'] ?? item?['holiday_date'] ?? _todayIso())
            .toString();
    String endDate =
        (item?['end_date'] ?? item?['holiday_date'] ?? _todayIso()).toString();
    bool isActive = item == null ? true : item['is_active'] == true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return _SheetScaffold(
              title: item == null ? 'Thêm ngày lễ' : 'Sửa ngày lễ',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _FieldLabel(label: 'Từ ngày'),
                  _PickerField(
                    value: _formatDateLabel(startDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                      await _pickDate(
                        currentValue: startDate,
                        onChanged: (String value) {
                          setSheetState(() => startDate = value);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _FieldLabel(label: 'Đến ngày'),
                  _PickerField(
                    value: _formatDateLabel(endDate),
                    icon: Icons.event_outlined,
                    onTap: () async {
                      await _pickDate(
                        currentValue: endDate,
                        onChanged: (String value) {
                          setSheetState(() => endDate = value);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Tiêu đề *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Đang bật'),
                    value: isActive,
                    onChanged: (bool value) {
                      setSheetState(() => isActive = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          _showSnack('Cần nhập tiêu đề ngày lễ.');
                          return;
                        }
                        final DateTime? start = DateTime.tryParse(startDate);
                        final DateTime? end = DateTime.tryParse(endDate);
                        if (start == null ||
                            end == null ||
                            end.isBefore(start)) {
                          _showSnack(
                            'Ngày kết thúc phải lớn hơn hoặc bằng ngày bắt đầu.',
                          );
                          return;
                        }
                        Navigator.of(context).pop();
                        setState(() => _submitting = true);
                        final Map<String, dynamic> response =
                            item == null
                                ? await widget.apiService
                                    .createAttendanceHoliday(
                                      widget.token,
                                      startDate: startDate,
                                      endDate: endDate,
                                      title: titleCtrl.text.trim(),
                                      note: noteCtrl.text.trim(),
                                      isActive: isActive,
                                    )
                                : await widget.apiService
                                    .updateAttendanceHoliday(
                                      widget.token,
                                      ((item['id'] as num?) ?? 0).toInt(),
                                      startDate: startDate,
                                      endDate: endDate,
                                      title: titleCtrl.text.trim(),
                                      note: noteCtrl.text.trim(),
                                      isActive: isActive,
                                    );
                        if (!mounted) return;
                        setState(() => _submitting = false);
                        _showSnack(response['message'].toString());
                        await _refreshAll();
                      },
                      child: Text(
                        item == null ? 'Thêm ngày lễ' : 'Cập nhật ngày lễ',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteHoliday(Map<String, dynamic> item) async {
    final bool confirmed = await _confirmAction(
      title: 'Xóa ngày lễ',
      content:
          'Xóa kỳ nghỉ ${_formatHolidayRangeLabel(item)} ra khỏi lịch nghỉ?',
      confirmLabel: 'Xóa',
      confirmColor: StitchTheme.dangerStrong,
    );
    if (!confirmed) return;
    setState(() => _submitting = true);
    final Map<String, dynamic> response = await widget.apiService
        .deleteAttendanceHoliday(
          widget.token,
          ((item['id'] as num?) ?? 0).toInt(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _showSnack(response['message'].toString());
    await _refreshAll();
  }

  Future<void> _showDeviceReviewSheet(
    Map<String, dynamic> item,
    String status,
  ) async {
    final TextEditingController noteCtrl = TextEditingController(
      text: (item['note'] ?? '').toString(),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _SheetScaffold(
          title: status == 'approved' ? 'Duyệt thiết bị' : 'Từ chối thiết bị',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${item['user']?['name'] ?? 'Nhân sự'} • ${item['device_name'] ?? 'Thiết bị'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText:
                      status == 'approved' ? 'Ghi chú duyệt' : 'Lý do từ chối',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        status == 'approved'
                            ? StitchTheme.primaryStrong
                            : StitchTheme.dangerStrong,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    setState(() => _submitting = true);
                    final Map<String, dynamic> response = await widget
                        .apiService
                        .reviewAttendanceDevice(
                          widget.token,
                          ((item['id'] as num?) ?? 0).toInt(),
                          status: status,
                          note: noteCtrl.text.trim(),
                        );
                    if (!mounted) return;
                    setState(() => _submitting = false);
                    _showSnack(response['message'].toString());
                    await _refreshAll();
                  },
                  child: Text(
                    status == 'approved'
                        ? 'Xác nhận duyệt'
                        : 'Xác nhận từ chối',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _revokeAttendanceDevice(Map<String, dynamic> item) async {
    if (!_canManualAdjust) return;
    final Map<String, dynamic>? userMap = item['user'] as Map<String, dynamic>?;
    final String name = (userMap?['name'] ?? 'nhân sự').toString();
    final bool ok = await _confirmAction(
      title: 'Gỡ thiết bị',
      content:
          'Gỡ thiết bị khỏi tài khoản $name? Người đó sẽ phải gửi phiếu đăng ký thiết bị lại trên app.',
      confirmLabel: 'Gỡ thiết bị',
      confirmColor: Colors.amber.shade800,
    );
    if (!ok) return;
    setState(() => _submitting = true);
    final Map<String, dynamic> response = await widget.apiService
        .deleteAttendanceDevice(
          widget.token,
          ((item['id'] as num?) ?? 0).toInt(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _showSnack(response['message'].toString());
    if (response['ok'] == true) {
      await _refreshAll();
    }
  }

  double _defaultUnitsForItem(Map<String, dynamic> item) {
    final String employmentType =
        (item['user']?['attendance_employment_type'] ?? 'full_time').toString();
    return employmentType == 'full_time' ? 1.0 : 0.5;
  }

  double _roundWorkUnits(double value) {
    return ((value * 2).roundToDouble() / 2).clamp(0.0, 1.0);
  }

  Future<void> _showManualRecordSheet({Map<String, dynamic>? item}) async {
    if (!_canManualAdjust) return;
    final List<Map<String, dynamic>> selectableStaff = <Map<String, dynamic>>[
      ..._staffRows,
    ];
    final int currentUserId = ((item?['user_id'] as num?) ?? 0).toInt();
    if (currentUserId > 0 &&
        !selectableStaff.any(
          (Map<String, dynamic> staff) =>
              ((staff['id'] as num?) ?? 0).toInt() == currentUserId,
        )) {
      selectableStaff.insert(0, <String, dynamic>{
        'id': currentUserId,
        'name': (item?['user_name'] ?? 'Nhân sự').toString(),
        'role': (item?['role'] ?? '—').toString(),
      });
    }
    int? selectedUserId =
        ((item?['user_id'] as num?) ??
                (selectableStaff.isNotEmpty
                    ? selectableStaff.first['id'] as num?
                    : null))
            ?.toInt();
    String workDate = _displayDateToIso((item?['work_date'] ?? '').toString());
    String checkInTime =
        (item?['check_in_at'] ?? '').toString() == '—'
            ? ''
            : (item?['check_in_at'] ?? '').toString();
    double workUnits = _roundWorkUnits(
      ((item?['work_units'] as num?) ??
              _defaultUnitsForItem(item ?? <String, dynamic>{}))
          .toDouble(),
    );
    final TextEditingController noteCtrl = TextEditingController(
      text: (item?['note'] ?? '').toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return _SheetScaffold(
              title:
                  item == null
                      ? 'Sửa công thủ công'
                      : 'Sửa công ${item['user_name'] ?? ''}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    value: selectedUserId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Nhân sự *'),
                    items:
                        selectableStaff.map((Map<String, dynamic> staff) {
                          final int staffId =
                              ((staff['id'] as num?) ?? 0).toInt();
                          return DropdownMenuItem<int>(
                            value: staffId,
                            child: Text(
                              '${staff['name'] ?? 'Nhân sự'} • ${staff['role'] ?? '—'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: (int? value) {
                      setSheetState(() => selectedUserId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _FieldLabel(label: 'Ngày công'),
                  _PickerField(
                    value: _formatDateLabel(workDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                      await _pickDate(
                        currentValue: workDate,
                        onChanged: (String value) {
                          setSheetState(() => workDate = value);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _FieldLabel(label: 'Giờ vào'),
                  _PickerField(
                    value:
                        checkInTime.isEmpty ? 'Không ghi giờ vào' : checkInTime,
                    icon: Icons.access_time_outlined,
                    onTap: () async {
                      await _pickTime(
                        currentValue: checkInTime,
                        onChanged: (String value) {
                          setSheetState(() => checkInTime = value);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _FieldLabel(label: 'Số công'),
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          setSheetState(() {
                            workUnits = _roundWorkUnits(workUnits - 0.5);
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            workUnits.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setSheetState(() {
                            workUnits = _roundWorkUnits(workUnits + 0.5);
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nhập công theo bước 0.5. 1.0 là đủ ngày, 0.5 là nửa buổi. Có thể đặt 0.0 nếu cần điều chỉnh vắng mặt.',
                    style: TextStyle(
                      fontSize: 12,
                      color: StitchTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (selectedUserId == null || selectedUserId == 0) {
                          _showSnack('Cần chọn nhân sự cần sửa công.');
                          return;
                        }
                        Navigator.of(context).pop();
                        setState(() => _submitting = true);
                        final Map<String, dynamic> response = await widget
                            .apiService
                            .manualUpdateAttendanceRecord(
                              widget.token,
                              userId: selectedUserId!,
                              workDate: workDate,
                              workUnits: workUnits,
                              checkInTime: checkInTime,
                              note: noteCtrl.text.trim(),
                            );
                        if (!mounted) return;
                        setState(() => _submitting = false);
                        _showSnack(response['message'].toString());
                        await _refreshAll();
                      },
                      child: const Text('Lưu công'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _reportDotToneColor(String? tone) {
    switch (tone) {
      case 'orange':
        return Colors.deepOrange;
      case 'blue':
        return Colors.blue.shade700;
      case 'teal':
        return Colors.teal;
      default:
        return StitchTheme.textMuted;
    }
  }

  String _reportDotToneLabel(String? tone) {
    switch (tone) {
      case 'orange':
        return 'Chấm app (chưa chỉnh)';
      case 'blue':
        return 'Đã chỉnh / duyệt';
      case 'teal':
        return 'Ngày lễ (tự động)';
      default:
        return tone ?? '—';
    }
  }

  Map<String, dynamic> _mergeForManualFromDetail(
    Map<String, dynamic> reportRow,
    Map<String, dynamic> record,
  ) {
    return <String, dynamic>{
      'user_id':
          ((record['user_id'] as num?) ?? (reportRow['user_id'] as num?))
              ?.toInt() ??
          0,
      'user_name': (reportRow['user_name'] ?? 'Nhân sự').toString(),
      'role': (reportRow['role'] ?? '—').toString(),
      'work_date': (record['work_date'] ?? reportRow['work_date'] ?? '')
          .toString(),
      'check_in_at': (record['check_in_at'] ?? '').toString(),
      'work_units': record['work_units'],
      'note': (record['note'] ?? '').toString(),
    };
  }

  Future<void> _showReportRecordDetailSheet(Map<String, dynamic> row) async {
    final int? recordId = (row['id'] as num?)?.toInt();
    if (recordId == null || recordId <= 0) {
      _showSnack('Không có bản ghi để xem chi tiết.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _ReportRecordDetailSheet(
          token: widget.token,
          apiService: widget.apiService,
          recordId: recordId,
          reportRow: row,
          canManualAdjust: _canManualAdjust,
          onOpenManualEdit: (Map<String, dynamic> record) {
            Navigator.of(sheetContext).pop();
            _showManualRecordSheet(
              item: _mergeForManualFromDetail(row, record),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: confirmColor),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCheckInSuccessSheet(Map<String, dynamic> record) async {
    final String checkInAt = (record['check_in_at'] ?? '').toString();
    final String checkInTime =
        checkInAt.trim().isEmpty
            ? '—'
            : _formatDateTimeLabel(checkInAt).split(' ').last;
    final String statusLabel = _statusLabel(
      (record['status'] ?? '').toString(),
      minutesLate: ((record['minutes_late'] as num?) ?? 0).toInt(),
    );
    final String schedule = '$_workStartTime - $_workEndTime';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: StitchTheme.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: StitchTheme.success.withValues(alpha: 0.1),
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: StitchTheme.success,
                          boxShadow: [
                            BoxShadow(
                              color: StitchTheme.success,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Chấm công thành công',
                    style: TextStyle(
                      color: StitchTheme.textMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lịch làm việc hôm nay: $schedule',
                    style: const TextStyle(
                      color: StitchTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: StitchTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 16, color: StitchTheme.textMuted),
                                  SizedBox(width: 6),
                                  Text('Giờ vào làm', style: TextStyle(color: StitchTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(checkInTime, style: const TextStyle(color: StitchTheme.textMain, fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: StitchTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.fact_check_outlined, size: 16, color: StitchTheme.textMuted),
                                  SizedBox(width: 6),
                                  Text('Trạng thái', style: TextStyle(color: StitchTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(statusLabel, style: TextStyle(color: _statusColor((record['status'] ?? '').toString()), fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: StitchTheme.primaryStrong,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() => _activeTab = 'timesheet');
                      },
                      child: const Text('Xem bảng công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: StitchTheme.surfaceAlt,
      selectedColor: StitchTheme.primarySoft,
      side: BorderSide(
        color: selected ? StitchTheme.primaryStrong : StitchTheme.border,
      ),
      labelStyle: const TextStyle(
        color: StitchTheme.textMain,
        fontWeight: FontWeight.w700,
      ),
      checkmarkColor: StitchTheme.textMain,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_AttendanceTabItem> tabs = _tabs;
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    final bool showCheckInDock = _canTrack && _activeTab == 'checkin';
    final bool shiftBlocked = _dashboard['check_in_allowed'] == false;
    final String shiftReason =
        (_dashboard['check_in_block_reason'] ?? '').toString().trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Chấm công Wi‑Fi')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          showCheckInDock
              ? _AttendanceCheckInDock(
                busy: _submitting,
                completed:
                    (_dashboard['today_record']?['check_in_at'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty,
                shiftBlocked: shiftBlocked,
                shiftMessage: shiftReason,
                onTap: _submitting ? null : _performCheckIn,
              )
              : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFF7FBFC),
              StitchTheme.bg,
              StitchTheme.surfaceAlt,
            ],
          ),
        ),
        child: SafeArea(
          child:
              _loading && _dashboard.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                    onRefresh: _refreshAll,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        (showCheckInDock ? 108 : 32) + bottomSafe,
                      ),
                      children: <Widget>[
                        if (_message.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          _InfoBanner(
                            tone: _InfoTone.warning,
                            title: 'Thông tin',
                            message: _message,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _AttendanceTabBarCard(
                          children:
                              tabs.map((_AttendanceTabItem tab) {
                                final bool selected = _activeTab == tab.key;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    avatar: Icon(
                                      tab.icon,
                                      size: 18,
                                      color:
                                          selected
                                              ? Colors.white
                                              : StitchTheme.textMuted,
                                    ),
                                    label: Text(tab.label),
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() => _activeTab = tab.key);
                                    },
                                    selectedColor: StitchTheme.primaryStrong,
                                    labelStyle: TextStyle(
                                      color:
                                          selected
                                              ? Colors.white
                                              : StitchTheme.textMain,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 16),
                        ..._buildTabBody(),
                        if (_submitting) ...<Widget>[
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  List<Widget> _buildTabBody() {
    switch (_activeTab) {
      case 'checkin':
        return _buildCheckInTab();
      case 'timesheet':
        return _buildTimesheetTab();
      case 'requests':
        return _buildRequestsTab();
      case 'settings':
        return _buildSettingsTab();
      case 'wifi':
        return _buildWifiTab();
      case 'devices':
        return _buildDevicesTab();
      case 'holidays':
        return _buildHolidaysTab();
      case 'staff':
        return _buildStaffTab();
      case 'report':
        return _buildReportTab();
      default:
        return _canTrack ? _buildCheckInTab() : _buildRequestsTab();
    }
  }

  List<Widget> _buildCheckInTab() {
    final Map<String, dynamic>? todayRecord =
        _dashboard['today_record'] as Map<String, dynamic>?;
    final Map<String, dynamic>? device =
        _dashboard['device'] as Map<String, dynamic>?;
    final AttendanceWifiSnapshot? wifi = _wifiSnapshot;
    final AttendanceWifiPermissionState? wifiPermission = _wifiPermissionState;
    final String deviceStatus = (device?['status'] ?? '').toString();
    final String registeredDeviceUuid =
        (device?['device_uuid'] ?? '').toString();
    final bool wifiPermissionReady =
        wifiPermission?.permissionGranted ?? (wifi?.permissionGranted ?? false);
    final bool wifiConnected = wifi?.hasWifi ?? false;
    final bool sameDeviceAsRegistered =
        registeredDeviceUuid.isNotEmpty &&
        _deviceIdentity != null &&
        registeredDeviceUuid == _deviceIdentity!.deviceUuid;
    final bool deviceApproved =
        sameDeviceAsRegistered && deviceStatus == 'approved';
    final bool alreadyCheckedIn =
        todayRecord != null &&
        (todayRecord['check_in_at'] ?? '').toString().trim().isNotEmpty;
    final bool canCheckInNow =
        _attendanceEnabled &&
        wifiPermissionReady &&
        wifiConnected &&
        deviceApproved &&
        !alreadyCheckedIn;
    final double todayWorkUnits =
        ((todayRecord?['work_units'] as num?) ?? 0).toDouble();

    String formatUnits(double value) {
      final double normalized = double.parse(value.toStringAsFixed(2));
      if ((normalized - normalized.roundToDouble()).abs() < 0.001) {
        return normalized.toStringAsFixed(0);
      }
      // Nếu phần thập phân 2 chữ số thì hiện 2
      final double oneDecimal = double.parse(value.toStringAsFixed(1));
      if ((normalized - oneDecimal).abs() < 0.001) {
        return oneDecimal.toStringAsFixed(1);
      }
      return normalized.toStringAsFixed(2);
    }

    final Color heroColor =
        alreadyCheckedIn
            ? StitchTheme.successStrong
            : canCheckInNow
            ? StitchTheme.primaryStrong
            : (!_attendanceEnabled
                ? StitchTheme.textMuted
                : StitchTheme.warningStrong);
    final IconData heroIcon =
        alreadyCheckedIn
            ? Icons.check_circle_rounded
            : canCheckInNow
            ? Icons.how_to_reg_rounded
            : Icons.phonelink_lock_outlined;
    final int todayMinutesLate =
        ((todayRecord?['minutes_late'] as num?) ?? 0).toInt();
    final String heroSubtitle =
        !_attendanceEnabled
            ? 'Quản trị đang tạm khóa chức năng chấm công Wi‑Fi trên toàn hệ thống.'
            : alreadyCheckedIn
            ? (todayMinutesLate > 0
                ? 'Bạn đi muộn $todayMinutesLate phút. Hệ thống đã tự tính ${formatUnits(todayWorkUnits)} công.'
                : 'Giờ vào làm của bạn đã được ghi nhận.')
            : 'Khi bắt đầu vào làm, bạn chỉ cần bấm nút bên dưới. Hệ thống sẽ tự kiểm tra Wi‑Fi công ty và trạng thái thiết bị trước khi ghi nhận công.';

    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _AttendancePrimaryCard(
          accent: heroColor,
          icon: heroIcon,
          title: '',
          subtitle: heroSubtitle,
          buttonLabel: null,
          onPressed: null,
          footers: <Widget>[
            _StatusPill(
              label:
                  alreadyCheckedIn
                      ? 'Giờ vào: ${_formatDateTimeLabel((todayRecord['check_in_at'] ?? '').toString()).split(' ').last}'
                      : (todayRecord == null
                          ? 'Chưa chấm công'
                          : _statusLabel(
                            (todayRecord['status'] ?? '').toString(),
                            minutesLate: ((todayRecord['minutes_late'] as num?) ?? 0).toInt(),
                          )),
              color:
                  alreadyCheckedIn
                      ? StitchTheme.successStrong
                      : _statusColor((todayRecord?['status'] ?? '').toString()),
            ),
            _StatusPill(
              label: 'Số công hôm nay: ${formatUnits(todayWorkUnits)}',
              color: StitchTheme.primaryStrong,
            ),
          ],
          actions: const <Widget>[],
        ),
      ),
    ];
  }

  List<Widget> _buildTimesheetTab() {
    final double totalUnits = _records.fold<double>(
      0,
      (double sum, Map<String, dynamic> item) =>
          sum + (((item['work_units'] as num?) ?? 0).toDouble()),
    );
    final int lateDays =
        _records.where((Map<String, dynamic> item) {
          return (((item['minutes_late'] as num?) ?? 0).toInt()) > 0;
        }).length;
    final int lateMinutes = _records.fold<int>(
      0,
      (int sum, Map<String, dynamic> item) =>
          sum + (((item['minutes_late'] as num?) ?? 0).toInt()),
    );

    String formatUnits(double value) {
      final double normalized = double.parse(value.toStringAsFixed(2));
      if ((normalized - normalized.roundToDouble()).abs() < 0.001) {
        return normalized.toStringAsFixed(0);
      }
      final double oneDecimal = double.parse(value.toStringAsFixed(1));
      if ((normalized - oneDecimal).abs() < 0.001) {
        return oneDecimal.toStringAsFixed(1);
      }
      return normalized.toStringAsFixed(2);
    }

    return <Widget>[
      _SectionCard(
        title: 'Bảng công cá nhân',
        subtitle:
            'Xem công đã ghi nhận theo khoảng ngày. Nếu đi muộn, hãy tạo đơn để người phụ trách duyệt.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _AttendanceSectionLabel('Khoảng ngày'),
            const SizedBox(height: 8),
            _AttendanceFilterPad(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _PickerField(
                      value: _formatDateLabel(_recordsFromDate),
                      icon: Icons.date_range_outlined,
                      onTap: () async {
                        await _pickDate(
                          currentValue: _recordsFromDate,
                          onChanged: (String value) {
                            setState(() => _recordsFromDate = value);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerField(
                      value: _formatDateLabel(_recordsToDate),
                      icon: Icons.date_range_outlined,
                      onTap: () async {
                        await _pickDate(
                          currentValue: _recordsToDate,
                          onChanged: (String value) {
                            setState(() => _recordsToDate = value);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    _submitting
                        ? null
                        : () async {
                          setState(() => _submitting = true);
                          await _loadRecords();
                          if (!mounted) return;
                          setState(() => _submitting = false);
                        },
                icon: const Icon(Icons.search_outlined),
                label: const Text('Xem bảng công'),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: StitchTheme.border),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: StitchMetricCard(
                    icon: Icons.task_alt_outlined,
                    label: 'Tổng số công',
                    value: formatUnits(totalUnits),
                    accent: StitchTheme.primaryStrong,
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: StitchMetricCard(
                    icon: Icons.schedule_outlined,
                    label: 'Số ngày đi muộn',
                    value: '$lateDays',
                    accent: StitchTheme.warningStrong,
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: StitchMetricCard(
                    icon: Icons.hourglass_bottom_outlined,
                    label: 'Tổng phút muộn',
                    value: '$lateMinutes',
                    accent: StitchTheme.warningStrong,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      _SectionCard(
        title: 'Chi tiết ngày công',
        subtitle:
            'Mỗi dòng thể hiện giờ vào làm, số công thực tế và trạng thái đã được ghi nhận trong hệ thống.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_records.isEmpty)
              const Text(
                'Chưa có bản ghi công trong khoảng đã chọn.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              ..._records.map((Map<String, dynamic> item) {
                return _ListCard(
                  title: _formatDateLabel((item['work_date'] ?? '').toString()),
                  subtitle:
                      'Giờ vào: ${_formatDateTimeLabel((item['check_in_at'] ?? '').toString())}',
                  trailing: _StatusPill(
                    label: _statusLabel((item['status'] ?? '').toString(), minutesLate: ((item['minutes_late'] as num?) ?? 0).toInt()),
                    color: _statusColor((item['status'] ?? '').toString()),
                  ),
                  details: <Widget>[
                    _MiniLine(
                      label: 'Số công',
                      value: '${item['work_units'] ?? 0}',
                    ),
                    _MiniLine(
                      label: 'Đi muộn',
                      value: '${item['minutes_late'] ?? 0} phút',
                    ),
                    _MiniLine(
                      label: 'Wi‑Fi',
                      value: (item['wifi_ssid'] ?? '—').toString(),
                    ),
                    if ((item['note'] ?? '').toString().trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          (item['note'] ?? '').toString(),
                          style: const TextStyle(
                            color: StitchTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildRequestsTab() {
    final List<Map<String, dynamic>> rows =
        _requestStatus.isEmpty
            ? _requests
            : _requests
                .where(
                  (Map<String, dynamic> item) =>
                      (item['status'] ?? '').toString() == _requestStatus,
                )
                .toList();
    return <Widget>[
      _SectionCard(
        title: 'Đơn xin phép',
        subtitle:
            _canManage
                ? 'Nhân viên có thể gửi đơn đi muộn hoặc nghỉ phép. Admin, quản trị hệ thống và kế toán sẽ duyệt và quyết định số công.'
                : 'Bạn có thể gửi đơn đi muộn hoặc nghỉ phép. Sau khi duyệt, hệ thống sẽ tính công theo quyết định phê duyệt.',
        action:
            _canTrack
                ? OutlinedButton.icon(
                  onPressed: _submitting ? null : _showLateRequestSheet,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Tạo đơn'),
                )
                : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _AttendanceSectionLabel('Lọc trạng thái'),
            const SizedBox(height: 8),
            _AttendanceFilterPad(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _buildChoice(
                    label: 'Tất cả',
                    selected: _requestStatus.isEmpty,
                    onTap: () async {
                      setState(() => _requestStatus = '');
                      await _loadRequests();
                    },
                  ),
                  _buildChoice(
                    label: 'Chờ duyệt',
                    selected: _requestStatus == 'pending',
                    onTap: () async {
                      setState(() => _requestStatus = 'pending');
                      await _loadRequests();
                    },
                  ),
                  _buildChoice(
                    label: 'Đã duyệt',
                    selected: _requestStatus == 'approved',
                    onTap: () async {
                      setState(() => _requestStatus = 'approved');
                      await _loadRequests();
                    },
                  ),
                  _buildChoice(
                    label: 'Từ chối',
                    selected: _requestStatus == 'rejected',
                    onTap: () async {
                      setState(() => _requestStatus = 'rejected');
                      await _loadRequests();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text(
                'Chưa có đơn nào.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              ...rows.map((Map<String, dynamic> item) {
                final Map<String, dynamic>? user =
                    item['user'] as Map<String, dynamic>?;
                return _ListCard(
                  title: (item['title'] ?? 'Đơn chấm công').toString(),
                  subtitle:
                      '${user?['name'] ?? 'Người dùng'} • ${_formatDateLabel((item['request_date'] ?? '').toString())}',
                  trailing: _StatusPill(
                    label: _statusLabel((item['status'] ?? '').toString()),
                    color: _statusColor((item['status'] ?? '').toString()),
                  ),
                  actions:
                      _canManage && (item['status'] ?? '') == 'pending'
                          ? <Widget>[
                            FilledButton(
                              onPressed:
                                  _submitting
                                      ? null
                                      : () => _showRequestReviewSheet(item),
                              child: const Text('Duyệt'),
                            ),
                          ]
                          : null,
                  details: <Widget>[
                    _MiniLine(
                      label: 'Loại đơn',
                      value: _requestTypeLabel(
                        (item['request_type'] ?? '').toString(),
                      ),
                    ),
                    if ((item['expected_check_in_time'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      _MiniLine(
                        label: 'Giờ dự kiến vào',
                        value:
                            (item['expected_check_in_time'] ?? '').toString(),
                      ),
                    if ((item['content'] ?? '').toString().trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          (item['content'] ?? '').toString(),
                          style: const TextStyle(height: 1.4),
                        ),
                      ),
                    if ((item['decision_note'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _InfoBanner(
                          tone: _InfoTone.info,
                          title: 'Ghi chú duyệt',
                          message: (item['decision_note'] ?? '').toString(),
                        ),
                      ),
                  ],
                );
              }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildSettingsTab() {
    return <Widget>[
      _SectionCard(
        title: 'Cấu hình chấm công',
        subtitle:
            'Admin, quản trị hệ thống và kế toán được đổi mốc giờ, thời gian cho phép đi muộn và nhắc giờ chấm công.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bật chấm công Wi‑Fi'),
              subtitle: const Text('Tắt sẽ khóa check-in toàn hệ thống.'),
              value: _attendanceEnabled,
              onChanged: (bool value) {
                setState(() => _attendanceEnabled = value);
              },
            ),
            const SizedBox(height: 8),
            _PickerSettingTile(
              label: 'Giờ bắt đầu làm',
              value: _workStartTime,
              icon: Icons.login_outlined,
              onTap: () async {
                await _pickTime(
                  currentValue: _workStartTime,
                  onChanged: (String value) {
                    setState(() => _workStartTime = value);
                  },
                );
              },
            ),
            _PickerSettingTile(
              label: 'Giờ bắt đầu buổi chiều',
              value: _afternoonStartTime,
              icon: Icons.wb_sunny_outlined,
              onTap: () async {
                await _pickTime(
                  currentValue: _afternoonStartTime,
                  onChanged: (String value) {
                    setState(() => _afternoonStartTime = value);
                  },
                );
              },
            ),
            _PickerSettingTile(
              label: 'Giờ kết thúc làm',
              value: _workEndTime,
              icon: Icons.logout_outlined,
              onTap: () async {
                await _pickTime(
                  currentValue: _workEndTime,
                  onChanged: (String value) {
                    setState(() => _workEndTime = value);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            _CounterTile(
              label: 'Số phút đến trễ cho phép',
              value: _lateGraceMinutes,
              onChanged: (int value) {
                setState(() => _lateGraceMinutes = value.clamp(0, 240));
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bật nhắc trước giờ vào làm'),
              subtitle: const Text(
                'Thông báo push trước giờ vào làm theo từng nhân sự.',
              ),
              value: _reminderEnabled,
              onChanged: (bool value) {
                setState(() => _reminderEnabled = value);
              },
            ),
            _CounterTile(
              label: 'Số phút nhắc trước',
              value: _reminderMinutesBefore,
              onChanged: (int value) {
                setState(() => _reminderMinutesBefore = value.clamp(0, 120));
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _saveSettings,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Lưu cấu hình'),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildWifiTab() {
    return <Widget>[
      _SectionCard(
        title: 'Danh sách Wi‑Fi/BSSID được phép',
        subtitle:
            'Chỉ có thiết bị đã duyệt và đang nằm trên Wi‑Fi này mới check-in hợp lệ.',
        action: FilledButton.icon(
          onPressed: _submitting ? null : () => _showWifiFormSheet(),
          icon: const Icon(Icons.add),
          label: const Text('Thêm'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_canGetCurrentBssid) ...<Widget>[
              _InfoBanner(
                tone: _InfoTone.info,
                title: 'Lấy BSSID trên app',
                message:
                    'Trình duyệt web không đọc được BSSID, nhưng admin và quản trị hệ thống có thể lấy và điền nhanh ngay trên mobile app.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed:
                        _submitting
                            ? null
                            : () => _refreshWifiSnapshot(
                              requestPermissions: true,
                            ),
                    icon: const Icon(Icons.wifi_tethering_outlined),
                    label: const Text('Lấy Wi‑Fi hiện tại'),
                  ),
                  if ((_wifiSnapshot?.hasWifi ?? false))
                    FilledButton.icon(
                      onPressed:
                          _submitting
                              ? null
                              : () =>
                                  _showWifiFormSheet(seedWifi: _wifiSnapshot),
                      icon: const Icon(Icons.add_link_outlined),
                      label: const Text('Dùng mạng đang kết nối'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _KeyValueLine(
                label: 'SSID hiện tại',
                value: _wifiSnapshot?.ssid ?? 'Chưa đọc được',
              ),
              _KeyValueLine(
                label: 'BSSID hiện tại',
                value: _wifiSnapshot?.bssid ?? 'Không có',
              ),
              const SizedBox(height: 12),
            ],
            if (_wifiRows.isEmpty)
              const Text(
                'Chưa có Wi‑Fi nào được phép.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              ..._wifiRows.map((Map<String, dynamic> item) {
                return _ListCard(
                  title: (item['ssid'] ?? 'Wi-Fi').toString(),
                  subtitle:
                      (item['bssid'] ?? 'Áp dụng cho mọi BSSID').toString(),
                  trailing: _StatusPill(
                    label: item['is_active'] == true ? 'Đang bật' : 'Tạm tắt',
                    color:
                        item['is_active'] == true
                            ? StitchTheme.successStrong
                            : StitchTheme.textMuted,
                  ),
                  actions: <Widget>[
                    IconButton(
                      onPressed:
                          _submitting
                              ? null
                              : () => _showWifiFormSheet(item: item),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: _submitting ? null : () => _deleteWifi(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                  details: <Widget>[
                    if ((item['note'] ?? '').toString().trim().isNotEmpty)
                      Text(
                        (item['note'] ?? '').toString(),
                        style: const TextStyle(
                          color: StitchTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                );
              }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildDevicesTab() {
    return <Widget>[
      _SectionCard(
        title: 'Duyệt thiết bị nhân viên',
        subtitle:
            'Mỗi nhân viên chỉ dùng một thiết bị đã được duyệt để chấm công.'
            '${_canManualAdjust ? ' Administrator có thể gỡ liên kết — nhân sự phải đăng ký lại trên app.' : ''}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildChoice(
                  label: 'Chờ duyệt',
                  selected: _deviceStatus == 'pending',
                  onTap: () async {
                    setState(() => _deviceStatus = 'pending');
                    await _loadManagerData();
                  },
                ),
                _buildChoice(
                  label: 'Đã duyệt',
                  selected: _deviceStatus == 'approved',
                  onTap: () async {
                    setState(() => _deviceStatus = 'approved');
                    await _loadManagerData();
                  },
                ),
                _buildChoice(
                  label: 'Từ chối',
                  selected: _deviceStatus == 'rejected',
                  onTap: () async {
                    setState(() => _deviceStatus = 'rejected');
                    await _loadManagerData();
                  },
                ),
                _buildChoice(
                  label: 'Tất cả',
                  selected: _deviceStatus.isEmpty,
                  onTap: () async {
                    setState(() => _deviceStatus = '');
                    await _loadManagerData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_devices.isEmpty)
              const Text(
                'Không có thiết bị nào trong bộ lọc hiện tại.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              ..._devices.map((Map<String, dynamic> item) {
                final Map<String, dynamic>? user =
                    item['user'] as Map<String, dynamic>?;
                final String status = (item['status'] ?? '').toString();
                return _ListCard(
                  title:
                      '${user?['name'] ?? 'Nhân sự'} • ${item['device_name'] ?? 'Thiết bị'}',
                  subtitle:
                      '${item['device_platform'] ?? '—'} • ${(item['device_model'] ?? '—').toString()}',
                  trailing: _StatusPill(
                    label: _statusLabel(status),
                    color: _statusColor(status),
                  ),
                  actions: <Widget>[
                    if (status == 'pending') ...<Widget>[
                      IconButton(
                        onPressed:
                            _submitting
                                ? null
                                : () =>
                                    _showDeviceReviewSheet(item, 'approved'),
                        icon: const Icon(Icons.check_circle_outline),
                      ),
                      IconButton(
                        onPressed:
                            _submitting
                                ? null
                                : () =>
                                    _showDeviceReviewSheet(item, 'rejected'),
                        icon: const Icon(Icons.cancel_outlined),
                      ),
                    ],
                    if (_canManualAdjust)
                      TextButton.icon(
                        onPressed:
                            _submitting
                                ? null
                                : () => _revokeAttendanceDevice(item),
                        icon: const Icon(Icons.link_off_outlined, size: 18),
                        label: const Text('Gỡ thiết bị'),
                      ),
                  ],
                  details: <Widget>[
                    _MiniLine(
                      label: 'Device ID',
                      value: (item['device_uuid'] ?? '—').toString(),
                    ),
                    _MiniLine(
                      label: 'Gửi lúc',
                      value: _formatDateTimeLabel(
                        (item['requested_at'] ?? '').toString(),
                      ),
                    ),
                    if ((item['note'] ?? '').toString().trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          (item['note'] ?? '').toString(),
                          style: const TextStyle(
                            color: StitchTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildHolidaysTab() {
    return <Widget>[
      _SectionCard(
        title: 'Kỳ nghỉ và ngày lễ',
        subtitle:
            'Có thể nhập một khoảng nghỉ nhiều ngày, ví dụ Tết 10 ngày. Cron sẽ tự động tạo bảng công cho từng ngày nằm trong khoảng đó.',
        action: FilledButton.icon(
          onPressed: _submitting ? null : () => _showHolidayFormSheet(),
          icon: const Icon(Icons.add),
          label: const Text('Thêm'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_holidays.isEmpty)
              const Text(
                'Chưa có kỳ nghỉ nào.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              ..._holidays.map((Map<String, dynamic> item) {
                return _ListCard(
                  title: (item['title'] ?? 'Ngày lễ').toString(),
                  subtitle: _formatHolidayRangeLabel(item),
                  trailing: _StatusPill(
                    label: item['is_active'] == true ? 'Đang bật' : 'Tạm tắt',
                    color:
                        item['is_active'] == true
                            ? StitchTheme.successStrong
                            : StitchTheme.textMuted,
                  ),
                  actions: <Widget>[
                    IconButton(
                      onPressed:
                          _submitting
                              ? null
                              : () => _showHolidayFormSheet(item: item),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed:
                          _submitting ? null : () => _deleteHoliday(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                  details: <Widget>[
                    if ((item['note'] ?? '').toString().trim().isNotEmpty)
                      Text(
                        (item['note'] ?? '').toString(),
                        style: const TextStyle(
                          color: StitchTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                );
              }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildStaffTab() {
    return <Widget>[
      _SectionCard(
        title: 'Cấu hình từng nhân sự',
        subtitle:
            'Toàn thời gian được 1 công. Mỗi sáng hoặc mỗi chiều được 0.5 công theo mốc giờ tương ứng.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildChoice(
                  label: 'Tất cả',
                  selected: _staffRole.isEmpty,
                  onTap: () async {
                    setState(() => _staffRole = '');
                    await _loadManagerData();
                  },
                ),
                for (final String role in <String>[
                  'admin',
                  'quan_ly',
                  'nhan_vien',
                  'ke_toan',
                ])
                  _buildChoice(
                    label: _roleLabel(role),
                    selected: _staffRole == role,
                    onTap: () async {
                      setState(() => _staffRole = role);
                      await _loadManagerData();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_staffRows.isEmpty)
              const Text(
                'Chưa có nhân sự phù hợp.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              ..._staffRows.map((Map<String, dynamic> item) {
                final String employmentType =
                    (item['attendance_employment_type'] ?? 'full_time')
                        .toString();
                return _ListCard(
                  title: (item['name'] ?? 'Nhân sự').toString(),
                  subtitle:
                      '${_roleLabel((item['role'] ?? '—').toString())} • ${item['department'] ?? 'Chưa có phòng ban'}',
                  trailing: _StatusPill(
                    label:
                        item['is_active'] == true
                            ? 'Đang hoạt động'
                            : 'Ngừng hoạt động',
                    color:
                        item['is_active'] == true
                            ? StitchTheme.successStrong
                            : StitchTheme.textMuted,
                  ),
                  details: <Widget>[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String type in <String>[
                          'full_time',
                          'half_day_morning',
                          'half_day_afternoon',
                        ])
                          ChoiceChip(
                            label: Text(_employmentLabel(type)),
                            selected: employmentType == type,
                            onSelected: (_) {
                              _updateStaffEmployment(
                                ((item['id'] as num?) ?? 0).toInt(),
                                type,
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildReportTab() {
    return <Widget>[
      _SectionCard(
        title: 'Báo cáo công',
        subtitle:
            'Lọc theo khoảng ngày để tổng hợp số công, ngày đi muộn và ngày lễ tự động. Số công được tính theo bước 0.5 và 1.0 là đủ ngày công.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _AttendanceSectionLabel('Khoảng ngày'),
            const SizedBox(height: 8),
            _AttendanceFilterPad(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _PickerField(
                      value: _formatDateLabel(_reportStartDate),
                      icon: Icons.event_outlined,
                      onTap: () async {
                        await _pickDate(
                          currentValue: _reportStartDate,
                          onChanged: (String value) {
                            setState(() => _reportStartDate = value);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerField(
                      value: _formatDateLabel(_reportEndDate),
                      icon: Icons.event_outlined,
                      onTap: () async {
                        await _pickDate(
                          currentValue: _reportEndDate,
                          onChanged: (String value) {
                            setState(() => _reportEndDate = value);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (_canManualAdjust)
                    OutlinedButton.icon(
                      onPressed:
                          _submitting ? null : () => _showManualRecordSheet(),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Sửa công tay'),
                    ),
                  FilledButton.icon(
                    onPressed:
                        _submitting
                            ? null
                            : () async {
                              setState(() => _submitting = true);
                              if (_canManage) {
                                await _loadManagerData();
                              } else {
                                await _loadReportOnly();
                              }
                              if (!mounted) return;
                              setState(() => _submitting = false);
                            },
                    icon: const Icon(Icons.search_outlined),
                    label: const Text('Xem báo cáo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: StitchTheme.border),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: StitchMetricCard(
                    icon: Icons.groups_2_outlined,
                    label: 'Tổng nhân viên',
                    value: '${_reportSummary['total_staff'] ?? 0}',
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: StitchMetricCard(
                    icon: Icons.work_history_outlined,
                    label: 'Công ngày hiện tại',
                    value: '${_reportSummary['today_work_units'] ?? 0}',
                    accent: StitchTheme.successStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_canManage)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed:
                      _submitting ? null : () => _showAttendanceExportDialog(),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Xuất Excel báo cáo'),
                ),
              ),
            if (_canManage) const SizedBox(height: 12),
            if (_reportRows.isEmpty)
              const Text(
                'Chưa có dữ liệu báo cáo trong khoảng đã chọn.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else ...<Widget>[
              _AttendanceDataTableCard(
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(
                    StitchTheme.primarySoft,
                  ),
                  dataRowMinHeight: 62,
                  dataRowMaxHeight: 72,
                  columns: <DataColumn>[
                    const DataColumn(label: Text('Ngày')),
                    const DataColumn(
                      label: Tooltip(
                        message:
                            'Cam: chấm app chưa chỉnh. Xanh: đã chỉnh/duyệt.',
                        child: Text('Loại'),
                      ),
                    ),
                    const DataColumn(label: Text('Nhân sự')),
                    const DataColumn(label: Text('Vai trò')),
                    const DataColumn(label: Text('Phòng ban')),
                    const DataColumn(label: Text('Giờ vào')),
                    const DataColumn(label: Text('Công')),
                    const DataColumn(label: Text('Đi muộn')),
                    const DataColumn(label: Text('Trạng thái')),
                    const DataColumn(label: Text('Nguồn')),
                    if (_canManualAdjust) const DataColumn(label: Text('')),
                  ],
                  rows:
                      _reportRows.map((Map<String, dynamic> item) {
                        final String tone =
                            (item['dot_tone'] ?? '').toString();
                        return DataRow(
                          onSelectChanged: (bool? selected) {
                            if (selected == true) {
                              _showReportRecordDetailSheet(item);
                            }
                          },
                          cells: <DataCell>[
                            DataCell(
                              Text((item['work_date'] ?? '—').toString()),
                            ),
                            DataCell(
                              Tooltip(
                                message: _reportDotToneLabel(tone),
                                child: Icon(
                                  Icons.circle,
                                  size: 14,
                                  color: _reportDotToneColor(tone),
                                ),
                              ),
                            ),
                            DataCell(
                              Text((item['user_name'] ?? 'Nhân sự').toString()),
                            ),
                            DataCell(
                              Text(
                                _roleLabel((item['role'] ?? '—').toString()),
                              ),
                            ),
                            DataCell(
                              Text((item['department'] ?? '—').toString()),
                            ),
                            DataCell(
                              Text((item['check_in_at'] ?? '—').toString()),
                            ),
                            DataCell(
                              Text((item['work_units'] ?? '0').toString()),
                            ),
                            DataCell(Text('${item['minutes_late'] ?? 0} phút')),
                            DataCell(
                              _StatusPill(
                                label: (item['status_label'] ?? '—').toString(),
                                color: _statusColor(
                                  (item['status'] ?? '').toString(),
                                ),
                              ),
                            ),
                            DataCell(
                              Text((item['source_label'] ?? '—').toString()),
                            ),
                            if (_canManualAdjust)
                              DataCell(
                                OutlinedButton(
                                  onPressed:
                                      _submitting
                                          ? null
                                          : () =>
                                              _showManualRecordSheet(item: item),
                                  child: const Text('Sửa công'),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Cam: chấm công qua app (Wi‑Fi), chưa chỉnh. Xanh dương: đã điều chỉnh hoặc duyệt đơn. Teal: ngày lễ tự động. Chạm dòng để xem chi tiết và lịch sử (nếu có).',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: StitchTheme.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

class _AttendanceTabBarCard extends StatelessWidget {
  const _AttendanceTabBarCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      ),
    );
  }
}

class _AttendanceFilterPad extends StatelessWidget {
  const _AttendanceFilterPad({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StitchTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: child,
    );
  }
}

class _AttendanceSectionLabel extends StatelessWidget {
  const _AttendanceSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.85,
        color: StitchTheme.labelEmphasis,
      ),
    );
  }
}

class _AttendanceDataTableCard extends StatelessWidget {
  const _AttendanceDataTableCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }
}

class _AttendanceTabItem {
  const _AttendanceTabItem({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StitchFilterCard(
        title: title,
        subtitle: subtitle.trim().isEmpty ? null : subtitle,
        trailing: action,
        child: child,
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.details,
    this.actions,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final List<Widget> details;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0E0F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
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
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
          if (details.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ...details,
          ],
          if (actions != null && actions!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions!),
          ],
        ],
      ),
    );
  }
}

class _AttendancePrimaryCard extends StatelessWidget {
  const _AttendancePrimaryCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    required this.footers,
    required this.actions,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onPressed;
  final List<Widget> footers;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: StitchTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.2), width: 2),
            ),
            child: Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[accent.withValues(alpha: 0.8), accent],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 44),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: StitchTheme.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: StitchTheme.textMuted, height: 1.45),
          ),
          if (footers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: footers,
            ),
          ],
          if (buttonLabel != null) ...<Widget>[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(
                  onPressed == null
                      ? Icons.check_circle_outline
                      : Icons.fingerprint,
                ),
                label: Text(buttonLabel!),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

enum _InfoTone { info, warning }

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.tone,
    required this.title,
    required this.message,
  });

  final _InfoTone tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color bg =
        tone == _InfoTone.warning
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFECFDF5);
    final Color border =
        tone == _InfoTone.warning
            ? const Color(0xFFF59E0B)
            : StitchTheme.primaryStrong;
    final Color text =
        tone == _InfoTone.warning
            ? const Color(0xFF9A3412)
            : const Color(0xFF115E59);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(color: text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(message, style: TextStyle(color: text, height: 1.35)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AttendanceCheckInDock extends StatelessWidget {
  const _AttendanceCheckInDock({
    required this.busy,
    required this.completed,
    this.shiftBlocked = false,
    this.shiftMessage = '',
    required this.onTap,
  });

  final bool busy;
  final bool completed;
  final bool shiftBlocked;
  final String shiftMessage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool disabled = busy || completed || shiftBlocked;
    final Color accent =
        completed
            ? StitchTheme.successStrong
            : disabled
            ? StitchTheme.textSubtle
            : const Color(0xFFF97316);
    final Color surface =
        completed
            ? const Color(0xFFECFDF5)
            : disabled
            ? const Color(0xFFF8FAFC)
            : Colors.white;
    final Color border =
        completed
            ? StitchTheme.successStrong.withValues(alpha: 0.18)
            : disabled
            ? StitchTheme.border
            : const Color(0xFFF97316).withValues(alpha: 0.18);
    final String title =
        busy
            ? 'Đang kiểm tra'
            : completed
            ? 'Đã chấm công hôm nay'
            : shiftBlocked
            ? 'Chưa thể chấm công'
            : 'Chấm công vào làm';
    final String subtitle =
        completed
            ? 'Bạn đã ghi nhận giờ vào hôm nay'
            : shiftBlocked && shiftMessage.isNotEmpty
            ? shiftMessage
            : disabled
            ? 'Hiện chưa thể chấm công'
            : 'Nhấn để xác nhận nhanh';

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: disabled ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(minWidth: 188, maxWidth: 228),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: disabled ? 0.08 : 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        completed || disabled
                            ? accent.withValues(alpha: completed ? 0.14 : 0.12)
                            : Colors.white,
                    gradient:
                        completed || disabled
                            ? null
                            : const LinearGradient(
                              colors: <Color>[
                                Color(0xFFF97316),
                                Color(0xFFFB923C),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    border: Border.all(
                      color:
                          completed
                              ? accent.withValues(alpha: 0.18)
                              : disabled
                              ? StitchTheme.border
                              : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  child:
                      busy
                          ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Icon(
                            completed
                                ? Icons.check_rounded
                                : Icons.fingerprint_rounded,
                            color: completed ? accent : Colors.white,
                            size: 20,
                          ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              disabled
                                  ? StitchTheme.textMuted
                                  : StitchTheme.textMain,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              completed
                                  ? StitchTheme.successStrong
                                  : StitchTheme.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!busy) ...<Widget>[
                  const SizedBox(width: 8),
                  Icon(
                    completed
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: completed ? 18 : 14,
                    color:
                        completed
                            ? StitchTheme.successStrong
                            : disabled
                            ? StitchTheme.textSubtle
                            : accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  const _KeyValueLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: StitchTheme.textMain, height: 1.35),
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: StitchTheme.textMuted,
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: StitchTheme.inputBorder),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: StitchTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.expand_more, color: StitchTheme.textSubtle),
          ],
        ),
      ),
    );
  }
}

class _PickerSettingTile extends StatelessWidget {
  const _PickerSettingTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon, color: StitchTheme.primaryStrong),
      title: Text(label),
      subtitle: const Text('Nhan de doi gia tri'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 36,
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

String _attendanceDetailSourceLabel(String? code) {
  switch (code) {
    case 'wifi':
      return 'Wi‑Fi (app)';
    case 'request_approval':
      return 'Duyệt đơn';
    case 'manual_adjustment':
      return 'Điều chỉnh tay';
    case 'holiday_auto':
      return 'Ngày lễ (cron)';
    default:
      return (code ?? '—').toString();
  }
}

String _attendanceDetailStatusLabel(String? status, int minutesLate) {
  switch (status) {
    case 'present':
      return 'Đúng công';
    case 'late_pending':
    case 'late':
      return 'Đi muộn${minutesLate > 0 ? ' $minutesLate phút' : ''}';
    case 'approved_full':
      return 'Duyệt đủ công';
    case 'approved_partial':
      return 'Duyệt công thủ công';
    case 'holiday_auto':
      return 'Ngày lễ tự động';
    default:
      return (status ?? '—').toString();
  }
}

String _attendanceDotToneCaption(String? tone) {
  switch (tone) {
    case 'orange':
      return 'Chấm app (chưa chỉnh)';
    case 'blue':
      return 'Đã chỉnh / duyệt';
    case 'teal':
      return 'Ngày lễ tự động';
    default:
      return tone ?? '—';
  }
}

Color _attendanceDotToneColor(String? tone) {
  switch (tone) {
    case 'orange':
      return Colors.deepOrange;
    case 'blue':
      return Colors.blue.shade700;
    case 'teal':
      return Colors.teal;
    default:
      return StitchTheme.textMuted;
  }
}

class _ReportRecordDetailSheet extends StatefulWidget {
  const _ReportRecordDetailSheet({
    required this.token,
    required this.apiService,
    required this.recordId,
    required this.reportRow,
    required this.canManualAdjust,
    required this.onOpenManualEdit,
  });

  final String token;
  final MobileApiService apiService;
  final int recordId;
  final Map<String, dynamic> reportRow;
  final bool canManualAdjust;
  final void Function(Map<String, dynamic> record) onOpenManualEdit;

  @override
  State<_ReportRecordDetailSheet> createState() =>
      _ReportRecordDetailSheetState();
}

class _ReportRecordDetailSheetState extends State<_ReportRecordDetailSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _record;
  List<Map<String, dynamic>> _editLogs = <Map<String, dynamic>>[];
  bool _formReadOnly = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Map<String, dynamic> res = await widget.apiService
        .getAttendanceRecordDetail(widget.token, widget.recordId);
    if (!mounted) return;
    if (res['ok'] == true) {
      final dynamic raw = res['record'];
      final Map<String, dynamic>? rec =
          raw is Map ? Map<String, dynamic>.from(raw) : null;
      final dynamic logsRaw = res['edit_logs'];
      final List<Map<String, dynamic>> logs = <Map<String, dynamic>>[];
      if (logsRaw is List) {
        for (final dynamic e in logsRaw) {
          if (e is Map) {
            logs.add(Map<String, dynamic>.from(e));
          }
        }
      }
      setState(() {
        _loading = false;
        _error = null;
        _record = rec;
        _editLogs = logs;
        _formReadOnly = res['form_read_only'] != false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Không tải được chi tiết.';
        _record = null;
      });
    }
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: StitchTheme.labelEmphasis,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: StitchTheme.textMain,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userName =
        (widget.reportRow['user_name'] ?? 'Nhân sự').toString();
    final String workDateHint =
        (widget.reportRow['work_date'] ?? '').toString();

    return _SheetScaffold(
      title: 'Chi tiết công — $userName',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (workDateHint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Ngày $workDateHint. ${_formReadOnly ? 'Bạn chỉ xem; chỉ Administrator sửa công trực tiếp không qua đơn.' : 'Administrator có thể điều chỉnh qua «Sửa công tay».'}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: StitchTheme.textMuted,
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: StitchTheme.dangerStrong),
            )
          else if (_record != null) ...<Widget>[
            _kv(
              'Số công',
              (_record!['work_units'] ?? '0').toString(),
            ),
            _kv(
              'Giờ vào (check-in)',
              _AttendanceWifiScreenState._formatDateTimeLabel(
                (_record!['check_in_at'] ?? '').toString(),
              ),
            ),
            _kv(
              'Phút trễ',
              '${(_record!['minutes_late'] as num?)?.toInt() ?? 0}',
            ),
            _kv(
              'Trạng thái',
              _attendanceDetailStatusLabel(
                (_record!['status'] ?? '').toString(),
                ((_record!['minutes_late'] as num?) ?? 0).toInt(),
              ),
            ),
            _kv(
              'Nguồn dữ liệu',
              _attendanceDetailSourceLabel(
                (_record!['source'] ?? '').toString(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.circle,
                    size: 14,
                    color: _attendanceDotToneColor(
                      (_record!['dot_tone'] ?? '').toString(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Loại chấm',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: StitchTheme.labelEmphasis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _attendanceDotToneCaption(
                            (_record!['dot_tone'] ?? '').toString(),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: StitchTheme.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _kv('Ghi chú', (_record!['note'] ?? '').toString().trim().isEmpty
                ? '—'
                : (_record!['note'] ?? '').toString(),),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Thiết bị / Wi‑Fi: ${_record!['device_name'] ?? '—'} • ${_record!['wifi_ssid'] ?? '—'}',
                style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
              ),
            ),
            if (_editLogs.isNotEmpty) ...<Widget>[
              const Text(
                'Lịch sử chỉnh sửa',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: StitchTheme.labelEmphasis,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _editLogs.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (BuildContext context, int i) {
                    final Map<String, dynamic> log = _editLogs[i];
                    final String when = _AttendanceWifiScreenState
                        ._formatDateTimeLabel(
                      (log['created_at'] ?? '').toString(),
                    );
                    final String actor =
                        (log['actor'] is Map
                                ? (log['actor'] as Map)['name']
                                : null)
                            ?.toString() ??
                        'Hệ thống';
                    final String action = (log['action'] ?? '').toString();
                    final dynamic payload = log['payload'];
                    String payloadText = '';
                    if (payload != null) {
                      if (payload is String) {
                        payloadText = payload;
                      } else {
                        try {
                          payloadText = const JsonEncoder.withIndent('  ')
                              .convert(payload);
                        } catch (_) {
                          payloadText = payload.toString();
                        }
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '$when • $actor — $action',
                          style: const TextStyle(
                            fontSize: 11,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                        if (payloadText.isNotEmpty)
                          SelectableText(
                            payloadText,
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.25,
                              color: StitchTheme.textMain,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ] else
              Text(
                (_record!['dot_tone'] ?? '').toString() == 'orange'
                    ? 'Bản ghi gốc từ app — chưa có lịch sử chỉnh sửa.'
                    : 'Chưa có mục lịch sử (có thể chỉnh qua luồng khác).',
                style: const TextStyle(
                  fontSize: 11,
                  color: StitchTheme.textMuted,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ),
                if (widget.canManualAdjust && !_formReadOnly && _record != null) ...<Widget>[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          widget.onOpenManualEdit(Map<String, dynamic>.from(_record!)),
                      child: const Text('Sửa công tay'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: StitchTheme.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

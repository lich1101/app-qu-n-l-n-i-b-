import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/utils/vietnam_time.dart';
import '../../core/widgets/stitch_form_sheet.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
    required this.canDelete,
    this.initialMeetingId,
  });

  final String token;
  final MobileApiService apiService;
  final bool canManage;
  final bool canDelete;

  /// Mở từ push thông báo (payload `meeting_id`).
  final int? initialMeetingId;

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController dateCtrl = TextEditingController();
  final TextEditingController linkCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController minutesCtrl = TextEditingController();
  final TextEditingController searchCtrl = TextEditingController();
  final TextEditingController dateFromCtrl = TextEditingController();
  final TextEditingController dateToCtrl = TextEditingController();

  List<Map<String, dynamic>> meetings = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> users = <Map<String, dynamic>>[];
  Set<int> selectedAttendeeIds = <int>{};
  bool loading = false;
  bool _listRefreshing = false;
  String message = '';
  int? editingMeetingId;
  int? attendeeFilterId;
  DateTime selectedDate = VietnamTime.now();
  bool _openedInitialMeeting = false;

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  DateTime? _parseMeetingDate(String raw) {
    if (raw.trim().isEmpty) return null;
    return VietnamTime.parse(raw);
  }

  String _fmtDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _fmtDateTime(DateTime date, TimeOfDay time) {
    final String hh = time.hour.toString().padLeft(2, '0');
    final String mm = time.minute.toString().padLeft(2, '0');
    return '${_fmtDate(date)} $hh:$mm:00';
  }

  String _displayDateTime(String raw) {
    final DateTime? date = _parseMeetingDate(raw);
    if (date == null) return raw;
    final String dd = date.day.toString().padLeft(2, '0');
    final String mm = date.month.toString().padLeft(2, '0');
    final String yyyy = date.year.toString();
    final String hh = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$minute';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime now = VietnamTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (date == null) return;
    if (!mounted) return;
    setState(() => controller.text = _fmtDate(date));
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final DateTime now = VietnamTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (date == null) return;
    if (!mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    if (!mounted) return;
    setState(() => controller.text = _fmtDateTime(date, time));
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchUsers();
    await _fetch();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    dateCtrl.dispose();
    linkCtrl.dispose();
    descCtrl.dispose();
    minutesCtrl.dispose();
    searchCtrl.dispose();
    dateFromCtrl.dispose();
    dateToCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getUsersLookup(widget.token);
    if (!mounted) return;
    setState(() => users = rows);
  }

  Future<void> _fetch() async {
    setState(() {
      if (meetings.isEmpty) {
        loading = true;
        _listRefreshing = false;
      } else {
        loading = false;
        _listRefreshing = true;
      }
    });
    try {
      final Map<String, dynamic> data = await widget.apiService.getMeetings(
        widget.token,
        search: searchCtrl.text.trim(),
        dateFrom: dateFromCtrl.text.trim(),
        dateTo: dateToCtrl.text.trim(),
        attendeeId: attendeeFilterId,
        perPage: 200,
      );
      if (!mounted) return;
      setState(() {
        loading = false;
        _listRefreshing = false;
        meetings =
            ((data['data'] ?? <dynamic>[]) as List<dynamic>)
                .map((dynamic e) => e as Map<String, dynamic>)
                .toList();
      });
      _tryOpenInitialMeetingFromPush();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          _listRefreshing = false;
        });
      }
    }
  }

  void _tryOpenInitialMeetingFromPush() {
    if (_openedInitialMeeting) return;
    final int? targetId = widget.initialMeetingId;
    if (targetId == null || targetId <= 0) return;
    if (meetings.isEmpty) return;
    for (final Map<String, dynamic> meeting in meetings) {
      if ((_parseInt(meeting['id']) ?? 0) == targetId) {
        _openedInitialMeeting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showMeetingDetails(meeting);
        });
        return;
      }
    }
  }

  Future<List<int>?> _openAttendeePicker(List<int> initialIds) async {
    final Set<int> temp = initialIds.toSet();
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: stitchFormSheetSurfaceDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const StitchFormSheetTitleBar(
                    title: 'Chọn thành viên họp',
                    subtitle:
                        'Chọn một hoặc nhiều người tham gia để lưu vào lịch họp.',
                    icon: Icons.group_add_outlined,
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child:
                            users.isEmpty
                                ? const StitchEmptyState(
                                  title: 'Không tải được thành viên',
                                  subtitle:
                                      'Danh sách người dùng chưa sẵn sàng, hãy thử kéo để tải lại sau.',
                                  icon: Icons.group_off_outlined,
                                )
                                : ListView(
                                  shrinkWrap: true,
                                  children:
                                      users.map((Map<String, dynamic> user) {
                                        final int id =
                                            _parseInt(user['id']) ?? 0;
                                        final bool checked = temp.contains(id);
                                        return CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          value: checked,
                                          title: Text(
                                            (user['name'] ?? '').toString(),
                                          ),
                                          subtitle: Text(
                                            (user['role'] ?? '').toString(),
                                          ),
                                          onChanged: (_) {
                                            setSheetState(() {
                                              if (checked) {
                                                temp.remove(id);
                                              } else {
                                                temp.add(id);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                ),
                      ),
                    ),
                  ),
                  StitchFormSheetActions(
                    primaryLabel: 'Xác nhận',
                    onCancel: () => Navigator.of(context).pop(null),
                    onPrimary: () => Navigator.of(context).pop(temp.toList()),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<String> _selectedAttendeeNames() {
    if (selectedAttendeeIds.isEmpty) return <String>[];
    return users
        .where((Map<String, dynamic> user) {
          final int? id = _parseInt(user['id']);
          return id != null && selectedAttendeeIds.contains(id);
        })
        .map((Map<String, dynamic> user) => (user['name'] ?? '').toString())
        .where((String name) => name.isNotEmpty)
        .toList();
  }

  bool _messageIsError() {
    final String lower = message.toLowerCase();
    return lower.contains('thất bại') ||
        lower.contains('vui lòng') ||
        lower.contains('không có quyền');
  }

  Future<bool> _save() async {
    if (!widget.canManage) {
      setState(() => message = 'Bạn không có quyền tạo/cập nhật lịch họp.');
      return false;
    }
    if (titleCtrl.text.trim().isEmpty || dateCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập Tiêu đề và Thời gian họp.');
      return false;
    }

    final List<int> attendeeIds = selectedAttendeeIds.toList()..sort();
    final bool ok =
        editingMeetingId == null
            ? await widget.apiService.createMeeting(
              widget.token,
              title: titleCtrl.text.trim(),
              scheduledAt: dateCtrl.text.trim(),
              meetingLink:
                  linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
              description:
                  descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              minutes:
                  minutesCtrl.text.trim().isEmpty
                      ? null
                      : minutesCtrl.text.trim(),
              attendeeIds: attendeeIds,
            )
            : await widget.apiService.updateMeeting(
              widget.token,
              editingMeetingId!,
              title: titleCtrl.text.trim(),
              scheduledAt: dateCtrl.text.trim(),
              meetingLink:
                  linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
              description:
                  descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              minutes:
                  minutesCtrl.text.trim().isEmpty
                      ? null
                      : minutesCtrl.text.trim(),
              attendeeIds: attendeeIds,
            );
    if (!mounted) return false;
    setState(() {
      message =
          ok
              ? (editingMeetingId == null
                  ? 'Tạo lịch họp thành công. Đã gửi thông báo cho thành viên.'
                  : 'Cập nhật lịch họp thành công.')
              : (editingMeetingId == null
                  ? 'Tạo lịch họp thất bại.'
                  : 'Cập nhật lịch họp thất bại.');
    });
    if (ok) {
      editingMeetingId = null;
      titleCtrl.clear();
      dateCtrl.clear();
      linkCtrl.clear();
      descCtrl.clear();
      minutesCtrl.clear();
      selectedAttendeeIds = <int>{};
      await _fetch();
    }
    return ok;
  }

  Future<void> _delete(int id) async {
    if (!widget.canDelete) {
      setState(() => message = 'Bạn không có quyền xóa lịch họp.');
      return;
    }
    final bool ok = await widget.apiService.deleteMeeting(widget.token, id);
    if (!mounted) return;
    setState(() {
      message = ok ? 'Xóa lịch họp thành công.' : 'Xóa lịch họp thất bại.';
    });
    if (ok) {
      await _fetch();
    }
  }

  void _resetForm() {
    editingMeetingId = null;
    titleCtrl.clear();
    dateCtrl.clear();
    linkCtrl.clear();
    descCtrl.clear();
    minutesCtrl.clear();
    selectedAttendeeIds = <int>{};
  }

  Future<void> _openForm({Map<String, dynamic>? meeting}) async {
    setState(() {
      message = '';
      if (meeting == null) {
        _resetForm();
        dateCtrl.text = _fmtDateTime(
          selectedDate,
          const TimeOfDay(hour: 9, minute: 0),
        );
      } else {
        editingMeetingId = _parseInt(meeting['id']) ?? 0;
        titleCtrl.text = (meeting['title'] ?? '').toString();
        dateCtrl.text = (meeting['scheduled_at'] ?? '')
            .toString()
            .replaceFirst('T', ' ')
            .substring(0, 19);
        linkCtrl.text = (meeting['meeting_link'] ?? '').toString();
        descCtrl.text = (meeting['description'] ?? '').toString();
        minutesCtrl.text = (meeting['minutes'] ?? '').toString();
        selectedAttendeeIds =
            ((meeting['attendees'] ?? <dynamic>[]) as List<dynamic>)
                .map((dynamic attendee) {
                  if (attendee is! Map<String, dynamic>) return null;
                  return _parseInt(
                    attendee['user_id'] ?? attendee['user']?['id'],
                  );
                })
                .whereType<int>()
                .toSet();
      }
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final List<String> attendeeNames = _selectedAttendeeNames();
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: stitchFormSheetSurfaceDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  StitchFormSheetTitleBar(
                    title:
                        editingMeetingId == null
                            ? 'Tạo lịch họp'
                            : 'Sửa lịch họp',
                    subtitle:
                        'Thiết lập thời gian, link họp, biên bản và thành viên tham gia.',
                    icon:
                        editingMeetingId == null
                            ? Icons.event_available_outlined
                            : Icons.edit_calendar_outlined,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          TextField(
                            controller: titleCtrl,
                            decoration: stitchSheetInputDecoration(
                              context,
                              label: 'Tiêu đề họp',
                            ),
                          ),
                          SizedBox(height: kStitchTaskFormGap),
                          TextField(
                            controller: dateCtrl,
                            readOnly: true,
                            decoration: stitchSheetInputDecoration(
                              context,
                              label: 'Thời gian',
                              hint: 'YYYY-MM-DD HH:MM:SS',
                            ).copyWith(
                              suffixIcon: const Icon(
                                Icons.calendar_month_outlined,
                              ),
                            ),
                            onTap: () => _pickDateTime(dateCtrl),
                          ),
                          SizedBox(height: kStitchTaskFormGap),
                          TextField(
                            controller: linkCtrl,
                            decoration: stitchSheetInputDecoration(
                              context,
                              label: 'Liên kết họp',
                            ),
                          ),
                          SizedBox(height: kStitchTaskFormGap),
                          TextField(
                            controller: descCtrl,
                            decoration: stitchSheetInputDecoration(
                              context,
                              label: 'Ghi chú họp',
                            ),
                            maxLines: 2,
                          ),
                          SizedBox(height: kStitchTaskFormGap),
                          TextField(
                            controller: minutesCtrl,
                            decoration: stitchSheetInputDecoration(
                              context,
                              label: 'Biên bản họp',
                            ),
                            maxLines: 2,
                          ),
                          SizedBox(height: kStitchTaskFormGap),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final List<int>? picked =
                                    await _openAttendeePicker(
                                      selectedAttendeeIds.toList(),
                                    );
                                if (!context.mounted || picked == null) return;
                                setSheetState(() {
                                  selectedAttendeeIds = picked.toSet();
                                });
                              },
                              icon: const Icon(Icons.group_outlined, size: 18),
                              label: Text(
                                'Chọn thành viên (${selectedAttendeeIds.length})',
                              ),
                            ),
                          ),
                          if (attendeeNames.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children:
                                  attendeeNames
                                      .map(
                                        (String name) => StitchStatusPill(
                                          label: name,
                                          color: StitchTheme.primaryStrong,
                                          icon: Icons.person_outline,
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],
                          if (message.isNotEmpty) ...<Widget>[
                            SizedBox(height: kStitchTaskFormGap),
                            StitchFeedbackBanner(
                              message: message,
                              isError: _messageIsError(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  StitchFormSheetActions(
                    primaryLabel:
                        editingMeetingId == null
                            ? 'Tạo lịch họp'
                            : 'Cập nhật lịch họp',
                    onPrimary:
                        widget.canManage
                            ? () async {
                              final bool ok = await _save();
                              if (!context.mounted) return;
                              if (ok) {
                                Navigator.of(context).pop();
                              } else {
                                setSheetState(() {});
                              }
                            }
                            : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() => _resetForm());
  }

  Future<void> _confirmDelete(int id) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc muốn xóa lịch họp này không?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    if (accepted == true) {
      await _delete(id);
    }
  }

  void _showMeetingDetails(Map<String, dynamic> meeting) {
    final List<dynamic> attendees =
        (meeting['attendees'] ?? <dynamic>[]) as List<dynamic>;
    Widget infoRow(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: StitchTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: StitchTheme.textSubtle,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.trim().isEmpty ? '—' : value,
                    style: const TextStyle(
                      color: StitchTheme.textMain,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: stitchFormSheetSurfaceDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StitchFormSheetTitleBar(
                title: (meeting['title'] ?? 'Lịch họp').toString(),
                subtitle: 'Thông tin chi tiết cuộc họp và thành viên tham gia.',
                icon: Icons.event_note_outlined,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      infoRow(
                        Icons.schedule_outlined,
                        'Bắt đầu',
                        _displayDateTime(
                          (meeting['scheduled_at'] ?? '').toString(),
                        ),
                      ),
                      infoRow(
                        Icons.link_outlined,
                        'Liên kết',
                        (meeting['meeting_link'] ?? '—').toString(),
                      ),
                      infoRow(
                        Icons.notes_outlined,
                        'Ghi chú',
                        (meeting['description'] ?? '—').toString(),
                      ),
                      infoRow(
                        Icons.article_outlined,
                        'Biên bản',
                        (meeting['minutes'] ?? '—').toString(),
                      ),
                      const SizedBox(height: 2),
                      const StitchSectionHeader(title: 'Thành viên tham gia'),
                      const SizedBox(height: 8),
                      if (attendees.isEmpty)
                        const StitchEmptyState(
                          title: 'Không có thành viên',
                          subtitle:
                              'Cuộc họp này chưa có người tham gia được gán.',
                          icon: Icons.group_off_outlined,
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              attendees.map((dynamic attendee) {
                                if (attendee is! Map<String, dynamic>) {
                                  return const SizedBox.shrink();
                                }
                                final String name =
                                    (attendee['user']?['name'] ??
                                            '#${attendee['user_id']}')
                                        .toString();
                                return StitchStatusPill(
                                  label: name,
                                  color: StitchTheme.primaryStrong,
                                  icon: Icons.person_outline,
                                );
                              }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> selectedDayMeetings =
        meetings.where((Map<String, dynamic> meeting) {
            final DateTime? when = _parseMeetingDate(
              (meeting['scheduled_at'] ?? '').toString(),
            );
            if (when == null) return false;
            return when.year == selectedDate.year &&
                when.month == selectedDate.month &&
                when.day == selectedDate.day;
          }).toList()
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            final DateTime? da = _parseMeetingDate(
              (a['scheduled_at'] ?? '').toString(),
            );
            final DateTime? db = _parseMeetingDate(
              (b['scheduled_at'] ?? '').toString(),
            );
            return (da ?? DateTime(2000)).compareTo(db ?? DateTime(2000));
          });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch họp'),
        actions: <Widget>[
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          CupertinoSliverRefreshControl(onRefresh: _fetch),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                if (_listRefreshing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                StitchAdminHeader(
                  title: 'Lịch họp',
                  subtitle:
                      'Theo dõi lịch họp theo ngày, lọc theo thành viên và mở nhanh chi tiết cuộc họp.',
                  icon: Icons.event_note_outlined,
                  actionLabel: widget.canManage ? 'Thêm lịch' : null,
                  onAction: widget.canManage ? () => _openForm() : null,
                ),
                const SizedBox(height: 14),
                StitchFilterCard(
                  title: 'Lịch tháng',
                  subtitle: 'Chọn ngày để xem các cuộc họp tương ứng.',
                  child: CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: DateTime(DateTime.now().year - 3),
                    lastDate: DateTime(DateTime.now().year + 5),
                    onDateChanged: (DateTime value) {
                      setState(() => selectedDate = value);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                StitchFilterCard(
                  title: 'Bộ lọc lịch họp',
                  subtitle:
                      'Lọc nhanh theo từ khóa, khoảng ngày và thành viên tham gia để lịch nhìn gọn hơn.',
                  trailing: OutlinedButton.icon(
                    onPressed: _fetch,
                    icon: const Icon(Icons.filter_alt_outlined, size: 18),
                    label: const Text('Lọc'),
                  ),
                  child: Column(
                    children: <Widget>[
                      StitchFilterField(
                        label: 'Tìm kiếm',
                        child: TextField(
                          controller: searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Tiêu đề hoặc ghi chú cuộc họp',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: StitchFilterField(
                              label: 'Từ ngày',
                              child: TextField(
                                controller: dateFromCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  hintText: 'YYYY-MM-DD',
                                  suffixIcon: Icon(Icons.event),
                                ),
                                onTap: () => _pickDate(dateFromCtrl),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StitchFilterField(
                              label: 'Đến ngày',
                              child: TextField(
                                controller: dateToCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  hintText: 'YYYY-MM-DD',
                                  suffixIcon: Icon(Icons.event),
                                ),
                                onTap: () => _pickDate(dateToCtrl),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StitchFilterField(
                        label: 'Thành viên',
                        child: DropdownButtonFormField<int?>(
                          value: attendeeFilterId,
                          decoration: const InputDecoration(
                            hintText: 'Tất cả thành viên',
                          ),
                          items: <DropdownMenuItem<int?>>[
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Tất cả thành viên'),
                            ),
                            ...users.map((Map<String, dynamic> user) {
                              final int? id = _parseInt(user['id']);
                              return DropdownMenuItem<int?>(
                                value: id,
                                child: Text((user['name'] ?? '').toString()),
                              );
                            }),
                          ],
                          onChanged: (int? value) {
                            setState(() => attendeeFilterId = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StitchSectionHeader(
                  title: 'Sự kiện ngày ${_fmtDate(selectedDate)}',
                  actionLabel: widget.canManage ? 'Thêm' : null,
                  onAction: widget.canManage ? () => _openForm() : null,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Giữ lâu vào cuộc họp để xem nhanh thành viên, ghi chú, link và thời gian bắt đầu.',
                  style: TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                ),
                if (message.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  StitchFeedbackBanner(
                    message: message,
                    isError: _messageIsError(),
                  ),
                ],
                if (loading && meetings.isEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  const StitchLoadingState(label: 'Đang tải lịch họp...'),
                ] else ...<Widget>[
                  const SizedBox(height: 10),
                  if (selectedDayMeetings.isEmpty)
                    const StitchEmptyState(
                      title: 'Không có lịch họp trong ngày',
                      subtitle:
                          'Chọn ngày khác hoặc tạo lịch họp mới nếu bạn có quyền quản lý.',
                      icon: Icons.event_busy_outlined,
                    ),
                  ...selectedDayMeetings.map((Map<String, dynamic> meeting) {
                    final int id = _parseInt(meeting['id']) ?? 0;
                    final List<dynamic> attendees =
                        (meeting['attendees'] ?? <dynamic>[]) as List<dynamic>;
                    return StitchAdminListItem(
                      title: (meeting['title'] ?? 'Cuộc họp').toString(),
                      subtitle: _displayDateTime(
                        (meeting['scheduled_at'] ?? '').toString(),
                      ),
                      meta: <String>[
                        'Thành viên: ${attendees.length}',
                        'Giữ lâu để xem chi tiết',
                      ],
                      icon: Icons.event_available_outlined,
                      accent: StitchTheme.primaryStrong,
                      onTap: () => _showMeetingDetails(meeting),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          StitchStatusPill(
                            label: '${attendees.length} người',
                            color: StitchTheme.primaryStrong,
                            icon: Icons.group_outlined,
                          ),
                          if (widget.canManage) ...<Widget>[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Sửa lịch họp',
                              onPressed: () => _openForm(meeting: meeting),
                            ),
                          ],
                          if (widget.canDelete)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 18,
                              ),
                              tooltip: 'Xóa lịch họp',
                              onPressed: () => _confirmDelete(id),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

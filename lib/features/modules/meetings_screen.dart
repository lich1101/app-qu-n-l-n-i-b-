import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
    required this.canDelete,
  });

  final String token;
  final MobileApiService apiService;
  final bool canManage;
  final bool canDelete;

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
  String message = '';
  int? editingMeetingId;
  int? attendeeFilterId;
  DateTime selectedDate = DateTime.now();

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  DateTime? _parseMeetingDate(String raw) {
    if (raw.trim().isEmpty) return null;
    final DateTime? direct = DateTime.tryParse(raw);
    if (direct != null) return direct.toLocal();
    final String fixed = raw.replaceFirst(' ', 'T');
    final DateTime? secondTry = DateTime.tryParse(fixed);
    return secondTry?.toLocal();
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
    final DateTime now = DateTime.now();
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
    final DateTime now = DateTime.now();
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
    final List<Map<String, dynamic>> rows = await widget.apiService.getUsersLookup(
      widget.token,
    );
    if (!mounted) return;
    setState(() => users = rows);
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
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
      meetings = ((data['data'] ?? <dynamic>[]) as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    });
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
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: StitchTheme.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Chọn thành viên họp',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: users.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Không tải được danh sách thành viên.',
                              style: TextStyle(color: StitchTheme.textMuted),
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: users.map((Map<String, dynamic> user) {
                              final int id = _parseInt(user['id']) ?? 0;
                              final bool checked = temp.contains(id);
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: checked,
                                title: Text((user['name'] ?? '').toString()),
                                subtitle: Text((user['role'] ?? '').toString()),
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
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(temp.toList()),
                          child: const Text('Xác nhận'),
                        ),
                      ),
                    ],
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
    final bool ok = editingMeetingId == null
        ? await widget.apiService.createMeeting(
            widget.token,
            title: titleCtrl.text.trim(),
            scheduledAt: dateCtrl.text.trim(),
            meetingLink: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
            description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
            minutes: minutesCtrl.text.trim().isEmpty ? null : minutesCtrl.text.trim(),
            attendeeIds: attendeeIds,
          )
        : await widget.apiService.updateMeeting(
            widget.token,
            editingMeetingId!,
            title: titleCtrl.text.trim(),
            scheduledAt: dateCtrl.text.trim(),
            meetingLink: linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim(),
            description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
            minutes: minutesCtrl.text.trim().isEmpty ? null : minutesCtrl.text.trim(),
            attendeeIds: attendeeIds,
          );
    if (!mounted) return false;
    setState(() {
      message = ok
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
        dateCtrl.text = _fmtDateTime(selectedDate, const TimeOfDay(hour: 9, minute: 0));
      } else {
        editingMeetingId = _parseInt(meeting['id']) ?? 0;
        titleCtrl.text = (meeting['title'] ?? '').toString();
        dateCtrl.text = (meeting['scheduled_at'] ?? '').toString().replaceFirst('T', ' ').substring(0, 19);
        linkCtrl.text = (meeting['meeting_link'] ?? '').toString();
        descCtrl.text = (meeting['description'] ?? '').toString();
        minutesCtrl.text = (meeting['minutes'] ?? '').toString();
        selectedAttendeeIds = ((meeting['attendees'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic attendee) {
              if (attendee is! Map<String, dynamic>) return null;
              return _parseInt(attendee['user_id'] ?? attendee['user']?['id']);
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
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: StitchTheme.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      editingMeetingId == null ? 'Tạo lịch họp' : 'Sửa lịch họp',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Tiêu đề họp'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dateCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Thời gian (YYYY-MM-DD HH:MM:SS)',
                      ),
                      onTap: () => _pickDateTime(dateCtrl),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: linkCtrl,
                      decoration: const InputDecoration(labelText: 'Liên kết họp'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Ghi chú họp'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: minutesCtrl,
                      decoration: const InputDecoration(labelText: 'Biên bản họp'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final List<int>? picked = await _openAttendeePicker(
                          selectedAttendeeIds.toList(),
                        );
                        if (!context.mounted || picked == null) return;
                        setSheetState(() {
                          selectedAttendeeIds = picked.toSet();
                        });
                      },
                      icon: const Icon(Icons.group_outlined, size: 18),
                      label: Text('Chọn thành viên (${selectedAttendeeIds.length})'),
                    ),
                    if (attendeeNames.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: attendeeNames
                            .map(
                              (String name) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: StitchTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: StitchTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(message),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.canManage
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
                            child: Text(
                              editingMeetingId == null
                                  ? 'Tạo lịch họp'
                                  : 'Cập nhật lịch họp',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
    final List<dynamic> attendees = (meeting['attendees'] ?? <dynamic>[]) as List<dynamic>;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
            color: StitchTheme.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                (meeting['title'] ?? 'Lịch họp').toString(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Bắt đầu: ${_displayDateTime((meeting['scheduled_at'] ?? '').toString())}'),
              const SizedBox(height: 8),
              Text('Liên kết: ${(meeting['meeting_link'] ?? '—').toString()}'),
              const SizedBox(height: 8),
              Text('Ghi chú: ${(meeting['description'] ?? '—').toString()}'),
              const SizedBox(height: 8),
              Text('Biên bản: ${(meeting['minutes'] ?? '—').toString()}'),
              const SizedBox(height: 10),
              const Text(
                'Thành viên tham gia',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (attendees.isEmpty)
                const Text(
                  'Không có thành viên.',
                  style: TextStyle(color: StitchTheme.textMuted),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: attendees.map((dynamic attendee) {
                    if (attendee is! Map<String, dynamic>) return const SizedBox.shrink();
                    final String name =
                        (attendee['user']?['name'] ?? '#${attendee['user_id']}').toString();
                    return Chip(
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
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
      final DateTime? when =
          _parseMeetingDate((meeting['scheduled_at'] ?? '').toString());
      if (when == null) return false;
      return when.year == selectedDate.year &&
          when.month == selectedDate.month &&
          when.day == selectedDate.day;
    }).toList()
          ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
            final DateTime? da =
                _parseMeetingDate((a['scheduled_at'] ?? '').toString());
            final DateTime? db =
                _parseMeetingDate((b['scheduled_at'] ?? '').toString());
            return (da ?? DateTime(2000)).compareTo(db ?? DateTime(2000));
          });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch họp'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CalendarDatePicker(
                  initialDate: selectedDate,
                  firstDate: DateTime(DateTime.now().year - 3),
                  lastDate: DateTime(DateTime.now().year + 5),
                  onDateChanged: (DateTime value) {
                    setState(() => selectedDate = value);
                  },
                ),
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
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Sự kiện ngày ${_fmtDate(selectedDate)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.canManage)
                  ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Giữ lâu vào cuộc họp để xem nhanh thành viên, ghi chú, link và thời gian bắt đầu.',
              style: TextStyle(fontSize: 12, color: StitchTheme.textMuted),
            ),
            if (message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(message),
            ],
            if (loading) ...<Widget>[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ] else ...<Widget>[
              const SizedBox(height: 8),
              if (selectedDayMeetings.isEmpty)
                const Text(
                  'Không có lịch họp trong ngày đã chọn.',
                  style: TextStyle(color: StitchTheme.textMuted),
                ),
              ...selectedDayMeetings.map((Map<String, dynamic> meeting) {
                final int id = _parseInt(meeting['id']) ?? 0;
                final List<dynamic> attendees =
                    (meeting['attendees'] ?? <dynamic>[]) as List<dynamic>;
                return Card(
                  child: ListTile(
                    onLongPress: () => _showMeetingDetails(meeting),
                    title: Text((meeting['title'] ?? 'Cuộc họp').toString()),
                    subtitle: Text(
                      '${_displayDateTime((meeting['scheduled_at'] ?? '').toString())}\n'
                      'Thành viên: ${attendees.length}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (widget.canManage)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openForm(meeting: meeting),
                          ),
                        if (widget.canDelete)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmDelete(id),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

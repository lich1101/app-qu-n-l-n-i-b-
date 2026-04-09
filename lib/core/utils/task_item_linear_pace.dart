import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';
import 'vietnam_time.dart';

/// So khớp [TaskItemLinearPaceService] (PHP): tiến độ kỳ vọng tuyến tính start→deadline.
class TaskItemLinearPaceResult {
  const TaskItemLinearPaceResult({
    required this.expectedToday,
    required this.actualToday,
    required this.behindPercent,
    required this.aheadPercent,
    required this.pace,
  });

  final int expectedToday;
  final int actualToday;
  /// max(0, expected − actual) — dùng khi chậm.
  final int behindPercent;
  /// max(0, actual − expected) — dùng khi vượt.
  final int aheadPercent;
  final String pace; // behind | on_track | ahead

  bool get isBehind => pace == 'behind';
  bool get isAhead => pace == 'ahead';
  bool get isOnTrack => pace == 'on_track';
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Tính từ payload đầu việc (start_date, deadline, created_at, progress_percent).
TaskItemLinearPaceResult computeTaskItemLinearPace(Map<String, dynamic> item) {
  final DateTime now = _dayOnly(VietnamTime.now());

  DateTime? start = VietnamTime.parse((item['start_date'] ?? '').toString());
  start = start != null ? _dayOnly(start) : null;

  if (start == null) {
    final String created = (item['created_at'] ?? '').toString();
    final DateTime? c = VietnamTime.parse(created);
    start = c != null ? _dayOnly(c) : now;
  }

  DateTime? deadline = VietnamTime.parse((item['deadline'] ?? '').toString());
  deadline = deadline != null ? _dayOnly(deadline) : null;

  if (deadline == null || deadline.isBefore(start)) {
    deadline = now;
  }

  int totalDays = deadline.difference(start).inDays;
  if (totalDays < 1) {
    totalDays = 1;
  }

  int expectedToday = 0;
  if (!now.isBefore(start)) {
    final DateTime effectiveEnd = now.isBefore(deadline) ? now : deadline;
    int elapsed = effectiveEnd.difference(start).inDays;
    if (elapsed < 0) {
      elapsed = 0;
    }
    if (elapsed > totalDays) {
      elapsed = totalDays;
    }
    expectedToday = ((elapsed / totalDays) * 100).round();
  }
  if (expectedToday < 0) expectedToday = 0;
  if (expectedToday > 100) expectedToday = 100;

  final int actual = _toPercent(item['progress_percent']);
  final int actualToday = actual.clamp(0, 100);

  final int rawDiff = expectedToday - actualToday;
  final int behind = rawDiff > 0 ? rawDiff : 0;
  final int ahead = rawDiff < 0 ? -rawDiff : 0;

  String pace = 'on_track';
  if (actualToday < expectedToday) {
    pace = 'behind';
  } else if (actualToday > expectedToday) {
    pace = 'ahead';
  }

  return TaskItemLinearPaceResult(
    expectedToday: expectedToday,
    actualToday: actualToday,
    behindPercent: behind,
    aheadPercent: ahead,
    pace: pace,
  );
}

int _toPercent(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse('${v ?? 0}') ?? 0;
}

/// Dòng trạng thái tiến độ (chữ nhỏ): đỏ chậm / xanh vượt.
Widget taskItemPaceStatusLine(TaskItemLinearPaceResult pace, {double fontSize = 11}) {
  if (pace.isBehind && pace.behindPercent > 0) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.trending_down_rounded,
          size: fontSize + 3,
          color: StitchTheme.dangerStrong,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Chậm ${pace.behindPercent}% so với kỳ vọng hôm nay',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: StitchTheme.dangerStrong,
            ),
          ),
        ),
      ],
    );
  }
  if (pace.isAhead && pace.aheadPercent > 0) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.trending_up_rounded,
          size: fontSize + 3,
          color: StitchTheme.successStrong,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Vượt ${pace.aheadPercent}% so với kỳ vọng hôm nay',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: StitchTheme.successStrong,
            ),
          ),
        ),
      ],
    );
  }
  return const SizedBox.shrink();
}

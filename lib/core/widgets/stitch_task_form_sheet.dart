import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';

/// Khoảng cách dọc giữa các ô trong form công việc / đầu việc (theo mẫu UI).
const double kStitchTaskFormGap = 16;

/// Mô tả ngữ cảnh form (full-screen): [title] tùy chọn — nên để trống khi AppBar đã có cùng tiêu đề.
Widget stitchTaskFormSheetHeader(
  BuildContext context, {
  String? title,
  String? subtitle,
}) {
  final String? t = title?.trim();
  final bool hasTitle = t != null && t.isNotEmpty;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (hasTitle)
        Text(
          t,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: StitchTheme.textMain,
            height: 1.25,
          ),
        ),
      if (subtitle != null && subtitle.trim().isNotEmpty) ...<Widget>[
        if (hasTitle) const SizedBox(height: 6),
        Text(
          subtitle.trim(),
          style: const TextStyle(
            fontSize: 13,
            color: StitchTheme.textMuted,
            height: 1.45,
          ),
        ),
      ],
    ],
  );
}

/// Ô chọn ngày (read-only) với icon lịch — gộp với theme viền outline của app.
InputDecoration stitchTaskDateDecoration(
  BuildContext context,
  String labelText,
) {
  return InputDecoration(
    labelText: labelText,
    suffixIcon: const Icon(
      Icons.calendar_today_outlined,
      size: 20,
      color: StitchTheme.textMuted,
    ),
  ).applyDefaults(Theme.of(context).inputDecorationTheme);
}

/// Viền/label cho ô chọn dạng sheet — **không** dùng [suffixIcon] ở đây vì
/// [StitchSearchableSelectField] đã vẽ một mũi tên trong nội dung (tránh hai icon).
InputDecoration stitchTaskDropdownDecoration(
  BuildContext context,
  String labelText,
) {
  return InputDecoration(
    labelText: labelText,
  ).applyDefaults(Theme.of(context).inputDecorationTheme);
}

/// Thanh báo lỗi / gợi ý trong form.
Widget stitchTaskFormMessage(String message, {bool isError = true}) {
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      message,
      style: TextStyle(
        color: isError ? StitchTheme.danger : StitchTheme.textMuted,
        fontSize: 13,
        height: 1.35,
      ),
    ),
  );
}

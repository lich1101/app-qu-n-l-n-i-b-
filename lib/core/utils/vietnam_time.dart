class VietnamTime {
  VietnamTime._();

  static const Duration utcPlus7 = Duration(hours: 7);
  static final RegExp _dateOnlyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _dateTimePattern = RegExp(
    r'^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}',
  );
  static final RegExp _tzSuffixPattern = RegExp(r'(Z|[+-]\d{2}:\d{2})$');

  static DateTime now() => DateTime.now().toUtc().add(utcPlus7);

  static DateTime? parse(String? raw) {
    final String value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    if (_dateOnlyPattern.hasMatch(value)) {
      final List<String> parts = value.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }

    String normalized =
        value.contains(' ') ? value.replaceFirst(' ', 'T') : value;
    final bool hasExplicitTimezone = _tzSuffixPattern.hasMatch(normalized);
    if (_dateTimePattern.hasMatch(normalized) && !hasExplicitTimezone) {
      normalized = '$normalized+07:00';
    }

    final DateTime? parsed = DateTime.tryParse(normalized);
    if (parsed == null) return null;
    if (hasExplicitTimezone || normalized.endsWith('+07:00')) {
      return parsed.toUtc().add(utcPlus7);
    }
    return parsed;
  }

  static String formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  static String formatTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatDateTime(DateTime value) {
    return '${formatDate(value)} ${formatTime(value)}';
  }

  static String todayIso() {
    final DateTime value = now();
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String monthStartIso() {
    final DateTime value = now();
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$year-$month-01';
  }

  /// `yyyy-MM-dd` cho TextField / payload — không dùng `substring(0, 10)` trên ISO có `Z`
  /// (ví dụ `...T17:00:00.000Z` là nửa đêm ngày kế theo theo giờ VN).
  static String toYmdInput(dynamic value) {
    final String raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';
    final DateTime? dt = parse(raw);
    if (dt == null) return '';
    final String y = dt.year.toString().padLeft(4, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// [showDatePicker.initialDate] — ngày lịch VN, giờ trưa local tránh lệch DST.
  static DateTime pickerInitialDate(dynamic value) {
    final String ymd = toYmdInput(value);
    if (ymd.length >= 10) {
      final List<String> parts = ymd.split('-');
      if (parts.length == 3) {
        final int? y = int.tryParse(parts[0]);
        final int? m = int.tryParse(parts[1]);
        final int? d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          return DateTime(y, m, d, 12);
        }
      }
    }
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 12);
  }

  /// Parse về ngày (không giờ) cho so sánh / giới hạn picker.
  static DateTime? parseDateOnly(dynamic raw) {
    final String ymd = toYmdInput(raw);
    if (ymd.length < 10) return null;
    final DateTime? dt = parse(ymd);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// `lastDate` cho [showDatePicker] khi có hạn dự án / công việc.
  static DateTime pickerLastDateWithCap(DateTime? maxDay) {
    if (maxDay != null) {
      return DateTime(maxDay.year, maxDay.month, maxDay.day);
    }
    return DateTime(DateTime.now().year + 10, 12, 31);
  }

  static DateTime pickerFirstDateDefault() {
    return DateTime(DateTime.now().year - 5, 1, 1);
  }

  /// Đảm bảo [firstDate] ≤ [lastDate] (dự án hết hạn trong quá khứ).
  static DateTime pickerFirstDateSafe(DateTime lastDate) {
    final DateTime def = pickerFirstDateDefault();
    if (lastDate.isBefore(def)) {
      return lastDate;
    }
    return def;
  }

  /// Kẹp [initial] vào [firstDate, lastDate].
  static DateTime clampPickerInitial(
    DateTime initial,
    DateTime firstDate,
    DateTime lastDate,
  ) {
    if (initial.isBefore(firstDate)) return firstDate;
    if (initial.isAfter(lastDate)) return lastDate;
    return initial;
  }

  /// Chuỗi `yyyy-MM-dd` không được sau ngày [maxDay] (nếu có).
  static bool ymdNotAfterCap(String? ymd, DateTime? maxDay) {
    if (maxDay == null || ymd == null || ymd.trim().isEmpty) return true;
    final DateTime? a = parse(ymd.trim());
    if (a == null) return true;
    final DateTime ad = DateTime(a.year, a.month, a.day);
    final DateTime md = DateTime(maxDay.year, maxDay.month, maxDay.day);
    return !ad.isAfter(md);
  }
}

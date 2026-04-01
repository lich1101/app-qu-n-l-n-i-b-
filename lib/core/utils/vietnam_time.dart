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
}

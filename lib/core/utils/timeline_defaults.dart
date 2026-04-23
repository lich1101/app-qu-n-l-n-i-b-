import 'vietnam_time.dart';

/// Chuỗi mặc định thời gian: hợp đồng → dự án → công việc → đầu việc
/// (không có quan hệ dự án cha trong DB; fallback hợp đồng qua `contract` / `linked_contract`).
class TimelineDefaults {
  TimelineDefaults._();

  static Map<String, dynamic>? _contractFromProject(
    Map<String, dynamic>? project,
  ) {
    if (project == null) return null;
    final Object? c = project['contract'];
    if (c is Map && c.isNotEmpty) {
      return Map<String, dynamic>.from(c);
    }
    final Object? lc = project['linked_contract'];
    if (lc is Map && lc.isNotEmpty) {
      return Map<String, dynamic>.from(lc);
    }
    return null;
  }

  static DateTime? _parseFirstNonEmpty(Iterable<dynamic> values) {
    for (final dynamic v in values) {
      final DateTime? d = VietnamTime.parse((v ?? '').toString().trim());
      if (d != null) return d;
    }
    return null;
  }

  /// Form tạo dự án: lấy từ một bản ghi hợp đồng (list API).
  static ({DateTime? start, DateTime? end}) datesFromContract(
    Map<String, dynamic>? contract,
  ) {
    if (contract == null) return (start: null, end: null);
    final DateTime? start = VietnamTime.parse(
      (contract['start_date'] ?? '').toString(),
    );
    final DateTime? end = VietnamTime.parse(
      (contract['end_date'] ?? '').toString(),
    );
    return (start: start, end: end);
  }

  /// Mặc định công việc: dự án → hợp đồng gắn dự án.
  static ({DateTime? start, DateTime? end}) taskDefaultsFromProject(
    Map<String, dynamic>? project,
  ) {
    if (project == null) {
      return (start: null, end: null);
    }
    final Map<String, dynamic>? contract = _contractFromProject(project);
    return (
      start: _parseFirstNonEmpty(<dynamic>[
        project['start_date'],
        contract?['start_date'],
      ]),
      end: _parseFirstNonEmpty(<dynamic>[
        project['deadline'],
        contract?['end_date'],
      ]),
    );
  }

  /// Mặc định đầu việc: công việc → dự án → hợp đồng.
  static ({DateTime? start, DateTime? end}) taskItemDefaults({
    required Map<String, dynamic>? task,
    required Map<String, dynamic>? project,
  }) {
    final ({DateTime? start, DateTime? end}) fromProject =
        taskDefaultsFromProject(project);
    return (
      start: _parseFirstNonEmpty(<dynamic>[
        task?['start_at'],
        fromProject.start,
      ]),
      end: _parseFirstNonEmpty(<dynamic>[task?['deadline'], fromProject.end]),
    );
  }
}

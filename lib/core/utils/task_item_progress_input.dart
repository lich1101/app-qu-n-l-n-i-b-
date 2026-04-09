/// Tiến độ phiếu báo cáo đầu việc — chỉ cho phép 0…100 (không vượt 100%).
class TaskItemProgressInput {
  TaskItemProgressInput._();

  /// Ô để trống → `null` (không gửi tiến độ). Có nhập nhưng không hợp lệ → `null` và gọi [onInvalid].
  static int? tryParseOptional(
    String raw, {
    void Function(String message)? onInvalid,
  }) {
    final String t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    final int? n = int.tryParse(t);
    if (n == null) {
      onInvalid?.call('Tiến độ phải là số nguyên (0–100).');
      return null;
    }
    if (n < 0 || n > 100) {
      onInvalid?.call('Tiến độ không được vượt quá 100% (và không nhỏ hơn 0%).');
      return null;
    }
    return n;
  }

  /// An toàn khi gửi dữ liệu đã có sẵn (ví dụ từ API).
  static int clampInt(int value) => value.clamp(0, 100);
}

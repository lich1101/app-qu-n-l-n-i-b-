import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';

/// Lọc nhiều nhân sự dạng tag (FilterChip). [users] lấy từ `GET /api/v1/users/lookup`.
class StaffMultiFilterRow extends StatelessWidget {
  const StaffMultiFilterRow({
    super.key,
    required this.users,
    required this.selectedIds,
    required this.onChanged,
    this.title = 'Lọc theo nhân sự',
    this.compact = true,
  });

  final List<Map<String, dynamic>> users;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: StitchTheme.labelEmphasis,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children:
              users.map((Map<String, dynamic> u) {
                final int id = int.tryParse('${u['id'] ?? 0}') ?? 0;
                if (id <= 0) {
                  return const SizedBox.shrink();
                }
                final String name =
                    (u['name'] ?? u['email'] ?? '?').toString();
                final bool sel = selectedIds.contains(id);
                return FilterChip(
                  showCheckmark: true,
                  checkmarkColor: StitchTheme.primaryStrong,
                  selectedColor: StitchTheme.primary.withValues(alpha: 0.22),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: BorderSide(
                    color: sel
                        ? StitchTheme.primaryStrong.withValues(alpha: 0.45)
                        : StitchTheme.inputBorder,
                    width: sel ? 1.35 : 1.1,
                  ),
                  label: Text(
                    name,
                    style: TextStyle(
                      fontSize: compact ? 12.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? StitchTheme.primaryStrong
                          : StitchTheme.textMain,
                      height: 1.15,
                    ),
                  ),
                  selected: sel,
                  onSelected: (_) {
                    final List<int> next = List<int>.from(selectedIds);
                    if (sel) {
                      next.remove(id);
                    } else {
                      next.add(id);
                    }
                    next.sort();
                    onChanged(next);
                  },
                );
              }).toList(),
        ),
        if (selectedIds.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => onChanged(<int>[]),
              child: const Text('Xóa lọc nhân sự'),
            ),
          ),
      ],
    );
  }
}

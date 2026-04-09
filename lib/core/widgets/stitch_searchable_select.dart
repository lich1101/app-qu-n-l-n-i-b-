import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';
import '../utils/fold_vietnamese_search.dart';
import 'stitch_task_form_sheet.dart';

/// Một lựa chọn trong danh sách (bottom sheet có tìm kiếm).
class StitchSelectOption<T> {
  const StitchSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leadingIcon,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? leadingIcon;
}

bool _matchesFoldedQuery(StitchSelectOption<dynamic> o, String queryFolded) {
  if (queryFolded.isEmpty) return true;
  final String hay = foldVietnameseForSearch('${o.label} ${o.subtitle ?? ''}');
  for (final String t in queryFolded.split(RegExp(r'\s+'))) {
    final String tt = t.trim();
    if (tt.isEmpty) continue;
    if (!hay.contains(tt)) return false;
  }
  return true;
}

/// Giá trị đặc biệt khi chọn «Không chọn» (phân biệt với đóng sheet = hủy).
const Object _stitchSelectClearedSentinel = Object();

/// Bottom sheet chọn mục: tiêu đề + số kết quả + ô tìm + danh sách (chữ nhỏ, ellipsis).
///
/// Trả về [Future] với:
/// - `null` — người dùng đóng sheet (hủy), không đổi lựa chọn;
/// - `_stitchSelectClearedSentinel` — chọn «Không chọn» (chỉ khi [allowNull]);
/// - giá trị kiểu [T] — mục được chọn.
Future<Object?> showStitchSearchableSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<StitchSelectOption<T>> options,
  T? selectedValue,
  bool allowNull = false,
  String nullLabel = '— Không chọn —',
  String searchHint = 'Tìm kiếm...',
}) {
  return showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return _StitchSearchableSelectSheetBody<T>(
        title: title,
        options: options,
        selectedValue: selectedValue,
        allowNull: allowNull,
        nullLabel: nullLabel,
        searchHint: searchHint,
      );
    },
  );
}

class _StitchSearchableSelectSheetBody<T> extends StatefulWidget {
  const _StitchSearchableSelectSheetBody({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.allowNull,
    required this.nullLabel,
    required this.searchHint,
  });

  final String title;
  final List<StitchSelectOption<T>> options;
  final T? selectedValue;
  final bool allowNull;
  final String nullLabel;
  final String searchHint;

  @override
  State<_StitchSearchableSelectSheetBody<T>> createState() =>
      _StitchSearchableSelectSheetBodyState<T>();
}

class _StitchSearchableSelectSheetBodyState<T>
    extends State<_StitchSearchableSelectSheetBody<T>> {
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double h = mq.size.height * 1;
    final String qFolded = foldVietnameseForSearch(_q.text);
    final List<StitchSelectOption<T>> filtered = widget.options
        .where((StitchSelectOption<T> o) => _matchesFoldedQuery(o, qFolded))
        .toList();
    final int count =
        filtered.length + (widget.allowNull && _matchesNullRow(qFolded) ? 1 : 0);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: StitchTheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _stitchSelectSheetDragHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: StitchTheme.textMain,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$count kết quả',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: StitchTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                  child: TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: StitchTheme.textMain,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: StitchTheme.textSubtle,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: StitchTheme.textMuted,
                      ),
                      filled: true,
                      fillColor: StitchTheme.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: StitchTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: StitchTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: StitchTheme.primary.withValues(alpha: 0.65),
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty &&
                          !(widget.allowNull && _matchesNullRow(qFolded))
                      ? const Center(
                          child: Text(
                            'Không có kết quả phù hợp.',
                            style: TextStyle(
                              fontSize: 13,
                              color: StitchTheme.textMuted,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                          children: <Widget>[
                            if (widget.allowNull && _matchesNullRow(qFolded))
                              _tile(
                                selected: widget.selectedValue == null,
                                onTap: () {
                                  Navigator.of(context).pop(_stitchSelectClearedSentinel);
                                },
                                leadingIcon: Icons.remove_circle_outline,
                                title: widget.nullLabel,
                                subtitle: null,
                              ),
                            for (final StitchSelectOption<T> o in filtered)
                              _tile(
                                selected: o.value == widget.selectedValue,
                                onTap: () {
                                  Navigator.of(context).pop(o.value);
                                },
                                leadingIcon: o.leadingIcon ?? Icons.circle_outlined,
                                title: o.label,
                                subtitle: o.subtitle,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesNullRow(String qFolded) {
    if (!widget.allowNull) return false;
    if (qFolded.isEmpty) return true;
    final String hay = foldVietnameseForSearch(widget.nullLabel);
    for (final String t in qFolded.split(RegExp(r'\s+'))) {
      final String tt = t.trim();
      if (tt.isEmpty) continue;
      if (!hay.contains(tt)) return false;
    }
    return true;
  }

  Widget _tile({
    required bool selected,
    required VoidCallback onTap,
    required IconData leadingIcon,
    required String title,
    required String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color:
              selected
                  ? StitchTheme.primarySoft
                  : StitchTheme.formSelectionFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected
                    ? StitchTheme.formSelectionBorder
                    : StitchTheme.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: StitchTheme.formSelectionIconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 22,
                    color: StitchTheme.primaryStrong,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                          height: 1.35,
                          color: StitchTheme.textMain,
                        ),
                      ),
                      if (subtitle != null && subtitle.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          subtitle.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: StitchTheme.textSubtle,
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hiển thị như ô form: chạm mở bottom sheet chọn (thay [DropdownButtonFormField]).
Widget _stitchSelectSheetDragHandle() {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: StitchTheme.border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class StitchSearchableSelectField<T> extends StatelessWidget {
  const StitchSearchableSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.label,
    required this.sheetTitle,
    this.searchHint = 'Tìm kiếm...',
    this.nullable = false,
    this.nullLabel = '— Không chọn —',
    this.decoration,
    this.displayString,
    this.enabled = true,
  });

  final T? value;
  final List<StitchSelectOption<T>> options;
  final FutureOr<void> Function(T? newValue)? onChanged;
  final String label;
  final String sheetTitle;
  final String searchHint;
  final bool nullable;
  final String nullLabel;
  final InputDecoration? decoration;
  /// Nếu không null, dùng làm text hiển thị thay vì tra từ [options].
  final String? displayString;
  final bool enabled;

  String _resolveLabel() {
    if (displayString != null) return displayString!;
    if (value == null && nullable) return nullLabel;
    if (value == null) return '—';
    for (final StitchSelectOption<T> o in options) {
      if (o.value == value) return o.label;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final InputDecoration dec =
        decoration ??
        stitchTaskDropdownDecoration(context, label);
    return InputDecorator(
      decoration: dec,
      child: InkWell(
        onTap:
            enabled
                ? () async {
                  final Object? r = await showStitchSearchableSelectSheet<T>(
                    context: context,
                    title: sheetTitle,
                    options: options,
                    selectedValue: value,
                    allowNull: nullable,
                    nullLabel: nullLabel,
                    searchHint: searchHint,
                  );
                  if (!context.mounted) return;
                  if (r == null) return;
                  if (identical(r, _stitchSelectClearedSentinel)) {
                    await onChanged?.call(null);
                    return;
                  }
                  await onChanged?.call(r as T);
                }
                : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _resolveLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StitchTheme.dropdownFieldValueStyle.copyWith(
                    color:
                        enabled
                            ? StitchTheme.textMain
                            : StitchTheme.textMuted,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color:
                    enabled
                        ? StitchTheme.textMuted
                        : StitchTheme.textSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

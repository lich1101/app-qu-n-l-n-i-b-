import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';

/// Thanh phân trang dùng chung cho các danh sách/bảng trong ứng dụng.
///
/// Quy ước `pageSize == 0` tương ứng với chế độ "Tất cả". Màn hình sử dụng
/// widget chịu trách nhiệm tải toàn bộ dữ liệu theo nhiều request nhỏ để không
/// phụ thuộc giới hạn `per_page` của backend.
class StitchListPagination extends StatelessWidget {
  const StitchListPagination({
    super.key,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.visibleCount,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.loading = false,
    this.pageSizeOptions = const <int>[20, 50, 100, 0],
    this.itemLabel = 'bản ghi',
  });

  final int currentPage;
  final int lastPage;
  final int total;
  final int visibleCount;
  final int pageSize;
  final bool loading;
  final List<int> pageSizeOptions;
  final String itemLabel;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  String _pageSizeLabel(int value) => value == 0 ? 'Tất cả' : '$value';

  String _rangeLabel() {
    if (total <= 0 || visibleCount <= 0) {
      return 'Không có $itemLabel';
    }
    if (pageSize == 0) {
      return 'Đang hiển thị tất cả $visibleCount / $total $itemLabel';
    }
    final int safePage = currentPage < 1 ? 1 : currentPage;
    final int start = ((safePage - 1) * pageSize) + 1;
    final int rawEnd = start + visibleCount - 1;
    final int end = rawEnd > total ? total : rawEnd;
    return 'Đang xem $start–$end / $total $itemLabel';
  }

  @override
  Widget build(BuildContext context) {
    final int safeLastPage = lastPage < 1 ? 1 : lastPage;
    final int safeCurrentPage =
        currentPage < 1
            ? 1
            : (currentPage > safeLastPage ? safeLastPage : currentPage);
    final bool showAll = pageSize == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text(
                'Hiển thị',
                style: TextStyle(
                  color: StitchTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: StitchTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: StitchTheme.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: pageSize,
                      isDense: true,
                      borderRadius: BorderRadius.circular(14),
                      items:
                          pageSizeOptions
                              .map(
                                (int value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(_pageSizeLabel(value)),
                                ),
                              )
                              .toList(),
                      onChanged:
                          loading
                              ? null
                              : (int? value) {
                                if (value == null || value == pageSize) return;
                                onPageSizeChanged(value);
                              },
                    ),
                  ),
                ),
              ),
              Text(
                _rangeLabel(),
                style: const TextStyle(
                  color: StitchTheme.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          if (!showAll && safeLastPage > 1) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed:
                      loading || safeCurrentPage <= 1
                          ? null
                          : () => onPageChanged(safeCurrentPage - 1),
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  label: const Text('Trước'),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: StitchTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Text(
                    '$safeCurrentPage / $safeLastPage',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed:
                      loading || safeCurrentPage >= safeLastPage
                          ? null
                          : () => onPageChanged(safeCurrentPage + 1),
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  label: const Text('Sau'),
                ),
              ],
            ),
          ],
          if (loading) ...<Widget>[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }
}

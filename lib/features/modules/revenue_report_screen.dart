import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class RevenueReportScreen extends StatefulWidget {
  const RevenueReportScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.currentUserRole,
  });

  final String token;
  final MobileApiService apiService;
  final String currentUserRole;

  @override
  State<RevenueReportScreen> createState() => _RevenueReportScreenState();
}

class _RevenueReportScreenState extends State<RevenueReportScreen> {
  bool loading = false;
  Map<String, dynamic> report = <String, dynamic>{};
  String availableFrom = '';
  String availableTo = '';

  final TextEditingController dateFromCtrl = TextEditingController();
  final TextEditingController dateToCtrl = TextEditingController();
  final TextEditingController targetCtrl = TextEditingController();

  String _fmtDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _displayDate(String value) {
    if (value.isEmpty) return '—';
    final List<String> parts = value.split('-');
    if (parts.length != 3) return value;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  String _formatCurrency(num value) {
    return '${value.toStringAsFixed(0)} VNĐ';
  }

  String _formatCompactCurrency(num value) {
    final double amount = value.toDouble();
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)} tỷ';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} triệu';
    }
    return '${amount.toStringAsFixed(0)} đ';
  }

  double _asDouble(dynamic value) {
    return double.tryParse((value ?? 0).toString()) ?? 0;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = DateTime.tryParse(controller.text) ?? now;
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: initialDate,
    );
    if (date == null || !mounted) return;
    setState(() => controller.text = _fmtDate(date));
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    dateFromCtrl.dispose();
    dateToCtrl.dispose();
    targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final Map<String, dynamic> company = await widget.apiService
        .getCompanyRevenueReport(
          widget.token,
          from: dateFromCtrl.text.trim(),
          to: dateToCtrl.text.trim(),
          targetRevenue: targetCtrl.text.trim(),
        );
    if (!mounted) return;
    final Map<String, dynamic> period =
        (company['period'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String nextAvailableFrom =
        (period['available_from'] ?? '').toString();
    final String nextAvailableTo = (period['available_to'] ?? '').toString();
    setState(() {
      loading = false;
      report = company;
      availableFrom = nextAvailableFrom;
      availableTo = nextAvailableTo;
      if (dateFromCtrl.text.trim().isEmpty && nextAvailableFrom.isNotEmpty) {
        dateFromCtrl.text = nextAvailableFrom;
      }
      if (dateToCtrl.text.trim().isEmpty && nextAvailableTo.isNotEmpty) {
        dateToCtrl.text = nextAvailableTo;
      }
    });
  }

  void _resetToFullRange() {
    setState(() {
      dateFromCtrl.text = availableFrom;
      dateToCtrl.text = availableTo;
      targetCtrl.clear();
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserRole != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Báo cáo doanh thu công ty')),
        body: const Center(
          child: Text(
            'Chỉ admin được xem báo cáo doanh thu công ty.',
            style: TextStyle(color: StitchTheme.textMuted),
          ),
        ),
      );
    }

    final Map<String, dynamic> periodTotals =
        (report['period_totals'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final List<Map<String, dynamic>> productBreakdown =
        ((report['product_breakdown'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic item) => Map<String, dynamic>.from(item as Map))
            .toList();
    final List<Map<String, dynamic>> staffBreakdown =
        ((report['staff_breakdown'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic item) => Map<String, dynamic>.from(item as Map))
            .toList();
    final List<Map<String, dynamic>> rows =
        ((report['daily_rows'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic item) => Map<String, dynamic>.from(item as Map))
            .toList();
    final String periodLabel =
        dateFromCtrl.text.isNotEmpty && dateToCtrl.text.isNotEmpty
            ? '${_displayDate(dateFromCtrl.text)} đến ${_displayDate(dateToCtrl.text)}'
            : 'Toàn thời gian';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo doanh thu công ty'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            _FilterCard(
              dateFromCtrl: dateFromCtrl,
              dateToCtrl: dateToCtrl,
              targetCtrl: targetCtrl,
              onPickFrom: () => _pickDate(dateFromCtrl),
              onPickTo: () => _pickDate(dateToCtrl),
              onApply: _fetch,
              onReset: _resetToFullRange,
              availableFrom: availableFrom,
              availableTo: availableTo,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _SummaryCard(
                  title: 'Doanh thu trong kỳ',
                  value: _formatCurrency(_asDouble(periodTotals['revenue'])),
                  note:
                      _asDouble(periodTotals['target_revenue']) > 0
                          ? 'Đạt ${_asDouble(periodTotals['target_rate']).toStringAsFixed(1)}% chỉ tiêu'
                          : periodLabel,
                ),
                _SummaryCard(
                  title: 'Dòng tiền trong kỳ',
                  value: _formatCurrency(_asDouble(periodTotals['cashflow'])),
                  note: 'Tổng thanh toán của các hợp đồng trong giai đoạn lọc',
                ),
                _SummaryCard(
                  title: 'Công nợ còn lại',
                  value: _formatCurrency(_asDouble(periodTotals['debt'])),
                  note: 'Phần chưa thanh toán của các hợp đồng đang xem',
                ),
                _SummaryCard(
                  title: 'Chi phí phát sinh',
                  value: _formatCurrency(_asDouble(periodTotals['costs'])),
                  note:
                      '${periodTotals['contracts_total'] ?? 0} hợp đồng đã duyệt trong khoảng lọc',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Doanh thu theo sản phẩm',
              subtitle:
                  'Biểu đồ tròn tính trên toàn bộ hợp đồng đã duyệt trong khoảng thời gian đang lọc.',
              child: _ProductPieCard(
                rows: productBreakdown,
                formatCompactCurrency: _formatCompactCurrency,
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Doanh thu theo nhân viên',
              subtitle:
                  'Nhân viên thu theo hợp đồng dùng đúng người thu đang đứng tên trên hợp đồng.',
              child: _StaffRevenueCard(
                rows: staffBreakdown,
                formatCompactCurrency: _formatCompactCurrency,
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Báo cáo chi tiết theo ngày',
              subtitle:
                  'Mỗi ngày được tổng hợp theo doanh thu hợp đồng, dòng tiền, công nợ và chi phí phát sinh.',
              child:
                  loading
                      ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                      : rows.isEmpty
                      ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Chưa có dữ liệu báo cáo.',
                          style: TextStyle(color: StitchTheme.textMuted),
                        ),
                      )
                      : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 18,
                          columns: const <DataColumn>[
                            DataColumn(label: Text('Ngày')),
                            DataColumn(label: Text('Doanh thu')),
                            DataColumn(label: Text('Dòng tiền')),
                            DataColumn(label: Text('Công nợ')),
                            DataColumn(label: Text('Chi phí')),
                            DataColumn(label: Text('Doanh thu TL')),
                            DataColumn(label: Text('Dòng tiền TL')),
                            DataColumn(label: Text('Công nợ TL')),
                            DataColumn(label: Text('Chi phí TL')),
                          ],
                          rows:
                              rows.map((Map<String, dynamic> item) {
                                final String date =
                                    (item['date'] ?? '').toString();
                                return DataRow(
                                  cells: <DataCell>[
                                    DataCell(Text(_displayDate(date))),
                                    DataCell(
                                      Text(
                                        _formatCurrency(
                                          _asDouble(item['revenue_daily']),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatCurrency(
                                          _asDouble(item['cashflow_daily']),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatCurrency(
                                          _asDouble(item['debt_daily']),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatCurrency(
                                          _asDouble(item['costs_daily']),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatCurrency(
                                          _asDouble(item['revenue_cumulative']),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatCurrency(
                                          _asDouble(
                                            item['cashflow_cumulative'],
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatCurrency(
                                          _asDouble(item['debt_cumulative']),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatCurrency(
                                          _asDouble(item['costs_cumulative']),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.dateFromCtrl,
    required this.dateToCtrl,
    required this.targetCtrl,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onApply,
    required this.onReset,
    required this.availableFrom,
    required this.availableTo,
  });

  final TextEditingController dateFromCtrl;
  final TextEditingController dateToCtrl;
  final TextEditingController targetCtrl;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final String availableFrom;
  final String availableTo;

  @override
  Widget build(BuildContext context) {
    return StitchFilterCard(
      title: 'Bộ lọc thời gian',
      subtitle:
          availableFrom.isNotEmpty && availableTo.isNotEmpty
              ? 'Mặc định hệ thống lấy toàn bộ dữ liệu từ ${availableFrom.split('-').reversed.join('/')} đến ${availableTo.split('-').reversed.join('/')}.'
              : 'Mặc định hệ thống lấy toàn bộ dữ liệu từ đầu đến cuối.',
      trailing: OutlinedButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const Text('Toàn thời gian'),
      ),
      child: Column(
        children: <Widget>[
          StitchFilterField(
            label: 'Từ ngày',
            child: TextField(
              controller: dateFromCtrl,
              readOnly: true,
              onTap: onPickFrom,
              decoration: const InputDecoration(
                hintText: 'Chọn ngày bắt đầu',
                suffixIcon: Icon(Icons.event),
              ),
            ),
          ),
          const SizedBox(height: 12),
          StitchFilterField(
            label: 'Đến ngày',
            child: TextField(
              controller: dateToCtrl,
              readOnly: true,
              onTap: onPickTo,
              decoration: const InputDecoration(
                hintText: 'Chọn ngày kết thúc',
                suffixIcon: Icon(Icons.event),
              ),
            ),
          ),
          const SizedBox(height: 12),
          StitchFilterField(
            label: 'Chỉ tiêu doanh thu (VNĐ)',
            child: TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Nhập chỉ tiêu nếu cần so sánh',
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('Áp dụng bộ lọc'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.note,
  });

  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: StitchTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: StitchTheme.textSubtle,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: StitchTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              note,
              style: const TextStyle(
                fontSize: 12,
                color: StitchTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: StitchTheme.textMuted)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ProductPieCard extends StatefulWidget {
  const _ProductPieCard({
    required this.rows,
    required this.formatCompactCurrency,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(num value) formatCompactCurrency;

  @override
  State<_ProductPieCard> createState() => _ProductPieCardState();
}

class _ProductPieCardState extends State<_ProductPieCard> {
  int _selectedIndex = 0;

  static const List<Color> _palette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
  ];

  void _selectSegment(Offset localPosition, Size size, List<_PieItem> items) {
    final double total = items.fold<double>(
      0,
      (double sum, _PieItem item) => sum + item.value,
    );
    if (items.isEmpty || total <= 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final Offset delta = localPosition - center;
    final double radius = math.min(size.width, size.height) / 2 - 12;
    final double innerRadius = radius * 0.54;
    final double distance = delta.distance;

    if (distance < innerRadius || distance > radius) {
      return;
    }

    double angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) {
      angle += math.pi * 2;
    }

    double startAngle = 0;
    for (int index = 0; index < items.length; index++) {
      final double sweepAngle = (items[index].value / total) * math.pi * 2;
      final double endAngle = startAngle + sweepAngle;
      if (angle >= startAngle && angle <= endAngle) {
        setState(() => _selectedIndex = index);
        return;
      }
      startAngle = endAngle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_PieItem> items =
        widget.rows.asMap().entries.map((entry) {
          return _PieItem(
            label: (entry.value['label'] ?? 'Sản phẩm').toString(),
            value: double.tryParse((entry.value['value'] ?? 0).toString()) ?? 0,
            color: _palette[entry.key % _palette.length],
          );
        }).toList();

    final double total = items.fold<double>(
      0,
      (double sum, _PieItem item) => sum + item.value,
    );

    if (items.isEmpty || total <= 0) {
      return const Text(
        'Chưa có dữ liệu sản phẩm trong giai đoạn này.',
        style: TextStyle(color: StitchTheme.textMuted),
      );
    }

    final int safeSelectedIndex =
        _selectedIndex.clamp(0, math.max(0, items.length - 1));
    final _PieItem selectedItem = items[safeSelectedIndex];
    final double selectedPercent =
        total > 0 ? (selectedItem.value / total) * 100 : 0;

    return Column(
      children: <Widget>[
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size chartSize = Size(constraints.maxWidth, 220);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp:
                    (TapUpDetails details) =>
                        _selectSegment(details.localPosition, chartSize, items),
                child: CustomPaint(
                  painter: _PieChartPainter(
                    items: items,
                    selectedIndex: safeSelectedIndex,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Tổng doanh thu',
                          style: TextStyle(
                            fontSize: 12,
                            color: StitchTheme.textMuted,
                          ),
                        ),
                        Text(
                          widget.formatCompactCurrency(total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StitchTheme.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: selectedItem.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      selectedItem.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${selectedPercent.toStringAsFixed(1)}% trong tổng doanh thu. Chạm vào mảng màu để xem sản phẩm khác.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.formatCompactCurrency(selectedItem.value),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final double percent = total > 0 ? (item.value / total) * 100 : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: const TextStyle(color: StitchTheme.textMuted),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.formatCompactCurrency(item.value),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StaffRevenueCard extends StatefulWidget {
  const _StaffRevenueCard({
    required this.rows,
    required this.formatCompactCurrency,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(num value) formatCompactCurrency;

  @override
  State<_StaffRevenueCard> createState() => _StaffRevenueCardState();
}

class _StaffRevenueCardState extends State<_StaffRevenueCard> {
  final Map<String, String> _selectedSeriesByStaff = <String, String>{};

  _RevenueValue _selectedValueFor(
    String staffKey,
    List<_RevenueValue> values,
  ) {
    final String? selectedKey = _selectedSeriesByStaff[staffKey];
    final _RevenueValue? selectedValue =
        selectedKey == null
            ? null
            : values
                .where((item) => item.meta.key == selectedKey)
                .cast<_RevenueValue?>()
                .firstWhere(
                  (item) => item != null,
                  orElse: () => null,
                );

    if (selectedValue != null) {
      return selectedValue;
    }

    return values.firstWhere(
      (item) => item.value > 0,
      orElse: () => values.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    const List<_RevenueSeries> series = <_RevenueSeries>[
      _RevenueSeries(
        key: 'revenue',
        label: 'Doanh thu',
        color: Color(0xFF0EA5E9),
      ),
      _RevenueSeries(
        key: 'cashflow',
        label: 'Dòng tiền',
        color: Color(0xFF10B981),
      ),
      _RevenueSeries(key: 'debt', label: 'Công nợ', color: Color(0xFFF59E0B)),
      _RevenueSeries(key: 'costs', label: 'Chi phí', color: Color(0xFFEF4444)),
    ];

    if (widget.rows.isEmpty) {
      return const Text(
        'Chưa có dữ liệu nhân viên trong giai đoạn này.',
        style: TextStyle(color: StitchTheme.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children:
              series.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 14),
        ...widget.rows.asMap().entries.map((entry) {
          final int index = entry.key;
          final Map<String, dynamic> row = entry.value;
          final List<_RevenueValue> values =
              series.map((item) {
                return _RevenueValue(
                  meta: item,
                  value: double.tryParse((row[item.key] ?? 0).toString()) ?? 0,
                );
              }).toList();
          final double total = values.fold<double>(
            0,
            (double sum, _RevenueValue item) => sum + item.value,
          );
          final String staffKey =
              (row['staff_id'] ?? row['staff_name'] ?? 'staff_$index')
                  .toString();
          final _RevenueValue selectedValue = _selectedValueFor(
            staffKey,
            values,
          );
          final double selectedPercent =
              total > 0 ? (selectedValue.value / total) * 100 : 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StitchTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: StitchTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials((row['staff_name'] ?? 'NV').toString()),
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            (row['staff_name'] ?? 'Chưa gán nhân viên')
                                .toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${row['contracts_count'] ?? 0} hợp đồng',
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 18,
                    color: const Color(0xFFE2E8F0),
                    child:
                        total > 0
                            ? Row(
                              children:
                                  values.map((item) {
                                    final double flexValue =
                                        (item.value <= 0 || total <= 0)
                                            ? 0
                                            : item.value / total;
                                    if (flexValue <= 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Expanded(
                                      flex: math.max(
                                        1,
                                        (flexValue * 1000).round(),
                                      ),
                                      child: Tooltip(
                                        message:
                                            '${row['staff_name']} • ${item.meta.label}: ${widget.formatCompactCurrency(item.value)}',
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap:
                                              () => setState(
                                                () =>
                                                    _selectedSeriesByStaff[staffKey] =
                                                        item.meta.key,
                                              ),
                                          child: Container(
                                            color: item.meta.color,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            )
                            : const Center(
                              child: Text(
                                '0',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: StitchTheme.textMuted,
                                ),
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: StitchTheme.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: selectedValue.meta.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              selectedValue.meta.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${selectedPercent.toStringAsFixed(1)}% trong tổng nhóm màu. Chạm vào thanh màu để xem chỉ số khác.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: StitchTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.formatCompactCurrency(selectedValue.value),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'NV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _RevenueSeries {
  const _RevenueSeries({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;
}

class _RevenueValue {
  const _RevenueValue({required this.meta, required this.value});

  final _RevenueSeries meta;
  final double value;
}

class _PieItem {
  const _PieItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({required this.items, required this.selectedIndex});

  final List<_PieItem> items;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 12;
    final double total = items.fold<double>(
      0,
      (double sum, _PieItem item) => sum + item.value,
    );
    final Paint paint = Paint()..style = PaintingStyle.fill;

    double startAngle = -math.pi / 2;
    for (int index = 0; index < items.length; index++) {
      final _PieItem item = items[index];
      final double sweepAngle =
          total <= 0 ? 0 : (item.value / total) * math.pi * 2;
      paint.color = item.color;
      final double activeRadius = index == selectedIndex ? radius + 4 : radius;
      final Rect rect = Rect.fromCircle(center: center, radius: activeRadius);
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    canvas.drawCircle(center, radius * 0.54, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

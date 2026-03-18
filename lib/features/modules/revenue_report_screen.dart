import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
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
    final DateTime initialDate =
        DateTime.tryParse(controller.text) ?? now;
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
        appBar: AppBar(
          title: const Text('Báo cáo doanh thu công ty'),
        ),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
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
                  note: periodLabel,
                ),
                _SummaryCard(
                  title: 'Tiền thu trong kỳ',
                  value: _formatCurrency(_asDouble(periodTotals['paid'])),
                  note:
                      'Công nợ ${_formatCompactCurrency(_asDouble(periodTotals['debt']))}',
                ),
                _SummaryCard(
                  title: 'Lợi nhuận tạm tính',
                  value:
                      _formatCurrency(_asDouble(periodTotals['net_revenue'])),
                  note:
                      'Chi phí ${_formatCompactCurrency(_asDouble(periodTotals['costs']))}',
                ),
                _SummaryCard(
                  title: 'Hợp đồng trong kỳ',
                  value: '${periodTotals['contracts_total'] ?? 0}',
                  note: 'Đã duyệt trong khoảng lọc',
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
                  'Giữ nguyên bảng đối chiếu doanh thu, tiền thu, công nợ và nợ tồn theo từng ngày.',
              child: loading
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
                              DataColumn(label: Text('Tiền thu')),
                              DataColumn(label: Text('Công nợ')),
                              DataColumn(label: Text('Nợ tồn tháng trước')),
                            ],
                            rows: rows.map((Map<String, dynamic> item) {
                              final String date = (item['date'] ?? '').toString();
                              return DataRow(
                                cells: <DataCell>[
                                  DataCell(Text(_displayDate(date))),
                                  DataCell(
                                    Text(_formatCurrency(_asDouble(item['revenue_daily']))),
                                  ),
                                  DataCell(
                                    Text(_formatCurrency(_asDouble(item['collected_daily']))),
                                  ),
                                  DataCell(
                                    Text(_formatCurrency(_asDouble(item['debt_daily']))),
                                  ),
                                  DataCell(
                                    Text(
                                      _formatCurrency(
                                        _asDouble(item['prev_month_debt_remaining']),
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
          const Text(
            'Bộ lọc thời gian',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            availableFrom.isNotEmpty && availableTo.isNotEmpty
                ? 'Mặc định hệ thống lấy toàn bộ dữ liệu từ ${availableFrom.split('-').reversed.join('/')} đến ${availableTo.split('-').reversed.join('/')}.'
                : 'Mặc định hệ thống lấy toàn bộ dữ liệu từ đầu đến cuối.',
            style: const TextStyle(color: StitchTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: dateFromCtrl,
                  readOnly: true,
                  onTap: onPickFrom,
                  decoration: const InputDecoration(
                    labelText: 'Từ ngày',
                    suffixIcon: Icon(Icons.event),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: dateToCtrl,
                  readOnly: true,
                  onTap: onPickTo,
                  decoration: const InputDecoration(
                    labelText: 'Đến ngày',
                    suffixIcon: Icon(Icons.event),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: targetCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Chỉ tiêu doanh thu (VNĐ)',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton(
                  onPressed: onApply,
                  child: const Text('Áp dụng'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  child: const Text('Toàn thời gian'),
                ),
              ),
            ],
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: StitchTheme.textMuted),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ProductPieCard extends StatelessWidget {
  const _ProductPieCard({
    required this.rows,
    required this.formatCompactCurrency,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(num value) formatCompactCurrency;

  static const List<Color> _palette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final List<_PieItem> items = rows.asMap().entries.map((entry) {
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

    return Column(
      children: <Widget>[
        SizedBox(
          height: 220,
          child: CustomPaint(
            painter: _PieChartPainter(items: items),
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
                    formatCompactCurrency(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
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
                  formatCompactCurrency(item.value),
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

class _StaffRevenueCard extends StatelessWidget {
  const _StaffRevenueCard({
    required this.rows,
    required this.formatCompactCurrency,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(num value) formatCompactCurrency;

  @override
  Widget build(BuildContext context) {
    final double maxSigned = rows.fold<double>(
      1,
      (double max, Map<String, dynamic> item) =>
          math.max(max, double.tryParse((item['signed_revenue'] ?? 0).toString()) ?? 0),
    );
    final double maxSettled = rows.fold<double>(
      1,
      (double max, Map<String, dynamic> item) =>
          math.max(max, double.tryParse((item['settled_revenue'] ?? 0).toString()) ?? 0),
    );
    final double maxCollected = rows.fold<double>(
      1,
      (double max, Map<String, dynamic> item) =>
          math.max(max, double.tryParse((item['collected_revenue'] ?? 0).toString()) ?? 0),
    );

    if (rows.isEmpty) {
      return const Text(
        'Chưa có dữ liệu nhân viên trong giai đoạn này.',
        style: TextStyle(color: StitchTheme.textMuted),
      );
    }

    return Column(
      children: rows.map((Map<String, dynamic> row) {
        final double signed =
            double.tryParse((row['signed_revenue'] ?? 0).toString()) ?? 0;
        final double settled =
            double.tryParse((row['settled_revenue'] ?? 0).toString()) ?? 0;
        final double collected =
            double.tryParse((row['collected_revenue'] ?? 0).toString()) ?? 0;
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
                          (row['staff_name'] ?? 'Chưa gán nhân viên').toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
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
              _MetricBar(
                label: 'Doanh số ký',
                color: const Color(0xFF60A5FA),
                progress: signed / maxSigned,
                value: formatCompactCurrency(signed),
              ),
              const SizedBox(height: 10),
              _MetricBar(
                label: 'Doanh số quyết toán',
                color: const Color(0xFFFBBF24),
                progress: settled / maxSettled,
                value: formatCompactCurrency(settled),
              ),
              const SizedBox(height: 10),
              _MetricBar(
                label: 'Thực thu',
                color: const Color(0xFF34D399),
                progress: collected / maxCollected,
                value: formatCompactCurrency(collected),
              ),
            ],
          ),
        );
      }).toList(),
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

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.color,
    required this.progress,
    required this.value,
  });

  final String label;
  final Color color;
  final double progress;
  final String value;

  @override
  Widget build(BuildContext context) {
    final double safeProgress = progress.clamp(0, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: StitchTheme.textMuted,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: safeProgress,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
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
  const _PieChartPainter({required this.items});

  final List<_PieItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 12;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final double total =
        items.fold<double>(0, (double sum, _PieItem item) => sum + item.value);
    final Paint paint = Paint()..style = PaintingStyle.fill;

    double startAngle = -math.pi / 2;
    for (final _PieItem item in items) {
      final double sweepAngle =
          total <= 0 ? 0 : (item.value / total) * math.pi * 2;
      paint.color = item.color;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    canvas.drawCircle(
      center,
      radius * 0.54,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}

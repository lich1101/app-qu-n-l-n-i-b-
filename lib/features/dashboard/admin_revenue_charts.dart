import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

/// Revenue dashboard charts available to all roles.
/// Backend CrmScope scopes data by role automatically:
///   admin     → all contracts
///   quan_ly   → department staff contracts
///   nhan_vien → own contracts
class AdminRevenueCharts extends StatefulWidget {
  const AdminRevenueCharts({
    super.key,
    required this.token,
    required this.apiService,
    this.currentUserRole = '',
  });

  final String token;
  final MobileApiService apiService;
  final String currentUserRole;

  @override
  State<AdminRevenueCharts> createState() => _AdminRevenueChartsState();
}

class _AdminRevenueChartsState extends State<AdminRevenueCharts> {
  bool _loading = true;
  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _serviceBreakdown = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _staffSales = <Map<String, dynamic>>[];
  double _totalRevenue = 0;
  double _totalCashflow = 0;
  int? _selectedPieIndex;

  static const List<Color> _palette = <Color>[
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFF43F5E),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    Color(0xFF14B8A6),
    Color(0xFF6366F1),
  ];

  static const List<String> _monthNames = <String>[
    'Tháng 1',
    'Tháng 2',
    'Tháng 3',
    'Tháng 4',
    'Tháng 5',
    'Tháng 6',
    'Tháng 7',
    'Tháng 8',
    'Tháng 9',
    'Tháng 10',
    'Tháng 11',
    'Tháng 12',
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String _monthLabel(DateTime d) => '${_monthNames[d.month - 1]}, ${d.year}';

  String _roleTitle(String section) {
    switch (widget.currentUserRole) {
      case 'admin':
        return section == 'pie'
            ? 'Doanh số theo sản phẩm'
            : 'Doanh số theo nhân viên';
      case 'quan_ly':
        return section == 'pie'
            ? 'Doanh số phòng ban – Sản phẩm'
            : 'Doanh số phòng ban – Nhân viên';
      default:
        return section == 'pie'
            ? 'Doanh số của tôi – Sản phẩm'
            : 'Doanh số của tôi';
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final DateTime start = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    final DateTime end = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );
    final String from =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final String to =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final Map<String, dynamic> data = await widget.apiService.getReportSummary(
      widget.token,
      from: from,
      to: to,
    );
    if (!mounted) return;
    final List<dynamic> rawService =
        (data['product_breakdown'] ?? data['service_breakdown'] ?? <dynamic>[])
            as List<dynamic>;
    final List<dynamic> rawStaff =
        (data['staff_sales_breakdown'] ?? <dynamic>[]) as List<dynamic>;
    setState(() {
      _loading = false;
      _selectedPieIndex = null;
      _serviceBreakdown =
          rawService
              .map((dynamic e) => e as Map<String, dynamic>)
              .where(
                (Map<String, dynamic> e) =>
                    (e['value'] as num? ?? 0).toDouble() > 0,
              )
              .toList();
      _staffSales =
          rawStaff.map((dynamic e) => e as Map<String, dynamic>).toList();
      _totalRevenue = (data['period_revenue_total'] ?? 0).toDouble();
      _totalCashflow = (data['period_cashflow_total'] ?? 0).toDouble();
    });
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _fetch();
  }

  void _nextMonth() {
    final DateTime now = DateTime.now();
    final DateTime next = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );
    if (next.isAfter(DateTime(now.year, now.month + 1, 0))) return;
    setState(() => _selectedMonth = next);
    _fetch();
  }

  String _fmtCurrency(double value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}tỷ';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}tr';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentMonth =
        _selectedMonth.year == DateTime.now().year &&
        _selectedMonth.month == DateTime.now().month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ──────── Beautiful Month selector ────────
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: <Widget>[
              // Left arrow
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _prevMonth,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x0A0F172A),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              // Center month label
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickMonth(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color:
                            isCurrentMonth
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _monthLabel(_selectedMonth),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color:
                              isCurrentMonth
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF475569),
                        ),
                      ),
                      if (isCurrentMonth) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Hiện tại',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Right arrow
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _nextMonth,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x0A0F172A),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color:
                          _canGoNext()
                              ? const Color(0xFF64748B)
                              : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else ...<Widget>[
          _buildPieSection(),
          const SizedBox(height: 16),
          _buildStaffSection(),
        ],
      ],
    );
  }

  bool _canGoNext() {
    final DateTime now = DateTime.now();
    final DateTime next = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );
    return !next.isAfter(DateTime(now.year, now.month + 1, 0));
  }

  Future<void> _pickMonth(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedMonth.year, _selectedMonth.month),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });
    _fetch();
  }

  Widget _buildPieSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_outline,
                  size: 18,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _roleTitle('pie'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_serviceBreakdown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Chưa có dữ liệu doanh số tháng này.',
                  style: TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children: <Widget>[
                SizedBox(
                  height: 200,
                  child: GestureDetector(
                    onTapDown: (TapDownDetails details) {
                      _handlePieTap(details.localPosition, 200);
                    },
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: _PieChartPainter(
                        data: _serviceBreakdown,
                        palette: _palette,
                        selectedIndex: _selectedPieIndex,
                      ),
                    ),
                  ),
                ),
                if (_selectedPieIndex != null &&
                    _selectedPieIndex! < _serviceBreakdown.length)
                  _buildPieTooltip(_selectedPieIndex!),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPieTooltip(int index) {
    final Map<String, dynamic> item = _serviceBreakdown[index];
    final String label = (item['label'] ?? 'Khác').toString();
    final double value = (item['value'] as num? ?? 0).toDouble();
    final double total = _serviceBreakdown.fold<double>(
      0,
      (double sum, Map<String, dynamic> e) =>
          sum + (e['value'] as num? ?? 0).toDouble(),
    );
    final double percent = total > 0 ? (value / total) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _palette[index % _palette.length].withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _palette[index % _palette.length].withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _palette[index % _palette.length],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Text(
            '${_fmtCurrency(value)} (${percent.toStringAsFixed(1)}%)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: _palette[index % _palette.length],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePieTap(Offset localPos, double size) {
    final double cx = size / 2;
    final double cy = size / 2;
    final double dx = localPos.dx - cx;
    final double dy = localPos.dy - cy;
    final double distance = math.sqrt(dx * dx + dy * dy);
    final double radius = size / 2;
    if (distance > radius || distance < radius * 0.35) {
      setState(() => _selectedPieIndex = null);
      return;
    }
    double angle = math.atan2(dy, dx);
    if (angle < -math.pi / 2) angle += 2 * math.pi;
    angle += math.pi / 2;
    if (angle > 2 * math.pi) angle -= 2 * math.pi;

    final double total = _serviceBreakdown.fold<double>(
      0,
      (double sum, Map<String, dynamic> e) =>
          sum + (e['value'] as num? ?? 0).toDouble(),
    );
    if (total <= 0) return;

    double cumAngle = 0;
    for (int i = 0; i < _serviceBreakdown.length; i++) {
      final double value =
          (_serviceBreakdown[i]['value'] as num? ?? 0).toDouble();
      final double sweep = (value / total) * 2 * math.pi;
      if (angle >= cumAngle && angle < cumAngle + sweep) {
        setState(() => _selectedPieIndex = i);
        return;
      }
      cumAngle += sweep;
    }
    setState(() => _selectedPieIndex = null);
  }

  Widget _buildStaffSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _roleTitle('staff'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Doanh thu: ${_fmtCurrency(_totalRevenue)} • Dòng tiền: ${_fmtCurrency(_totalCashflow)}',
            style: const TextStyle(
              fontSize: 12,
              color: StitchTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (_staffSales.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Chưa có dữ liệu nhân viên.',
                  style: TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ..._staffSales.asMap().entries.map(
              (MapEntry<int, Map<String, dynamic>> entry) =>
                  _buildStaffBar(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  Widget _buildStaffBar(int index, Map<String, dynamic> staff) {
    final String name = (staff['staff_name'] ?? 'Nhân sự').toString();
    final double revenue = (staff['revenue'] as num? ?? 0).toDouble();
    final double cashflow = (staff['cashflow'] as num? ?? 0).toDouble();
    final double maxRevenue =
        _staffSales.isEmpty
            ? 1
            : _staffSales
                .map(
                  (Map<String, dynamic> s) =>
                      (s['revenue'] as num? ?? 0).toDouble(),
                )
                .reduce(math.max);
    final double maxCashflow =
        _staffSales.isEmpty
            ? 1
            : _staffSales
                .map(
                  (Map<String, dynamic> s) =>
                      (s['cashflow'] as num? ?? 0).toDouble(),
                )
                .reduce(math.max);
    final double revenueRatio = maxRevenue > 0 ? revenue / maxRevenue : 0;
    final double cashflowRatio = maxCashflow > 0 ? cashflow / maxCashflow : 0;

    final List<Color> barColors = <Color>[
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFF43F5E),
      const Color(0xFFF97316),
    ];
    final Color barColor = barColors[index % barColors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: barColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _MetricProgressLine(
            label: 'Doanh thu',
            valueLabel: _fmtCurrency(revenue),
            ratio: revenueRatio,
            barColor: barColor,
          ),
          const SizedBox(height: 6),
          _MetricProgressLine(
            label: 'Dòng tiền',
            valueLabel: _fmtCurrency(cashflow),
            ratio: cashflowRatio,
            barColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _MetricProgressLine extends StatelessWidget {
  const _MetricProgressLine({
    required this.label,
    required this.valueLabel,
    required this.ratio,
    required this.barColor,
  });

  final String label;
  final String valueLabel;
  final double ratio;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final double clampedRatio = ratio.isNaN ? 0 : ratio.clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: StitchTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 7,
            child: LinearProgressIndicator(
              value: clampedRatio,
              backgroundColor: StitchTheme.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({
    required this.data,
    required this.palette,
    this.selectedIndex,
  });

  final List<Map<String, dynamic>> data;
  final List<Color> palette;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = math.min(cx, cy) - 4;
    final double innerRadius = radius * 0.38;

    final double total = data.fold<double>(
      0,
      (double sum, Map<String, dynamic> e) =>
          sum + (e['value'] as num? ?? 0).toDouble(),
    );
    if (total <= 0) return;

    double startAngle = -math.pi / 2;
    for (int i = 0; i < data.length; i++) {
      final double value = (data[i]['value'] as num? ?? 0).toDouble();
      final double sweepAngle = (value / total) * 2 * math.pi;
      final bool isSelected = selectedIndex == i;

      final Paint paint =
          Paint()
            ..color = palette[i % palette.length]
            ..style = PaintingStyle.fill;

      final double drawRadius = isSelected ? radius + 4 : radius;

      // Draw arc segment
      final Path path =
          Path()
            ..moveTo(
              cx + innerRadius * math.cos(startAngle),
              cy + innerRadius * math.sin(startAngle),
            )
            ..lineTo(
              cx + drawRadius * math.cos(startAngle),
              cy + drawRadius * math.sin(startAngle),
            )
            ..arcTo(
              Rect.fromCircle(center: Offset(cx, cy), radius: drawRadius),
              startAngle,
              sweepAngle,
              false,
            )
            ..lineTo(
              cx + innerRadius * math.cos(startAngle + sweepAngle),
              cy + innerRadius * math.sin(startAngle + sweepAngle),
            )
            ..arcTo(
              Rect.fromCircle(center: Offset(cx, cy), radius: innerRadius),
              startAngle + sweepAngle,
              -sweepAngle,
              false,
            )
            ..close();

      canvas.drawPath(path, paint);

      // Percentage label
      if (sweepAngle > 0.3) {
        final double midAngle = startAngle + sweepAngle / 2;
        final double labelR = (innerRadius + drawRadius) / 2;
        final double lx = cx + labelR * math.cos(midAngle);
        final double ly = cy + labelR * math.sin(midAngle);
        final double pct = (value / total) * 100;

        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: '${pct.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.selectedIndex != selectedIndex;
}

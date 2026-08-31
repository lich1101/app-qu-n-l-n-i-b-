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

class _AdminRevenueChartsState extends State<AdminRevenueCharts>
    with AutomaticKeepAliveClientMixin<AdminRevenueCharts> {
  bool _loading = true;
  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _serviceBreakdown = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _staffSales = <Map<String, dynamic>>[];
  double _totalRevenue = 0;
  double _totalCashflow = 0;

  /// Khớp API `product_breakdown_total` (tổng các slice, gồm «Hợp đồng chưa có sản phẩm»).
  double _productBreakdownTotal = 0;
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
        (data['product_breakdown'] ?? <dynamic>[]) as List<dynamic>;
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
          rawStaff
              .map((dynamic e) => e as Map<String, dynamic>)
              .where(_hasMeaningfulStaffMetrics)
              .toList();
      _totalRevenue = (data['period_revenue_total'] ?? 0).toDouble();
      _totalCashflow = (data['period_cashflow_total'] ?? 0).toDouble();
      _productBreakdownTotal =
          (data['product_breakdown_total'] ?? 0).toDouble();
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

  /// Định dạng số đầy đủ kiểu vi-VN (117.826.500) cho legend / tổng giữa donut.
  String _fmtCurrencyFull(double value) {
    final int v = value.round();
    final String s = v.abs().toString();
    final List<String> parts = <String>[];
    for (int i = s.length; i > 0; i -= 3) {
      final int start = i > 3 ? i - 3 : 0;
      parts.insert(0, s.substring(start, i));
    }
    return (v < 0 ? '-' : '') + parts.join('.');
  }

  int _contractCountFor(Map<String, dynamic> item) {
    return int.tryParse(
          (item['contracts_count'] ?? item['contract_count'] ?? 0).toString(),
        ) ??
        0;
  }

  String _contractCountSuffix(int count) {
    return count > 0 ? ' · $count HĐ' : '';
  }

  bool _hasMeaningfulStaffMetrics(Map<String, dynamic> row) {
    return ((row['revenue'] as num?) ?? 0).toDouble() > 0 ||
        ((row['cashflow'] as num?) ?? 0).toDouble() > 0 ||
        ((row['contracts_count'] as num?) ?? 0).toInt() > 0;
  }

  double _pieCenterTotal() {
    if (_productBreakdownTotal > 0) {
      return _productBreakdownTotal;
    }
    return _serviceBreakdown.fold<double>(
      0,
      (double sum, Map<String, dynamic> e) =>
          sum + (e['value'] as num? ?? 0).toDouble(),
    );
  }

  int _staffContractsTotal() {
    return _staffSales.fold<int>(
      0,
      (int sum, Map<String, dynamic> item) => sum + _contractCountFor(item),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            color: Colors.white,
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
                          fontWeight: FontWeight.w500,
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
                              fontWeight: FontWeight.w500,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StitchTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _roleTitle('pie'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(
                                0xFF8B5CF6,
                              ).withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            'Theo danh mục',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.06,
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tỷ trọng theo danh mục / dòng hàng hợp đồng đã duyệt (giá trị hiệu lực). Kỳ theo ngày duyệt.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: StitchTheme.textMuted,
                      ),
                    ),
                  ],
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Column(
                    children: <Widget>[
                      const Text(
                        'Doanh thu',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.04,
                          color: StitchTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmtCurrencyFull(_pieCenterTotal()),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A),
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ChartInfoPill(
                      icon: Icons.pie_chart_rounded,
                      label: 'Tổng kỳ',
                      value: _fmtCurrency(_pieCenterTotal()),
                      accent: const Color(0xFF8B5CF6),
                    ),
                    _ChartInfoPill(
                      icon: Icons.category_rounded,
                      label: 'Hạng mục',
                      value: '${_serviceBreakdown.length} mục',
                      accent: const Color(0xFF3B82F6),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    height: 200,
                    width: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        GestureDetector(
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
                        IgnorePointer(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              SizedBox(
                                width: 86,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _fmtCurrencyFull(_pieCenterTotal()),
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF0F172A),
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedPieIndex != null &&
                    _selectedPieIndex! < _serviceBreakdown.length)
                  _buildPieTooltip(_selectedPieIndex!),
                const SizedBox(height: 12),
                const Text(
                  'Chi tiết theo mục',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.06,
                    color: StitchTheme.textSubtle,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _serviceBreakdown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> item =
                          _serviceBreakdown[index];
                      final String label = (item['label'] ?? 'Khác').toString();
                      final double value =
                          (item['value'] as num? ?? 0).toDouble();
                      final double total = _pieCenterTotal();
                      final double pct = total > 0 ? (value / total) * 100 : 0;
                      final int contractsCount = _contractCountFor(item);
                      final Color color = _palette[index % _palette.length];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() => _selectedPieIndex = index);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _selectedPieIndex == index
                                      ? color.withValues(alpha: 0.06)
                                      : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    _selectedPieIndex == index
                                        ? color.withValues(alpha: 0.35)
                                        : StitchTheme.border,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Text(
                                      _fmtCurrencyFull(value),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      '${pct.toStringAsFixed(1)}%'
                                      '${_contractCountSuffix(contractsCount)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: StitchTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
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
    final int contractsCount = _contractCountFor(item);
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
        borderRadius: BorderRadius.circular(16),
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
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Text(
            '${_fmtCurrency(value)} (${percent.toStringAsFixed(1)}%)'
            '${_contractCountSuffix(contractsCount)}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StitchTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
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
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _ChartInfoPill(
                  icon: Icons.trending_up_rounded,
                  label: 'Doanh thu',
                  value: _fmtCurrency(_totalRevenue),
                  accent: const Color(0xFF3B82F6),
                  dense: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChartInfoPill(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Dòng tiền',
                  value: _fmtCurrency(_totalCashflow),
                  accent: const Color(0xFF10B981),
                  dense: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChartInfoPill(
                  icon: Icons.description_rounded,
                  label: 'Hợp đồng',
                  value: '${_staffContractsTotal()} HĐ',
                  accent: const Color(0xFFF59E0B),
                  dense: true,
                ),
              ),
            ],
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
    final int contractsCount = _contractCountFor(staff);
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
    final int maxContracts =
        _staffSales.isEmpty
            ? 1
            : _staffSales
                .map((Map<String, dynamic> s) => _contractCountFor(s))
                .reduce(math.max);
    final double revenueRatio = maxRevenue > 0 ? revenue / maxRevenue : 0;
    final double cashflowRatio = maxCashflow > 0 ? cashflow / maxCashflow : 0;
    final double contractsRatio =
        maxContracts > 0 ? contractsCount / maxContracts : 0;

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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: StitchTheme.border),
        ),
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
                        fontWeight: FontWeight.w500,
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
                      fontWeight: FontWeight.w500,
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
            const SizedBox(height: 6),
            _MetricProgressLine(
              label: 'Hợp đồng',
              valueLabel: '$contractsCount HĐ',
              ratio: contractsRatio,
              barColor: const Color(0xFFF59E0B),
            ),
          ],
        ),
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
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: clampedRatio),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (
              BuildContext context,
              double animatedValue,
              Widget? child,
            ) {
              return SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: animatedValue,
                  backgroundColor: StitchTheme.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChartInfoPill extends StatelessWidget {
  const _ChartInfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Widget textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: dense ? 10 : 10.5,
            fontWeight: FontWeight.w500,
            color: StitchTheme.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: dense ? 12 : 12.5,
            fontWeight: FontWeight.w500,
            color: StitchTheme.textMain,
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: dense ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          Container(
            width: dense ? 28 : 30,
            height: dense ? 28 : 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: dense ? 15 : 16, color: accent),
          ),
          SizedBox(width: dense ? 6 : 8),
          dense ? Expanded(child: textColumn) : textColumn,
        ],
      ),
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
    const double fullCircleEpsilon = 0.0001;

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
      final Offset center = Offset(cx, cy);

      final Path path;
      if (sweepAngle >= (2 * math.pi) - fullCircleEpsilon) {
        path =
            Path()
              ..fillType = PathFillType.evenOdd
              ..addOval(Rect.fromCircle(center: center, radius: drawRadius))
              ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
      } else {
        path =
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
                Rect.fromCircle(center: center, radius: drawRadius),
                startAngle,
                sweepAngle,
                false,
              )
              ..lineTo(
                cx + innerRadius * math.cos(startAngle + sweepAngle),
                cy + innerRadius * math.sin(startAngle + sweepAngle),
              )
              ..arcTo(
                Rect.fromCircle(center: center, radius: innerRadius),
                startAngle + sweepAngle,
                -sweepAngle,
                false,
              )
              ..close();
      }

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
              fontWeight: FontWeight.w500,
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

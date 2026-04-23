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
  bool _filterExpanded = false;
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

  bool _hasMeaningfulStaffMetrics(Map<String, dynamic> row) {
    return _asDouble(row['revenue']) > 0 ||
        _asDouble(row['cashflow']) > 0 ||
        _asDouble(row['debt']) > 0 ||
        _asDouble(row['costs']) > 0 ||
        ((row['contracts_count'] as num?) ?? 0).toInt() > 0;
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

  void _applyExplicitRange(
    DateTime from,
    DateTime to, {
    bool collapsePanel = false,
  }) {
    setState(() {
      dateFromCtrl.text = _fmtDate(from);
      dateToCtrl.text = _fmtDate(to);
      if (collapsePanel) {
        _filterExpanded = false;
      }
    });
    _fetch();
  }

  void _applyRecentDays(int days) {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: math.max(days - 1, 0)));
    _applyExplicitRange(start, DateTime(now.year, now.month, now.day));
  }

  void _applyCurrentMonth() {
    final DateTime now = DateTime.now();
    _applyExplicitRange(
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 0),
    );
  }

  @override
  void initState() {
    super.initState();
    // Default to current month
    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(now.year, now.month, 1);
    final DateTime monthEnd = DateTime(now.year, now.month + 1, 0);
    dateFromCtrl.text = _fmtDate(monthStart);
    dateToCtrl.text = _fmtDate(monthEnd);
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

  String get _screenTitle {
    switch (widget.currentUserRole) {
      case 'admin':
        return 'Báo cáo doanh thu công ty';
      case 'quan_ly':
        return 'Báo cáo doanh thu phòng ban';
      default:
        return 'Báo cáo doanh thu cá nhân';
    }
  }

  @override
  Widget build(BuildContext context) {
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
            .where(_hasMeaningfulStaffMetrics)
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
      appBar: AppBar(title: Text(_screenTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              // ── Compact period bar ──
              _CompactPeriodBar(
                periodLabel: periodLabel,
                onTapExpand:
                    () => setState(() => _filterExpanded = !_filterExpanded),
                expanded: _filterExpanded,
                onReset: _resetToFullRange,
                loading: loading,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _InfoPill(
                    icon: Icons.visibility_rounded,
                    label: 'Đang xem',
                    value: periodLabel,
                  ),
                  _InfoPill(
                    icon: Icons.event_available_rounded,
                    label: 'Nguồn dữ liệu',
                    value:
                        availableFrom.isNotEmpty && availableTo.isNotEmpty
                            ? '${_displayDate(availableFrom)} - ${_displayDate(availableTo)}'
                            : 'Tự động theo hệ thống',
                  ),
                  _InfoPill(
                    icon:
                        loading
                            ? Icons.sync_rounded
                            : Icons.check_circle_rounded,
                    label: loading ? 'Trạng thái' : 'Bộ lọc',
                    value: loading ? 'Đang tải lại báo cáo' : 'Đã đồng bộ',
                    accent:
                        loading
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                  ),
                ],
              ),
              if (_filterExpanded) ...<Widget>[
                const SizedBox(height: 10),
                _CompactFilterPanel(
                  dateFromCtrl: dateFromCtrl,
                  dateToCtrl: dateToCtrl,
                  targetCtrl: targetCtrl,
                  onPickFrom: () => _pickDate(dateFromCtrl),
                  onPickTo: () => _pickDate(dateToCtrl),
                  onRecent7: () => _applyRecentDays(7),
                  onRecent30: () => _applyRecentDays(30),
                  onCurrentMonth: _applyCurrentMonth,
                  onFullRange: _resetToFullRange,
                  onApply: () {
                    setState(() => _filterExpanded = false);
                    _fetch();
                  },
                  loading: loading,
                ),
              ],
              const SizedBox(height: 16),
              // ── 2x2 Summary grid ──
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SummaryCard(
                      title: 'Doanh thu',
                      value: _formatCompactCurrency(
                        _asDouble(periodTotals['revenue']),
                      ),
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Dòng tiền',
                      value: _formatCompactCurrency(
                        _asDouble(periodTotals['cashflow']),
                      ),
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SummaryCard(
                      title: 'Công nợ',
                      value: _formatCompactCurrency(
                        _asDouble(periodTotals['debt']),
                      ),
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Chi phí',
                      value: _formatCompactCurrency(
                        _asDouble(periodTotals['costs']),
                      ),
                      icon: Icons.payments_rounded,
                      color: const Color(0xFFEF4444),
                      subtitle: '${periodTotals['contracts_total'] ?? 0} HĐ',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Doanh thu theo sản phẩm',
                subtitle:
                    'Biểu đồ tròn tính trên toàn bộ hợp đồng đã duyệt trong khoảng thời gian đang lọc.',
                icon: Icons.donut_large_rounded,
                accentColor: const Color(0xFF8B5CF6),
                badge: 'Theo sản phẩm',
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
                icon: Icons.bar_chart_rounded,
                accentColor: const Color(0xFF0EA5E9),
                badge: 'Theo người',
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
                icon: Icons.table_rows_rounded,
                accentColor: const Color(0xFF10B981),
                badge: 'Theo ngày',
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
                                            _asDouble(
                                              item['revenue_cumulative'],
                                            ),
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
      ),
    );
  }
}

class _CompactPeriodBar extends StatelessWidget {
  const _CompactPeriodBar({
    required this.periodLabel,
    required this.onTapExpand,
    required this.expanded,
    required this.onReset,
    required this.loading,
  });

  final String periodLabel;
  final VoidCallback onTapExpand;
  final bool expanded;
  final VoidCallback onReset;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white,
            const Color(0xFFF8FAFC),
            const Color(0xFFE6FFFB),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFFDBEAFE),
                  const Color(0xFFCCFBF1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              loading ? Icons.sync_rounded : Icons.date_range_rounded,
              size: 18,
              color:
                  loading ? const Color(0xFFB45309) : const Color(0xFF0F766E),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Khoảng thời gian đang xem',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.18,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  periodLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? 'Đang tải lại số liệu theo bộ lọc này'
                      : 'Chạm nút tinh chỉnh để đổi ngày, chỉ tiêu hoặc preset nhanh',
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: StitchTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: <Widget>[
              GestureDetector(
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Toàn bộ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onTapExpand,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: expanded ? const Color(0xFF0F766E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x0A0F172A),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    expanded ? Icons.close_rounded : Icons.tune_rounded,
                    size: 16,
                    color: expanded ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = const Color(0xFF0F766E),
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.14,
                  color: StitchTheme.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: StitchTheme.textMain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactFilterPanel extends StatelessWidget {
  const _CompactFilterPanel({
    required this.dateFromCtrl,
    required this.dateToCtrl,
    required this.targetCtrl,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onRecent7,
    required this.onRecent30,
    required this.onCurrentMonth,
    required this.onFullRange,
    required this.onApply,
    required this.loading,
  });

  final TextEditingController dateFromCtrl;
  final TextEditingController dateToCtrl;
  final TextEditingController targetCtrl;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onRecent7;
  final VoidCallback onRecent30;
  final VoidCallback onCurrentMonth;
  final VoidCallback onFullRange;
  final VoidCallback onApply;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Preset nhanh',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.18,
              color: StitchTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _QuickFilterChip(label: '7 ngày', onTap: onRecent7),
              _QuickFilterChip(label: '30 ngày', onTap: onRecent30),
              _QuickFilterChip(label: 'Tháng này', onTap: onCurrentMonth),
              _QuickFilterChip(label: 'Toàn bộ', onTap: onFullRange),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniDateField(
                  label: 'Từ ngày',
                  controller: dateFromCtrl,
                  onTap: onPickFrom,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniDateField(
                  label: 'Đến ngày',
                  controller: dateToCtrl,
                  onTap: onPickTo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: targetCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Chỉ tiêu doanh thu (VNĐ) — tùy chọn',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onApply,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(
                loading ? 'Đang tải...' : 'Áp dụng bộ lọc',
                style: const TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDateField extends StatelessWidget {
  const _MiniDateField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    controller.text.isNotEmpty ? controller.text : '—',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          controller.text.isNotEmpty
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const Icon(Icons.event, size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          colors: <Color>[color.withValues(alpha: 0.08), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon = Icons.auto_graph_rounded,
    this.accentColor = const Color(0xFF0F766E),
    this.badge,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;
  final Color accentColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          colors: <Color>[Colors.white, accentColor.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: StitchTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: StitchTheme.border),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: StitchTheme.textMain,
            ),
          ),
        ),
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

    final int safeSelectedIndex = _selectedIndex.clamp(
      0,
      math.max(0, items.length - 1),
    );
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
            gradient: LinearGradient(
              colors: <Color>[
                selectedItem.color.withValues(alpha: 0.08),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selectedItem.color.withValues(alpha: 0.22),
            ),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: item.color.withValues(
                    alpha: item == selectedItem ? 0.32 : 0.12,
                  ),
                ),
              ),
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

  _RevenueValue _selectedValueFor(String staffKey, List<_RevenueValue> values) {
    final String? selectedKey = _selectedSeriesByStaff[staffKey];
    final _RevenueValue? selectedValue =
        selectedKey == null
            ? null
            : values
                .where((item) => item.meta.key == selectedKey)
                .cast<_RevenueValue?>()
                .firstWhere((item) => item != null, orElse: () => null);

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
                    height: 20,
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
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: <Color>[
                                                  item.meta.color,
                                                  item.meta.color.withValues(
                                                    alpha: 0.76,
                                                  ),
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                            ),
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
                    gradient: LinearGradient(
                      colors: <Color>[
                        selectedValue.meta.color.withValues(alpha: 0.08),
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedValue.meta.color.withValues(alpha: 0.18),
                    ),
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

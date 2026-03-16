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

  final TextEditingController dateFromCtrl = TextEditingController();
  final TextEditingController dateToCtrl = TextEditingController();
  final TextEditingController targetCtrl = TextEditingController();

  String _fmtDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (date == null) return;
    if (!mounted) return;
    setState(() => controller.text = _fmtDate(date));
  }

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    final DateTime firstDay = DateTime(now.year, now.month, 1);
    dateFromCtrl.text = _fmtDate(firstDay);
    dateToCtrl.text = _fmtDate(now);
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
    setState(() {
      loading = false;
      report = company;
    });
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

    final List<dynamic> rows =
        (report['daily_rows'] ?? <dynamic>[]) as List<dynamic>;
    final Map<String, dynamic> lastRow = rows.isNotEmpty
        ? rows.last as Map<String, dynamic>
        : <String, dynamic>{};

    double _asDouble(dynamic value) =>
        double.tryParse((value ?? 0).toString()) ?? 0;

    final double totalRevenue = _asDouble(
      lastRow['revenue_cumulative'] ?? report['total_revenue'],
    );
    final double totalPaid = _asDouble(
      lastRow['collected_cumulative'] ?? report['total_paid'],
    );
    final double totalDebt = _asDouble(
      lastRow['debt_cumulative'] ?? report['total_debt'],
    );
    final double totalCosts = _asDouble(report['total_costs']);
    final int contractsTotal =
        int.tryParse((report['contracts_total'] ?? 0).toString()) ?? 0;

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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Tổng doanh thu',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${totalRevenue.toStringAsFixed(0)} VNĐ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: StitchTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Hợp đồng: $contractsTotal',
                      style: const TextStyle(color: StitchTheme.textMuted)),
                  const SizedBox(height: 6),
                  Text('Nợ đã thu hồi: ${totalPaid.toStringAsFixed(0)} VNĐ',
                      style: const TextStyle(color: StitchTheme.textMuted)),
                  Text('Công nợ (Nợ tồn): ${totalDebt.toStringAsFixed(0)} VNĐ',
                      style: const TextStyle(color: StitchTheme.textMuted)),
                  Text('Chi phí: ${totalCosts.toStringAsFixed(0)} VNĐ',
                      style: const TextStyle(color: StitchTheme.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StitchTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Bộ lọc báo cáo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: dateFromCtrl,
                          readOnly: true,
                          onTap: () => _pickDate(dateFromCtrl),
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
                          onTap: () => _pickDate(dateToCtrl),
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _fetch,
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (rows.isEmpty)
              const Text(
                'Chưa có dữ liệu báo cáo.',
                style: TextStyle(color: StitchTheme.textMuted),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: StitchTheme.border),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Ngày')),
                      DataColumn(label: Text('Doanh thu')),
                      DataColumn(label: Text('Tiền thu')),
                      DataColumn(label: Text('Công nợ')),
                      DataColumn(label: Text('Nợ tồn tháng trước')),
                    ],
                    rows: rows.map((dynamic row) {
                      final Map<String, dynamic> item =
                          row as Map<String, dynamic>;
                      final String date = (item['date'] ?? '').toString();
                      final String showDate = date.isEmpty
                          ? '—'
                          : '${date.substring(8, 10)}-${date.substring(5, 7)}-${date.substring(0, 4)}';
                      final double revenueDaily =
                          _asDouble(item['revenue_daily']);
                      final double collectedDaily =
                          _asDouble(item['collected_daily']);
                      final double debtDaily = _asDouble(item['debt_daily']);
                      final double prevDebtRemaining =
                          _asDouble(item['prev_month_debt_remaining']);
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(Text(showDate)),
                          DataCell(
                              Text('${revenueDaily.toStringAsFixed(0)} VNĐ')),
                          DataCell(
                              Text('${collectedDaily.toStringAsFixed(0)} VNĐ')),
                          DataCell(
                              Text('${debtDaily.toStringAsFixed(0)} VNĐ')),
                          DataCell(Text(
                              '${prevDebtRemaining.toStringAsFixed(0)} VNĐ')),
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

import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.token,
    required this.apiService,
    this.showBack = true,
  });

  final String token;
  final MobileApiService apiService;
  final bool showBack;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic> report = <String, dynamic>{};
  bool loading = false;
  String selectedTab = 'backlinks';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    final Map<String, dynamic> data = await widget.apiService.getReportSummary(
      widget.token,
    );
    setState(() {
      loading = false;
      report = data;
    });
  }

  int _readInt(List<String> keys, {int fallback = 0}) {
    for (final String key in keys) {
      final dynamic value = report[key];
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        final int? parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  List<int> _daBuckets() {
    final dynamic raw = report['da_buckets'];
    if (raw is List) {
      return raw.map((dynamic e) {
        if (e is int) return e;
        return int.tryParse(e.toString()) ?? 0;
      }).toList();
    }
    return <int>[45, 80, 65, 30];
  }

  List<Map<String, dynamic>> _recentLinks() {
    final dynamic raw = report['recent_links'] ?? report['links'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => item)
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tính năng đang được hoàn thiện, sẽ có trong bản cập nhật tiếp theo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int linksLive = _readInt(<String>[
      'links_live',
      'backlinks_live',
      'links_done',
    ]);
    final int linksTotal = _readInt(<String>[
      'links_total',
      'backlinks_total',
    ], fallback: 100);
    final int linksPending = _readInt(<String>[
      'links_pending',
      'backlinks_pending',
    ]);
    final int totalWords = _readInt(<String>['content_words', 'words_total']);
    final int seoScore = _readInt(<String>['seo_score'], fallback: 92);
    final int auditTotal = _readInt(<String>['audit_total']);
    final int auditDone = _readInt(<String>['audit_done']);
    final int auditOpen = _readInt(<String>['audit_open']);
    final int websiteTotal = _readInt(<String>['website_total']);
    final int websiteIndexed = _readInt(<String>['website_indexed']);
    final int websiteTraffic = _readInt(<String>[
      'website_traffic_avg',
      'website_traffic',
    ]);
    final int websiteRanking = _readInt(<String>['website_ranking_avg']);

    final List<int> daBuckets = _daBuckets();
    final List<Map<String, dynamic>> recentLinks = _recentLinks();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: <Widget>[
                  if (widget.showBack)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new),
                    )
                  else
                    const SizedBox(width: 40),
                  const Expanded(
                    child: Text(
                      'Báo cáo Hiệu suất',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showComingSoon,
                    icon: Icon(Icons.download, color: StitchTheme.primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _SegmentedControl(
                value: selectedTab,
                options: const <String, String>{
                  'backlinks': 'Backlinks',
                  'content': 'Content',
                  'seo': 'SEO',
                },
                onChanged:
                    (String value) => setState(() => selectedTab = value),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetch,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: <Widget>[
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: <Widget>[
                        _ReportMetricCard(
                          icon: Icons.link,
                          label: 'Backlinks đã lên',
                          value: '$linksLive/$linksTotal',
                          progress:
                              linksTotal == 0
                                  ? 0
                                  : (linksLive / linksTotal)
                                      .clamp(0, 1)
                                      .toDouble(),
                          accent: StitchTheme.primary,
                        ),
                        _ReportMetricCard(
                          icon: Icons.schedule,
                          label: 'Đang chờ',
                          value: linksPending.toString(),
                          subLabel: '+${(linksPending / 4).round()} mới',
                          accent: StitchTheme.warning,
                        ),
                      ],
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const <Widget>[
                                  Text(
                                    'Phân bổ DA',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Dữ liệu thu thập tháng hiện tại',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: StitchTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.more_horiz,
                                color: StitchTheme.textSubtle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 140,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List<Widget>.generate(4, (int index) {
                                final int value =
                                    index < daBuckets.length
                                        ? daBuckets[index]
                                        : 0;
                                final double height =
                                    (value.clamp(10, 100) / 100) * 120;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: <Widget>[
                                        Container(
                                          height: height,
                                          decoration: BoxDecoration(
                                            color:
                                                index == 2
                                                    ? StitchTheme.primary
                                                    : StitchTheme.primarySoft,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(8),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'DA ${(index + 1) * 20}+',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: StitchTheme.textSubtle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Thống kê Content',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          onPressed: _showComingSoon,
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    ),
                    _StatRow(
                      icon: Icons.description,
                      title: 'Tổng số từ',
                      subtitle: 'Sản lượng tháng này',
                      value:
                          totalWords == 0 ? '128.400' : totalWords.toString(),
                      trailing: '+14.2%',
                      accent: StitchTheme.primary,
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      icon: Icons.query_stats,
                      title: 'Điểm SEO trung bình',
                      subtitle: 'Dữ liệu Surfer SEO',
                      value: '$seoScore / 100',
                      trailing: 'Tối ưu',
                      accent: StitchTheme.primary,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Audit Content & Website Care',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      icon: Icons.fact_check,
                      title: 'URL Audit',
                      subtitle: 'Tổng số URL đã Audit',
                      value: auditTotal.toString(),
                      trailing: '$auditDone đã hoàn tất',
                      accent: StitchTheme.primary,
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      icon: Icons.report_problem_outlined,
                      title: 'Audit còn mở',
                      subtitle: 'URL còn lại cần xử lý',
                      value: auditOpen.toString(),
                      trailing: 'Theo dõi',
                      accent: StitchTheme.warning,
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      icon: Icons.public,
                      title: 'Website Care',
                      subtitle: 'Checklist bảo trì',
                      value: websiteTotal.toString(),
                      trailing: '$websiteIndexed đã lập chỉ mục',
                      accent: StitchTheme.primary,
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      icon: Icons.trending_up,
                      title: 'Traffic Trung Bình',
                      subtitle: 'Website Care tổng thể',
                      value: websiteTraffic.toString(),
                      trailing: 'Δ $websiteRanking',
                      accent: StitchTheme.success,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Vị trí đặt Backlinks gần đây',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (recentLinks.isEmpty)
                      const Text(
                        'Chưa có dữ liệu Backlinks gần đây.',
                        style: TextStyle(color: StitchTheme.textMuted),
                      )
                    else
                      ...recentLinks.map((Map<String, dynamic> item) {
                        final String domain =
                            (item['domain'] ?? item['name'] ?? 'domain.com')
                                .toString();
                        final String da = (item['da'] ?? 'DA 0').toString();
                        final String status =
                            (item['status'] ?? 'Đang duyệt').toString();
                        return _RecentLinkTile(
                          domain: domain,
                          meta: '$da • $status',
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: StitchTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children:
            options.entries.map((MapEntry<String, String> entry) {
              final bool selected = entry.key == value;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              selected
                                  ? StitchTheme.primary
                                  : StitchTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.progress,
    this.subLabel,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final double? progress;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
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
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: StitchTheme.textSubtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (subLabel != null) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: StitchTheme.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subLabel!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: StitchTheme.primary,
                ),
              ),
            ),
          ],
          if (progress != null) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 6,
                color: accent,
                backgroundColor: StitchTheme.surfaceAlt,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.trailing,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: StitchTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: StitchTheme.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: StitchTheme.primary,
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

class _RecentLinkTile extends StatelessWidget {
  const _RecentLinkTile({required this.domain, required this.meta});

  final String domain;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final String initials = domain.isEmpty ? 'NA' : domain[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: StitchTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StitchTheme.border),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  domain,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: StitchTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: StitchTheme.textSubtle),
        ],
      ),
    );
  }
}

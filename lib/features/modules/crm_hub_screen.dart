import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';

class CrmHubScreen extends StatelessWidget {
  const CrmHubScreen({
    super.key,
    this.onOpenCrm,
    this.onOpenOpportunities,
    this.onOpenContracts,
    this.onOpenProducts,
    this.onOpenLeadForms,
    this.onOpenLeadTypes,
    this.onOpenRevenueTiers,
    this.onOpenRevenueReport,
  });

  final VoidCallback? onOpenCrm;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenContracts;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenLeadForms;
  final VoidCallback? onOpenLeadTypes;
  final VoidCallback? onOpenRevenueTiers;
  final VoidCallback? onOpenRevenueReport;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom + 80;
    final List<_CrmItem> mainItems = <_CrmItem>[
      if (onOpenCrm != null)
        _CrmItem(
          title: 'Khách hàng',
          subtitle: 'Danh sách khách hàng & phân công',
          icon: Icons.people_alt_outlined,
          onTap: onOpenCrm!,
        ),
      if (onOpenOpportunities != null)
        _CrmItem(
          title: 'Cơ hội bán hàng',
          subtitle: 'Pipeline chăm sóc khách hàng',
          icon: Icons.trending_up_outlined,
          onTap: onOpenOpportunities!,
        ),
      if (onOpenContracts != null)
        _CrmItem(
          title: 'Hợp đồng',
          subtitle: 'Khách hàng → hợp đồng → dự án',
          icon: Icons.description_outlined,
          onTap: onOpenContracts!,
        ),
      if (onOpenProducts != null)
        _CrmItem(
          title: 'Sản phẩm & danh mục',
          subtitle: 'Quản lý sản phẩm, nhóm danh mục và đơn giá',
          icon: Icons.shopping_bag_outlined,
          onTap: onOpenProducts!,
        ),
    ];

    final List<_CrmItem> configItems = <_CrmItem>[
      if (onOpenLeadForms != null)
        _CrmItem(
          title: 'Form tư vấn',
          subtitle: 'Tạo iframe thu khách hàng tiềm năng',
          icon: Icons.webhook_outlined,
          onTap: onOpenLeadForms!,
        ),
      if (onOpenLeadTypes != null)
        _CrmItem(
          title: 'Trạng thái khách hàng',
          subtitle: 'Cấu hình thẻ & màu sắc',
          icon: Icons.label_outline,
          onTap: onOpenLeadTypes!,
        ),
      if (onOpenRevenueTiers != null)
        _CrmItem(
          title: 'Hạng doanh thu',
          subtitle: 'Đã từng mua hàng/Bạc/Vàng/Kim cương',
          icon: Icons.workspace_premium_outlined,
          onTap: onOpenRevenueTiers!,
        ),
      if (onOpenRevenueReport != null)
        _CrmItem(
          title: 'Doanh thu công ty',
          subtitle: 'Theo dõi doanh thu tổng hợp toàn công ty',
          icon: Icons.stacked_line_chart_outlined,
          onTap: onOpenRevenueReport!,
        ),
    ];

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
        children: <Widget>[
          StitchPageHeader(
            title: 'CRM & Kinh doanh',
            subtitle:
                'Tập trung khách hàng, cơ hội, hợp đồng và sản phẩm vào một luồng làm việc thống nhất để theo dõi doanh thu.',
            icon: Icons.groups_2_outlined,
            stats: <StitchHeaderStat>[
              StitchHeaderStat(
                label: 'Phân hệ chính',
                value: mainItems.length.toString(),
              ),
              StitchHeaderStat(
                label: 'Cấu hình CRM',
                value: configItems.length.toString(),
                accent: StitchTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          StitchSurfaceCard(
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: StitchTheme.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.alt_route_outlined,
                    color: StitchTheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Luồng CRM chuẩn',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Khách hàng -> Cơ hội -> Hợp đồng -> Dự án -> Doanh thu công ty.',
                        style: TextStyle(
                          color: StitchTheme.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const StitchSectionHeader(title: 'Vận hành CRM'),
          const SizedBox(height: 12),
          ...mainItems.map(_CrmItemCard.new),
          const SizedBox(height: 16),
          if (configItems.isNotEmpty) ...<Widget>[
            const StitchSectionHeader(title: 'Cấu hình CRM'),
            const SizedBox(height: 10),
            ...configItems.map(_CrmItemCard.new),
          ],
        ],
      ),
    );
  }
}

class _CrmItem {
  const _CrmItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _CrmItemCard extends StatelessWidget {
  const _CrmItemCard(this.item);

  final _CrmItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: item.onTap,
      child: StitchSurfaceCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: StitchTheme.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: StitchTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: StitchTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: StitchTheme.textSubtle),
          ],
        ),
      ),
    );
  }
}

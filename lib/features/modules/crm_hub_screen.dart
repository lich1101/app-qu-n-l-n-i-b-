import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';

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
          subtitle: 'Danh mục sản phẩm, nhóm hàng và đơn giá',
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
          const Text(
            'CRM & Sales',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quản lý khách hàng, cơ hội bán hàng, hợp đồng và sản phẩm.',
            style: TextStyle(color: StitchTheme.textMuted),
          ),
          const SizedBox(height: 16),
          ...mainItems.map(_CrmItemCard.new),
          const SizedBox(height: 16),
          if (configItems.isNotEmpty) ...<Widget>[
            const Text(
              'Cấu hình CRM',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StitchTheme.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: item.onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: StitchTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: StitchTheme.textMuted,
                      height: 1.3,
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

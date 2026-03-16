import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';

class ModuleCenterScreen extends StatelessWidget {
  const ModuleCenterScreen({
    super.key,
    this.onOpenNotifications,
    this.onOpenDeadline,
    this.onOpenHandover,
    this.onOpenChat,
    this.onOpenActivityLogs,
    this.onOpenMeetings,
    this.onOpenCrm,
    this.onOpenContracts,
    this.onOpenOpportunities,
    this.onOpenProducts,
    this.onOpenDepartments,
    this.onOpenDepartmentAssignments,
    this.onOpenRevenueReport,
    this.onOpenLeadForms,
    this.onOpenLeadTypes,
    this.onOpenRevenueTiers,
    this.onOpenReports,
    this.onOpenServices,
    this.onOpenProjects,
    this.onOpenCreateProject,
  });

  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenDeadline;
  final VoidCallback? onOpenHandover;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenActivityLogs;
  final VoidCallback? onOpenMeetings;
  final VoidCallback? onOpenCrm;
  final VoidCallback? onOpenContracts;
  final VoidCallback? onOpenOpportunities;
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenDepartments;
  final VoidCallback? onOpenDepartmentAssignments;
  final VoidCallback? onOpenRevenueReport;
  final VoidCallback? onOpenLeadForms;
  final VoidCallback? onOpenLeadTypes;
  final VoidCallback? onOpenRevenueTiers;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenProjects;
  final VoidCallback? onOpenCreateProject;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final TextScaler scaler = media.textScaler.clamp(
      minScaleFactor: 0.95,
      maxScaleFactor: 1.1,
    );
    final List<_ModuleItem> modules = <_ModuleItem>[
      _ModuleItem(
        title: 'Quản lý dự án',
        subtitle: 'Bảng Kanban/Dòng thời gian/Biểu đồ Gantt + tiến độ',
        icon: Icons.account_tree_outlined,
        onTap: onOpenProjects,
      ),
      _ModuleItem(
        title: 'Đơn hàng & phân công công việc',
        subtitle: 'Giao việc theo luồng Quản trị/Quản lý',
        icon: Icons.assignment_turned_in_outlined,
      ),
      _ModuleItem(
        title: 'Nhắc nhở hạn chót',
        subtitle: 'Trong ứng dụng, email, webhook',
        icon: Icons.alarm_on_outlined,
        onTap: onOpenDeadline,
      ),
      _ModuleItem(
        title: 'Nộp liên kết/video tài liệu',
        subtitle: 'Phiên bản bàn giao theo công việc',
        icon: Icons.video_collection_outlined,
        onTap: onOpenHandover,
      ),
      _ModuleItem(
        title: 'Phân luồng quản lý',
        subtitle: 'Phân quyền theo phòng ban',
        icon: Icons.route_outlined,
      ),
      _ModuleItem(
        title: 'Báo cáo & KPI',
        subtitle: 'Tổng hợp hiệu suất dự án/cá nhân',
        icon: Icons.bar_chart_outlined,
        onTap: onOpenReports,
      ),
      _ModuleItem(
        title: 'Quy trình theo dịch vụ',
        subtitle: 'Backlinks/Content/Audit Content/Website Care',
        icon: Icons.design_services_outlined,
        onTap: onOpenServices,
      ),
      _ModuleItem(
        title: 'Quản lý lịch họp',
        subtitle: 'Tạo lịch, biên bản, người tham dự',
        icon: Icons.event_note_outlined,
        onTap: onOpenMeetings,
      ),
      _ModuleItem(
        title: 'Chat nội bộ',
        subtitle: 'Trao đổi theo công việc/dự án',
        icon: Icons.chat_bubble_outline,
        onTap: onOpenChat,
      ),
      _ModuleItem(
        title: 'Thông báo nội bộ',
        subtitle: 'Nhắc hạn & thông báo hệ thống',
        icon: Icons.notifications_outlined,
        onTap: onOpenNotifications,
      ),
      _ModuleItem(
        title: 'Nhật ký hệ thống',
        subtitle: 'Lịch sử thao tác & đổi trạng thái',
        icon: Icons.history_toggle_off_outlined,
        onTap: onOpenActivityLogs,
      ),
      _ModuleItem(
        title: 'Quản lý khách hàng',
        subtitle: 'Khách hàng, thanh toán, người phụ trách',
        icon: Icons.people_alt_outlined,
        onTap: onOpenCrm,
      ),
      _ModuleItem(
        title: 'Cơ hội bán hàng',
        subtitle: 'Phễu khách hàng tiềm năng',
        icon: Icons.trending_up_outlined,
        onTap: onOpenOpportunities,
      ),
      _ModuleItem(
        title: 'Hợp đồng',
        subtitle: 'Khách hàng → hợp đồng → dự án',
        icon: Icons.description_outlined,
        onTap: onOpenContracts,
      ),
      _ModuleItem(
        title: 'Sản phẩm & danh mục',
        subtitle: 'Sản phẩm, danh mục và đơn giá theo nghiệp vụ',
        icon: Icons.shopping_bag_outlined,
        onTap: onOpenProducts,
      ),
      _ModuleItem(
        title: 'Phòng ban',
        subtitle: 'Quản lý phòng ban & quản lý',
        icon: Icons.account_tree_outlined,
        onTap: onOpenDepartments,
      ),
      _ModuleItem(
        title: 'Điều phối phòng ban',
        subtitle: 'Giao việc và theo dõi tiến độ giữa các phòng ban',
        icon: Icons.assignment_ind_outlined,
        onTap: onOpenDepartmentAssignments,
      ),
      _ModuleItem(
        title: 'Báo cáo doanh thu công ty',
        subtitle: 'Tổng hợp doanh thu toàn công ty',
        icon: Icons.stacked_line_chart_outlined,
        onTap: onOpenRevenueReport,
      ),
      _ModuleItem(
        title: 'Form tư vấn',
        subtitle: 'Tạo iframe thu khách hàng tiềm năng',
        icon: Icons.webhook_outlined,
        onTap: onOpenLeadForms,
      ),
      _ModuleItem(
        title: 'Trạng thái khách hàng tiềm năng',
        subtitle: 'Cấu hình thẻ & màu sắc',
        icon: Icons.label_outline,
        onTap: onOpenLeadTypes,
      ),
      _ModuleItem(
        title: 'Hạng doanh thu',
        subtitle: 'Đã từng mua hàng/Bạc/Vàng/Kim cương',
        icon: Icons.workspace_premium_outlined,
        onTap: onOpenRevenueTiers,
      ),
      _ModuleItem(
        title: 'Chuẩn kỹ thuật',
        subtitle: 'Bảo mật, mở rộng, tích hợp API',
        icon: Icons.security_outlined,
      ),
    ].where((item) => item.onTap != null).toList();

    return MediaQuery(
      data: media.copyWith(textScaler: scaler),
      child: Scaffold(
        backgroundColor: StitchTheme.bg,
        appBar: AppBar(
          title: const Text('Trung tâm phân hệ'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              StitchPageHeader(
                title: 'Phân hệ nghiệp vụ',
                subtitle:
                    'Tập hợp các phân hệ vận hành, CRM, báo cáo và cài đặt theo đúng luồng sử dụng nội bộ trên mobile.',
                icon: Icons.grid_view_outlined,
                stats: <StitchHeaderStat>[
                  StitchHeaderStat(label: 'Khả dụng', value: '${modules.length}'),
                  const StitchHeaderStat(label: 'Thiết kế', value: 'Mobile-first'),
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
                      child: Icon(Icons.add_circle, color: StitchTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const <Widget>[
                          Text(
                            'Tạo dự án mới',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Khởi tạo dự án mới theo mẫu Stitch.',
                            style: TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenCreateProject,
                      child:
                          Text(onOpenCreateProject == null ? 'Không có quyền' : 'Tạo mới'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...modules.map(
                (_ModuleItem item) => StitchSurfaceCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: item.onTap,
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: StitchTheme.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: StitchTheme.primary),
                        ),
                        const SizedBox(width: 12),
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
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          item.onTap != null
                              ? Icons.arrow_forward_ios
                              : Icons.info_outline,
                          size: 16,
                          color: item.onTap != null
                              ? StitchTheme.textMuted
                              : StitchTheme.textSubtle,
                        ),
                      ],
                    ),
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

class _ModuleItem {
  _ModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
}

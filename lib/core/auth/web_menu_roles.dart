// Khớp menu web: web/resources/js/Layouts/Authenticated.jsx
// (filter: item.roles.includes(currentRole)).
// Không kế thừa administrator → admin (khác với quyền API chỉ có "admin").

/// Kiểm tra role hiện tại có trong danh sách menu web hay không (khớp chuỗi, không merge role).
bool webMenuHasRole(String? currentRole, List<String> webMenuRoles) {
  final String r = (currentRole ?? '').toString();
  return webMenuRoles.contains(r);
}

/// CRM — "Khách hàng"
const List<String> kWebMenuCrmClients = <String>[
  'admin',
  'quan_ly',
  'nhan_vien',
  'ke_toan',
];

/// CRM — "Cơ hội"
const List<String> kWebMenuOpportunities = <String>[
  'admin',
  'quan_ly',
  'nhan_vien',
];

/// CRM — "Form tư vấn"
const List<String> kWebMenuLeadForms = <String>['admin'];

/// Sales — "Hợp đồng"
const List<String> kWebMenuContracts = <String>[
  'admin',
  'quan_ly',
  'nhan_vien',
  'ke_toan',
];

/// Sales — "Sản phẩm"
const List<String> kWebMenuProducts = <String>[
  'admin',
  'quan_ly',
  'nhan_vien',
  'ke_toan',
];

/// Operations — "Dự án" / "Công việc" / "Đầu việc" (cùng roles)
const List<String> kWebMenuOperationsProjectsTasks = <String>[
  'admin',
  'quan_ly',
  'nhan_vien',
];

/// Operations — "Bàn giao dự án"
const List<String> kWebMenuHandover = <String>['admin', 'nhan_vien'];

/// Operations — "Lịch họp"
const List<String> kWebMenuMeetings = <String>['admin', 'quan_ly'];

/// Operations — "Chấm công"
const List<String> kWebMenuAttendance = <String>[
  'admin',
  'administrator',
  'quan_ly',
  'nhan_vien',
  'ke_toan',
];

/// Reports — "Báo cáo KPI"
const List<String> kWebMenuReportsKpi = <String>['admin', 'quan_ly'];

/// Reports — "Doanh thu công ty"
const List<String> kWebMenuReportsCompany = <String>['admin'];

/// System — "Phòng ban"
const List<String> kWebMenuDepartments = <String>['admin', 'quan_ly'];

/// System — "Trạng thái khách hàng" / "Trạng thái cơ hội" / "Hạng doanh thu"
const List<String> kWebMenuAdminOnlySettings = <String>['admin'];

/// System — "Barem công việc"
const List<String> kWebMenuServiceWorkflows = <String>[
  'admin',
  'administrator',
  'quan_ly',
  'nhan_vien',
];

/// System — "Nhật ký hệ thống"
const List<String> kWebMenuActivityLogs = <String>['admin', 'quan_ly'];


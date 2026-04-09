// Khớp middleware role trên web/routes/api.php (nhóm auth).

/// Kiểm tra role khớp danh sách API (chuỗi tuyệt đối, không merge role).
bool apiRoleMatches(String? role, List<String> apiRoles) {
  final String r = (role ?? '').toString();
  return apiRoles.contains(r);
}

// --- CRM (api.php ~279–300) ---
/// POST/PUT /crm/clients
const List<String> kApiCrmClientWrite = <String>[
  'admin',
  'quan_ly',
  'nhan_vien',
];

/// DELETE /crm/clients/{client}
const List<String> kApiCrmClientDelete = <String>['admin'];

/// POST/PUT /crm/payments
const List<String> kApiCrmPaymentWrite = <String>['admin', 'ke_toan'];

/// DELETE /crm/payments/{payment}
const List<String> kApiCrmPaymentDelete = <String>['admin'];

// --- Hợp đồng (api.php ~302–332) ---
/// GET/POST /contracts
const List<String> kApiContractReadCreate = <String>[
  'admin',
  'administrator',
  'quan_ly',
  'nhan_vien',
  'ke_toan',
];

/// PUT/DELETE /contracts/{contract}
const List<String> kApiContractUpdateDelete = <String>[
  'admin',
  'administrator',
  'quan_ly',
  'ke_toan',
];

/// POST /contracts/{contract}/approve
const List<String> kApiContractApprove = <String>[
  'admin',
  'administrator',
  'ke_toan',
];

/// POST /contracts/{contract}/payments — thêm dòng thu
const List<String> kApiContractPaymentLineCreate = <String>[
  'admin',
  'administrator',
  'quan_ly',
  'nhan_vien',
  'ke_toan',
];

/// PUT/DELETE /contracts/{contract}/payments/{payment}
const List<String> kApiContractPaymentLineMutate = <String>[
  'admin',
  'administrator',
  'ke_toan',
];

/// POST /contracts/{contract}/costs — thêm dòng chi
const List<String> kApiContractCostLineCreate = <String>[
  'admin',
  'administrator',
  'quan_ly',
  'nhan_vien',
  'ke_toan',
];

/// PUT/DELETE /contracts/{contract}/costs/{cost}
const List<String> kApiContractCostLineMutate = <String>[
  'admin',
  'administrator',
  'ke_toan',
];

// --- Cơ hội (api.php ~340–348) ---
const List<String> kApiOpportunityReadWrite = <String>[
  'admin',
  'quan_ly',
  'nhan_vien',
];

const List<String> kApiOpportunityDelete = <String>['admin'];

// --- Sản phẩm (api.php ~359–374) ---
/// POST/PUT sản phẩm
const List<String> kApiProductMutate = <String>['admin', 'ke_toan'];

/// DELETE sản phẩm
const List<String> kApiProductDelete = <String>['admin'];

// --- Lịch họp (api.php ~271–277) — GET không middleware
const List<String> kApiMeetingManage = <String>['admin', 'quan_ly'];

const List<String> kApiMeetingDelete = <String>['admin'];

// --- Dự án — POST /projects (khớp ProjectController + ProjectsKanban web) ---
const List<String> kApiProjectStore = <String>[
  'admin',
  'administrator',
  'quan_ly',
];

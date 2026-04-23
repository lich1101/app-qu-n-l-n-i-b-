import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../../config/app_env.dart';
import '../messaging/app_tag_message.dart';
import '../auth/api_role_access.dart';
import '../../data/services/mobile_api_service.dart';
import '../../features/modules/client_detail_screen.dart';
import '../../features/modules/client_staff_transfer_screen.dart';
import '../../features/modules/chat_screen.dart';
import '../../features/modules/attendance_wifi_screen.dart';
import '../../features/modules/contracts_screen.dart';
import '../../features/modules/meetings_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/tasks/task_detail_screen.dart';
import '../../features/tasks/task_item_detail_screen.dart';
import '../../features/modules/opportunities_screen.dart';
import '../../features/modules/opportunity_detail_screen.dart';
import '../../features/modules/notifications_screen.dart';
import '../../features/modules/products_screen.dart';

class NotificationRouter {
  static Future<void> routeMessage(
    BuildContext context,
    RemoteMessage message, {
    required String token,
    required MobileApiService apiService,
    int? currentUserId,
    String? currentUserRole,
  }) async {
    await routePayload(
      context,
      message.data,
      token: token,
      apiService: apiService,
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
    );
  }

  static Future<void> routePayload(
    BuildContext context,
    Map<String, dynamic> payload, {
    required String token,
    required MobileApiService apiService,
    int? currentUserId,
    String? currentUserRole,
  }) async {
    final Map<String, dynamic> data = _normalizePayload(payload);
    final type = (data['type'] ?? '').toString().toLowerCase();

    final clientId = _extractInt(data, 'client_id');
    final taskId = _extractInt(data, 'task_id');
    final projectId = _extractInt(data, 'project_id');
    final contractId = _extractInt(data, 'contract_id');
    final contractFinanceRequestId = _extractInt(
      data,
      'contract_finance_request_id',
    );
    final taskItemId = _extractInt(data, 'task_item_id');
    final taskItemUpdateId = _extractInt(data, 'task_item_update_id');
    final opportunityId = _extractInt(data, 'opportunity_id');
    final meetingId = _extractInt(data, 'meeting_id');
    final productId = _extractInt(data, 'product_id');
    final transferId = _extractInt(data, 'transfer_id');
    final bool isOpportunityNotification =
        _isOpportunityType(type) ||
        (opportunityId != null && opportunityId > 0);

    debugPrint('[NotificationRouter] Routing type=$type data=$data');

    Widget? screen;
    String? missingMessage;
    final String role = (currentUserRole ?? '').toLowerCase();

    final bool isClientNotification = _isClientNotificationType(type);

    if (type == 'staff_transfer_request' &&
        transferId != null &&
        transferId > 0) {
      screen = ClientStaffTransferScreen(
        token: token,
        apiService: apiService,
        transferId: transferId,
        currentUserId: currentUserId,
      );
    } else if (isOpportunityNotification) {
      if (opportunityId != null && opportunityId > 0) {
        final opportunity = await apiService.getOpportunityDetail(
          token,
          opportunityId,
        );
        if (opportunity == null || opportunity.isEmpty) {
          missingMessage = 'Cơ hội không tồn tại.';
        } else {
          screen = OpportunityDetailScreen(
            token: token,
            apiService: apiService,
            opportunityId: opportunityId,
            canManage: apiRoleMatches(role, kApiOpportunityReadWrite),
            canDelete: apiRoleMatches(role, kApiOpportunityDelete),
          );
        }
      } else {
        screen = OpportunitiesScreen(
          token: token,
          apiService: apiService,
          canManage: apiRoleMatches(role, kApiOpportunityReadWrite),
          canDelete: apiRoleMatches(role, kApiOpportunityDelete),
        );
      }
    } else if (isClientNotification) {
      if (clientId == null || clientId <= 0) {
        missingMessage = 'Khách hàng không tồn tại.';
      } else if (await _clientExists(apiService, token, clientId)) {
        screen = ClientDetailScreen(
          token: token,
          apiService: apiService,
          clientId: clientId,
          currentUserId: currentUserId,
        );
      } else {
        missingMessage = 'Khách hàng không tồn tại.';
      }
    } else if (_isTaskChatType(type)) {
      if (taskId != null && taskId > 0) {
        final task = await apiService.getTaskDetail(token, taskId);
        if (task != null && task.isNotEmpty) {
          screen = ChatDetailScreen(
            token: token,
            apiService: apiService,
            task: task,
            currentUserId: currentUserId,
          );
        } else {
          missingMessage = 'Công việc không tồn tại.';
        }
      } else {
        missingMessage = 'Công việc không tồn tại.';
      }
    } else if (type.contains('attendance')) {
      screen = AttendanceWifiScreen(
        token: token,
        apiService: apiService,
        currentUserRole: currentUserRole ?? '',
      );
    } else if (type.startsWith('meeting_') ||
        (meetingId != null && meetingId > 0)) {
      screen = MeetingsScreen(
        token: token,
        apiService: apiService,
        canManage: apiRoleMatches(role, kApiMeetingManage),
        canDelete: apiRoleMatches(role, kApiMeetingDelete),
        initialMeetingId: meetingId,
      );
    } else if (_isContractDeepLinkType(type)) {
      if (contractId != null &&
          contractId > 0 &&
          !await _contractExists(apiService, token, contractId)) {
        missingMessage = 'Hợp đồng không tồn tại.';
      }

      if (missingMessage == null) {
        final bool focusPendingContractApproval = type == 'contract_approval';
        screen = ContractsScreen(
          token: token,
          apiService: apiService,
          canManage: apiRoleMatches(role, kApiContractUpdateDelete),
          canCreate: apiRoleMatches(role, kApiContractReadCreate),
          canDelete: false,
          canApprove: apiRoleMatches(role, kApiContractApprove),
          canCreateContractFinanceLines: apiRoleMatches(
            role,
            kApiContractPaymentLineCreate,
          ),
          canEditContractFinanceLines: apiRoleMatches(
            role,
            kApiContractPaymentLineMutate,
          ),
          currentUserRole: role,
          currentUserId: currentUserId,
          initialContractId: contractId,
          initialFinanceRequestId: contractFinanceRequestId,
          initialFocusPendingContractApproval: focusPendingContractApproval,
        );
      }
    } else if (type.contains('project') || type.contains('handover')) {
      if (projectId != null && projectId > 0) {
        if (await _projectExists(apiService, token, projectId)) {
          screen = ProjectDetailScreen(
            token: token,
            apiService: apiService,
            projectId: projectId,
          );
        } else {
          missingMessage = 'Dự án không tồn tại.';
        }
      } else {
        screen = ProjectsScreen(
          token: token,
          apiService: apiService,
          canCreate: apiRoleMatches(role, kApiProjectStore),
        );
      }
    } else if (type == 'lead_form' || _isLeadFormSettingsType(type)) {
      await _openLeadFormWeb(context);
      return;
    } else if (type == 'product' || type.startsWith('product_')) {
      screen = ProductsScreen(
        token: token,
        apiService: apiService,
        canManage: apiRoleMatches(role, kApiProductMutate),
        canDelete: apiRoleMatches(role, kApiProductDelete),
        initialProductId: productId,
      );
    } else if (_isTaskItemType(type)) {
      int? resolvedTaskId = taskId;
      if (taskItemId != null && taskItemId > 0) {
        final Map<String, dynamic>? itemDetail = await apiService
            .getTaskItemDetail(token, taskItemId);
        if (itemDetail != null && itemDetail.isNotEmpty) {
          resolvedTaskId ??= _extractInt(itemDetail, 'task_id');
          if (resolvedTaskId != null && resolvedTaskId > 0) {
            screen = TaskItemDetailScreen(
              token: token,
              apiService: apiService,
              taskId: resolvedTaskId,
              itemId: taskItemId,
              initialUpdateId: taskItemUpdateId,
            );
          }
        }
      }

      if (screen == null && taskId != null && taskId > 0) {
        if (await _taskExists(apiService, token, taskId)) {
          screen = TaskDetailScreen(
            token: token,
            apiService: apiService,
            taskId: taskId,
          );
        }
      }

      if (screen == null) {
        missingMessage = 'Đầu việc không tồn tại.';
      }
    } else if (_isTaskType(type)) {
      if (taskId != null && taskId > 0) {
        if (await _taskExists(apiService, token, taskId)) {
          screen = TaskDetailScreen(
            token: token,
            apiService: apiService,
            taskId: taskId,
          );
        } else {
          missingMessage = 'Công việc không tồn tại.';
        }
      } else {
        missingMessage = 'Công việc không tồn tại.';
      }
    }

    if (!context.mounted) return;
    if (missingMessage != null) {
      _showMissingMessage(context, missingMessage);
      return;
    }

    screen ??= NotificationsScreen(
      token: token,
      apiService: apiService,
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
    );

    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
  }

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> normalized = <String, dynamic>{...payload};
    final dynamic nested = normalized['data'];
    if (nested is Map<String, dynamic>) {
      normalized.addAll(nested);
    } else if (nested is Map) {
      normalized.addAll(nested.cast<String, dynamic>());
    } else if (nested is String && nested.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(nested);
        if (decoded is Map<String, dynamic>) {
          normalized.addAll(decoded);
        } else if (decoded is Map) {
          normalized.addAll(decoded.cast<String, dynamic>());
        }
      } catch (_) {
        // Ignore malformed JSON payload.
      }
    }
    return normalized;
  }

  static int? _extractInt(Map<String, dynamic> data, String key) {
    final val = data[key];
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  static bool _isClientNotificationType(String type) {
    return type == 'facebook_lead' ||
        type == 'new_client' ||
        type == 'client_form_lead' ||
        type == 'crm_new_lead' ||
        type == 'lead_form_new_lead' ||
        type == 'crm_phone_duplicate_merged' ||
        type.startsWith('crm_client_');
  }

  /// lead_form_new_lead → màn khách (CRM); còn lại lead_form_* → cấu hình form.
  static bool _isLeadFormSettingsType(String type) {
    if (type == 'lead_form') {
      return true;
    }
    if (!type.startsWith('lead_form_')) {
      return false;
    }
    return type != 'lead_form_new_lead';
  }

  /// Push hợp đồng / phiếu tài chính — không dùng chung `contains('contract')` để tránh nhầm type khác.
  static bool _isContractDeepLinkType(String type) {
    if (type.isEmpty) {
      return false;
    }
    return type == 'contract_approval' ||
        type.startsWith('contract_finance_') ||
        type == 'contract_finance_request_pending' ||
        type == 'contract_finance_request_pending_payment' ||
        type == 'contract_finance_request_pending_cost' ||
        type.startsWith('contract_unpaid') ||
        type.startsWith('contract_expiry');
  }

  static bool _isTaskChatType(String type) {
    return type == 'task_chat_message' ||
        type == 'task_comment_tag' ||
        type == 'attention';
  }

  static bool _isTaskItemType(String type) {
    return type == 'task_item_update_pending' ||
        type == 'task_item_update_feedback' ||
        type == 'task_item_assigned' ||
        type == 'task_item_progress_late';
  }

  static bool _isTaskType(String type) {
    return type == 'task_assigned' ||
        type == 'task_update_pending' ||
        type == 'task_update_feedback' ||
        type == 'deadline_reminder';
  }

  static bool _isOpportunityType(String type) {
    return type == 'new_opportunity' ||
        type == 'opportunity_due_reminder' ||
        type == 'crm_notification' ||
        type == 'crm_client_opportunity_created' ||
        type.contains('opportunity');
  }

  static Future<bool> _clientExists(
    MobileApiService apiService,
    String token,
    int clientId,
  ) async {
    final data = await apiService.getClientFlow(token, clientId);
    if (data.isEmpty) return false;
    final dynamic client = data['client'];
    if (client is Map<String, dynamic>) {
      return _extractInt(client, 'id') == clientId;
    }
    if (client is Map) {
      final Map<String, dynamic> casted = client.cast<String, dynamic>();
      return _extractInt(casted, 'id') == clientId;
    }
    return false;
  }

  static Future<bool> _contractExists(
    MobileApiService apiService,
    String token,
    int contractId,
  ) async {
    final data = await apiService.getContractDetail(token, contractId);
    if (data.isEmpty) return false;
    return _extractInt(data, 'id') == contractId;
  }

  static Future<bool> _projectExists(
    MobileApiService apiService,
    String token,
    int projectId,
  ) async {
    final data = await apiService.getProject(token, projectId);
    if (data == null || data.isEmpty) return false;
    return _extractInt(data, 'id') == projectId;
  }

  static Future<bool> _taskExists(
    MobileApiService apiService,
    String token,
    int taskId,
  ) async {
    final data = await apiService.getTaskDetail(token, taskId);
    if (data == null || data.isEmpty) return false;
    return _extractInt(data, 'id') == taskId;
  }

  static void _showMissingMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    AppTagMessage.hide();
    AppTagMessage.show(message);
  }

  /// Cấu hình form chỉ trên web — mở `/form-tu-van`.
  static Future<void> _openLeadFormWeb(BuildContext context) async {
    final String base = AppEnv.webBaseUrl.replaceAll(RegExp(r'/$'), '');
    final Uri uri = Uri.parse('$base/form-tu-van');
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showMissingMessage(
          context,
          'Không thể mở trình duyệt. Hãy cấu hình form tư vấn trên web.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showMissingMessage(
          context,
          'Không thể mở trang form tư vấn trên web.',
        );
      }
    }
  }
}

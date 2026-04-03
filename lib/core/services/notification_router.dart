import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../data/services/mobile_api_service.dart';
import '../../features/modules/client_detail_screen.dart';
import '../../features/modules/chat_screen.dart';
import '../../features/modules/attendance_wifi_screen.dart';
import '../../features/modules/contracts_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/tasks/task_detail_screen.dart';
import '../../features/tasks/task_item_detail_screen.dart';
import '../../features/modules/opportunities_screen.dart';
import '../../features/modules/notifications_screen.dart';

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
    final taskItemId = _extractInt(data, 'task_item_id');
    final taskItemUpdateId = _extractInt(data, 'task_item_update_id');

    debugPrint('[NotificationRouter] Routing type=$type data=$data');

    Widget? screen;

    final bool isClientNotification =
        type == 'facebook_lead' ||
        type == 'new_client' ||
        type == 'client_form_lead' ||
        type == 'crm_new_lead' ||
        type.startsWith('crm_client_');

    if (isClientNotification) {
      if (clientId != null && clientId > 0) {
        screen = ClientDetailScreen(
          token: token,
          apiService: apiService,
          clientId: clientId,
          currentUserId: currentUserId,
        );
      }
    } else if (type == 'task_chat_message' ||
        type == 'task_comment_tag' ||
        type == 'attention') {
      if (taskId != null && taskId > 0) {
        final task = await apiService.getTaskDetail(token, taskId);
        if (task != null && task.isNotEmpty) {
          screen = ChatDetailScreen(
            token: token,
            apiService: apiService,
            task: task,
            currentUserId: currentUserId,
          );
        }
      }
    } else if (type.contains('attendance')) {
      screen = AttendanceWifiScreen(
        token: token,
        apiService: apiService,
        currentUserRole: currentUserRole ?? '',
      );
    } else if (type == 'contract_approval' || type.contains('contract')) {
      final String role = currentUserRole ?? '';
      screen = ContractsScreen(
        token: token,
        apiService: apiService,
        canManage: ['admin', 'quan_ly', 'ke_toan'].contains(role),
        canCreate: ['admin', 'quan_ly', 'nhan_vien', 'ke_toan'].contains(role),
        canDelete: ['admin', 'quan_ly', 'ke_toan'].contains(role),
        canApprove: ['admin', 'ke_toan'].contains(role),
        currentUserRole: role,
        currentUserId: currentUserId,
      );
    } else if (type.contains('project') || type.contains('handover')) {
      final String role = currentUserRole ?? '';
      if (projectId != null && projectId > 0) {
        screen = ProjectDetailScreen(
          token: token,
          apiService: apiService,
          projectId: projectId,
        );
      } else {
        screen = ProjectsScreen(
          token: token,
          apiService: apiService,
          canCreate: ['admin', 'quan_ly'].contains(role),
        );
      }
    } else if (type == 'task_assigned' ||
        type == 'task_update_pending' ||
        type == 'task_update_feedback' ||
        type == 'task_item_assigned' ||
        type == 'deadline_reminder') {
      if (taskId != null && taskId > 0) {
        screen = TaskDetailScreen(
          token: token,
          apiService: apiService,
          taskId: taskId,
        );
      }
    } else if (type == 'task_item_update_pending' ||
        type == 'task_item_update_feedback') {
      if (taskId != null &&
          taskId > 0 &&
          taskItemId != null &&
          taskItemId > 0) {
        screen = TaskItemDetailScreen(
          token: token,
          apiService: apiService,
          taskId: taskId,
          itemId: taskItemId,
          initialUpdateId: taskItemUpdateId,
        );
      } else if (taskId != null && taskId > 0) {
        screen = TaskDetailScreen(
          token: token,
          apiService: apiService,
          taskId: taskId,
        );
      }
    } else if (type == 'new_opportunity') {
      final String role = currentUserRole ?? '';
      screen = OpportunitiesScreen(
        token: token,
        apiService: apiService,
        canManage: ['admin', 'quan_ly', 'nhan_vien'].contains(role),
        canDelete: ['admin'].contains(role),
      );
    }

    screen ??= NotificationsScreen(
      token: token,
      apiService: apiService,
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
    );

    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
    }
  }

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> normalized = <String, dynamic>{...payload};
    final dynamic nested = normalized['data'];
    if (nested is Map<String, dynamic>) {
      normalized.addAll(nested);
    } else if (nested is Map) {
      normalized.addAll(nested.cast<String, dynamic>());
    }
    return normalized;
  }

  static int? _extractInt(Map<String, dynamic> data, String key) {
    final val = data[key];
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }
}

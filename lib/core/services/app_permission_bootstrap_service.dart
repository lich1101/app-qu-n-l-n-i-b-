import 'package:firebase_messaging/firebase_messaging.dart';

import 'app_firebase.dart';
import 'attendance_wifi_service.dart';

class AppPermissionBootstrapState {
  const AppPermissionBootstrapState({
    required this.wifiPermission,
    required this.notificationStatus,
    required this.notificationsSupported,
  });

  final AttendanceWifiPermissionState wifiPermission;
  final AuthorizationStatus notificationStatus;
  final bool notificationsSupported;

  bool get wifiGranted => wifiPermission.permissionGranted;

  bool get notificationsGranted {
    if (!notificationsSupported) return true;
    return notificationStatus == AuthorizationStatus.authorized ||
        notificationStatus == AuthorizationStatus.provisional;
  }

  bool get allGranted => wifiGranted && notificationsGranted;

  bool get needsSettingsAttention {
    if (wifiPermission.requiresSettings) return true;
    if (!notificationsSupported) return false;
    return notificationStatus == AuthorizationStatus.denied;
  }
}

class AppPermissionBootstrapService {
  static Future<AppPermissionBootstrapState> checkStatus() async {
    final AttendanceWifiPermissionState wifiPermission =
        await AttendanceWifiService.checkPermissionStatus();

    final bool notificationsSupported = AppFirebase.isConfigured;
    final AuthorizationStatus notificationStatus =
        notificationsSupported
            ? await AppFirebase.notificationAuthorizationStatus()
            : AuthorizationStatus.authorized;

    return AppPermissionBootstrapState(
      wifiPermission: wifiPermission,
      notificationStatus: notificationStatus,
      notificationsSupported: notificationsSupported,
    );
  }

  static Future<AppPermissionBootstrapState>
  requestEssentialPermissions() async {
    await AttendanceWifiService.requestPermission();
    if (AppFirebase.isConfigured) {
      await AppFirebase.requestNotificationPermission();
    }
    return checkStatus();
  }
}

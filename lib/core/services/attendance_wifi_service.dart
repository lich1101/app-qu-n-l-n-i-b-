import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendanceWifiPermissionState {
  const AttendanceWifiPermissionState({
    required this.locationStatus,
    required this.nearbyWifiStatus,
    required this.permissionGranted,
  });

  final PermissionStatus locationStatus;
  final PermissionStatus nearbyWifiStatus;
  final bool permissionGranted;

  bool get requiresSettings =>
      locationStatus.isPermanentlyDenied ||
      nearbyWifiStatus.isPermanentlyDenied;
}

class AttendanceWifiSnapshot {
  const AttendanceWifiSnapshot({
    required this.permissionGranted,
    this.ssid,
    this.bssid,
    this.error,
  });

  final bool permissionGranted;
  final String? ssid;
  final String? bssid;
  final String? error;

  bool get hasWifi => ssid != null && ssid!.isNotEmpty;
}

class AttendanceWifiService {
  static Future<AttendanceWifiSnapshot> readCurrentWifi({
    bool requestPermissions = true,
  }) async {
    final AttendanceWifiPermissionState permissionState =
        requestPermissions
            ? await requestPermission()
            : await checkPermissionStatus();
    if (!permissionState.permissionGranted) {
      return const AttendanceWifiSnapshot(
        permissionGranted: false,
        error:
            'Trên iPhone, cần cấp quyền Vị trí để ứng dụng đọc SSID và BSSID.',
      );
    }

    final NetworkInfo networkInfo = NetworkInfo();
    final String? ssid = _sanitize(await networkInfo.getWifiName());
    final String? bssid = _sanitize(await networkInfo.getWifiBSSID());

    if (ssid == null || ssid.isEmpty) {
      return const AttendanceWifiSnapshot(
        permissionGranted: true,
        error: 'Không tìm thấy Wi-Fi đang kết nối.',
      );
    }

    return AttendanceWifiSnapshot(
      permissionGranted: true,
      ssid: ssid,
      bssid: bssid?.toLowerCase(),
    );
  }

  static Future<AttendanceWifiPermissionState> checkPermissionStatus() {
    return _resolvePermissionState(requestPermissions: false);
  }

  static Future<AttendanceWifiPermissionState> requestPermission() {
    return _resolvePermissionState(requestPermissions: true);
  }

  static Future<AttendanceWifiPermissionState> _resolvePermissionState({
    required bool requestPermissions,
  }) async {
    final PermissionStatus locationStatus =
        requestPermissions
            ? await Permission.locationWhenInUse.request()
            : await Permission.locationWhenInUse.status;
    final PermissionStatus nearbyWifiStatus =
        Platform.isAndroid
            ? requestPermissions
                ? await Permission.nearbyWifiDevices.request()
                : await Permission.nearbyWifiDevices.status
            : PermissionStatus.granted;
    final bool locationGranted =
        locationStatus.isGranted || locationStatus.isLimited;
    final bool nearbyGranted =
        Platform.isAndroid &&
        (nearbyWifiStatus.isGranted || nearbyWifiStatus.isLimited);

    return AttendanceWifiPermissionState(
      locationStatus: locationStatus,
      nearbyWifiStatus: nearbyWifiStatus,
      permissionGranted: locationGranted || nearbyGranted,
    );
  }

  static String? _sanitize(String? value) {
    if (value == null) return null;
    final String cleaned = value.replaceAll('"', '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}

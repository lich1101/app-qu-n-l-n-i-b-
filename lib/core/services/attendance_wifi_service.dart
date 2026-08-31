import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendanceWifiPermissionState {
  const AttendanceWifiPermissionState({
    required this.locationStatus,
    required this.locationServiceStatus,
    required this.nearbyWifiStatus,
    required this.permissionGranted,
  });

  final PermissionStatus locationStatus;
  final ServiceStatus locationServiceStatus;
  final PermissionStatus nearbyWifiStatus;
  final bool permissionGranted;

  bool get locationPermissionGranted =>
      locationStatus.isGranted || locationStatus.isLimited;

  bool get locationServiceEnabled =>
      locationServiceStatus.isEnabled || locationServiceStatus.isNotApplicable;

  bool get nearbyWifiBlocked =>
      Platform.isAndroid &&
      (nearbyWifiStatus.isDenied ||
          nearbyWifiStatus.isPermanentlyDenied ||
          nearbyWifiStatus.isRestricted);

  bool get requiresSettings =>
      locationStatus.isPermanentlyDenied ||
      (Platform.isAndroid && nearbyWifiStatus.isPermanentlyDenied);

  String get blockingMessage {
    if (!locationPermissionGranted) {
      return requiresSettings
          ? 'Quyền Vị trí đang bị chặn. Vui lòng mở Cài đặt, cấp quyền Vị trí cho ứng dụng rồi thử lại.'
          : 'Ứng dụng cần quyền Vị trí để đọc SSID/BSSID khi chấm công Wi‑Fi.';
    }
    if (!locationServiceEnabled) {
      return 'Máy đang tắt Dịch vụ vị trí/GPS. Vui lòng bật Vị trí rồi mở lại app để chấm công Wi‑Fi.';
    }
    if (nearbyWifiBlocked) {
      return requiresSettings
          ? 'Quyền Wi‑Fi lân cận đang bị chặn. Vui lòng mở Cài đặt và cấp quyền Thiết bị lân cận/Wi‑Fi lân cận cho ứng dụng.'
          : 'Vui lòng cấp quyền Thiết bị lân cận/Wi‑Fi lân cận nếu Android yêu cầu để app đọc Wi‑Fi hiện tại.';
    }
    return 'Ứng dụng chưa đủ quyền để đọc Wi‑Fi hiện tại.';
  }
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
  static const int _readAttemptCount = 4;
  static const Duration _readRetryDelay = Duration(milliseconds: 350);

  static Future<AttendanceWifiSnapshot> readCurrentWifi({
    bool requestPermissions = true,
  }) async {
    final AttendanceWifiPermissionState permissionState =
        requestPermissions
            ? await requestPermission()
            : await checkPermissionStatus();
    if (!permissionState.permissionGranted) {
      return AttendanceWifiSnapshot(
        permissionGranted: false,
        error: permissionState.blockingMessage,
      );
    }

    final NetworkInfo networkInfo = NetworkInfo();
    Object? lastReadError;

    for (int attempt = 0; attempt < _readAttemptCount; attempt += 1) {
      try {
        final String? ssid = _sanitizeSsid(await networkInfo.getWifiName());
        final String? bssid = _sanitizeBssid(await networkInfo.getWifiBSSID());

        if (ssid != null && ssid.isNotEmpty) {
          return AttendanceWifiSnapshot(
            permissionGranted: true,
            ssid: ssid,
            bssid: bssid,
          );
        }
      } catch (error) {
        lastReadError = error;
      }

      if (attempt < _readAttemptCount - 1) {
        await Future<void>.delayed(_readRetryDelay * (attempt + 1));
      }
    }

    return AttendanceWifiSnapshot(
      permissionGranted: true,
      error: _wifiUnavailableMessage(permissionState, lastReadError),
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
    final ServiceStatus locationServiceStatus = await _locationServiceStatus();
    final PermissionStatus nearbyWifiStatus =
        Platform.isAndroid
            ? requestPermissions
                ? await Permission.nearbyWifiDevices.request()
                : await Permission.nearbyWifiDevices.status
            : PermissionStatus.granted;
    final bool locationGranted =
        locationStatus.isGranted || locationStatus.isLimited;
    final bool locationServiceEnabled =
        locationServiceStatus.isEnabled ||
        locationServiceStatus.isNotApplicable;
    // Reading current SSID/BSSID requires location permission on mobile.
    // Android also requires the system Location/GPS service to be turned on.
    // Nearby Wi‑Fi permission is requested for Android 13+ compatibility, but
    // older devices may report it as denied/not applicable, so location remains
    // the hard gate before attempting to read the current connected network.
    final bool permissionGranted = locationGranted && locationServiceEnabled;

    return AttendanceWifiPermissionState(
      locationStatus: locationStatus,
      locationServiceStatus: locationServiceStatus,
      nearbyWifiStatus: nearbyWifiStatus,
      permissionGranted: permissionGranted,
    );
  }

  static Future<ServiceStatus> _locationServiceStatus() async {
    try {
      return await Permission.locationWhenInUse.serviceStatus;
    } catch (_) {
      return ServiceStatus.notApplicable;
    }
  }

  static String? _sanitizeSsid(String? value) {
    if (value == null) return null;
    final String cleaned = value.replaceAll('"', '').trim();
    final String normalized = cleaned.toLowerCase();
    if (normalized == '<unknown ssid>' || normalized == 'unknown ssid') {
      return null;
    }
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? _sanitizeBssid(String? value) {
    if (value == null) return null;
    final String cleaned = value.replaceAll('"', '').trim().toLowerCase();
    if (cleaned.isEmpty ||
        cleaned == '00:00:00:00:00:00' ||
        cleaned == '02:00:00:00:00:00') {
      return null;
    }
    return cleaned;
  }

  static String _wifiUnavailableMessage(
    AttendanceWifiPermissionState permissionState,
    Object? lastReadError,
  ) {
    if (lastReadError != null) {
      return 'Không đọc được Wi‑Fi hiện tại từ thiết bị. Vui lòng bật Wi‑Fi, bật Vị trí/GPS rồi thử lại.';
    }
    if (!permissionState.locationServiceEnabled) {
      return permissionState.blockingMessage;
    }
    if (Platform.isIOS) {
      return 'Không đọc được Wi‑Fi hiện tại. Hãy dùng thiết bị iPhone thật, bật Wi‑Fi, bật Vị trí chính xác cho ứng dụng rồi thử lại.';
    }
    if (Platform.isAndroid) {
      if (permissionState.nearbyWifiBlocked) {
        return 'Không đọc được Wi‑Fi hiện tại. Hãy bật Wi‑Fi + Vị trí/GPS; nếu Android hỏi quyền Thiết bị lân cận/Wi‑Fi lân cận thì cấp quyền rồi thử lại.';
      }
      return 'Không đọc được Wi‑Fi hiện tại. Hãy bật Wi‑Fi và Vị trí/GPS rồi thử lại.';
    }
    return 'Không tìm thấy Wi‑Fi đang kết nối.';
  }
}

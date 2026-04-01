import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

class AttendanceDeviceIdentity {
  const AttendanceDeviceIdentity({
    required this.deviceUuid,
    required this.deviceName,
    required this.devicePlatform,
    required this.deviceModel,
  });

  final String deviceUuid;
  final String deviceName;
  final String devicePlatform;
  final String deviceModel;

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'device_platform': devicePlatform,
      'device_model': deviceModel,
    };
  }
}

class AttendanceDeviceIdentityService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _deviceUuidKey = 'attendance_device_uuid';
  static const MethodChannel _channel = MethodChannel(
    'vn.clickon.jobnew/device_identity',
  );

  static Future<AttendanceDeviceIdentity> resolve() async {
    final String deviceUuid = await _getOrCreateDeviceUuid();
    final String platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
            ? 'android'
            : Platform.operatingSystem;
    final String deviceName = Platform.isIOS
        ? 'iPhone cá nhân'
        : Platform.isAndroid
            ? 'Android cá nhân'
            : 'Thiết bị cá nhân';
    final String deviceModel =
        Platform.operatingSystemVersion.replaceAll('\n', ' ').trim();

    return AttendanceDeviceIdentity(
      deviceUuid: deviceUuid,
      deviceName: deviceName,
      devicePlatform: platform,
      deviceModel: deviceModel,
    );
  }

  static Future<String> _getOrCreateDeviceUuid() async {
    final String? nativeDeviceUuid = await _readNativeDeviceUuid();
    if (nativeDeviceUuid != null && nativeDeviceUuid.trim().isNotEmpty) {
      await _storage.write(key: _deviceUuidKey, value: nativeDeviceUuid);
      return nativeDeviceUuid;
    }

    final String? existing = await _storage.read(key: _deviceUuidKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final Random random = Random.secure();
    final String millis =
        DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final String seed = List<String>.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    final String created = 'attendance-$millis-$seed';
    await _storage.write(key: _deviceUuidKey, value: created);
    return created;
  }

  static Future<String?> _readNativeDeviceUuid() async {
    try {
      final String? value = await _channel.invokeMethod<String>('getDeviceId');
      final String normalized = value?.trim() ?? '';
      if (normalized.isEmpty) return null;
      return normalized;
    } catch (_) {
      return null;
    }
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teso_internal_task_manager/core/services/attendance_wifi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int permissionGranted = 1;
  const int serviceDisabled = 0;
  const int serviceEnabled = 1;
  const MethodChannel permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const MethodChannel networkInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/network_info',
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(networkInfoChannel, null);
  });

  test('retry đọc Wi‑Fi khi platform trả null thoáng qua', () async {
    int wifiNameCalls = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
          switch (call.method) {
            case 'checkPermissionStatus':
              return permissionGranted;
            case 'checkServiceStatus':
              return serviceEnabled;
          }
          fail('Unexpected permission call: ${call.method}');
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(networkInfoChannel, (MethodCall call) async {
          switch (call.method) {
            case 'wifiName':
              wifiNameCalls += 1;
              return wifiNameCalls < 3 ? null : '"Office WiFi"';
            case 'wifiBSSID':
              return '02:00:00:00:00:00';
          }
          fail('Unexpected network info call: ${call.method}');
        });

    final AttendanceWifiSnapshot snapshot =
        await AttendanceWifiService.readCurrentWifi(requestPermissions: false);

    expect(snapshot.hasWifi, isTrue);
    expect(snapshot.ssid, 'Office WiFi');
    expect(snapshot.bssid, isNull);
    expect(wifiNameCalls, 3);
  });

  test('không đọc Wi‑Fi khi Dịch vụ vị trí/GPS đang tắt', () async {
    int networkReads = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
          switch (call.method) {
            case 'checkPermissionStatus':
              return permissionGranted;
            case 'checkServiceStatus':
              return serviceDisabled;
          }
          fail('Unexpected permission call: ${call.method}');
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(networkInfoChannel, (MethodCall call) async {
          networkReads += 1;
          return null;
        });

    final AttendanceWifiSnapshot snapshot =
        await AttendanceWifiService.readCurrentWifi(requestPermissions: false);

    expect(snapshot.permissionGranted, isFalse);
    expect(snapshot.hasWifi, isFalse);
    expect(snapshot.error, contains('Dịch vụ vị trí'));
    expect(networkReads, 0);
  });
}

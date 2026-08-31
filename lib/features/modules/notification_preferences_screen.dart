import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../config/app_env.dart';
import '../../core/messaging/app_tag_message.dart';
import '../../core/settings/app_settings.dart';
import '../../core/services/app_firebase.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/widgets/stitch_widgets.dart';
import '../../data/services/mobile_api_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({
    super.key,
    required this.token,
    required this.apiService,
    this.onSyncDeviceToken,
  });

  final String token;
  final MobileApiService apiService;
  final Future<Map<String, dynamic>> Function()? onSyncDeviceToken;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _notificationsEnabled = true;
  bool _categorySystemEnabled = true;
  bool _categoryCrmEnabled = true;
  AuthorizationStatus _authorizationStatus = AuthorizationStatus.notDetermined;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _osPermissionEnabled =>
      _authorizationStatus == AuthorizationStatus.authorized ||
      _authorizationStatus == AuthorizationStatus.provisional;

  Future<void> _load() async {
    setState(() => _loading = true);
    final Map<String, dynamic> settings = await widget.apiService
        .getNotificationPreferences(widget.token);
    AuthorizationStatus status = AuthorizationStatus.notDetermined;
    if (AppFirebase.isConfigured) {
      status = await AppFirebase.notificationAuthorizationStatus();
    }
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = settings['notifications_enabled'] != false;
      _categorySystemEnabled = settings['category_system_enabled'] != false;
      _categoryCrmEnabled = settings['category_crm_realtime_enabled'] != false;
      _authorizationStatus = status;
      _loading = false;
    });
  }

  Future<void> _save({
    bool? notificationsEnabled,
    bool? categorySystemEnabled,
    bool? categoryCrmRealtimeEnabled,
  }) async {
    setState(() => _saving = true);
    final Map<String, dynamic> res = await widget.apiService
        .updateNotificationPreferences(
          widget.token,
          notificationsEnabled: notificationsEnabled,
          categorySystemEnabled: categorySystemEnabled,
          categoryCrmRealtimeEnabled: categoryCrmRealtimeEnabled,
        );
    if (!mounted) return;
    if (res['error'] == true) {
      setState(() => _saving = false);
      AppTagMessage.show('Không thể lưu cài đặt thông báo.', isError: true);
      return;
    }
    setState(() {
      _notificationsEnabled = res['notifications_enabled'] != false;
      _categorySystemEnabled = res['category_system_enabled'] != false;
      _categoryCrmEnabled = res['category_crm_realtime_enabled'] != false;
      _saving = false;
    });
  }

  Future<void> _requestOsPermission() async {
    if (!AppFirebase.isConfigured) return;
    final bool granted = await AppFirebase.requestNotificationPermission();
    final bool syncOk = await _syncDeviceToken(showSuccessToast: false);
    final AuthorizationStatus status =
        await AppFirebase.notificationAuthorizationStatus();
    if (!mounted) return;
    setState(() => _authorizationStatus = status);
    if (!syncOk) {
      return;
    }
    AppTagMessage.show(
      granted
          ? 'Đã cấp quyền thông báo trên thiết bị.'
          : 'Hệ điều hành chưa cấp quyền thông báo.',
      isError: !granted,
    );
  }

  Future<bool> _syncDeviceToken({bool showSuccessToast = true}) async {
    if (widget.onSyncDeviceToken == null) {
      return false;
    }
    final Map<String, dynamic> result = await widget.onSyncDeviceToken!();
    if (AppFirebase.isConfigured) {
      final AuthorizationStatus status =
          await AppFirebase.notificationAuthorizationStatus();
      if (mounted) {
        setState(() => _authorizationStatus = status);
      }
    }
    if (!mounted) return false;
    final bool ok = result['ok'] == true;
    final String reason =
        (result['message'] ?? result['reason'] ?? result['status'] ?? '')
            .toString()
            .trim();
    if (!ok) {
      AppTagMessage.show(
        'Đồng bộ token thất bại${reason.isNotEmpty ? ': $reason' : ''}',
        isError: true,
      );
      return false;
    }
    if (!showSuccessToast) {
      return true;
    }
    AppTagMessage.show('Đã đồng bộ lại token thông báo.');
    return true;
  }

  String _authorizationLabel() {
    switch (_authorizationStatus) {
      case AuthorizationStatus.authorized:
        return 'Đã bật';
      case AuthorizationStatus.provisional:
        return 'Tạm thời';
      case AuthorizationStatus.denied:
        return 'Bị chặn';
      case AuthorizationStatus.notDetermined:
        return 'Chưa xác định';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String token = AppFirebase.lastPushToken ?? '';
    final String tokenLabel =
        token.isEmpty
            ? 'Chưa có token'
            : '${token.substring(0, token.length > 10 ? 10 : token.length)}...${token.substring(token.length > 8 ? token.length - 8 : 0)}';
    final String updatedAt =
        AppFirebase.lastPushTokenAt?.toLocal().toString() ?? '—';
    final String brand = appSettingsStore.settings.brandName;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý thông báo')),
      body: SafeArea(
        child:
            _loading
                ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: <Widget>[
                    const StitchLoadingState(
                      label: 'Đang tải cài đặt thông báo...',
                    ),
                  ],
                )
                : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: <Widget>[
                    StitchAdminHeader(
                      title: 'Quản lý thông báo',
                      subtitle:
                          'Kiểm soát quyền thiết bị, nhóm thông báo và trạng thái token nhận push.',
                      icon: Icons.notifications_active_outlined,
                      actionLabel:
                          !_osPermissionEnabled ? 'Xin quyền thông báo' : null,
                      onAction:
                          !_osPermissionEnabled ? _requestOsPermission : null,
                    ),
                    const SizedBox(height: 14),
                    StitchFilterCard(
                      title: brand,
                      subtitle: 'Quyền hệ điều hành: ${_authorizationLabel()}',
                      trailing: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'icon.png',
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          StitchStatusPill(
                            label:
                                _osPermissionEnabled
                                    ? 'Thiết bị đã cho phép'
                                    : 'Thiết bị chưa cho phép',
                            color:
                                _osPermissionEnabled
                                    ? StitchTheme.successStrong
                                    : StitchTheme.warningStrong,
                            icon:
                                _osPermissionEnabled
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_outlined,
                          ),
                          if (!_osPermissionEnabled) ...<Widget>[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _requestOsPermission,
                                icon: const Icon(
                                  Icons.notifications_active_outlined,
                                ),
                                label: const Text('Xin quyền thông báo'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    StitchFilterCard(
                      title: 'Kênh nhận thông báo',
                      subtitle:
                          'Bật/tắt toàn bộ thông báo hoặc từng nhóm nghiệp vụ quan trọng.',
                      child: Column(
                        children: <Widget>[
                          SwitchListTile.adaptive(
                            value: _notificationsEnabled,
                            title: const Text('Cho phép thông báo'),
                            subtitle: const Text(
                              'Tắt mục này sẽ chặn toàn bộ thông báo từ server.',
                              style: TextStyle(fontSize: 12),
                            ),
                            onChanged:
                                _saving
                                    ? null
                                    : (bool value) async {
                                      await _save(notificationsEnabled: value);
                                      if (value &&
                                          AppFirebase.isConfigured &&
                                          !_osPermissionEnabled) {
                                        await _requestOsPermission();
                                      }
                                      await _syncDeviceToken();
                                    },
                          ),
                          const Divider(height: 1, thickness: 1),
                          SwitchListTile.adaptive(
                            value: _categorySystemEnabled,
                            title: const Text('Thông báo hệ thống'),
                            subtitle: const Text(
                              'Nhắc deadline, đầu việc, lịch họp, chat công việc...',
                              style: TextStyle(fontSize: 12),
                            ),
                            onChanged:
                                (!_notificationsEnabled || _saving)
                                    ? null
                                    : (bool value) =>
                                        _save(categorySystemEnabled: value),
                          ),
                          const Divider(height: 1, thickness: 1),
                          SwitchListTile.adaptive(
                            value: _categoryCrmEnabled,
                            title: const Text('Thông báo realtime CRM'),
                            subtitle: const Text(
                              'Lead/hợp đồng và các thông báo realtime thuộc CRM.',
                              style: TextStyle(fontSize: 12),
                            ),
                            onChanged:
                                (!_notificationsEnabled || _saving)
                                    ? null
                                    : (bool value) => _save(
                                      categoryCrmRealtimeEnabled: value,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    StitchFilterCard(
                      title: 'Trạng thái thiết bị',
                      subtitle:
                          'Thông tin kỹ thuật phục vụ debug push notification.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Nền tảng: ${Platform.isIOS ? 'iOS' : 'Android'}',
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            'API: ${AppEnv.apiBaseUrl}',
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Token: $tokenLabel',
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cập nhật token: $updatedAt',
                            style: const TextStyle(
                              color: StitchTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _syncDeviceToken,
                              icon: const Icon(Icons.sync),
                              label: const Text('Đồng bộ token thiết bị'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

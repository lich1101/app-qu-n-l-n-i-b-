import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/auth/api_role_access.dart';
import '../../core/auth/web_menu_roles.dart';
import '../../config/app_env.dart';
import '../../core/services/app_firebase.dart';
import '../../core/services/app_permission_bootstrap_service.dart';
import '../../core/services/notification_router.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';
import '../auth/login_screen.dart';
import '../accounts/accounts_screen.dart';
import '../dashboard/overview_screen.dart';
import '../modules/crm_hub_screen.dart';
import '../modules/crm_screen.dart';
import '../modules/contracts_screen.dart';
import '../modules/handover_screen.dart';
import '../modules/chat_screen.dart';
import '../modules/activity_log_screen.dart';
import '../modules/attendance_wifi_screen.dart';
import '../modules/meetings_screen.dart';
import '../modules/module_center_screen.dart';
import '../modules/notifications_screen.dart';
import '../modules/reports_screen.dart';
import '../modules/services_screen.dart';
import '../modules/opportunities_screen.dart';
import '../modules/products_screen.dart';
import '../modules/revenue_report_screen.dart';
import '../modules/lead_types_screen.dart';
import '../modules/opportunity_statuses_screen.dart';
import '../modules/revenue_tiers_screen.dart';
import '../modules/departments_screen.dart';
import '../projects/create_project_screen.dart';
import '../projects/projects_screen.dart';
import '../tasks/task_items_screen.dart';
import '../tasks/tasks_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const Set<String> _chatNotificationTypes = <String>{
    'task_chat_message',
    'task_comment_tag',
  };
  final MobileApiService _api = MobileApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _tokenKey = 'noibo_auth_token';
  static const String _savedAccountsKey = 'noibo_saved_accounts';
  static const String _rememberKey = 'noibo_remember_account';
  int _tabIndex = 0;
  bool _isBootstrapDone = false;
  bool _isLoggingIn = false;

  Map<String, dynamic> overview = <String, dynamic>{};
  Map<String, dynamic> accounts = <String, dynamic>{};
  int unreadNotifications = 0;
  int unreadChats = 0;
  Map<String, dynamic>? authUser;
  String? authToken;
  String authMessage = '';
  List<String> savedAccounts = <String>[];
  bool rememberAccount = true;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  Timer? _sessionGuardTimer;
  bool _isCheckingSession = false;
  bool _permissionPromptQueued = false;
  bool _permissionPromptVisible = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  RemoteMessage? _pendingInitialMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedAccounts();
    _bootstrap();
    if (AppFirebase.isConfigured) {
      _setupPushNotificationInteractions();
      AppFirebase.ensureForegroundMessaging().then((_) {
        _foregroundSub?.cancel();
        _foregroundSub = AppFirebase.foregroundMessages.listen((_) async {
          await _refreshNotificationBadge();
        });
      });
    }
  }

  Future<void> _setupPushNotificationInteractions() async {
    if (!AppFirebase.isConfigured) return;

    // 1. Handle message when app is in background but still running
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handlePushNavigation(message);
    });

    // 2. Handle message when app was terminated
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _pendingInitialMessage = initialMessage;
    }
  }

  void _handlePushNavigation(RemoteMessage message) {
    if (authToken == null || authToken!.isEmpty) {
      _pendingInitialMessage = message;
      return;
    }

    final dynamic rawId = authUser?['id'];
    final int? currentUserId =
        rawId is int ? rawId : int.tryParse('${rawId ?? ''}');

    NotificationRouter.routeMessage(
      context,
      message,
      token: authToken!,
      apiService: _api,
      currentUserId: currentUserId,
      currentUserRole: (authUser?['role'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundSub?.cancel();
    _sessionGuardTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleAppResumed());
    }
  }

  Future<void> _handleAppResumed() async {
    await _validateActiveSession(silent: true);
    if (!mounted) return;
    if (authToken == null || authToken!.isEmpty) return;
    await _registerDeviceToken(requestPermission: false);
    _scheduleEssentialPermissionPrompt();
  }

  Duration get _bootstrapTimeout =>
      Duration(seconds: AppEnv.requestTimeoutSeconds);

  Future<void> _loadSavedAccounts() async {
    final String? raw = await _secureStorage.read(key: _savedAccountsKey);
    final String? rememberRaw = await _secureStorage.read(key: _rememberKey);
    final bool remember = rememberRaw == null ? true : rememberRaw == '1';
    List<String> accounts = <String>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        accounts = decoded.map((dynamic e) => e.toString()).toList();
      } catch (_) {
        accounts = <String>[];
      }
    }
    if (!mounted) return;
    setState(() {
      savedAccounts = accounts;
      rememberAccount = remember;
    });
  }

  Future<void> _persistSavedAccounts() async {
    final String raw = jsonEncode(savedAccounts);
    await _secureStorage.write(key: _savedAccountsKey, value: raw);
  }

  Future<void> _addSavedAccount(String email) async {
    if (!rememberAccount) return;
    final String normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final List<String> next = <String>{normalized, ...savedAccounts}.toList();
    if (!mounted) return;
    setState(() {
      savedAccounts = next.take(5).toList();
    });
    await _persistSavedAccounts();
  }

  Future<void> _removeSavedAccount(String email) async {
    final String normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final List<String> next =
        savedAccounts.where((String e) => e != normalized).toList();
    if (!mounted) return;
    setState(() {
      savedAccounts = next;
    });
    await _persistSavedAccounts();
  }

  Future<void> _toggleRemember(bool value) async {
    if (!mounted) return;
    setState(() => rememberAccount = value);
    await _secureStorage.write(key: _rememberKey, value: value ? '1' : '0');
  }

  void _selectSavedAccount(String email) {
    emailController.text = email;
  }

  Future<Map<String, dynamic>> _safeMap(
    Future<Map<String, dynamic>> future,
  ) async {
    try {
      return await future.timeout(_bootstrapTimeout);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _loadBootstrapPublicData() async {
    String bootstrapMessage = '';
    Map<String, dynamic> summary = <String, dynamic>{};
    Map<String, dynamic> accountSummary = <String, dynamic>{};
    Map<String, dynamic> settings = <String, dynamic>{};
    try {
      final List<Map<String, dynamic>> results =
          await Future.wait(<Future<Map<String, dynamic>>>[
            _safeMap(_api.getPublicSummary()),
            _safeMap(_api.getPublicAccountsSummary()),
            _safeMap(_api.getSettings()),
          ]);
      summary = results[0];
      accountSummary = results[1];
      settings = results[2];
    } catch (_) {
      bootstrapMessage =
          'Không thể kết nối máy chủ. Vui lòng kiểm tra API_BASE_URL.';
    }

    if (settings.isNotEmpty) {
      appSettingsStore.apply(AppSettingsData.fromJson(settings));
    }
    if (!mounted) return;
    setState(() {
      if (summary.isNotEmpty) {
        overview = summary;
      }
      if (accountSummary.isNotEmpty) {
        accounts = accountSummary;
      }
      if (bootstrapMessage.isNotEmpty && authMessage.isEmpty) {
        authMessage = bootstrapMessage;
      }
    });
  }

  Future<void> _finishRestoredSessionBootstrap(String token) async {
    try {
      final List<Map<String, dynamic>> summaryResults =
          await Future.wait(<Future<Map<String, dynamic>>>[
            _safeMap(_api.getPublicSummary(token)),
            _safeMap(_api.getPublicAccountsSummary(token)),
          ]);
      if (mounted) {
        setState(() {
          if (summaryResults[0].isNotEmpty) {
            overview = summaryResults[0];
          }
          if (summaryResults[1].isNotEmpty) {
            accounts = summaryResults[1];
          }
        });
      }
    } catch (_) {
      // Keep the shell responsive even if dashboard summaries are slow.
    }

    await _ensureFirebaseAuth();
    await _registerDeviceToken(requestPermission: false);
    await _refreshNotificationBadge();
    _scheduleEssentialPermissionPrompt();
    if (_pendingInitialMessage != null) {
      final msg = _pendingInitialMessage!;
      _pendingInitialMessage = null;
      _handlePushNavigation(msg);
    }
  }

  Future<void> _bootstrap() async {
    unawaited(_loadBootstrapPublicData());
    await _restoreSession();
    if (!mounted) return;
    setState(() => _isBootstrapDone = true);
  }

  void _startSessionGuard() {
    _sessionGuardTimer?.cancel();
    if (authToken == null || authToken!.isEmpty) {
      return;
    }
    _sessionGuardTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_validateActiveSession(silent: true));
    });
  }

  void _stopSessionGuard() {
    _sessionGuardTimer?.cancel();
    _sessionGuardTimer = null;
  }

  Future<void> _clearLocalSession({
    required String message,
    bool clearAuthMessage = true,
  }) async {
    _stopSessionGuard();
    if (AppFirebase.isConfigured) {
      await AppFirebase.clearSessionForAccountSwitch();
    }
    await _secureStorage.delete(key: _tokenKey);
    if (!mounted) return;
    setState(() {
      authUser = null;
      authToken = null;
      authMessage = clearAuthMessage ? message : '';
      unreadNotifications = 0;
      unreadChats = 0;
      _tabIndex = 0;
    });
    _permissionPromptQueued = false;
    _permissionPromptVisible = false;
  }

  Future<void> _handleSessionRevoked() async {
    await _clearLocalSession(
      message:
          'Tài khoản đã đăng nhập trên thiết bị di động khác. Vui lòng đăng nhập lại.',
    );
  }

  Future<void> _validateActiveSession({bool silent = false}) async {
    final String? token = authToken;
    if (token == null || token.isEmpty || _isCheckingSession) {
      return;
    }

    _isCheckingSession = true;
    try {
      final Map<String, dynamic> me = await _fetchMeWithRetry(token);
      final int statusCode = (me['statusCode'] ?? 500) as int;

      if (statusCode == 401 || statusCode == 403) {
        await _handleSessionRevoked();
        return;
      }

      if (statusCode == 200 && mounted) {
        setState(() {
          authUser = me['body'] as Map<String, dynamic>;
          if (!silent && authMessage.contains('thiết bị di động khác')) {
            authMessage = '';
          }
        });
      }
    } catch (_) {
      // Keep current session if the network is temporarily unavailable.
    } finally {
      _isCheckingSession = false;
    }
  }

  Future<void> _restoreSession() async {
    final String? token = await _secureStorage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return;
    final Map<String, dynamic> me = await _fetchMeWithRetry(token);
    if ((me['statusCode'] ?? 500) == 200) {
      setState(() {
        authToken = token;
        authUser = me['body'] as Map<String, dynamic>;
        authMessage = 'Đã khôi phục phiên đăng nhập.';
      });
      _startSessionGuard();
      unawaited(_finishRestoredSessionBootstrap(token));
    } else {
      final int statusCode = (me['statusCode'] ?? 500) as int;
      if (statusCode == 401 || statusCode == 403) {
        await _handleSessionRevoked();
      } else {
        if (statusCode >= 500 && mounted) {
          setState(() {
            authMessage =
                'Máy chủ xác thực đang bận. Vui lòng mở lại ứng dụng sau vài giây.';
          });
          return;
        }
        await _clearLocalSession(
          message: _apiMessage(
            me['body'] as Map<String, dynamic>?,
            'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.',
          ),
        );
      }
    }
  }

  int _extractUnreadCount(Map<String, dynamic> data) {
    final List<dynamic> notifications =
        (data['notifications'] ?? <dynamic>[]) as List<dynamic>;
    final List<dynamic> reminders =
        (data['reminders'] ?? <dynamic>[]) as List<dynamic>;
    final List<dynamic> logs = (data['logs'] ?? <dynamic>[]) as List<dynamic>;
    int countUnread(
      List<dynamic> list, {
      bool Function(Map<String, dynamic> item)? predicate,
    }) {
      int count = 0;
      for (final dynamic item in list) {
        if (item is! Map<String, dynamic>) continue;
        if (item['is_read'] == true) continue;
        if (predicate != null && !predicate(item)) continue;
        count += 1;
      }
      return count;
    }

    return countUnread(
          notifications,
          predicate: (Map<String, dynamic> item) {
            final String type = (item['type'] ?? '').toString();
            return !_chatNotificationTypes.contains(type);
          },
        ) +
        countUnread(reminders) +
        countUnread(logs);
  }

  int _extractUnreadChats(Map<String, dynamic> data) {
    final List<dynamic> notifications =
        (data['notifications'] ?? <dynamic>[]) as List<dynamic>;
    int count = 0;
    for (final dynamic item in notifications) {
      if (item is! Map<String, dynamic>) continue;
      if (item['is_read'] == true) continue;
      final String type = (item['type'] ?? '').toString();
      if (_chatNotificationTypes.contains(type)) {
        count += 1;
      }
    }
    return count;
  }

  int? _parseUnreadValue(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) {
      final int parsed = value.toInt();
      return parsed < 0 ? 0 : parsed;
    }
    final int? parsed = int.tryParse('${value ?? ''}');
    if (parsed == null) return null;
    return parsed < 0 ? 0 : parsed;
  }

  Future<void> _refreshNotificationBadge() async {
    if (authToken == null || authToken!.isEmpty) return;
    try {
      final Map<String, dynamic> data = await _api
          .getNotifications(authToken!)
          .timeout(_bootstrapTimeout);
      if (!mounted) return;
      final int? unreadNotificationFromApi = _parseUnreadValue(
        data['unread_notification'],
      );
      final int? unreadChatFromApi = _parseUnreadValue(data['unread_chat']);
      setState(() {
        unreadNotifications =
            unreadNotificationFromApi ?? _extractUnreadCount(data);
        unreadChats = unreadChatFromApi ?? _extractUnreadChats(data);
      });
    } catch (_) {
      // ignore
    }
  }

  String _apiMessage(Map<String, dynamic>? responseBody, String fallback) {
    final String message = (responseBody?['message'] ?? '').toString().trim();
    return message.isNotEmpty ? message : fallback;
  }

  Future<Map<String, dynamic>> _fetchMeWithRetry(
    String token, {
    int maxAttempts = 3,
  }) async {
    Map<String, dynamic> last = <String, dynamic>{
      'statusCode': 500,
      'body': <String, dynamic>{},
    };

    for (int attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        last = await _api.me(token).timeout(_bootstrapTimeout);
      } catch (_) {
        last = <String, dynamic>{
          'statusCode': 500,
          'body': <String, dynamic>{
            'message': 'Không thể kết nối đến máy chủ xác thực.',
          },
        };
      }

      final int statusCode = (last['statusCode'] ?? 500) as int;
      if (statusCode == 200 || statusCode == 401 || statusCode == 403) {
        return last;
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }

    return last;
  }

  Future<void> loginMobile({
    required String email,
    required String password,
  }) async {
    _stopSessionGuard();
    setState(() {
      _isLoggingIn = true;
      authMessage = '';
    });
    final Map<String, dynamic> login = await _api.login(
      email: email,
      password: password,
    );
    if (!mounted) return;
    if ((login['statusCode'] ?? 500) != 200) {
      setState(() {
        _isLoggingIn = false;
        authMessage = 'Đăng nhập thất bại. Kiểm tra lại tài khoản/mật khẩu.';
      });
      return;
    }
    final Map<String, dynamic> body = login['body'] as Map<String, dynamic>;
    final String token = (body['token'] ?? '').toString();
    if (token.isEmpty) {
      setState(() {
        _isLoggingIn = false;
        authMessage = 'API không trả về token.';
      });
      return;
    }
    final Map<String, dynamic> me = await _fetchMeWithRetry(token);
    if (!mounted) return;
    final int meStatusCode = (me['statusCode'] ?? 500) as int;
    if (meStatusCode == 200) {
      await _secureStorage.write(key: _tokenKey, value: token);
      final Map<String, dynamic> summary = await _api.getPublicSummary(token);
      final Map<String, dynamic> accountSummary = await _api
          .getPublicAccountsSummary(token);
      if (!mounted) return;
      setState(() {
        authToken = token;
        authUser = me['body'] as Map<String, dynamic>;
        authMessage = 'Đăng nhập thành công.';
        overview = summary;
        accounts = accountSummary;
        _isLoggingIn = false;
      });
      _startSessionGuard();
      await _ensureFirebaseAuth();
      await _registerDeviceToken(requestPermission: false);
      await _addSavedAccount(email);
      await _refreshNotificationBadge();
      _scheduleEssentialPermissionPrompt();
      if (_pendingInitialMessage != null) {
        final msg = _pendingInitialMessage!;
        _pendingInitialMessage = null;
        _handlePushNavigation(msg);
      }
    } else {
      final Map<String, dynamic> fallbackUser =
          body['user'] is Map<String, dynamic>
              ? (body['user'] as Map<String, dynamic>)
              : <String, dynamic>{};
      if (fallbackUser.isNotEmpty && meStatusCode >= 500) {
        await _secureStorage.write(key: _tokenKey, value: token);
        final Map<String, dynamic> summary = await _api.getPublicSummary(token);
        final Map<String, dynamic> accountSummary = await _api
            .getPublicAccountsSummary(token);
        if (!mounted) return;
        setState(() {
          authToken = token;
          authUser = fallbackUser;
          authMessage =
              'Đăng nhập thành công. Máy chủ xác thực phản hồi chậm, ứng dụng đã dùng dữ liệu phiên hiện tại.';
          overview = summary;
          accounts = accountSummary;
          _isLoggingIn = false;
        });
        _startSessionGuard();
        await _ensureFirebaseAuth();
        await _registerDeviceToken(requestPermission: false);
        await _addSavedAccount(email);
        await _refreshNotificationBadge();
        _scheduleEssentialPermissionPrompt();
        return;
      }

      setState(() {
        _isLoggingIn = false;
        authMessage = _apiMessage(
          me['body'] as Map<String, dynamic>?,
          'Nhận token thành công nhưng gọi /me thất bại.',
        );
      });
    }
  }

  Future<String> forgotPasswordMobile({required String email}) async {
    final Map<String, dynamic> response = await _api.forgotPassword(
      email: email,
    );
    final int statusCode = (response['statusCode'] ?? 500) as int;
    final Map<String, dynamic> body =
        (response['body'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final String message = (body['message'] ?? '').toString().trim();

    if (message.isNotEmpty) {
      return message;
    }

    if (statusCode == 200) {
      return 'Nếu email hợp lệ, hệ thống đã gửi mật khẩu mới về hộp thư của bạn.';
    }

    return 'Không thể xử lý yêu cầu quên mật khẩu.';
  }

  Future<void> logoutMobile() async {
    if (authToken != null && authToken!.isNotEmpty) {
      await _api.logout(authToken!);
    }
    await _clearLocalSession(message: 'Đã đăng xuất.');
  }

  Future<Map<String, dynamic>> _registerDeviceToken({
    bool requestPermission = false,
  }) async {
    if (authToken == null || authToken!.isEmpty) {
      return <String, dynamic>{'ok': false, 'reason': 'missing_auth_token'};
    }
    if (!AppFirebase.isConfigured) {
      return <String, dynamic>{
        'ok': false,
        'reason': 'firebase_not_configured',
      };
    }
    Map<String, dynamic> lastResult = <String, dynamic>{
      'ok': false,
      'reason': 'push_token_unavailable',
    };
    try {
      await AppFirebase.registerPushToken(
        requestPermission: requestPermission,
        onToken: (
          String token,
          bool notificationsEnabled,
          String? apnsEnvironment,
        ) async {
          lastResult = await _api.registerDeviceTokenWithResult(
            authToken!,
            deviceToken: token,
            platform: Platform.isIOS ? 'ios' : 'android',
            deviceName: AppEnv.appName,
            notificationsEnabled: notificationsEnabled,
            apnsEnvironment: apnsEnvironment,
          );
          lastResult['device_token_suffix'] =
              token.length > 12 ? token.substring(token.length - 12) : token;
          lastResult['notifications_enabled'] = notificationsEnabled;
          lastResult['apns_environment'] = apnsEnvironment;
        },
      );
      return lastResult;
    } catch (_) {
      // Avoid blocking app startup if push token can't be registered yet.
      return <String, dynamic>{
        'ok': false,
        'reason': 'register_device_token_exception',
      };
    }
  }

  void _scheduleEssentialPermissionPrompt() {
    if (_permissionPromptQueued || _permissionPromptVisible) return;
    if (authToken == null || authToken!.isEmpty) return;
    _permissionPromptQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || authToken == null || authToken!.isEmpty) {
        _permissionPromptQueued = false;
        return;
      }

      final AppPermissionBootstrapState initialState =
          await AppPermissionBootstrapService.checkStatus();
      if (!mounted || authToken == null || authToken!.isEmpty) {
        _permissionPromptQueued = false;
        return;
      }

      if (initialState.allGranted) {
        _permissionPromptQueued = false;
        if (initialState.notificationsGranted) {
          await _registerDeviceToken(requestPermission: false);
        }
        return;
      }

      _permissionPromptVisible = true;
      final AppPermissionBootstrapState result =
          await _showEssentialPermissionSheet(initialState);
      _permissionPromptVisible = false;
      _permissionPromptQueued = false;

      if (!mounted) return;
      if (result.notificationsGranted) {
        await _registerDeviceToken(requestPermission: false);
      }
    });
  }

  Future<AppPermissionBootstrapState> _showEssentialPermissionSheet(
    AppPermissionBootstrapState initialState,
  ) async {
    AppPermissionBootstrapState currentState = initialState;
    bool requesting = false;
    bool shouldOpenSettings = initialState.needsSettingsAttention;

    final AppPermissionBootstrapState?
    result = await showModalBottomSheet<AppPermissionBootstrapState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            Future<void> openSettings() async {
              await openAppSettings();
            }

            Future<void> refreshStatus() async {
              final AppPermissionBootstrapState next =
                  await AppPermissionBootstrapService.checkStatus();
              if (!context.mounted) return;
              setSheetState(() {
                currentState = next;
                shouldOpenSettings = next.needsSettingsAttention;
              });
            }

            Future<void> requestPermissions() async {
              if (shouldOpenSettings || currentState.needsSettingsAttention) {
                await openSettings();
                return;
              }
              setSheetState(() => requesting = true);
              final AppPermissionBootstrapState next =
                  await AppPermissionBootstrapService.requestEssentialPermissions();
              if (next.notificationsGranted) {
                await _registerDeviceToken(requestPermission: false);
              }
              if (!context.mounted) return;
              setSheetState(() {
                requesting = false;
                currentState = next;
                shouldOpenSettings =
                    next.needsSettingsAttention || !next.wifiGranted;
              });
              if (next.allGranted && context.mounted) {
                Navigator.of(context).pop(next);
              }
            }

            return _EssentialPermissionSheet(
              state: currentState,
              requesting: requesting,
              onGrantNow: requestPermissions,
              onCheckAgain: refreshStatus,
              onLater: () => Navigator.of(context).pop(currentState),
              onOpenSettings: openSettings,
              preferOpenSettings: shouldOpenSettings,
            );
          },
        );
      },
    );

    return result ?? currentState;
  }

  Future<void> _ensureFirebaseAuth() async {
    if (authToken == null || authToken!.isEmpty) return;
    if (!AppFirebase.isConfigured) return;
    String? token;
    try {
      token = await _api.getFirebaseToken(authToken!);
    } catch (_) {
      return;
    }
    if (token == null || token.isEmpty) return;
    await AppFirebase.signInWithCustomToken(token);
  }

  bool _hasRole(List<String> roles) {
    final String role = (authUser?['role'] ?? '').toString();
    if (roles.contains(role)) return true;
    // "administrator" là super-admin, tự động kế thừa mọi quyền của "admin".
    if (role == 'administrator' && roles.contains('admin')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBootstrapDone) {
      return Scaffold(
        backgroundColor: StitchTheme.bg,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[StitchTheme.bg, StitchTheme.surfaceAlt],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: StitchTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: StitchTheme.border),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: StitchTheme.textMain.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset('icon.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    appSettingsStore.settings.brandName.isNotEmpty
                        ? appSettingsStore.settings.brandName
                        : AppEnv.appName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đang khởi động hệ thống',
                    style: TextStyle(
                      color: StitchTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        StitchTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final bool isAuthenticated = authToken != null && authToken!.isNotEmpty;
    if (!isAuthenticated) {
      return LoginScreen(
        emailController: emailController,
        passwordController: passwordController,
        authMessage: authMessage,
        isLoading: _isLoggingIn,
        onLogin: loginMobile,
        onForgotPassword: forgotPasswordMobile,
        savedAccounts: savedAccounts,
        rememberMe: rememberAccount,
        onToggleRemember: _toggleRemember,
        onSelectAccount: _selectSavedAccount,
        onRemoveAccount: _removeSavedAccount,
      );
    }

    // Phân quyền hiển thị / luồng: khớp menu web (Authenticated.jsx) — webMenuHasRole.
    // Thao tác ghi API (kế thừa administrator→admin khi API có "admin"): _hasRole.
    final String role = (authUser?['role'] ?? '').toString();
    final String currentUserRole = role;

    // Lịch họp — menu web Operations
    final bool canViewMeetings = webMenuHasRole(role, kWebMenuMeetings);

    // CRM — "Khách hàng": xem menu vs CRUD (API clients: admin,quan_ly,nhan_vien)
    final bool canViewCrm = webMenuHasRole(role, kWebMenuCrmClients);
    // Hợp đồng — menu Sales; sửa/xóa: không nhan_vien (khớp Contracts web)
    final bool canViewContracts = webMenuHasRole(role, kWebMenuContracts);

    final bool canViewProjects = webMenuHasRole(
      role,
      kWebMenuOperationsProjectsTasks,
    );
    /// Khớp web ProjectsKanban (canCreate) + middleware POST /projects.
    final bool canCreateProject =
        canViewProjects && apiRoleMatches(role, kApiProjectStore);
    final bool canViewServiceWorkflows = webMenuHasRole(
      role,
      kWebMenuServiceWorkflows,
    );

    final bool canViewReports = webMenuHasRole(role, kWebMenuReportsKpi);
    final bool canViewDepartments = webMenuHasRole(role, kWebMenuDepartments);
    final bool canViewRevenue = webMenuHasRole(role, kWebMenuReportsCompany);

    final bool canViewHandover = webMenuHasRole(role, kWebMenuHandover);

    final bool canViewLogs = webMenuHasRole(role, kWebMenuActivityLogs);

    final bool canViewOpportunities = webMenuHasRole(
      role,
      kWebMenuOpportunities,
    );

    final bool canViewLeadTypes = webMenuHasRole(role, kWebMenuAdminOnlySettings);
    final bool canViewOpportunityStatuses = webMenuHasRole(
      role,
      kWebMenuAdminOnlySettings,
    );
    final bool canViewRevenueTiers = webMenuHasRole(
      role,
      kWebMenuAdminOnlySettings,
    );
    final bool canViewAttendance = webMenuHasRole(role, kWebMenuAttendance);

    final bool canViewProducts = webMenuHasRole(role, kWebMenuProducts);

    final bool canViewCrmHub =
        canViewCrm ||
        canViewOpportunities ||
        canViewContracts ||
        canViewProducts ||
        canViewLeadTypes ||
        canViewOpportunityStatuses ||
        canViewRevenueTiers ||
        canViewRevenue;

    Future<void> openScreen(Widget Function() builder) {
      return Navigator.of(
        context,
      ).push(MaterialPageRoute<Widget>(builder: (_) => builder()));
    }
    final dynamic rawUserId = authUser?['id'];
    final int? resolvedUserId =
        rawUserId is int ? rawUserId : int.tryParse('${rawUserId ?? ''}');

    void openProjects() => openScreen(
      () => ProjectsScreen(
        token: authToken!,
        apiService: _api,
        canView: canViewProjects,
        canCreate: canCreateProject,
      ),
    );
    void openHandover() => openScreen(
      () => HandoverCenterScreen(token: authToken!, apiService: _api),
    );
    void openChat() => openScreen(() {
      final dynamic rawId = authUser == null ? null : authUser!['id'];
      final int? currentUserId =
          rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
      return ChatScreen(
        token: authToken!,
        apiService: _api,
        currentUserId: currentUserId,
      );
    });
    void openActivityLogs() => openScreen(
      () => ActivityLogScreen(token: authToken!, apiService: _api),
    );
    void openNotifications() => openScreen(() {
      final dynamic rawId = authUser == null ? null : authUser!['id'];
      final int? currentUserId =
          rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
      return NotificationsScreen(
        token: authToken!,
        apiService: _api,
        currentUserId: currentUserId,
        currentUserRole: (authUser?['role'] ?? '').toString(),
      );
    }).then((_) => _refreshNotificationBadge());
    void openMeetings() => openScreen(
      () => MeetingsScreen(
        token: authToken!,
        apiService: _api,
        canManage: apiRoleMatches(role, kApiMeetingManage),
        canDelete: apiRoleMatches(role, kApiMeetingDelete),
      ),
    );
    void openCrm() => openScreen(
      () => CrmScreen(
        token: authToken!,
        apiService: _api,
        canManageClients: apiRoleMatches(role, kApiCrmClientWrite),
        canManagePayments: apiRoleMatches(role, kApiCrmPaymentWrite),
        canDelete: apiRoleMatches(role, kApiCrmClientDelete),
        currentUserRole: currentUserRole,
      ),
    );
    void openOpportunities() => openScreen(
      () => OpportunitiesScreen(
        token: authToken!,
        apiService: _api,
        canManage: apiRoleMatches(role, kApiOpportunityReadWrite),
        canDelete: apiRoleMatches(role, kApiOpportunityDelete),
      ),
    );
    void openContracts() => openScreen(
      () => ContractsScreen(
        token: authToken!,
        apiService: _api,
        canManage: apiRoleMatches(role, kApiContractUpdateDelete),
        canCreate: apiRoleMatches(role, kApiContractReadCreate),
        canDelete: apiRoleMatches(role, kApiContractUpdateDelete),
        canApprove: apiRoleMatches(role, kApiContractApprove),
        canCreateContractFinanceLines: apiRoleMatches(
          role,
          kApiContractPaymentLineCreate,
        ),
        canEditContractFinanceLines: apiRoleMatches(
          role,
          kApiContractPaymentLineMutate,
        ),
        currentUserRole: currentUserRole,
        currentUserId: resolvedUserId,
      ),
    );
    void openProducts() => openScreen(
      () => ProductsScreen(
        token: authToken!,
        apiService: _api,
        canManage: apiRoleMatches(role, kApiProductMutate),
        canDelete: apiRoleMatches(role, kApiProductDelete),
      ),
    );
    void openDepartments() => openScreen(
      () => DepartmentsScreen(
        token: authToken!,
        apiService: _api,
        canManage: _hasRole(<String>['admin']),
      ),
    );
    void openRevenueReport() => openScreen(
      () => RevenueReportScreen(
        token: authToken!,
        apiService: _api,
        currentUserRole: currentUserRole,
      ),
    );
    void openLeadTypes() =>
        openScreen(() => LeadTypesScreen(token: authToken!, apiService: _api));
    void openOpportunityStatuses() => openScreen(
      () => OpportunityStatusesScreen(token: authToken!, apiService: _api),
    );
    void openRevenueTiers() => openScreen(
      () => RevenueTiersScreen(token: authToken!, apiService: _api),
    );
    void openReports() =>
        openScreen(() => ReportsScreen(token: authToken!, apiService: _api));
    void openServices() => openScreen(
      () => ServicesScreen(
        token: authToken!,
        apiService: _api,
        canManage: _hasRole(<String>['admin', 'quan_ly']),
        canDelete: _hasRole(<String>['admin']),
      ),
    );
    void openAttendance() => openScreen(
      () => AttendanceWifiScreen(
        token: authToken!,
        apiService: _api,
        currentUserRole: currentUserRole,
      ),
    );
    void openTasksList() => openScreen(
          () => TasksListScreen(
            token: authToken!,
            apiService: _api,
          ),
        );

    void openTaskItems() =>
        openScreen(() => TaskItemsScreen(token: authToken!, apiService: _api));
    void openCreateProject() => openScreen(
      () => CreateProjectScreen(token: authToken!, apiService: _api),
    );

    Widget buildModuleCenter() => ModuleCenterScreen(
      onOpenProjects: canViewProjects ? openProjects : null,
      onOpenHandover: canViewHandover ? openHandover : null,
      onOpenChat: openChat,
      onOpenActivityLogs: canViewLogs ? openActivityLogs : null,
      onOpenNotifications: openNotifications,
      onOpenCreateProject: canCreateProject ? openCreateProject : null,
      onOpenMeetings: canViewMeetings ? openMeetings : null,
      onOpenCrm: canViewCrm ? openCrm : null,
      onOpenOpportunities: canViewOpportunities ? openOpportunities : null,
      onOpenContracts: canViewContracts ? openContracts : null,
      onOpenProducts: canViewProducts ? openProducts : null,
      onOpenDepartments: canViewDepartments ? openDepartments : null,
      onOpenRevenueReport: canViewRevenue ? openRevenueReport : null,
      onOpenLeadTypes: canViewLeadTypes ? openLeadTypes : null,
      onOpenOpportunityStatuses:
          canViewOpportunityStatuses ? openOpportunityStatuses : null,
      onOpenRevenueTiers: canViewRevenueTiers ? openRevenueTiers : null,
      onOpenReports: canViewReports ? openReports : null,
      onOpenServices: canViewServiceWorkflows ? openServices : null,
      onOpenAttendance: canViewAttendance ? openAttendance : null,
      onOpenTasks: canViewProjects ? openTasksList : null,
      onOpenTaskItems: canViewProjects ? openTaskItems : null,
    );

    final List<OverviewQuickAction> quickActions = <OverviewQuickAction>[
      if (canViewProjects)
        OverviewQuickAction(
          label: 'Dự án',
          icon: Icons.account_tree_outlined,
          onTap: openProjects,
          color: const Color(0xFF2563EB),
        ),
      if (canViewReports)
        OverviewQuickAction(
          label: 'Báo cáo',
          icon: Icons.bar_chart_outlined,
          onTap: openReports,
          color: const Color(0xFF0EA5A6),
        ),
      if (canViewHandover)
        OverviewQuickAction(
          label: 'Bàn giao dự án',
          icon: Icons.assignment_turned_in_outlined,
          onTap: openHandover,
          color: const Color(0xFF8B5CF6),
        ),
      if (canViewMeetings)
        OverviewQuickAction(
          label: 'Lịch họp',
          icon: Icons.event_note_outlined,
          onTap: openMeetings,
          color: const Color(0xFF4F46E5),
        ),
      if (canViewLogs)
        OverviewQuickAction(
          label: 'Nhật ký',
          icon: Icons.history_toggle_off_outlined,
          onTap: openActivityLogs,
          color: const Color(0xFF64748B),
        ),
      if (canViewAttendance)
        OverviewQuickAction(
          label: 'Chấm công',
          icon: Icons.wifi_tethering_outlined,
          onTap: openAttendance,
          color: const Color(0xFF0EA5A6),
        ),
    ];

    final List<OverviewQuickAction> adminActions = <OverviewQuickAction>[
      if (canViewDepartments)
        OverviewQuickAction(
          label: 'Phòng ban',
          icon: Icons.account_tree_outlined,
          onTap: openDepartments,
          color: const Color(0xFF0EA5E9),
        ),
      if (canViewRevenue)
        OverviewQuickAction(
          label: 'Doanh thu công ty',
          icon: Icons.stacked_line_chart_outlined,
          onTap: openRevenueReport,
          color: const Color(0xFFF97316),
        ),
      OverviewQuickAction(
        label: 'Tất cả',
        icon: Icons.grid_view_outlined,
        onTap: () => openScreen(buildModuleCenter),
        color: const Color(0xFF334155),
      ),
    ];

    final List<Widget> mainTabs = <Widget>[
      OverviewScreen(
        summary: overview,
        authUser: authUser,
        quickActions: quickActions,
        adminActions: adminActions,
        unreadNotifications: unreadNotifications,
        unreadChats: unreadChats,
        onOpenNotifications: openNotifications,
        onOpenChat: openChat,
        token: authToken,
        apiService: _api,
        currentUserRole: currentUserRole,
      ),
      if (canViewProjects)
        ProjectsScreen(
          token: authToken ?? '',
          apiService: _api,
          canView: true,
          canCreate: canCreateProject,
        ),
      if (canViewCrmHub)
        CrmHubScreen(
          onOpenCrm: canViewCrm ? openCrm : null,
          onOpenOpportunities: canViewOpportunities ? openOpportunities : null,
          onOpenContracts: canViewContracts ? openContracts : null,
          onOpenProducts: canViewProducts ? openProducts : null,
          onOpenLeadTypes: canViewLeadTypes ? openLeadTypes : null,
          onOpenOpportunityStatuses:
              canViewOpportunityStatuses ? openOpportunityStatuses : null,
          onOpenRevenueTiers: canViewRevenueTiers ? openRevenueTiers : null,
          onOpenRevenueReport: canViewRevenue ? openRevenueReport : null,
        ),
      AccountsScreen(
        summary: accounts,
        authUser: authUser,
        onLogout: logoutMobile,
        token: authToken,
        apiService: _api,
        onSyncDeviceToken: _registerDeviceToken,
      ),
    ];

    final int lastTabIndex = mainTabs.length - 1;
    final int safeTabIndex = _tabIndex.clamp(0, lastTabIndex);
    if (safeTabIndex != _tabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = safeTabIndex);
      });
    }

    final bool showFabSlot = canCreateProject && canViewProjects;
    final int? tabProjectsIndex = canViewProjects ? 1 : null;
    final int? tabCrmIndex =
        canViewCrmHub ? (canViewProjects ? 2 : 1) : null;

    return Scaffold(
      extendBody: false,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: mainTabs[safeTabIndex],
      ),
      floatingActionButton:
          canCreateProject && canViewProjects
              ? FloatingActionButton(
                elevation: 10,
                backgroundColor: StitchTheme.primary,
                foregroundColor: Colors.white,
                onPressed: authToken == null ? null : openCreateProject,
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNavBar(
        currentIndex: safeTabIndex,
        onTap: (int value) => setState(() => _tabIndex = value),
        hasCenterButton: showFabSlot,
        showProjectsTab: canViewProjects,
        showCrmTab: canViewCrmHub,
        tabProjectsIndex: tabProjectsIndex,
        tabCrmIndex: tabCrmIndex,
        accountTabIndex: lastTabIndex,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.hasCenterButton,
    required this.showProjectsTab,
    required this.showCrmTab,
    required this.tabProjectsIndex,
    required this.tabCrmIndex,
    required this.accountTabIndex,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hasCenterButton;
  final bool showProjectsTab;
  final bool showCrmTab;
  final int? tabProjectsIndex;
  final int? tabCrmIndex;
  final int accountTabIndex;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final bool compact = media.size.height < 720 || media.size.width < 380;
    return BottomAppBar(
      shape: hasCenterButton ? const CircularNotchedRectangle() : null,
      notchMargin: hasCenterButton ? 8 : 0,
      elevation: 12,
      surfaceTintColor: Colors.transparent,
      color: StitchTheme.surface,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: media.padding.bottom == 0 ? 4 : 0),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            compact ? 6 : 8,
            12,
            compact ? 8 : 10,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _NavItem(
                  label: 'Tổng quan',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  isActive: currentIndex == 0,
                  onTap: () => onTap(0),
                  compact: compact,
                ),
              ),
              if (showProjectsTab && tabProjectsIndex != null)
                Expanded(
                  child: _NavItem(
                    label: 'Dự án',
                    icon: Icons.account_tree_outlined,
                    activeIcon: Icons.account_tree,
                    isActive: currentIndex == tabProjectsIndex,
                    onTap: () => onTap(tabProjectsIndex!),
                    compact: compact,
                  ),
                ),
              if (hasCenterButton) SizedBox(width: compact ? 60 : 72),
              if (showCrmTab && tabCrmIndex != null)
                Expanded(
                  child: _NavItem(
                    label: 'CRM',
                    icon: Icons.groups_outlined,
                    activeIcon: Icons.groups,
                    isActive: currentIndex == tabCrmIndex,
                    onTap: () => onTap(tabCrmIndex!),
                    compact: compact,
                  ),
                ),
              Expanded(
                child: _NavItem(
                  label: 'Tài khoản',
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  isActive: currentIndex == accountTabIndex,
                  onTap: () => onTap(accountTabIndex),
                  compact: compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? StitchTheme.primary : StitchTheme.textSubtle;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 2 : 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: compact ? 19 : 21,
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: compact ? 9.5 : 10.5,
                height: 1.1,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EssentialPermissionSheet extends StatelessWidget {
  const _EssentialPermissionSheet({
    required this.state,
    required this.requesting,
    required this.onGrantNow,
    required this.onCheckAgain,
    required this.onLater,
    required this.onOpenSettings,
    required this.preferOpenSettings,
  });

  final AppPermissionBootstrapState state;
  final bool requesting;
  final Future<void> Function() onGrantNow;
  final Future<void> Function() onCheckAgain;
  final VoidCallback onLater;
  final Future<void> Function() onOpenSettings;
  final bool preferOpenSettings;

  static String _wifiStatusLabel(AppPermissionBootstrapState state) {
    if (state.wifiGranted) return 'Đã sẵn sàng';
    if (state.wifiPermission.requiresSettings) return 'Cần mở Cài đặt';
    return 'Cần cấp quyền';
  }

  static String _notificationStatusLabel(AppPermissionBootstrapState state) {
    if (!state.notificationsSupported) return 'Không sử dụng';
    if (state.notificationsGranted) return 'Đã sẵn sàng';
    if (state.notificationStatus == AuthorizationStatus.denied) {
      return 'Cần bật trong Cài đặt';
    }
    return 'Cần cấp quyền';
  }

  static Color _wifiColor(AppPermissionBootstrapState state) {
    if (state.wifiGranted) return StitchTheme.successStrong;
    return StitchTheme.warningStrong;
  }

  static Color _notificationColor(AppPermissionBootstrapState state) {
    if (!state.notificationsSupported) return StitchTheme.textMuted;
    if (state.notificationsGranted) return StitchTheme.successStrong;
    return StitchTheme.warningStrong;
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool showSettingsButton =
        state.needsSettingsAttention || preferOpenSettings;
    final bool allReady = state.allGranted;
    final bool canRequestNow = !requesting && !allReady;
    final String primaryLabel =
        allReady
            ? 'Đã cấp đủ quyền'
            : showSettingsButton
            ? 'Mở Cài đặt'
            : (requesting ? 'Đang xin quyền...' : 'Cấp quyền ngay');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: StitchTheme.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF0F766E), Color(0xFF14B8A6)],
              ),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cấp quyền cần thiết ngay từ đầu',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: StitchTheme.textMain,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Để chấm công Wi-Fi và nhận thông báo nhắc giờ không bị ngắt mạch, ứng dụng sẽ xin quyền ngay khi bạn vào hệ thống.',
            style: TextStyle(color: StitchTheme.textMuted, height: 1.45),
          ),
          const SizedBox(height: 18),
          _EssentialPermissionTile(
            icon: Icons.wifi_tethering_outlined,
            title: 'Wi-Fi và vị trí',
            status: _wifiStatusLabel(state),
            description:
                state.wifiGranted
                    ? 'Đã có thể đọc SSID/BSSID và kiểm tra đúng mạng công ty.'
                    : 'Ứng dụng cần quyền Vị trí (Android/iOS) để đọc Wi‑Fi hiện tại và xác minh BSSID nội bộ khi chấm công.',
            color: _wifiColor(state),
          ),
          if (state.notificationsSupported) ...<Widget>[
            const SizedBox(height: 12),
            _EssentialPermissionTile(
              icon: Icons.notifications_active_outlined,
              title: 'Thông báo',
              status: _notificationStatusLabel(state),
              description:
                  state.notificationsGranted
                      ? 'Đã sẵn sàng nhận nhắc giờ chấm công và thông báo hệ thống.'
                      : 'Bật thông báo để nhận nhắc trước giờ vào làm và các cập nhật quan trọng.',
              color: _notificationColor(state),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  requesting || allReady
                      ? null
                      : (showSettingsButton ? onOpenSettings : onGrantNow),
              icon: Icon(
                allReady
                    ? Icons.check_circle_outline
                    : (showSettingsButton
                        ? Icons.settings_outlined
                        : Icons.shield_outlined),
              ),
              label: Text(primaryLabel),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: canRequestNow ? onCheckAgain : null,
                  child: const Text('Kiểm tra lại'),
                ),
              ),
              const SizedBox(width: 10),
              if (showSettingsButton)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: requesting ? null : onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Mở Cài đặt'),
                  ),
                )
              else
                Expanded(
                  child: TextButton(
                    onPressed: requesting ? null : onLater,
                    child: const Text('Để sau'),
                  ),
                ),
            ],
          ),
          if (showSettingsButton) ...<Widget>[
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: requesting ? null : onLater,
                child: const Text('Để sau'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EssentialPermissionTile extends StatelessWidget {
  const _EssentialPermissionTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String status;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: StitchTheme.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: StitchTheme.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

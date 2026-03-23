import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_env.dart';
import '../../core/theme/stitch_theme.dart';
import '../../core/settings/app_settings.dart';
import '../../core/services/app_firebase.dart';
import '../../data/services/mobile_api_service.dart';
import '../auth/login_screen.dart';
import '../accounts/accounts_screen.dart';
import '../dashboard/overview_screen.dart';
import '../modules/crm_hub_screen.dart';
import '../modules/crm_screen.dart';
import '../modules/contracts_screen.dart';
import '../modules/handover_screen.dart';
import '../modules/chat_screen.dart';
import '../modules/chatbot_bot_list_screen.dart';
import '../modules/activity_log_screen.dart';
import '../modules/meetings_screen.dart';
import '../modules/module_center_screen.dart';
import '../modules/notifications_screen.dart';
import '../modules/reports_screen.dart';
import '../modules/services_screen.dart';
import '../modules/opportunities_screen.dart';
import '../modules/products_screen.dart';
import '../modules/revenue_report_screen.dart';
import '../modules/lead_forms_screen.dart';
import '../modules/lead_types_screen.dart';
import '../modules/revenue_tiers_screen.dart';
import '../modules/departments_screen.dart';
import '../projects/create_project_screen.dart';
import '../projects/projects_screen.dart';
import '../tasks/tasks_screen.dart';

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
  List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];
  List<String> taskStatuses = <String>['todo', 'doing', 'done', 'blocked'];
  int unreadNotifications = 0;
  int unreadChats = 0;
  bool taskLoading = false;
  String taskMessage = '';
  String taskStatusFilter = '';
  Map<String, dynamic>? authUser;
  String? authToken;
  String authMessage = '';
  List<String> savedAccounts = <String>[];
  bool rememberAccount = true;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  Timer? _sessionGuardTimer;
  bool _isCheckingSession = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedAccounts();
    _bootstrap();
    if (AppFirebase.isConfigured) {
      AppFirebase.ensureForegroundMessaging().then((_) {
        _foregroundSub?.cancel();
        _foregroundSub = AppFirebase.foregroundMessages.listen((_) async {
          await _refreshNotificationBadge();
        });
      });
    }
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
      unawaited(_validateActiveSession());
      if (authToken != null && authToken!.isNotEmpty) {
        unawaited(_registerDeviceToken());
      }
    }
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

  Future<void> _bootstrap() async {
    String bootstrapMessage = '';
    Map<String, dynamic> summary = <String, dynamic>{};
    Map<String, dynamic> accountSummary = <String, dynamic>{};
    Map<String, dynamic> meta = <String, dynamic>{};
    Map<String, dynamic> settings = <String, dynamic>{};
    try {
      final List<Map<String, dynamic>> results =
          await Future.wait(<Future<Map<String, dynamic>>>[
            _safeMap(_api.getPublicSummary()),
            _safeMap(_api.getPublicAccountsSummary()),
            _safeMap(_api.getMeta()),
            _safeMap(_api.getSettings()),
          ]);
      summary = results[0];
      accountSummary = results[1];
      meta = results[2];
      settings = results[3];
    } catch (_) {
      bootstrapMessage =
          'Không thể kết nối máy chủ. Vui lòng kiểm tra API_BASE_URL.';
    }
    if (mounted) {
      setState(() {
        overview = summary;
        accounts = accountSummary;
        final List<dynamic> statuses =
            (meta['task_statuses'] ?? <dynamic>[]) as List<dynamic>;
        if (statuses.isNotEmpty) {
          taskStatuses = statuses.map((dynamic e) => e.toString()).toList();
        }
        if (bootstrapMessage.isNotEmpty) {
          authMessage = bootstrapMessage;
        }
      });
    }
    if (settings.isNotEmpty) {
      appSettingsStore.apply(AppSettingsData.fromJson(settings));
    }
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
    await _secureStorage.delete(key: _tokenKey);
    if (!mounted) return;
    setState(() {
      authUser = null;
      authToken = null;
      authMessage = clearAuthMessage ? message : '';
      tasks = <Map<String, dynamic>>[];
      taskMessage = '';
      taskStatusFilter = '';
      unreadNotifications = 0;
      unreadChats = 0;
      _tabIndex = 0;
    });
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
      final Map<String, dynamic> me = await _api
          .me(token)
          .timeout(_bootstrapTimeout);
      final int statusCode = (me['statusCode'] ?? 500) as int;

      if (statusCode == 401) {
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
    Map<String, dynamic> me = <String, dynamic>{};
    try {
      me = await _api.me(token).timeout(_bootstrapTimeout);
    } catch (_) {
      return;
    }
    if ((me['statusCode'] ?? 500) == 200) {
      setState(() {
        authToken = token;
        authUser = me['body'] as Map<String, dynamic>;
        authMessage = 'Đã khôi phục phiên đăng nhập.';
      });
      _startSessionGuard();
      await _ensureFirebaseAuth();
      await _registerDeviceToken();
      try {
        await fetchTasks(silent: true).timeout(_bootstrapTimeout);
      } catch (_) {
        // ignore timeout
      }
      await _refreshNotificationBadge();
    } else {
      final int statusCode = (me['statusCode'] ?? 500) as int;
      if (statusCode == 401) {
        await _handleSessionRevoked();
      } else {
        await _clearLocalSession(
          message: 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.',
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
    final Map<String, dynamic> me = await _api.me(token);
    if (!mounted) return;
    if ((me['statusCode'] ?? 500) == 200) {
      await _secureStorage.write(key: _tokenKey, value: token);
      final Map<String, dynamic> summary = await _api.getPublicSummary();
      final Map<String, dynamic> accountSummary =
          await _api.getPublicAccountsSummary();
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
      await _registerDeviceToken();
      await _addSavedAccount(email);
      await fetchTasks(silent: true);
      await _refreshNotificationBadge();
    } else {
      setState(() {
        _isLoggingIn = false;
        authMessage = 'Nhận token thành công nhưng gọi /me thất bại.';
      });
    }
  }

  Future<String> forgotPasswordMobile({required String email}) async {
    final Map<String, dynamic> response = await _api.forgotPassword(email: email);
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
    await _clearLocalSession(message: 'Đã đăng xuất token.');
  }

  Future<Map<String, dynamic>> _registerDeviceToken() async {
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

  Future<void> fetchTasks({String? status, bool silent = false}) async {
    if (authToken == null || authToken!.isEmpty) {
      setState(() {
        taskMessage = 'Cần đăng nhập để xem và thao tác công việc.';
        tasks = <Map<String, dynamic>>[];
      });
      return;
    }
    final String resolvedStatus = status ?? taskStatusFilter;
    if (!silent) setState(() => taskLoading = true);
    final List<Map<String, dynamic>> rows = await _api.getTasks(
      authToken!,
      status: resolvedStatus,
    );
    setState(() {
      taskLoading = false;
      taskStatusFilter = resolvedStatus;
      taskMessage = rows.isEmpty ? 'Không có công việc phù hợp bộ lọc.' : '';
      tasks = rows;
    });
  }

  Future<void> updateTaskStatus(
    Map<String, dynamic> task,
    String newStatus,
  ) async {
    if (authToken == null || authToken!.isEmpty) return;
    setState(() => taskLoading = true);
    final bool ok = await _api.updateTaskStatus(authToken!, task, newStatus);
    await fetchTasks(status: taskStatusFilter, silent: true);
    setState(() {
      taskLoading = false;
      taskMessage =
          ok
              ? 'Đã cập nhật trạng thái công việc.'
              : 'Cập nhật công việc thất bại.';
    });
  }

  bool _hasRole(List<String> roles) {
    final String role = (authUser?['role'] ?? '').toString();
    return roles.contains(role);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBootstrapDone) {
      return Scaffold(
        backgroundColor: StitchTheme.bg,
        body: Center(
          child: ClipOval(
            child: Image.asset(
              'icon.png',
              width: 140,
              height: 140,
              fit: BoxFit.cover,
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

    final bool canManageMeetings = _hasRole(<String>['admin', 'quan_ly']);
    final bool canDeleteMeetings = _hasRole(<String>['admin']);
    final bool canManageCrm = _hasRole(<String>[
      'admin',
      'quan_ly',
      'nhan_vien',
    ]);
    final bool canDeleteCrm = _hasRole(<String>['admin']);
    final bool canManageContracts = _hasRole(<String>[
      'admin',
      'quan_ly',
      'nhan_vien',
      'ke_toan',
    ]);
    final bool canDeleteContracts = _hasRole(<String>['admin']);
    final bool canCreateProject = _hasRole(<String>['admin', 'quan_ly']);
    final bool canViewProjects = _hasRole(<String>['admin', 'quan_ly', 'nhan_vien']);
    final bool canViewReports = _hasRole(<String>['admin', 'quan_ly']);
    final bool canViewDepartments = _hasRole(<String>['admin', 'quan_ly']);
    final bool canViewRevenue = _hasRole(<String>['admin']);
    final bool canViewHandover = _hasRole(<String>[
      'admin',
      'nhan_vien',
    ]);
    final bool canViewChat = _hasRole(<String>[
      'admin',
      'quan_ly',
      'nhan_vien',
      'ke_toan',
    ]);
    final bool canViewLogs = _hasRole(<String>['admin', 'quan_ly']);
    final bool canViewMeetings = _hasRole(<String>['admin', 'quan_ly']);
    final bool canViewOpportunities = _hasRole(<String>[
      'admin',
      'quan_ly',
      'nhan_vien',
    ]);
    final bool canViewLeadForms = _hasRole(<String>['admin']);
    final bool canViewLeadTypes = _hasRole(<String>['admin']);
    final bool canViewRevenueTiers = _hasRole(<String>['admin']);

    Future<void> openScreen(Widget Function() builder) {
      return Navigator.of(
        context,
      ).push(MaterialPageRoute<Widget>(builder: (_) => builder()));
    }

    final String currentUserRole = (authUser?['role'] ?? '').toString();
    final dynamic rawUserId = authUser?['id'];
    final int? resolvedUserId =
        rawUserId is int ? rawUserId : int.tryParse('${rawUserId ?? ''}');

    void openProjects() => openScreen(
      () => ProjectsScreen(
        token: authToken!,
        apiService: _api,
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
    void openChatbot() => openScreen(
      () => ChatbotBotListScreen(token: authToken!, apiService: _api),
    );
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
      );
    }).then((_) => _refreshNotificationBadge());
    void openMeetings() => openScreen(
      () => MeetingsScreen(
        token: authToken!,
        apiService: _api,
        canManage: canManageMeetings,
        canDelete: canDeleteMeetings,
      ),
    );
    void openCrm() => openScreen(
      () => CrmScreen(
        token: authToken!,
        apiService: _api,
        canManageClients: canManageCrm,
        canManagePayments: _hasRole(<String>['admin', 'ke_toan']),
        canDelete: canDeleteCrm,
        currentUserRole: (authUser?['role'] ?? '').toString(),
      ),
    );
    void openOpportunities() => openScreen(
      () => OpportunitiesScreen(
        token: authToken!,
        apiService: _api,
        canManage: _hasRole(<String>['admin', 'quan_ly', 'nhan_vien']),
      ),
    );
    void openContracts() => openScreen(
      () => ContractsScreen(
        token: authToken!,
        apiService: _api,
        canManage: canManageContracts,
        canDelete: canDeleteContracts,
        canApprove: _hasRole(<String>['admin', 'ke_toan']),
        currentUserRole: currentUserRole,
        currentUserId: resolvedUserId,
      ),
    );
    void openProducts() => openScreen(
      () => ProductsScreen(
        token: authToken!,
        apiService: _api,
        canManage: _hasRole(<String>['admin', 'quan_ly']),
        canDelete: _hasRole(<String>['admin']),
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
    void openLeadForms() =>
        openScreen(() => LeadFormsScreen(token: authToken!, apiService: _api));
    void openLeadTypes() =>
        openScreen(() => LeadTypesScreen(token: authToken!, apiService: _api));
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
    void openCreateProject() => openScreen(
      () => CreateProjectScreen(token: authToken!, apiService: _api),
    );

    Widget buildModuleCenter() => ModuleCenterScreen(
      onOpenProjects: canViewProjects ? openProjects : null,
      onOpenHandover: canViewHandover ? openHandover : null,
      onOpenChat: canViewChat ? openChat : null,
      onOpenActivityLogs: canViewLogs ? openActivityLogs : null,
      onOpenNotifications: openNotifications,
      onOpenCreateProject: canCreateProject ? openCreateProject : null,
      onOpenMeetings: canViewMeetings ? openMeetings : null,
      onOpenCrm: canManageCrm ? openCrm : null,
      onOpenOpportunities: canViewOpportunities ? openOpportunities : null,
      onOpenContracts: canManageContracts ? openContracts : null,
      onOpenProducts: canManageContracts ? openProducts : null,
      onOpenDepartments: canViewDepartments ? openDepartments : null,
      onOpenRevenueReport: canViewRevenue ? openRevenueReport : null,
      onOpenLeadForms: canViewLeadForms ? openLeadForms : null,
      onOpenLeadTypes: canViewLeadTypes ? openLeadTypes : null,
      onOpenRevenueTiers: canViewRevenueTiers ? openRevenueTiers : null,
      onOpenReports: canViewReports ? openReports : null,
      onOpenServices: canViewProjects ? openServices : null,
      onOpenChatbot: openChatbot,
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
      OverviewQuickAction(
        label: 'Trợ lý AI',
        icon: Icons.smart_toy_outlined,
        onTap: openChatbot,
        color: const Color(0xFF6366F1),
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

    final List<Widget> tabs = <Widget>[
      OverviewScreen(
        summary: overview,
        authUser: authUser,
        quickActions: quickActions,
        adminActions: adminActions,
        unreadNotifications: unreadNotifications,
        unreadChats: unreadChats,
        onOpenNotifications: openNotifications,
        onOpenChat: canViewChat ? openChat : null,
      ),
      TasksScreen(
        tasks: tasks,
        statuses: taskStatuses,
        currentFilter: taskStatusFilter,
        loading: taskLoading,
        message: taskMessage,
        isAuthenticated: isAuthenticated,
        onRefresh: fetchTasks,
        onUpdateStatus: updateTaskStatus,
        token: authToken,
        apiService: _api,
        currentUserRole: (authUser?['role'] ?? '').toString(),
        currentUserId: resolvedUserId,
      ),
      CrmHubScreen(
        onOpenCrm: canManageCrm ? openCrm : null,
        onOpenOpportunities: canViewOpportunities ? openOpportunities : null,
        onOpenContracts: canManageContracts ? openContracts : null,
        onOpenProducts: canManageContracts ? openProducts : null,
        onOpenLeadForms: canViewLeadForms ? openLeadForms : null,
        onOpenLeadTypes: canViewLeadTypes ? openLeadTypes : null,
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

    return Scaffold(
      extendBody: false,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: tabs[_tabIndex],
      ),
      floatingActionButton:
          canCreateProject
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
        currentIndex: _tabIndex,
        onTap: (int value) => setState(() => _tabIndex = value),
        hasCenterButton: canCreateProject,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.hasCenterButton,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hasCenterButton;

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
              Expanded(
                child: _NavItem(
                  label: 'Công việc',
                  icon: Icons.event_note_outlined,
                  activeIcon: Icons.event_note,
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                  compact: compact,
                ),
              ),
              if (hasCenterButton) SizedBox(width: compact ? 60 : 72),
              Expanded(
                child: _NavItem(
                  label: 'CRM',
                  icon: Icons.groups_outlined,
                  activeIcon: Icons.groups,
                  isActive: currentIndex == 2,
                  onTap: () => onTap(2),
                  compact: compact,
                ),
              ),
              Expanded(
                child: _NavItem(
                  label: 'Tài khoản',
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  isActive: currentIndex == 3,
                  onTap: () => onTap(3),
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

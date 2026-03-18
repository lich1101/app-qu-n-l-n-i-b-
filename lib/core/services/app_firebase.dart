import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../config/app_env.dart';

class AppFirebase {
  static bool _initialized = false;
  static Future<void>? _initializingFuture;
  static bool _foregroundConfigured = false;
  static FirebaseDatabase? _database;
  static FirebaseAuth? _auth;
  static String? _lastPushToken;
  static DateTime? _lastPushTokenAt;
  static String? _lastApnsEnvironment;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  static String? _lastForegroundMessageKey;
  static DateTime? _lastForegroundMessageAt;
  static const MethodChannel _pushEnvironmentChannel = MethodChannel(
    'vn.clickon.jobnew/push_environment',
  );

  static Stream<RemoteMessage> get foregroundMessages =>
      _foregroundController.stream;

  static bool get isConfigured =>
      AppEnv.firebaseApiKey.isNotEmpty &&
      AppEnv.firebaseProjectId.isNotEmpty &&
      AppEnv.firebaseMessagingSenderId.isNotEmpty &&
      AppEnv.firebaseDatabaseUrl.isNotEmpty &&
      (AppEnv.firebaseAppIdAndroid.isNotEmpty ||
          AppEnv.firebaseAppIdIos.isNotEmpty);

  static Future<void> ensureInitialized() async {
    if (_initialized || !isConfigured) return;
    if (_initializingFuture != null) {
      await _initializingFuture;
      return;
    }

    _initializingFuture = _initializeFirebase();
    try {
      await _initializingFuture;
    } finally {
      _initializingFuture = null;
    }
  }

  static Future<void> _initializeFirebase() async {
    final String appId =
        Platform.isIOS ? AppEnv.firebaseAppIdIos : AppEnv.firebaseAppIdAndroid;
    if (appId.isEmpty) return;

    final bool hasDefaultApp = Firebase.apps.any(
      (FirebaseApp app) => app.name == '[DEFAULT]',
    );

    if (!hasDefaultApp) {
      try {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: AppEnv.firebaseApiKey,
            appId: appId,
            messagingSenderId: AppEnv.firebaseMessagingSenderId,
            projectId: AppEnv.firebaseProjectId,
            databaseURL: AppEnv.firebaseDatabaseUrl,
          ),
        );
      } on FirebaseException catch (error) {
        if (error.code != 'duplicate-app') {
          rethrow;
        }
      }
    }

    _auth = FirebaseAuth.instance;
    _database = FirebaseDatabase.instance;
    _initialized = true;
  }

  static Future<void> ensureForegroundMessaging() async {
    if (!isConfigured) return;
    await ensureInitialized();
    if (_foregroundConfigured) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'crm_default',
      'Thông báo hệ thống',
      description: 'Thông báo realtime từ hệ thống CRM',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        debugPrint(
          '[Push][Foreground] id=${message.messageId ?? '-'} '
          'title=${message.notification?.title ?? message.data['title'] ?? '-'} '
          'body=${message.notification?.body ?? message.data['body'] ?? '-'} '
          'data=${_compactData(message.data)}',
        );
      }
      if (_isDuplicateForegroundMessage(message)) {
        return;
      }
      _foregroundController.add(message);
      await _showLocalNotification(message, channel);
    });

    _foregroundConfigured = true;
  }

  static Future<void> _showLocalNotification(
    RemoteMessage message,
    AndroidNotificationChannel channel,
  ) async {
    final RemoteNotification? notification = message.notification;
    final String title =
        notification?.title ??
        (message.data['title'] ?? 'Thông báo').toString();
    final String body =
        notification?.body ?? (message.data['body'] ?? '').toString();
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  static bool _isDuplicateForegroundMessage(RemoteMessage message) {
    final String key = _messageFingerprint(message);
    final DateTime now = DateTime.now();
    if (_lastForegroundMessageKey == key &&
        _lastForegroundMessageAt != null &&
        now.difference(_lastForegroundMessageAt!).inSeconds <= 8) {
      return true;
    }
    _lastForegroundMessageKey = key;
    _lastForegroundMessageAt = now;
    return false;
  }

  static String _messageFingerprint(RemoteMessage message) {
    final RemoteNotification? notification = message.notification;
    final String type = (message.data['type'] ?? '').toString();
    final String taskId = (message.data['task_id'] ?? '').toString();
    final String itemId = (message.data['task_item_id'] ?? '').toString();
    final String commentId = (message.data['comment_id'] ?? '').toString();
    final String title =
        (notification?.title ?? message.data['title'] ?? '').toString();
    final String body =
        (notification?.body ?? message.data['body'] ?? '').toString();
    return [
      message.messageId ?? '',
      type,
      taskId,
      itemId,
      commentId,
      title,
      body,
    ].join('|');
  }

  static String _compactData(Map<String, dynamic> data) {
    if (data.isEmpty) return '{}';
    final Map<String, dynamic> compact = <String, dynamic>{};
    data.forEach((String key, dynamic value) {
      final String text = value?.toString() ?? '';
      compact[key] = text.length > 64 ? '${text.substring(0, 64)}...' : text;
    });
    return compact.toString();
  }

  static FirebaseDatabase? get database => _database;
  static String? get lastPushToken => _lastPushToken;
  static DateTime? get lastPushTokenAt => _lastPushTokenAt;

  static Future<bool> signInWithCustomToken(String token) async {
    if (!isConfigured || token.isEmpty) return false;
    await ensureInitialized();
    if (_auth == null) return false;
    try {
      await _auth!.signInWithCustomToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Stream<DatabaseEvent>? taskChatStream(int taskId) {
    if (!_initialized || _database == null) return null;
    return _database!.ref('task_chats/$taskId/messages').onValue;
  }

  static Query? taskChatQuery(int taskId, {int? limit}) {
    if (!_initialized || _database == null) return null;
    Query query = _database!
        .ref('task_chats/$taskId/messages')
        .orderByChild('created_at');
    if (limit != null && limit > 0) {
      query = query.limitToLast(limit);
    }
    return query;
  }

  static Future<String?> registerPushToken({
    required FutureOr<void> Function(
      String token,
      bool notificationsEnabled,
      String? apnsEnvironment,
    )
    onToken,
  }) async {
    if (!isConfigured) return null;
    await ensureInitialized();
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    bool notificationsEnabled = false;
    String? apnsEnvironment;
    try {
      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      notificationsEnabled = _isAuthorizedStatus(settings.authorizationStatus);
    } catch (_) {
      // Ignore permission errors and continue to avoid blocking app startup.
    }

    messaging.onTokenRefresh.listen((newToken) {
      if (newToken.isNotEmpty) {
        _lastPushToken = newToken;
        _lastPushTokenAt = DateTime.now();
        if (kDebugMode) {
          final String suffix =
              newToken.length > 12
                  ? newToken.substring(newToken.length - 12)
                  : newToken;
          debugPrint('[Push][TokenRefresh] suffix=$suffix');
        }
        notificationPermissionGranted().then(
          (bool permission) async {
            final String? environment =
                Platform.isIOS
                    ? (_lastApnsEnvironment ?? await _resolveApnsEnvironment())
                    : null;
            _lastApnsEnvironment = environment;
            return onToken(newToken, permission, environment);
          },
        );
      }
    });

    if (Platform.isIOS) {
      apnsEnvironment = await _resolveApnsEnvironment();
      _lastApnsEnvironment = apnsEnvironment;
      final String? apnsToken = await _waitForApnsToken(messaging);
      if (kDebugMode) {
        final String suffix =
            (apnsToken != null && apnsToken.isNotEmpty)
                ? (apnsToken.length > 12
                    ? apnsToken.substring(apnsToken.length - 12)
                    : apnsToken)
                : 'missing';
        debugPrint(
          '[Push][APNS] token_suffix=$suffix environment=${apnsEnvironment ?? 'unknown'}',
        );
      }
    }

    final String? token = await _waitForFcmToken(messaging);
    if (token != null && token.isNotEmpty) {
      _lastPushToken = token;
      _lastPushTokenAt = DateTime.now();
      if (kDebugMode) {
        final String suffix =
            token.length > 12 ? token.substring(token.length - 12) : token;
        debugPrint(
          '[Push][TokenInit] suffix=$suffix permission=$notificationsEnabled apns_environment=${apnsEnvironment ?? 'n/a'}',
        );
      }
      await onToken(token, notificationsEnabled, apnsEnvironment);
    }
    return token;
  }

  static Future<String?> _resolveApnsEnvironment() async {
    if (!Platform.isIOS) return null;
    try {
      final String? environment = await _pushEnvironmentChannel.invokeMethod<
        String
      >('getApnsEnvironment');
      if (environment == null) return null;
      final String normalized = environment.trim().toLowerCase();
      if (normalized == 'development' || normalized == 'production') {
        return normalized;
      }
    } on PlatformException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<String?> _waitForApnsToken(FirebaseMessaging messaging) async {
    if (!Platform.isIOS) return null;
    for (int attempt = 0; attempt < 8; attempt++) {
      try {
        final String? token = await messaging.getAPNSToken();
        if (token != null && token.isNotEmpty) {
          return token;
        }
      } catch (_) {
        // Retry because iOS may not expose APNs token immediately after launch.
      }
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
    return null;
  }

  static Future<String?> _waitForFcmToken(FirebaseMessaging messaging) async {
    for (int attempt = 0; attempt < 8; attempt++) {
      try {
        final String? token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          return token;
        }
      } on FirebaseException catch (e) {
        if (e.code != 'apns-token-not-set') {
          if (kDebugMode) {
            debugPrint('[Push][FCM] getToken error=${e.code}');
          }
          return null;
        }
      } catch (_) {
        return null;
      }

      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    return null;
  }

  static Future<AuthorizationStatus> notificationAuthorizationStatus() async {
    if (!isConfigured) return AuthorizationStatus.notDetermined;
    await ensureInitialized();
    final NotificationSettings settings =
        await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  static Future<bool> notificationPermissionGranted() async {
    final AuthorizationStatus status = await notificationAuthorizationStatus();
    return _isAuthorizedStatus(status);
  }

  static Future<bool> requestNotificationPermission() async {
    if (!isConfigured) return false;
    await ensureInitialized();
    final NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
    return _isAuthorizedStatus(settings.authorizationStatus);
  }

  static bool _isAuthorizedStatus(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }
}

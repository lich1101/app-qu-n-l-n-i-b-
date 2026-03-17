import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app/internal_task_app.dart';
import 'core/services/app_firebase.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await dotenv.load(fileName: '.env');
  await AppFirebase.ensureInitialized();
  if (kDebugMode) {
    debugPrint(
      '[Push][Background] id=${message.messageId ?? '-'} '
      'title=${message.notification?.title ?? message.data['title'] ?? '-'} '
      'body=${message.notification?.body ?? message.data['body'] ?? '-'}',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  if (AppFirebase.isConfigured) {
    await AppFirebase.ensureInitialized();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await AppFirebase.ensureForegroundMessaging();
  }
  runApp(const InternalTaskApp());
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get appName =>
      dotenv.env['APP_NAME']?.trim().isNotEmpty == true
          ? dotenv.env['APP_NAME']!
          : 'Jobs ClickOn';

  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000/api/v1';

  static String get webBaseUrl =>
      dotenv.env['WEB_BASE_URL'] ?? 'http://127.0.0.1:8000';

  static String resolveMediaUrl(String? value) {
    final String raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';

    final Uri? parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) {
      return raw;
    }

    if (raw.startsWith('//')) {
      final String scheme = Uri.tryParse(webBaseUrl)?.scheme ?? 'https';
      return '$scheme:$raw';
    }

    final String origin = _originFrom(
      webBaseUrl.isNotEmpty ? webBaseUrl : apiBaseUrl,
    );
    if (origin.isEmpty) {
      return raw;
    }

    return Uri.parse('$origin/').resolve(raw).toString();
  }

  static int get requestTimeoutSeconds =>
      int.tryParse(dotenv.env['REQUEST_TIMEOUT_SECONDS'] ?? '') ?? 30;

  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';

  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? '';

  static String get firebaseMessagingSenderId =>
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';

  static String get firebaseDatabaseUrl =>
      dotenv.env['FIREBASE_DATABASE_URL'] ?? '';

  static String get firebaseAppIdAndroid =>
      dotenv.env['FIREBASE_APP_ID_ANDROID'] ?? '';

  static String get firebaseAppIdIos => dotenv.env['FIREBASE_APP_ID_IOS'] ?? '';

  static String _originFrom(String value) {
    final Uri? parsed = Uri.tryParse(value);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return '';
    }
    final String portSegment = parsed.hasPort ? ':${parsed.port}' : '';
    return '${parsed.scheme}://${parsed.host}$portSegment';
  }
}

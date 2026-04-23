import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../config/app_env.dart';
import '../core/messaging/app_tag_message.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/stitch_theme.dart';
import '../features/home/home_shell.dart';

class InternalTaskApp extends StatelessWidget {
  const InternalTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSettingsStore,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('vi', 'VN'),
          supportedLocales: const <Locale>[
            Locale('vi', 'VN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          title:
              appSettingsStore.settings.brandName.isNotEmpty
                  ? appSettingsStore.settings.brandName
                  : AppEnv.appName,
          color: StitchTheme.bg,
          theme: StitchTheme.light(),
          themeMode: ThemeMode.light,
          builder: (BuildContext context, Widget? child) {
            final MediaQueryData media = MediaQuery.of(context);
            final TextScaler scaler = media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.15,
            );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: StitchTheme.surface,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: MediaQuery(
                  data: media.copyWith(textScaler: scaler),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      child ?? const SizedBox.shrink(),
                      const AppTagMessageOverlay(),
                    ],
                  ),
                ),
              ),
            );
          },
          home: const HomeShell(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../config/app_env.dart';
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
          title: appSettingsStore.settings.brandName.isNotEmpty
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
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: MediaQuery(
                data: media.copyWith(textScaler: scaler),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const HomeShell(),
        );
      },
    );
  }
}

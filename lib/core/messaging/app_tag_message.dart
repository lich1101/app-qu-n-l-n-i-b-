import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';

/// Thông báo ngắn dạng tag phía trên màn hình (thay SnackBar đáy, tránh che FAB).
class AppTagMessage {
  AppTagMessage._();

  static final ValueNotifier<AppTagMessageState?> _notifier =
      ValueNotifier<AppTagMessageState?>(null);
  static Timer? _timer;

  static void show(String message, {Duration? duration, bool isError = false}) {
    final String trimmed = message.trim();
    if (trimmed.isEmpty) return;
    _timer?.cancel();
    _notifier.value = AppTagMessageState(message: trimmed, isError: isError);
    final Duration d = duration ?? const Duration(seconds: 4);
    _timer = Timer(d, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _notifier.value = null;
  }
}

class AppTagMessageState {
  const AppTagMessageState({required this.message, this.isError = false});

  final String message;
  final bool isError;
}

/// Neo dưới status bar; đặt trong [Stack] (sau [child] route để luôn nổi trên).
class AppTagMessageOverlay extends StatelessWidget {
  const AppTagMessageOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTagMessageState?>(
      valueListenable: AppTagMessage._notifier,
      builder: (BuildContext context, AppTagMessageState? value, Widget? _) {
        if (value == null) {
          return const SizedBox.shrink();
        }
        final double top = MediaQuery.paddingOf(context).top + 8;
        final Color bg =
            value.isError ? StitchTheme.dangerStrong : StitchTheme.textMain;
        return Positioned(
          left: 16,
          right: 16,
          top: top,
          child: Material(
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            color: bg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      value.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: AppTagMessage.hide,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

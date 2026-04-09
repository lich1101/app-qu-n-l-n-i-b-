import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';

/// Nền trang form full-screen (kiểu Winmap: xám nhạt).
class StitchFormPageBackground extends StatelessWidget {
  const StitchFormPageBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StitchTheme.formPageBackground,
      child: child,
    );
  }
}

/// Khối section dạng strip trắng, viền dưới (Winmap `_sectionContainer`).
class StitchFormSection extends StatelessWidget {
  const StitchFormSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.margin = const EdgeInsets.only(bottom: 8),
    this.showBottomBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(
                  color: StitchTheme.formSectionDivider.withValues(alpha: 0.65),
                ),
              )
            : null,
      ),
      child: child,
    );
  }
}

/// Tiêu đề section: icon primary + chữ đậm (~16).
class StitchFormSectionHeader extends StatelessWidget {
  const StitchFormSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: StitchTheme.formSelectionIconBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: StitchTheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(icon, color: StitchTheme.primaryStrong, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: StitchTheme.textMain,
                height: 1.25,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Hàng chọn (picker): nền primary nhạt, viền, icon box + title/subtitle + chevron.
class StitchSelectionRow extends StatelessWidget {
  const StitchSelectionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon = Icons.touch_app_outlined,
    this.onTap,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData leadingIcon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        enabled ? StitchTheme.textMain : StitchTheme.textMuted;
    final Color sub =
        enabled ? StitchTheme.textMuted : StitchTheme.textSubtle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: enabled
                ? StitchTheme.formSelectionFill
                : StitchTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? StitchTheme.formSelectionBorder
                  : StitchTheme.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: StitchTheme.formSelectionIconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  leadingIcon,
                  color: StitchTheme.primaryStrong,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: fg,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null &&
                        subtitle!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: sub,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? StitchTheme.textSubtle : StitchTheme.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh nút dưới cùng (Hủy + Lưu / gửi).
class StitchFormBottomBar extends StatelessWidget {
  const StitchFormBottomBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.onSecondary,
    this.secondaryLabel = 'Hủy',
    this.primaryStyle,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final VoidCallback? onSecondary;
  final String secondaryLabel;
  final ButtonStyle? primaryStyle;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: StitchTheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StitchTheme.surface,
          border: Border(
            top: BorderSide(
              color: StitchTheme.formSectionDivider.withValues(alpha: 0.9),
            ),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: StitchTheme.textMain.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: <Widget>[
                if (onSecondary != null) ...<Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: primaryLoading ? null : onSecondary,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: StitchTheme.inputBorder),
                      ),
                      child: Text(secondaryLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: onSecondary != null ? 1 : 1,
                  child: FilledButton(
                    onPressed: primaryLoading ? null : onPrimary,
                    style:
                        primaryStyle ??
                        FilledButton.styleFrom(
                          backgroundColor: StitchTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                    child:
                        primaryLoading
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// AppBar chuẩn form: tiêu đề giữa, nút Đóng phải.
PreferredSizeWidget stitchFormAppBar({
  required BuildContext context,
  required String title,
  VoidCallback? onClose,
  List<Widget>? actions,
}) {
  return AppBar(
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    actions: <Widget>[
      if (actions != null) ...actions,
      TextButton(
        onPressed: onClose ?? () => Navigator.of(context).maybePop(),
        child: const Text('Đóng'),
      ),
      const SizedBox(width: 4),
    ],
  );
}

/// Padding đáy cho [ListView] khi có [StitchFormBottomBar] (~khoảng an toàn).
double stitchFormListBottomPaddingForBar() => 120;

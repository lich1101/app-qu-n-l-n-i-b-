import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';
import 'stitch_task_form_sheet.dart';

export 'stitch_task_form_sheet.dart'
    show
        kStitchTaskFormGap,
        stitchTaskFormSheetHeader,
        stitchTaskDateDecoration,
        stitchTaskDropdownDecoration,
        stitchTaskFormMessage;

/// Bo góc trên bottom sheet form (đồng bộ CRM / cơ hội / sản phẩm).
const double kStitchFormSheetTopRadius = 28;

/// Khoảng cách giữa các ô trong form (alias ngắn).
double get kStitchFormGap => kStitchTaskFormGap;

BoxDecoration stitchFormSheetSurfaceDecoration() {
  return BoxDecoration(
    color: StitchTheme.surface,
    gradient: LinearGradient(
      colors: <Color>[
        Colors.white,
        StitchTheme.surface,
        StitchTheme.surfaceAlt.withValues(alpha: 0.4),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(kStitchFormSheetTopRadius),
    ),
    border: Border.all(color: StitchTheme.border.withValues(alpha: 0.72)),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: StitchTheme.textMain.withValues(alpha: 0.1),
        blurRadius: 28,
        offset: const Offset(0, -6),
      ),
    ],
  );
}

/// Thanh kéo trên cùng sheet.
Widget stitchFormSheetDragHandle() {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: StitchTheme.border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// Tiêu đề form trong sheet: icon + title + subtitle + nút đóng (giống «Thêm/Sửa khách hàng»).
class StitchFormSheetTitleBar extends StatelessWidget {
  const StitchFormSheetTitleBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white,
            StitchTheme.surface,
            StitchTheme.surfaceAlt.withValues(alpha: 0.32),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(kStitchFormSheetTopRadius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          stitchFormSheetDragHandle(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      StitchTheme.primarySoft,
                      StitchTheme.primary.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: StitchTheme.primary.withValues(alpha: 0.2),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: StitchTheme.primary.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(icon, color: StitchTheme.primaryStrong, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: StitchTheme.textMain,
                      ),
                    ),
                    if (subtitle != null &&
                        subtitle!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!.trim(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: StitchTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose ?? () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: StitchTheme.surfaceAlt,
                  foregroundColor: StitchTheme.textMuted,
                ),
                icon: const Icon(Icons.close_rounded, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chân sheet: Hủy + nút chính (đồng bộ CRM / sản phẩm).
class StitchFormSheetActions extends StatelessWidget {
  const StitchFormSheetActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.onCancel,
    this.secondaryLabel = 'Hủy',
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final VoidCallback? onCancel;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.98),
            StitchTheme.surface,
            StitchTheme.surfaceAlt.withValues(alpha: 0.46),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel ?? () => Navigator.of(context).pop(),
                child: Text(secondaryLabel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: primaryLoading ? null : onPrimary,
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
    );
  }
}

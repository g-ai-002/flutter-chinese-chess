import 'package:flutter/material.dart';

/// 状态胶囊：淡底细边的圆角标语，对局状态条与棋钟条共用。
///
/// [filled] 为 true 时用实心底色配 [onAccent] 文字（如「将军」），
/// 否则用 [accent] 的淡底与描边，[active] 控制淡底与描边的浓度。
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.accent,
    required this.child,
    this.filled = false,
    this.active = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
  });

  final Color accent;
  final Widget child;
  final bool filled;
  final bool active;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: filled
            ? accent
            : accent.withValues(alpha: active ? 0.10 : 0.04),
        borderRadius: BorderRadius.circular(20),
        border: filled
            ? null
            : Border.all(
                color: active
                    ? accent.withValues(alpha: 0.45)
                    : colors.outline.withValues(alpha: 0.6),
              ),
      ),
      child: child,
    );
  }
}

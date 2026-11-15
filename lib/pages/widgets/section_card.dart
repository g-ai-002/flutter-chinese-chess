import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// 设置页、残局页等信息卡片的统一容器。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.trailing,
    this.radius = 14,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;
  final Widget? trailing;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: padding,
      decoration: panelDecoration(colors, radius: radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: colors.primary),
                const SizedBox(width: 8),
              ],
              Text(title, style: theme.textTheme.titleSmall),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

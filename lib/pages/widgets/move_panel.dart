import 'package:flutter/material.dart';

import '../../models/move_record.dart';
import 'move_list.dart';

/// 棋谱侧栏：标题、手数、棋谱列表与底部说明，对局页与复盘页共用。
class MovePanel extends StatelessWidget {
  const MovePanel({
    super.key,
    required this.history,
    required this.footer,
    this.highlightIndex,
    this.onTapIndex,
  });

  final List<MoveRecord> history;

  /// 底部说明文字，随对局或复盘进度变化。
  final String footer;

  final int? highlightIndex;
  final ValueChanged<int>? onTapIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(Icons.menu_book_outlined, size: 17, color: colors.primary),
                const SizedBox(width: 7),
                Text('棋谱', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${history.length} 手',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: colors.outline.withValues(alpha: 0.5)),
          Expanded(
            child: MoveList(
              history: history,
              highlightIndex: highlightIndex,
              onTapIndex: onTapIndex,
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          Divider(color: colors.outline.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Text(
              footer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

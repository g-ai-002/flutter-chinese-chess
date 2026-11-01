import 'package:flutter/material.dart';

import '../../game/engine/board_utils.dart';
import '../../game/game_controller.dart';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';

/// 对局状态条：行棋方、AI 思考中、将军提示与执子信息。
class GameStatusBar extends StatelessWidget {
  const GameStatusBar({
    super.key,
    required this.controller,
    required this.humanSide,
  });

  final GameController controller;
  final int humanSide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final side = controller.board.sideToMove;
    final sideColor = sideColorOf(side);
    final isAiMode = controller.mode == GameMode.vsAi;
    final puzzle = controller.puzzle;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: sideColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sideColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: sideColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${sideName(side)}行棋',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: sideColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (controller.thinking)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI 思考中',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          )
        else if (controller.inCheck)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '将军',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          )
        else if (isAiMode && controller.aiInsight != null)
          Tooltip(
            message:
                '节点 ${controller.aiInsight!.nodes} · '
                '评分 ${controller.aiInsight!.score}',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.memory_rounded,
                  size: 13,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  controller.aiInsight!.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        if (puzzle != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '限 ${puzzle.mateIn} 步 · 剩 ${controller.remainingMoves ?? 0} 步',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Text(
            isAiMode ? (humanSide == red ? '你执红' : '你执黑') : '同屏对弈',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

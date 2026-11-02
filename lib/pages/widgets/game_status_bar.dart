import 'package:flutter/material.dart';

import '../../game/ai_player.dart';
import '../../game/engine/board_utils.dart';
import '../../game/game_controller.dart';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';
import 'status_chip.dart';

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

    return SizedBox(
      height: 30,
      child: Row(
        children: [
          StatusChip(
            accent: sideColor,
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
          Flexible(flex: 4, child: _status(theme)),
          const Spacer(),
          if (puzzle != null)
            StatusChip(
              accent: colors.primaryContainer,
              filled: true,
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
      ),
    );
  }

  /// 行棋方右侧的即时状态：思考中 > 提示 > 将军 > 引擎摘要 > 开局。
  Widget _status(ThemeData theme) {
    if (controller.thinking) {
      return _ThinkingLabel(color: theme.colorScheme.onSurfaceVariant);
    }
    if (controller.hintLoading) {
      return const _HintLabel(loading: true);
    }
    final hint = controller.hintNotation;
    if (hint != null) {
      return _HintLabel(text: '提示 $hint');
    }
    if (controller.inCheck) {
      return StatusChip(
        accent: theme.colorScheme.primary,
        filled: true,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          '将军',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      );
    }
    final insight = controller.aiInsight;
    if (controller.mode == GameMode.vsAi && insight != null) {
      return _InsightLabel(insight: insight);
    }
    final opening = controller.opening;
    if (opening != null) {
      final next = opening.next;
      return Tooltip(
        message: opening.note ?? '',
        child: StatusChip(
          accent: theme.colorScheme.tertiary,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 13,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '开局 · ${opening.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (next != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '试走 $next',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// 走子提示：搜索中显示转圈，完成后显示建议着法。
class _HintLabel extends StatelessWidget {
  const _HintLabel({this.text, this.loading = false});

  final String? text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFFC08A2E);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: accent),
          )
        else
          const Icon(Icons.lightbulb_outline, size: 14, color: accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            loading ? '正在寻找提示' : text ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// AI 思考中的转圈与文案。
class _ThinkingLabel extends StatelessWidget {
  const _ThinkingLabel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'AI 思考中',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// 引擎摘要：层数与用时，悬停可看节点数与评分。
class _InsightLabel extends StatelessWidget {
  const _InsightLabel({required this.insight});

  final AiInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: insight.detail,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.memory_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              insight.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

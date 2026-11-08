import 'package:flutter/material.dart';

import '../../game/engine/board_utils.dart';
import '../../game/game_controller.dart';
import '../../models/game_models.dart';
import '../../models/move_record.dart';
import '../../theme/app_theme.dart';
import 'board_hud.dart';
import 'status_chip.dart';

/// 走子提示与「寻找提示」共用的金色。
const Color _hintColor = Color(0xFFC08A2E);

/// 对局状态区：行棋方、上一手、将军提示、走子提示与引擎摘要。
///
/// 用 [Wrap] 排布，窄屏或侧栏里自动换行，不会因为提示变长而溢出；
/// 紧凑模式下只保留行棋方与一条最需要立刻知道的信息。
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
    if (HudScope.compactOf(context)) return _compactChip(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final side = controller.board.sideToMove;
    final sideColor = sideColorOf(side);
    final history = controller.history;
    final lastMove = history.isEmpty ? null : history.last;
    final puzzle = controller.puzzle;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
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
        _status(context),
        if (lastMove != null) _LastMoveChip(record: lastMove),
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
            controller.mode == GameMode.vsAi
                ? (humanSide == red ? '你执红' : '你执黑')
                : '同屏对弈',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  /// 行棋方右侧的即时状态：思考中 > 提示 > 将军 > 引擎摘要。
  Widget _status(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (controller.thinking) {
      return _StatusInfo(
        text: 'AI 思考中',
        color: colors.onSurfaceVariant,
        loading: true,
      );
    }
    if (controller.hintLoading) {
      return const _StatusInfo(
        text: '正在寻找提示',
        color: _hintColor,
        loading: true,
      );
    }
    final hint = controller.hintNotation;
    if (hint != null) {
      return _StatusInfo(
        icon: Icons.lightbulb_outline,
        text: '提示 $hint',
        color: _hintColor,
      );
    }
    if (controller.inCheck) {
      return StatusChip(
        accent: colors.primary,
        filled: true,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          '将军',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      );
    }
    final insight = controller.aiInsight;
    if (controller.mode == GameMode.vsAi && insight != null) {
      return _StatusInfo(
        icon: Icons.memory_rounded,
        text: insight.label,
        color: colors.onSurfaceVariant,
        tooltip: insight.detail,
      );
    }
    return const SizedBox.shrink();
  }

  /// 紧凑模式：行棋方与即时状态合并成一行，余下的横向空间留给操作按钮。
  Widget _compactChip(BuildContext context) {
    final theme = Theme.of(context);
    final side = controller.board.sideToMove;
    final sideColor = sideColorOf(side);
    final detail = _compactDetail();
    final text = detail == null
        ? '${sideName(side)}行棋'
        : '${sideName(side)}行棋 · $detail';
    return StatusChip(
      accent: sideColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: sideColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: sideColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 紧凑模式下只保留最需要立刻知道的一条信息。
  String? _compactDetail() {
    if (controller.thinking) return 'AI 思考中';
    if (controller.hintLoading) return '寻找提示';
    final hint = controller.hintNotation;
    if (hint != null) return '提示 $hint';
    if (controller.inCheck) return '将军';
    final puzzle = controller.puzzle;
    if (puzzle != null) return '剩 ${controller.remainingMoves ?? 0} 步';
    return null;
  }
}

/// 上一手的中文记法，让不打开棋谱也能确认对手刚走了什么。
class _LastMoveChip extends StatelessWidget {
  const _LastMoveChip({required this.record});

  final MoveRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return StatusChip(
      accent: colors.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '上一手',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            record.notation,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 提示、思考与引擎摘要共用的一行：可选图标或转圈，文本超出省略。
class _StatusInfo extends StatelessWidget {
  const _StatusInfo({
    required this.text,
    required this.color,
    this.icon,
    this.loading = false,
    this.tooltip,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool loading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
          )
        else if (icon != null)
          Icon(icon, size: 13, color: color),
        if (loading || icon != null) const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    final message = tooltip;
    return message == null ? row : Tooltip(message: message, child: row);
  }
}

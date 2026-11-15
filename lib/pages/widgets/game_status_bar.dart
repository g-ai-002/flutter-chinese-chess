import 'package:material_ui/material_ui.dart';

import '../../game/engine/board_utils.dart';
import '../../game/game_controller.dart';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';
import 'board_hud.dart';
import 'status_chip.dart';

/// 对局状态区：行棋方、将军提示、走子提示与引擎摘要。
///
/// 只放此刻最需要知道的信息，执子与难度交给标题副标题，上一手交给棋谱；
/// 用 [Wrap] 排布，窄屏或侧栏里自动换行，不会因为提示变长而溢出。
/// 紧凑模式下只保留行棋方与一条最需要立刻知道的信息。
class GameStatusBar extends StatelessWidget {
  const GameStatusBar({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final side = controller.board.sideToMove;
    final sideColor = sideColorOf(side);
    final compact = HudScope.compactOf(context);
    final status = _statusData(context, compact: compact);
    if (compact) {
      final detail =
          status?.text ??
          (controller.puzzle == null
              ? null
              : '剩 ${controller.remainingMoves ?? 0} 步');
      return _SideChip(
        sideColor: sideColor,
        compact: true,
        text: detail == null
            ? '${sideName(side)}行棋'
            : '${sideName(side)}行棋 · $detail',
      );
    }
    final puzzle = controller.puzzle;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _SideChip(
          sideColor: sideColor,
          compact: false,
          text: '${sideName(side)}行棋',
        ),
        if (status != null) _statusChip(context, status),
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
          ),
      ],
    );
  }

  /// 即时状态按优先级收敛到一条：思考中 > 提示 > 将军 > 引擎摘要。
  /// 紧凑模式去掉引擎摘要与独立的残局胶囊，把宽度留给操作按钮。
  _Status? _statusData(BuildContext context, {required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    if (controller.thinking) {
      return _Status('AI 思考中', colors.onSurfaceVariant, loading: true);
    }
    if (controller.hintLoading) {
      return const _Status('正在寻找提示', appHintAccent, loading: true);
    }
    final hint = controller.hintNotation;
    if (hint != null) {
      return _Status('提示 $hint', appHintAccent, icon: Icons.lightbulb_outline);
    }
    if (controller.inCheck) {
      return _Status('将军', colors.primary, filled: true);
    }
    final insight = controller.aiInsight;
    if (!compact && controller.mode == GameMode.vsAi && insight != null) {
      return _Status(
        insight.label,
        colors.onSurfaceVariant,
        icon: Icons.memory_rounded,
        tooltip: insight.detail,
      );
    }
    return null;
  }

  /// 将军用实心胶囊强调，其余状态沿用带图标的文字行。
  Widget _statusChip(BuildContext context, _Status status) {
    if (!status.filled) {
      return _StatusInfo(
        text: status.text,
        color: status.color,
        icon: status.icon,
        loading: status.loading,
        tooltip: status.tooltip,
      );
    }
    final theme = Theme.of(context);
    return StatusChip(
      accent: status.color,
      filled: true,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Text(
        status.text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// 行棋方胶囊：左侧圆点标出阵营，紧凑模式把即时状态并入同一行。
class _SideChip extends StatelessWidget {
  const _SideChip({
    required this.sideColor,
    required this.text,
    required this.compact,
  });

  final Color sideColor;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dot = compact ? 7.0 : 8.0;
    final style =
        (compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
            ?.copyWith(color: sideColor, fontWeight: FontWeight.w600);
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return StatusChip(
      accent: sideColor,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 5,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: sideColor, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 6 : 7),
          if (compact) Flexible(child: label) else label,
        ],
      ),
    );
  }
}

/// 一条即时状态：文案、颜色与可选的图标、转圈和悬停提示。
class _Status {
  const _Status(
    this.text,
    this.color, {
    this.icon,
    this.loading = false,
    this.filled = false,
    this.tooltip,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool loading;
  final bool filled;
  final String? tooltip;
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

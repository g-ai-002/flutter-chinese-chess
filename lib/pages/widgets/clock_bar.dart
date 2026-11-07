import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/engine/board_utils.dart';
import '../../game/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'status_chip.dart';

/// 棋钟条：并列展示双方剩余时间，当前行棋方高亮，不足一分钟转为警示色。
class ClockBar extends StatefulWidget {
  const ClockBar({super.key, required this.controller});

  final GameController controller;

  @override
  State<ClockBar> createState() => _ClockBarState();
}

class _ClockBarState extends State<ClockBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  /// 只在本方走棋时结算并刷新，终局后定时器空转不再触发重建。
  void _tick() {
    final controller = widget.controller;
    if (!(controller.clock?.isRunning ?? false)) return;
    controller.tickClock();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = widget.controller.clock;
    if (clock == null) return const SizedBox.shrink();
    final active = widget.controller.result == null ? clock.activeSide : null;
    // 用 Wrap 排布：侧栏这类窄空间里两块棋钟自动上下错开，不会横向溢出。
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final side in const [red, black])
          _ClockChip(
            side: side,
            remainingMs: clock.remainingMs(side),
            active: active == side,
          ),
      ],
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({
    required this.side,
    required this.remainingMs,
    required this.active,
  });

  final int side;
  final int remainingMs;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final urgent = remainingMs <= 60000;
    final accent = urgent ? colors.error : sideColorOf(side);
    return StatusChip(
      accent: accent,
      active: active,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            side == red ? '红' : '黑',
            style: theme.textTheme.labelSmall?.copyWith(
              color: active || urgent ? accent : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatClock(remainingMs),
            style: theme.textTheme.labelMedium?.copyWith(
              color: active || urgent ? accent : colors.onSurface,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

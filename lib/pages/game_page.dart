import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/xiangqi_game.dart';
import '../game/engine/board_utils.dart';
import '../game/game_controller.dart';
import '../models/game_models.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/game_status_bar.dart';
import 'widgets/move_list.dart';

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.mode,
    required this.difficulty,
    required this.humanSide,
  });

  final GameMode mode;
  final Difficulty difficulty;
  final int humanSide;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _controller;
  late final XiangqiGame _game;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _controller = GameController(
      mode: widget.mode,
      difficulty: widget.difficulty,
      humanSide: widget.humanSide,
      showHints: settings.showHints,
    );
    _game = XiangqiGame(controller: _controller);
    _controller.addListener(_onControllerChanged);
    LogService.info(
      '开始对局: ${widget.mode.label}, 难度 ${widget.difficulty.label}, '
      '执${widget.humanSide == red ? '红' : '黑'}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.start();
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final result = _controller.result;
    if (result != null && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showGameResultDialog(
          context,
          result: result,
          moveCount: _controller.history.length,
          onRestart: () {
            _resultShown = false;
            _controller.restart();
          },
        );
      });
    }
  }

  Future<void> _confirmResign() async {
    if (await confirmResign(context)) _controller.resign();
  }

  void _showMoveSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.55,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => MoveList(
            history: _controller.history,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
          ),
        ),
      ),
    );
  }

  void _showRules() => showRulesDialog(context);

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.mode.label),
            Text(
              widget.mode == GameMode.vsAi
                  ? '${widget.difficulty.label} · ${widget.humanSide == red ? '执红' : '执黑'}'
                  : '同屏对弈',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '行棋规则',
            onPressed: _showRules,
            icon: const Icon(Icons.help_outline, size: 21),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 880;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (wide) return _buildWide();
                return _buildCompact();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildWide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                GameStatusBar(
                  controller: _controller,
                  humanSide: widget.humanSide,
                ),
                const SizedBox(height: 10),
                Expanded(child: _buildBoard()),
                const SizedBox(height: 8),
                _buildActions(showMoves: false),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(width: 292, child: _buildSidePanel()),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: GameStatusBar(
            controller: _controller,
            humanSide: widget.humanSide,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildBoard(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: _buildActions(showMoves: true),
        ),
      ],
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = math.min(constraints.maxWidth, 660.0);
        var height = width * 10 / 9;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * 9 / 10;
        }
        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GameWidget<XiangqiGame>(
                key: const ValueKey('xiangqi-board'),
                game: _game,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions({required bool showMoves}) {
    final isAi = widget.mode == GameMode.vsAi;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      children: [
        _ActionButton(
          icon: Icons.undo_rounded,
          label: '悔棋',
          onPressed: _controller.canUndo ? _controller.undo : null,
        ),
        _ActionButton(
          icon: Icons.refresh_rounded,
          label: '重开',
          onPressed: _controller.restart,
        ),
        if (showMoves)
          _ActionButton(
            icon: Icons.format_list_bulleted_rounded,
            label: '棋谱',
            onPressed: _showMoveSheet,
          ),
        if (isAi)
          _ActionButton(
            icon: Icons.flag_outlined,
            label: '认输',
            onPressed: _controller.result == null ? _confirmResign : null,
          ),
      ],
    );
  }

  Widget _buildSidePanel() {
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
                  '${_controller.history.length} 手',
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
              history: _controller.history,
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          Divider(color: colors.outline.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Text(
              '提示：点击棋子选中，再点目标位置落子。',
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onPressed != null;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        foregroundColor: enabled ? colors.onSurface : colors.onSurfaceVariant,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: enabled ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

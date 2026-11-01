import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/xiangqi_game.dart';
import '../game/engine/board_utils.dart';
import '../game/game_controller.dart';
import '../game/opening_book.dart';
import '../game/puzzles.dart';
import '../models/game_models.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../services/sound_service.dart';
import 'review_page.dart';
import 'widgets/board_stage.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/game_status_bar.dart';
import 'widgets/move_list.dart';
import 'widgets/move_panel.dart';

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.mode,
    required this.difficulty,
    required this.humanSide,
    this.puzzle,
  });

  final GameMode mode;
  final Difficulty difficulty;
  final int humanSide;

  /// 残局关卡，非空时以残局规则判定胜负。
  final Puzzle? puzzle;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _controller;
  late final XiangqiGame _game;
  bool _resultShown = false;
  int _seenMoves = 0;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _controller = GameController(
      mode: widget.mode,
      difficulty: widget.difficulty,
      humanSide: widget.humanSide,
      showHints: settings.showHints,
      showOpeningHints: settings.showOpeningHints,
      puzzle: widget.puzzle,
    );
    _game = XiangqiGame(view: _controller, skin: settings.boardSkin);
    _controller.addListener(_onControllerChanged);
    final puzzle = widget.puzzle;
    LogService.info(
      puzzle == null
          ? '开始对局: ${widget.mode.label}, 难度 ${widget.difficulty.label}, '
                '执${widget.humanSide == red ? '红' : '黑'}'
          : '开始残局: ${puzzle.title}, 限 ${puzzle.mateIn} 步',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.skin = Provider.of<SettingsProvider>(context).boardSkin;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _syncMoveFeedback();
    final result = _controller.result;
    if (result == null || _resultShown) return;
    _resultShown = true;
    SoundService.play(MoveFeedback.end);
    final puzzle = widget.puzzle;
    final cleared = puzzle != null && _controller.puzzleCleared;
    final moves = _controller.humanMoves;
    if (puzzle != null && cleared) {
      context.read<SettingsProvider>().recordPuzzleCleared(puzzle.id, moves);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (puzzle == null) {
        showGameResultDialog(
          context,
          result: result,
          moveCount: _controller.history.length,
          onRestart: _restart,
          onReview: _openReview,
        );
        return;
      }
      showPuzzleResultDialog(
        context,
        cleared: cleared,
        reason: result.reason,
        moves: moves,
        mateIn: puzzle.mateIn,
        onRetry: _restart,
        onNext: cleared ? _nextPuzzleBuilder(puzzle) : null,
      );
    });
  }

  /// 新增着法时按将军、吃子、普通落子给出反馈；悔棋或重开后重置计数。
  void _syncMoveFeedback() {
    final history = _controller.history;
    if (history.length <= _seenMoves) {
      _seenMoves = history.length;
      return;
    }
    for (var i = _seenMoves; i < history.length; i++) {
      final record = history[i];
      SoundService.play(
        record.givesCheck
            ? MoveFeedback.check
            : record.isCapture
            ? MoveFeedback.capture
            : MoveFeedback.move,
      );
    }
    _seenMoves = history.length;
  }

  void _restart() {
    _resultShown = false;
    _controller.restart();
  }

  /// 终局后进入复盘，棋谱快照与开局布局一并带过去。
  void _openReview() {
    final result = _controller.result;
    final title = widget.mode == GameMode.twoPlayers
        ? widget.mode.label
        : '${widget.mode.label} · ${widget.difficulty.label}';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(
          title: title,
          result: result == null ? null : '${result.title}（${result.reason}）',
          moves: List.of(_controller.history),
          layout: _controller.board.startLayout,
          startSide: _controller.board.startSide,
        ),
      ),
    );
  }

  /// 通关后跳到下一关，已是最后一关时返回 null。
  VoidCallback? _nextPuzzleBuilder(Puzzle current) {
    final index = kPuzzles.indexWhere((item) => item.id == current.id);
    if (index < 0 || index + 1 >= kPuzzles.length) return null;
    final next = kPuzzles[index + 1];
    return () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GamePage(
            mode: GameMode.puzzle,
            difficulty: widget.difficulty,
            humanSide: kPuzzleHumanSide,
            puzzle: next,
          ),
        ),
      );
    };
  }

  void _showPuzzleHint() {
    final puzzle = widget.puzzle;
    if (puzzle == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('提示 · ${puzzle.title}'),
        content: Text(puzzle.hint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
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
    final puzzle = widget.puzzle;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(puzzle?.title ?? widget.mode.label),
            Text(
              puzzle != null
                  ? '残局挑战 · 红先 ${puzzle.mateIn} 步杀'
                  : widget.mode == GameMode.vsAi
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
                _buildStatus(),
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
          child: _buildStatus(),
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

  Widget _buildStatus() {
    final opening = _controller.opening;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameStatusBar(controller: _controller, humanSide: widget.humanSide),
        if (opening != null) ...[
          const SizedBox(height: 8),
          _OpeningHint(info: opening),
        ],
      ],
    );
  }

  Widget _buildBoard() =>
      BoardStage(game: _game, gameKey: const ValueKey('xiangqi-board'));

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
        if (widget.puzzle != null)
          _ActionButton(
            icon: Icons.lightbulb_outline,
            label: '提示',
            onPressed: _showPuzzleHint,
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

  Widget _buildSidePanel() =>
      MovePanel(history: _controller.history, footer: '提示：点击棋子选中，再点目标位置落子。');
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

/// 开局提示：显示当前开局名称与推荐着法。
class _OpeningHint extends StatelessWidget {
  const _OpeningHint({required this.info});

  final OpeningInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final next = info.next;
    final hint = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_outlined, size: 13, color: colors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '开局 · ${info.name}',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          if (next != null) ...[
            const SizedBox(width: 8),
            Text(
              '试走 $next',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
    final note = info.note;
    if (note == null) return hint;
    return Tooltip(message: note, child: hint);
  }
}

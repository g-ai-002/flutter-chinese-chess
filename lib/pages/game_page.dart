import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/xiangqi_game.dart';
import '../game/engine/board_utils.dart';
import '../game/game_controller.dart';
import '../game/puzzles.dart';
import '../models/game_models.dart';
import '../models/saved_game.dart';
import '../providers/settings_provider.dart';
import '../services/game_history_service.dart';
import '../services/log_service.dart';
import '../services/sound_service.dart';
import '../utils/board_display_mode.dart';
import 'review_page.dart';
import 'widgets/board_hud.dart';
import 'widgets/board_stage.dart';
import 'widgets/clock_bar.dart';
import 'widgets/game_dialogs.dart';
import 'widgets/game_status_bar.dart';
import 'widgets/move_list.dart';

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
  late DateTime _startedAt;
  late String _gameId;
  bool _resultShown = false;
  int _seenMoves = 0;

  @override
  void initState() {
    super.initState();
    _resetGameIdentity();
    final settings = context.read<SettingsProvider>();
    _controller = GameController(
      mode: widget.mode,
      difficulty: widget.difficulty,
      humanSide: widget.humanSide,
      showHints: settings.showHints,
      showOpeningHints: settings.showOpeningHints,
      timeControl: settings.timeControl,
      puzzle: widget.puzzle,
    );
    _game = XiangqiGame(view: _controller, skin: settings.boardSkin);
    _controller.addListener(_onControllerChanged);
    final puzzle = widget.puzzle;
    final clock = _controller.timeControl;
    final clockText = clock.isTimed ? '，棋钟 ${clock.label}' : '';
    LogService.info(
      puzzle == null
          ? '开始对局: ${widget.mode.label}, 难度 ${widget.difficulty.label}, '
                '执${widget.humanSide == red ? '红' : '黑'}$clockText'
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
    if (result == null) {
      // 悔棋或重开后回到对局中，下一次终局仍需弹出结果。
      _resultShown = false;
      return;
    }
    if (_resultShown) return;
    _resultShown = true;
    SoundService.play(MoveFeedback.end);
    final puzzle = widget.puzzle;
    if (puzzle == null) _archiveGame(result);
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
    _resetGameIdentity();
    _controller.restart();
  }

  void _resetGameIdentity() {
    _startedAt = DateTime.now();
    _gameId = 'game_${_startedAt.microsecondsSinceEpoch}';
  }

  String get _gameTitle => widget.mode == GameMode.twoPlayers
      ? widget.mode.label
      : '${widget.mode.label} · ${widget.difficulty.label}';

  /// 终局后写入最近对局；悔棋后重判沿用同一 id，覆盖旧结果而不是新增一条。
  void _archiveGame(GameResult result) {
    if (_controller.history.isEmpty) return;
    unawaited(
      GameHistoryService.instance.record(
        SavedGame(
          id: _gameId,
          title: _gameTitle,
          endedAt: DateTime.now(),
          layout: _controller.board.startLayout,
          startSide: _controller.board.startSide,
          moves: _controller.history,
          result: '${result.title}（${result.reason}）',
        ),
      ),
    );
  }

  /// 终局后进入复盘，棋谱快照与开局布局一并带过去。
  void _openReview() {
    final result = _controller.result;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(
          title: _gameTitle,
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
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text('棋谱', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      '${_controller.history.length} 手',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: MoveList(
                  history: _controller.history,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRules() => showRulesDialog(context);

  /// 副标题：残局看步数，常规对局看难度与执子，限时对局补上棋钟。
  String _subtitle(Puzzle? puzzle) {
    if (puzzle != null) return '残局挑战 · 红先 ${puzzle.mateIn} 步杀';
    final control = _controller.timeControl;
    final clock = control.isTimed ? ' · ${control.label}' : '';
    if (widget.mode == GameMode.vsAi) {
      final side = widget.humanSide == red ? '执红' : '执黑';
      return '${widget.difficulty.label} · $side$clock';
    }
    return '同屏对弈$clock';
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 没有 AppBar 与上下状态条，棋盘独占整块安全区；提示信息以悬浮卡片挂在四周。
    return BoardDisplayMode(
      child: Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, board) => BoardHud(
              board: board!,
              topStart: _buildTitle(),
              topEnd: _buildTools(),
              bottomStart: GameStatusBar(
                controller: _controller,
                humanSide: widget.humanSide,
              ),
              bottomEnd: _buildActions(),
            ),
            child: _buildBoard(),
          ),
        ),
      ),
    );
  }

  /// 标题卡：返回 + 对局名称与副标题，不再占用独立的应用栏。
  Widget _buildTitle() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.puzzle?.title ?? widget.mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              _HudSubtitle(
                text: _subtitle(widget.puzzle),
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 右上角工具卡：棋钟与规则入口，未设棋钟时只留规则按钮。
  Widget _buildTools() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_controller.clock != null) ...[
          // 侧栏较窄时棋钟自行折行，避免把卡片撑破。
          Flexible(child: ClockBar(controller: _controller)),
          const SizedBox(width: 6),
        ],
        IconButton(
          tooltip: '行棋规则',
          onPressed: _showRules,
          icon: const Icon(Icons.help_outline, size: 20),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        ),
      ],
    );
  }

  Widget _buildBoard() => RepaintBoundary(
    child: BoardStage(game: _game, gameKey: const ValueKey('xiangqi-board')),
  );

  Widget _buildActions() {
    final isAi = widget.mode == GameMode.vsAi;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 2,
      runSpacing: 2,
      children: [
        _ActionButton(
          icon: Icons.undo_rounded,
          label: '悔棋',
          onPressed: _controller.canUndo ? _controller.undo : null,
        ),
        _ActionButton(
          icon: Icons.refresh_rounded,
          label: '重开',
          onPressed: _restart,
        ),
        if (widget.puzzle != null)
          _ActionButton(
            icon: Icons.lightbulb_outline,
            label: '提示',
            onPressed: _showPuzzleHint,
          ),
        if (isAi)
          _ActionButton(
            icon: Icons.lightbulb_outline,
            label: _controller.hintLoading ? '思考中' : '提示',
            onPressed: _controller.canInteractive && !_controller.hintLoading
                ? _controller.requestHint
                : null,
          ),
        if (isAi)
          _ActionButton(
            icon: Icons.flag_outlined,
            label: '认输',
            onPressed: _controller.result == null ? _confirmResign : null,
          ),
        _ActionButton(
          icon: Icons.format_list_bulleted_rounded,
          label: '棋谱',
          onPressed: _showMoveSheet,
        ),
      ],
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
    // 紧凑 HUD 里只留图标，一串按钮并排也不会把状态卡挤下去。
    final compact = HudScope.compactOf(context);
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(compact ? 38 : 54, compact ? 38 : 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 4,
          vertical: compact ? 0 : 2,
        ),
        foregroundColor: enabled ? colors.onSurface : colors.onSurfaceVariant,
      ),
      child: compact
          ? Icon(icon, size: 21)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    color: enabled ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
    return compact ? Tooltip(message: label, child: button) : button;
  }
}

/// 标题卡副标题：紧凑 HUD 里隐藏，给标题留出更多宽度。
class _HudSubtitle extends StatelessWidget {
  const _HudSubtitle({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (HudScope.compactOf(context)) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontSize: 11, color: color),
    );
  }
}

import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import '../models/move_record.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';
import 'ai_player.dart';
import 'board_state.dart';
import 'board_view.dart';
import 'engine/board_utils.dart';
import 'engine/rules.dart';
import 'match_clock.dart';
import 'opening_book.dart';
import 'puzzles.dart';

/// 对局控制器：选择、落子、AI 回合、悔棋、棋钟与终局判定。
class GameController extends ChangeNotifier implements BoardView {
  GameController({
    required this.mode,
    required this.difficulty,
    required this.humanSide,
    AiMoveProvider? aiMove,
    XiangqiBoard? board,
    this.showHints = true,
    this.showOpeningHints = true,
    TimeControl timeControl = TimeControl.none,
    this.puzzle,
  }) : timeControl = puzzle == null ? timeControl : TimeControl.none,
       board = board ?? _initialBoard(puzzle),
       _aiMove = aiMove ?? AiPlayer.chooseMove;

  static XiangqiBoard _initialBoard(Puzzle? puzzle) => puzzle == null
      ? XiangqiBoard.initial()
      : XiangqiBoard.fromLayout(puzzle.layout);

  final GameMode mode;
  final Difficulty difficulty;
  final int humanSide;
  @override
  final bool showHints;
  final bool showOpeningHints;

  /// 本局的时间方案，残局固定为不限时。
  final TimeControl timeControl;
  final Puzzle? puzzle;
  @override
  final XiangqiBoard board;
  final AiMoveProvider _aiMove;

  /// 限时对局的计时簿记，不限时或残局为 null。
  late final ClockTracker? _tracker = timeControl.isTimed
      ? ClockTracker(timeControl)
      : null;

  /// 限时对局的棋钟，供界面展示双方剩余时间。
  MatchClock? get clock => _tracker?.clock;

  @override
  int? selected;
  @override
  List<int> legalTargets = const [];
  bool thinking = false;
  @override
  bool inCheck = false;
  GameResult? result;

  int _serial = 0;
  bool _disposed = false;

  bool get isHumanTurn =>
      mode == GameMode.twoPlayers || board.sideToMove == humanSide;

  bool get canInteractive => result == null && !thinking && isHumanTurn;

  bool get canUndo {
    if (board.history.isEmpty) return false;
    if (mode == GameMode.twoPlayers) return true;
    return board.history.any((record) => sideOf(record.piece) == humanSide);
  }

  @override
  List<MoveRecord> get history => board.history;

  /// 当前开局提示，残局与关闭提示时为 null。
  OpeningInfo? get opening {
    if (!showOpeningHints || mode == GameMode.puzzle) return null;
    return OpeningBook.lookup(board);
  }

  /// 人类已落子的步数，残局按此计算剩余步数。
  int get humanMoves =>
      board.history.where((record) => sideOf(record.piece) == humanSide).length;

  int? get remainingMoves {
    final limit = puzzle?.mateIn;
    if (limit == null) return null;
    final left = limit - humanMoves;
    return left < 0 ? 0 : left;
  }

  /// 残局挑战是否已通关。
  bool get puzzleCleared => puzzle != null && result?.winner == humanSide;

  /// 页面挂载后调用；人类执黑时由 AI 先行。
  void start() {
    inCheck = XiangqiRules.isKingInCheck(board.cells, board.sideToMove);
    _syncClock();
    _notify();
    if (mode != GameMode.twoPlayers && board.sideToMove != humanSide) _think();
  }

  /// 界面定时调用：把当前行棋方的实际用时结算给棋钟，超时即判负。
  /// [elapsed] 仅测试用，传入时不再读取真实耗时。
  void tickClock([Duration? elapsed]) {
    if (result != null) return;
    final expired = _tracker?.settle(elapsed);
    if (expired == null) return;
    LogService.warning('${sideName(expired)}超时判负');
    _finish(GameResult(winner: opponentOf(expired), reason: '超时'));
  }

  @override
  void tapCell(int index) {
    if (!canInteractive) return;
    final piece = board.cells[index];
    if (selected != null && legalTargets.contains(index)) {
      _play(selected!, index);
      return;
    }
    if (piece != 0 && sideOf(piece) == board.sideToMove) {
      if (selected == index) {
        _clearSelection();
        return;
      }
      selected = index;
      legalTargets = [
        for (final move in XiangqiRules.legalMovesFrom(board.cells, index))
          moveTo(move),
      ];
      _notify();
      return;
    }
    if (selected != null) _clearSelection();
  }

  void undo() {
    if (!canUndo) return;
    _serial++;
    thinking = false;
    do {
      board.undoLast();
    } while (mode != GameMode.twoPlayers &&
        board.sideToMove != humanSide &&
        board.history.isNotEmpty);
    result = null;
    _tracker?.rewind(keepMoves: board.history.length, side: board.sideToMove);
    _clearSelection(notify: false);
    inCheck = XiangqiRules.isKingInCheck(board.cells, board.sideToMove);
    LogService.info('悔棋，当前轮到${sideName(board.sideToMove)}');
    _notify();
  }

  void restart() {
    _serial++;
    board.reset();
    thinking = false;
    result = null;
    inCheck = false;
    _tracker?.restart(board.sideToMove);
    _clearSelection(notify: false);
    LogService.info('重新开始对局');
    _notify();
    if (mode != GameMode.twoPlayers && board.sideToMove != humanSide) _think();
  }

  void resign() {
    if (result != null) return;
    _serial++;
    thinking = false;
    _finish(GameResult(winner: opponentOf(humanSide), reason: '认输'));
  }

  /// 收敛终局：记录结果、停表、收掉残留选中，写日志并通知界面。
  void _finish(GameResult outcome) {
    result = outcome;
    _tracker?.stop();
    _clearSelection(notify: false);
    LogService.info('对局结束: ${outcome.title} (${outcome.reason})');
    _notify();
  }

  void _clearSelection({bool notify = true}) {
    selected = null;
    legalTargets = const [];
    if (notify) _notify();
  }

  void _play(int from, int to) {
    // 先结算本步用时，超时则以超时结束，不再落子。
    tickClock();
    if (result != null) return;
    final record = board.tryApply(from, to);
    if (record == null) return;
    _tracker?.mark();
    selected = null;
    legalTargets = const [];
    final captureText = record.isCapture
        ? ' 吃${pieceName(record.captured)}'
        : '';
    final checkText = record.givesCheck ? ' 将军' : '';
    LogService.info(
      '落子 ${sideName(sideOf(record.piece))} ${record.notation}'
      '$captureText$checkText',
    );
    _afterMove();
  }

  void _afterMove() {
    final status = XiangqiRules.positionStatus(board.cells, board.sideToMove);
    inCheck = status.inCheck;
    final outcome = _adjudicate(
      hasLegalMoves: status.hasLegalMoves,
      inCheck: status.inCheck,
    );
    if (outcome != null) {
      _finish(outcome);
      return;
    }
    _syncClock();
    _notify();
    if (mode != GameMode.twoPlayers && board.sideToMove != humanSide) _think();
  }

  /// 把计时交给当前行棋方；终局时停表。
  void _syncClock() {
    final tracker = _tracker;
    if (tracker == null) return;
    if (result == null) {
      tracker.resume(board.sideToMove);
    } else {
      tracker.stop();
    }
  }

  /// 依据规则裁定终局；对局继续时返回 null。
  GameResult? _adjudicate({
    required bool hasLegalMoves,
    required bool inCheck,
  }) {
    if (!hasLegalMoves) {
      return GameResult(
        winner: opponentOf(board.sideToMove),
        reason: inCheck ? '绝杀' : '困毙',
      );
    }
    if (board.repetitionCount >= 3) {
      final checker = board.perpetualCheckingSide;
      return checker == null
          ? const GameResult(winner: null, reason: '三次重复局面')
          : GameResult(winner: opponentOf(checker), reason: '长将判负');
    }
    if (board.noCapturePlies >= AppConstants.drawNoCapturePlies) {
      return const GameResult(winner: null, reason: '六十回合无吃子');
    }
    if (puzzle != null && humanMoves >= puzzle!.mateIn) {
      return GameResult(winner: opponentOf(humanSide), reason: '超出限定步数');
    }
    return null;
  }

  Future<void> _think() async {
    if (thinking || result != null) return;
    thinking = true;
    _notify();
    final serial = ++_serial;
    final side = board.sideToMove;
    final stopwatch = Stopwatch()..start();
    AiReply? reply;
    try {
      reply = await _aiMove(Uint8List.fromList(board.cells), side, difficulty);
    } catch (e, stack) {
      LogService.error('AI 搜索失败', e, stack);
    }
    if (_disposed || serial != _serial) return;

    thinking = false;
    stopwatch.stop();
    if (reply != null) {
      LogService.info(
        'AI 完成: 深度 ${reply.depth}, 节点 ${reply.nodes}, '
        '评分 ${reply.score}, 用时 ${stopwatch.elapsedMilliseconds}ms',
      );
    }

    final move = reply?.move ?? -1;
    final fallback = XiangqiRules.legalMoves(board.cells, side);
    if (fallback.isEmpty) {
      _afterMove();
      return;
    }
    if (move < 0 || !fallback.contains(move)) {
      LogService.warning('AI 未返回合法着法，改用兜底着法');
      final pick = fallback.first;
      _play(moveFrom(pick), moveTo(pick));
      return;
    }
    _play(moveFrom(move), moveTo(move));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _serial++;
    super.dispose();
  }
}

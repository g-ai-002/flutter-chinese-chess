import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import '../models/move_record.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';
import 'ai_player.dart';
import 'board_state.dart';
import 'engine/board_utils.dart';
import 'engine/rules.dart';
import 'puzzles.dart';

/// 对局控制器：选择、落子、AI 回合、悔棋、终局判定。
class GameController extends ChangeNotifier {
  GameController({
    required this.mode,
    required this.difficulty,
    required this.humanSide,
    AiMoveProvider? aiMove,
    XiangqiBoard? board,
    this.showHints = true,
    this.puzzle,
  }) : board = board ?? _initialBoard(puzzle),
       _aiMove = aiMove ?? AiPlayer.chooseMove;

  static XiangqiBoard _initialBoard(Puzzle? puzzle) => puzzle == null
      ? XiangqiBoard.initial()
      : XiangqiBoard.fromLayout(puzzle.layout);

  final GameMode mode;
  final Difficulty difficulty;
  final int humanSide;
  final bool showHints;
  final Puzzle? puzzle;
  final XiangqiBoard board;
  final AiMoveProvider _aiMove;

  int? selected;
  List<int> legalTargets = const [];
  bool thinking = false;
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

  List<MoveRecord> get history => board.history;

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
    _notify();
    if (mode != GameMode.twoPlayers && board.sideToMove != humanSide) _think();
  }

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
    _clearSelection(notify: false);
    LogService.info('重新开始对局');
    _notify();
    if (mode != GameMode.twoPlayers && board.sideToMove != humanSide) _think();
  }

  void resign() {
    if (result != null) return;
    _serial++;
    thinking = false;
    result = GameResult(winner: opponentOf(humanSide), reason: '认输');
    LogService.info('对局结束: ${result!.title} (${result!.reason})');
    _notify();
  }

  void _clearSelection({bool notify = true}) {
    selected = null;
    legalTargets = const [];
    if (notify) _notify();
  }

  void _play(int from, int to) {
    if (result != null) return;
    if (!XiangqiRules.isLegalMove(board.cells, board.sideToMove, from, to)) {
      return;
    }
    final record = board.applyMove(from, to);
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
    if (!status.hasLegalMoves) {
      result = GameResult(
        winner: opponentOf(board.sideToMove),
        reason: status.inCheck ? '绝杀' : '困毙',
      );
    } else if (board.repetitionCount >= 3) {
      final checker = board.perpetualCheckingSide;
      result = checker == null
          ? const GameResult(winner: null, reason: '三次重复局面')
          : GameResult(winner: opponentOf(checker), reason: '长将判负');
    } else if (board.noCapturePlies >= AppConstants.drawNoCapturePlies) {
      result = const GameResult(winner: null, reason: '六十回合无吃子');
    } else if (puzzle != null && humanMoves >= puzzle!.mateIn) {
      result = GameResult(winner: opponentOf(humanSide), reason: '超出限定步数');
    }
    _notify();
    if (result != null) {
      LogService.info('对局结束: ${result!.title} (${result!.reason})');
      return;
    }
    if (mode != GameMode.twoPlayers && board.sideToMove != humanSide) _think();
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

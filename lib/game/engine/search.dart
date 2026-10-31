import 'dart:math';
import 'dart:typed_data';

import 'board_utils.dart';
import 'evaluation.dart';
import 'rules.dart';

class SearchResult {
  const SearchResult({
    required this.move,
    required this.score,
    required this.nodes,
    required this.depth,
  });

  /// 编码后的着法，无棋可走时为 -1。
  final int move;
  final int score;
  final int nodes;
  final int depth;
}

/// 负极大值搜索 + Alpha-Beta 剪枝。
class XiangqiSearch {
  XiangqiSearch._();

  static const int _mateScore = 1000000;
  static const int _infinity = 1 << 30;

  static SearchResult bestMove({
    required Uint8List cells,
    required int side,
    required int depth,
    int randomness = 0,
    int? seed,
    int maxNodes = 700000,
  }) {
    final board = Uint8List.fromList(cells);
    final context = _SearchContext(maxNodes);
    final moves = XiangqiRules.legalMoves(board, side);
    if (moves.isEmpty) {
      return SearchResult(
        move: -1,
        score: -_mateScore,
        nodes: context.nodes,
        depth: depth,
      );
    }
    _orderMoves(board, moves);

    final random = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
    final scores = <int, int>{};
    var alpha = -_infinity;
    var bestMove = moves.first;
    var bestScore = -_infinity;

    for (final move in moves) {
      final captured = _applyMove(board, move);
      final int score;
      if (randomness > 0) {
        score = -_negamax(
          board,
          opponentOf(side),
          depth - 1,
          -_infinity,
          _infinity,
          1,
          context,
        );
      } else {
        score = -_negamax(
          board,
          opponentOf(side),
          depth - 1,
          -_infinity,
          -alpha,
          1,
          context,
        );
      }
      _restoreMove(board, move, captured);
      if (context.aborted) break;

      scores[move] = score;
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      if (score > alpha) alpha = score;
    }

    var chosen = bestMove;
    if (randomness > 0 && scores.isNotEmpty) {
      final threshold = bestScore - randomness;
      final candidates = [
        for (final entry in scores.entries)
          if (entry.value >= threshold) entry.key,
      ];
      if (candidates.isNotEmpty) {
        chosen = candidates[random.nextInt(candidates.length)];
      }
    }

    return SearchResult(
      move: chosen,
      score: scores[chosen] ?? bestScore,
      nodes: context.nodes,
      depth: depth,
    );
  }

  static int _negamax(
    Uint8List cells,
    int side,
    int depth,
    int alpha,
    int beta,
    int ply,
    _SearchContext context,
  ) {
    context.nodes++;
    if (context.nodes >= context.maxNodes) {
      context.aborted = true;
      return XiangqiEvaluation.evaluateForSide(cells, side);
    }
    if ((context.nodes & 1023) == 0 && context.expired) {
      context.aborted = true;
      return XiangqiEvaluation.evaluateForSide(cells, side);
    }
    if (depth <= 0) {
      return _quiescence(cells, side, alpha, beta, ply, context, 0);
    }

    final moves = XiangqiRules.pseudoMoves(cells, side);
    if (moves.isEmpty) return -_mateScore + ply;
    _orderMoves(cells, moves);

    var best = -_infinity;
    var legalCount = 0;
    final enemy = opponentOf(side);
    for (final move in moves) {
      final captured = _applyMove(cells, move);
      if (!XiangqiRules.isPositionSafe(cells, side)) {
        _restoreMove(cells, move, captured);
        continue;
      }
      legalCount++;
      final score = -_negamax(
        cells,
        enemy,
        depth - 1,
        -beta,
        -alpha,
        ply + 1,
        context,
      );
      _restoreMove(cells, move, captured);
      if (context.aborted) return best == -_infinity ? score : best;
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    if (legalCount == 0) return -_mateScore + ply;
    return best;
  }

  /// 静态搜索：只展开吃子，消除固定深度搜索的"地平线效应"。
  /// 被将军时不能停招，需展开所有应将着法。
  static int _quiescence(
    Uint8List cells,
    int side,
    int alpha,
    int beta,
    int ply,
    _SearchContext context,
    int qdepth,
  ) {
    context.nodes++;
    if (context.nodes >= context.maxNodes) {
      context.aborted = true;
      return XiangqiEvaluation.evaluateForSide(cells, side);
    }
    if ((context.nodes & 1023) == 0 && context.expired) {
      context.aborted = true;
      return XiangqiEvaluation.evaluateForSide(cells, side);
    }

    final inCheck = XiangqiRules.isKingInCheck(cells, side);
    if (qdepth >= 8) {
      return XiangqiEvaluation.evaluateForSide(cells, side);
    }
    if (!inCheck) {
      final standPat = XiangqiEvaluation.evaluateForSide(cells, side);
      if (standPat >= beta) return beta;
      if (standPat > alpha) alpha = standPat;
      if (qdepth >= 4) return alpha;
    }

    final candidates = <int>[];
    for (final move in XiangqiRules.pseudoMoves(cells, side)) {
      if (inCheck || cells[moveTo(move)] != 0) candidates.add(move);
    }
    if (candidates.isEmpty) {
      return inCheck ? -_mateScore + ply : alpha;
    }
    _orderMoves(cells, candidates);

    final enemy = opponentOf(side);
    var best = -_infinity;
    for (final move in candidates) {
      final captured = _applyMove(cells, move);
      if (!XiangqiRules.isPositionSafe(cells, side)) {
        _restoreMove(cells, move, captured);
        continue;
      }
      final score = -_quiescence(
        cells,
        enemy,
        -beta,
        -alpha,
        ply + 1,
        context,
        qdepth + 1,
      );
      _restoreMove(cells, move, captured);
      if (context.aborted) return inCheck && best > -_infinity ? best : alpha;
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    if (inCheck && best == -_infinity) return -_mateScore + ply;
    return inCheck ? best : alpha;
  }

  /// 搜索中落子，返回被吃的棋子，供 [_restoreMove] 还原。
  static int _applyMove(Uint8List cells, int move) {
    final from = moveFrom(move);
    final to = moveTo(move);
    final captured = cells[to];
    cells[to] = cells[from];
    cells[from] = 0;
    return captured;
  }

  static void _restoreMove(Uint8List cells, int move, int captured) {
    final from = moveFrom(move);
    final to = moveTo(move);
    cells[from] = cells[to];
    cells[to] = captured;
  }

  /// 吃子优先排序：被吃子价值越高、己方棋子价值越低，越先搜索。
  /// 全为静默着法时保留生成顺序，避免无意义的排序开销。
  static void _orderMoves(Uint8List cells, List<int> moves) {
    if (moves.length < 2) return;
    final priorities = <int, int>{};
    var hasCapture = false;
    for (final move in moves) {
      final priority = _movePriority(cells, move);
      priorities[move] = priority;
      if (priority > 0) hasCapture = true;
    }
    if (!hasCapture) return;
    moves.sort((a, b) => priorities[b]! - priorities[a]!);
  }

  static int _movePriority(Uint8List cells, int move) {
    final from = moveFrom(move);
    final to = moveTo(move);
    final captured = cells[to];
    if (captured == 0) return 0;
    final attacker = cells[from];
    return XiangqiEvaluation.pieceValues[typeOf(captured)] * 10 -
        XiangqiEvaluation.pieceValues[typeOf(attacker)];
  }
}

class _SearchContext {
  _SearchContext(this.maxNodes);

  final int maxNodes;
  int nodes = 0;
  bool aborted = false;
  final Stopwatch _watch = Stopwatch()..start();

  bool get expired => _watch.elapsedMilliseconds > 8000;
}

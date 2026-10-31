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
      final from = moveFrom(move);
      final to = moveTo(move);
      final piece = board[from];
      final captured = board[to];
      board[to] = piece;
      board[from] = 0;
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
      board[from] = piece;
      board[to] = captured;
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
    if (depth <= 0) return XiangqiEvaluation.evaluateForSide(cells, side);

    final moves = XiangqiRules.pseudoMoves(cells, side);
    if (moves.isEmpty) return -_mateScore + ply;
    _orderMoves(cells, moves);

    var best = -_infinity;
    var legalCount = 0;
    final enemy = opponentOf(side);
    for (final move in moves) {
      final from = moveFrom(move);
      final to = moveTo(move);
      final piece = cells[from];
      final captured = cells[to];
      cells[to] = piece;
      cells[from] = 0;
      if (XiangqiRules.kingsFacing(cells) ||
          XiangqiRules.isKingInCheck(cells, side)) {
        cells[from] = piece;
        cells[to] = captured;
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
      cells[from] = piece;
      cells[to] = captured;
      if (context.aborted) return best == -_infinity ? score : best;
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    if (legalCount == 0) return -_mateScore + ply;
    return best;
  }

  /// 吃子优先排序：被吃子价值越高、己方棋子价值越低，越先搜索。
  static void _orderMoves(Uint8List cells, List<int> moves) {
    moves.sort((a, b) => _movePriority(cells, b) - _movePriority(cells, a));
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

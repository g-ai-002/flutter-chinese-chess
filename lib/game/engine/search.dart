import 'dart:math';
import 'dart:typed_data';

import 'board_utils.dart';
import 'evaluation.dart';
import 'mate_score.dart';
import 'rules.dart';
import 'search_board.dart';
import 'transposition_table.dart';

class SearchResult {
  const SearchResult({
    required this.move,
    required this.score,
    required this.nodes,
    required this.depth,
  });

  final int move;
  final int score;
  final int nodes;

  final int depth;
}

/// 搜索预算：节点上限与思考时限，先到先停。
class SearchBudget {
  SearchBudget({required this.maxNodes, required this.timeLimitMillis})
    : _watch = Stopwatch()..start();

  static const int defaultMaxNodes = 700000;

  static const int defaultTimeLimitMillis = 4000;

  final int maxNodes;
  final int timeLimitMillis;
  final Stopwatch _watch;
  int nodes = 0;
  bool _spent = false;

  /// 预算已耗尽，搜索应尽快收回。
  bool get spent => _spent;

  /// 记一个节点，返回预算是否已耗尽；时限每 512 个节点检查一次。
  bool consume() {
    if (_spent) return true;
    nodes++;
    if (nodes >= maxNodes || _timedOut()) _spent = true;
    return _spent;
  }

  bool _timedOut() =>
      timeLimitMillis > 0 &&
      (nodes & 511) == 0 &&
      _watch.elapsedMilliseconds >= timeLimitMillis;
}

/// 负极大值搜索 + Alpha-Beta 剪枝，配合置换表与迭代加深。
class XiangqiSearch {
  XiangqiSearch._();

  static SearchResult bestMove({
    required Uint8List cells,
    required int side,
    required int depth,
    int randomness = 0,
    int? seed,
    int maxNodes = SearchBudget.defaultMaxNodes,
    int timeLimitMillis = SearchBudget.defaultTimeLimitMillis,
  }) => _Searcher(
    SearchBoard(cells, side),
    SearchBudget(maxNodes: maxNodes, timeLimitMillis: timeLimitMillis),
  ).run(maxDepth: depth, randomness: randomness, seed: seed);
}

class _RootPass {
  const _RootPass({
    required this.move,
    required this.score,
    required this.scores,
    required this.complete,
  });

  final int move;
  final int score;
  final Map<int, int> scores;
  final bool complete;
}

class _Searcher {
  _Searcher(this._board, this._budget);

  static const int _infinity = 1 << 30;

  static const int _killerPlies = 64;

  static const int _historyCap = 1 << 16;

  static const int _ttMoveWeight = 1 << 20;
  static const int _captureWeight = 1 << 18;
  static const int _killerWeight = 100000;
  static const int _secondKillerWeight = 90000;

  final SearchBoard _board;
  final SearchBudget _budget;
  final TranspositionTable _table = TranspositionTable();
  final Int32List _killers = Int32List(_killerPlies * 2);
  final Int32List _history = Int32List(cellCount * cellCount);

  Int32List _sortedMoves = Int32List(96);
  Int32List _sortedScores = Int32List(96);

  SearchResult run({
    required int maxDepth,
    required int randomness,
    int? seed,
  }) {
    final moves = XiangqiRules.legalMoves(_board.cells, _board.sideToMove);
    if (moves.isEmpty) {
      return SearchResult(
        move: -1,
        score: -MateScore.mate,
        nodes: _budget.nodes,
        depth: 0,
      );
    }

    final ordered = List<int>.of(moves);
    var bestMove = ordered.first;
    var bestScore = 0;
    var scores = const <int, int>{};
    var completed = 0;

    // 至少跑完第一层，避免调用方传入 0 层时拿不到任何评估。
    final limit = maxDepth < 1 ? 1 : maxDepth;
    for (var depth = 1; depth <= limit; depth++) {
      if (_budget.spent) break;
      final pass = _searchRoot(depth, ordered, randomness);
      // 未跑完的一轮只在还没有完整结果时兜底，避免半轮分数误导挑档。
      if (pass.move >= 0 && (pass.complete || completed == 0)) {
        bestMove = pass.move;
        bestScore = pass.score;
        scores = pass.scores;
        if (pass.complete) completed = depth;
      }
      if (!pass.complete) break;
      _sortRoot(ordered, scores);
      // 已确认杀棋，再加深也不会改变最优着法。
      if (bestScore > MateScore.threshold) break;
    }

    final chosen = _chooseRoot(bestMove, scores, bestScore, randomness, seed);
    return SearchResult(
      move: chosen,
      score: scores[chosen] ?? bestScore,
      nodes: _budget.nodes,
      depth: completed,
    );
  }

  int _chooseRoot(
    int bestMove,
    Map<int, int> scores,
    int bestScore,
    int randomness,
    int? seed,
  ) {
    if (randomness <= 0 || scores.isEmpty) return bestMove;
    final threshold = bestScore - randomness;
    final candidates = [
      for (final entry in scores.entries)
        if (entry.value >= threshold) entry.key,
    ];
    if (candidates.isEmpty) return bestMove;
    final random = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
    return candidates[random.nextInt(candidates.length)];
  }

  _RootPass _searchRoot(int depth, List<int> ordered, int randomness) {
    final scores = <int, int>{};
    var alpha = -_infinity;
    var bestMove = -1;
    var bestScore = -_infinity;
    var complete = true;

    for (final move in ordered) {
      _board.make(move);
      // 随机档不收敛窗口，保留全部着法的分数供后续挑档。
      final score = -_negamax(
        depth - 1,
        -_infinity,
        randomness > 0 ? _infinity : -alpha,
        1,
      );
      _board.unmake();
      if (_budget.spent) {
        complete = false;
        break;
      }
      scores[move] = score;
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      if (randomness <= 0 && score > alpha) alpha = score;
    }

    return _RootPass(
      move: bestMove,
      score: bestScore,
      scores: scores,
      complete: complete,
    );
  }

  void _sortRoot(List<int> ordered, Map<int, int> scores) {
    if (scores.length < 2) return;
    ordered.sort(
      (a, b) => (scores[b] ?? -_infinity) - (scores[a] ?? -_infinity),
    );
  }

  int _negamax(int depth, int alpha, int beta, int ply) {
    if (_budget.consume()) return _evaluate();
    if (depth <= 0) return _quiescence(alpha, beta, ply, 0);

    final side = _board.sideToMove;
    final alphaOrig = alpha;
    final entry = _table.lookup(_board.hashLow, _board.hashHigh, ply);
    if (entry != null &&
        entry.depth >= depth &&
        _cutoffAllowed(entry, alpha, beta)) {
      return entry.score;
    }

    final moves = XiangqiRules.pseudoMoves(_board.cells, side);
    if (moves.isEmpty) return -MateScore.at(ply);
    _orderMoves(moves, ply, entry?.move ?? -1);

    var best = -_infinity;
    var bestMove = -1;
    var legalCount = 0;
    for (final move in moves) {
      final quiet = _board.cells[moveTo(move)] == 0;
      _board.make(move);
      if (!_board.isPositionSafe(side)) {
        _board.unmake();
        continue;
      }
      legalCount++;
      final score = -_negamax(depth - 1, -beta, -alpha, ply + 1);
      _board.unmake();
      if (_budget.spent) return best == -_infinity ? score : best;
      if (score > best) {
        best = score;
        bestMove = move;
      }
      if (score > alpha) alpha = score;
      if (alpha >= beta) {
        if (quiet) _recordCutoff(move, ply, depth);
        break;
      }
    }
    if (legalCount == 0) return -MateScore.at(ply);

    _table.store(
      low: _board.hashLow,
      high: _board.hashHigh,
      ply: ply,
      depth: depth,
      score: best,
      bound: best <= alphaOrig
          ? TranspositionTable.upper
          : best >= beta
          ? TranspositionTable.lower
          : TranspositionTable.exact,
      move: bestMove,
    );
    return best;
  }

  static bool _cutoffAllowed(TtEntry entry, int alpha, int beta) {
    switch (entry.bound) {
      case TranspositionTable.lower:
        return entry.score >= beta;
      case TranspositionTable.upper:
        return entry.score <= alpha;
      default:
        return true;
    }
  }

  /// 静态搜索：只展开吃子，消除固定深度搜索的"地平线效应"。
  /// 被将军时不能停招，需展开所有应将着法。
  int _quiescence(int alpha, int beta, int ply, int qdepth) {
    if (_budget.consume()) return _evaluate();
    if (qdepth >= 8) return _evaluate();

    final side = _board.sideToMove;
    final inCheck = _board.isKingInCheck(side);
    if (!inCheck) {
      final standPat = _evaluate();
      if (standPat >= beta) return beta;
      if (standPat > alpha) alpha = standPat;
      if (qdepth >= 4) return alpha;
    }

    final candidates = <int>[];
    for (final move in XiangqiRules.pseudoMoves(_board.cells, side)) {
      if (inCheck || _board.cells[moveTo(move)] != 0) candidates.add(move);
    }
    if (candidates.isEmpty) {
      return inCheck ? -MateScore.at(ply) : alpha;
    }
    _orderMoves(candidates, ply, -1);

    var best = -_infinity;
    for (final move in candidates) {
      _board.make(move);
      if (!_board.isPositionSafe(side)) {
        _board.unmake();
        continue;
      }
      final score = -_quiescence(-beta, -alpha, ply + 1, qdepth + 1);
      _board.unmake();
      if (_budget.spent) return inCheck && best > -_infinity ? best : alpha;
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    if (inCheck && best == -_infinity) return -MateScore.at(ply);
    return inCheck ? best : alpha;
  }

  int _evaluate() =>
      XiangqiEvaluation.evaluateForSide(_board.cells, _board.sideToMove);

  void _recordCutoff(int move, int ply, int depth) {
    if (ply >= _killerPlies) return;
    final index = ply * 2;
    if (_killers[index] != move) {
      _killers[index + 1] = _killers[index];
      _killers[index] = move;
    }
    final weighted = _history[move] + depth * depth;
    _history[move] = weighted > _historyCap ? _historyCap : weighted;
  }

  void _orderMoves(List<int> moves, int ply, int ttMove) {
    final count = moves.length;
    if (count < 2) return;
    if (count > _sortedMoves.length) _growSorting(count);
    for (var index = 0; index < count; index++) {
      final move = moves[index];
      _sortedMoves[index] = move;
      _sortedScores[index] = _priority(move, ply, ttMove);
    }
    // 插入排序：着法数量不大，且上一轮结果已让高分着法靠前。
    for (var index = 1; index < count; index++) {
      final move = _sortedMoves[index];
      final score = _sortedScores[index];
      var cursor = index - 1;
      while (cursor >= 0 && _sortedScores[cursor] < score) {
        _sortedMoves[cursor + 1] = _sortedMoves[cursor];
        _sortedScores[cursor + 1] = _sortedScores[cursor];
        cursor--;
      }
      _sortedMoves[cursor + 1] = move;
      _sortedScores[cursor + 1] = score;
    }
    for (var index = 0; index < count; index++) {
      moves[index] = _sortedMoves[index];
    }
  }

  void _growSorting(int count) {
    var size = _sortedMoves.length;
    while (size < count) {
      size *= 2;
    }
    _sortedMoves = Int32List(size);
    _sortedScores = Int32List(size);
  }

  int _priority(int move, int ply, int ttMove) {
    if (move == ttMove) return _ttMoveWeight;
    final captured = _board.cells[moveTo(move)];
    if (captured != 0) {
      final attacker = _board.cells[moveFrom(move)];
      return _captureWeight +
          XiangqiEvaluation.pieceValues[typeOf(captured)] * 10 -
          XiangqiEvaluation.pieceValues[typeOf(attacker)];
    }
    if (ply < _killerPlies) {
      final index = ply * 2;
      if (_killers[index] == move) return _killerWeight;
      if (_killers[index + 1] == move) return _secondKillerWeight;
    }
    return _history[move];
  }
}

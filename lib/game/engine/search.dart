import 'dart:math';
import 'dart:typed_data';

import 'board_utils.dart';
import 'evaluation.dart';
import 'rules.dart';
import 'transposition_table.dart';
import 'zobrist.dart';

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

  /// 实际完成搜索的层数，可能小于请求的层数。
  final int depth;
}

/// 负极大值搜索 + Alpha-Beta 剪枝，配合置换表与迭代加深。
class XiangqiSearch {
  XiangqiSearch._();

  /// 默认节点预算。
  static const int defaultMaxNodes = 700000;

  /// 默认思考时限（毫秒），先到先停。
  static const int defaultTimeLimitMillis = 4000;

  static SearchResult bestMove({
    required Uint8List cells,
    required int side,
    required int depth,
    int randomness = 0,
    int? seed,
    int maxNodes = defaultMaxNodes,
    int timeLimitMillis = defaultTimeLimitMillis,
  }) => _Searcher(
    cells,
    maxNodes,
    timeLimitMillis,
  ).run(side: side, maxDepth: depth, randomness: randomness, seed: seed);
}

/// 根节点一轮搜索的结果；[complete] 为 false 表示预算耗尽、只搜了一部分着法。
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
  _Searcher(Uint8List cells, int maxNodes, int timeLimitMillis)
    : cells = Uint8List.fromList(cells),
      _context = _SearchContext(maxNodes, timeLimitMillis);

  static const int _mateScore = 1000000;
  static const int _infinity = 1 << 30;

  /// 连杀分数超过该阈值即视为已找到杀棋，可以提前收工。
  static const int _mateThreshold = 999000;

  /// 杀手着法按层记录，两层足够覆盖大多数截断。
  static const int _killerPlies = 64;

  /// 历史启发的上限，保证不会盖过杀手着法与吃子着法的权重。
  static const int _historyCap = 1 << 16;

  /// 着法排序的临时缓冲区，只在一个节点的生成阶段使用，不跨递归。
  static const int _bufferSize = 192;

  final Uint8List cells;
  final _SearchContext _context;
  final TranspositionTable _table = TranspositionTable();
  final Int32List _killers = Int32List(_killerPlies * 2);
  final Int32List _history = Int32List(cellCount * cellCount);
  final Int32List _sortMoves = Int32List(_bufferSize);
  final Int32List _sortScores = Int32List(_bufferSize);

  int _hashLow = 0;
  int _hashHigh = 0;
  int _rootSide = red;

  SearchResult run({
    required int side,
    required int maxDepth,
    required int randomness,
    int? seed,
  }) {
    _rootSide = side;
    final hash = Zobrist.hashOf(cells, side);
    _hashLow = hash.low;
    _hashHigh = hash.high;
    final moves = XiangqiRules.legalMoves(cells, side);
    if (moves.isEmpty) {
      return SearchResult(
        move: -1,
        score: -_mateScore,
        nodes: _context.nodes,
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
      if (_context.exhausted) break;
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
      if (bestScore > _mateThreshold) break;
    }

    final chosen = _chooseRoot(bestMove, scores, bestScore, randomness, seed);
    return SearchResult(
      move: chosen,
      score: scores[chosen] ?? bestScore,
      nodes: _context.nodes,
      depth: completed,
    );
  }

  /// 随机档在接近最优的一批着法里随机挑选，其余档位直接用最优着法。
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

  /// 搜索一层根节点：逐个展开根着法，返回本轮最优着法与全部得分。
  _RootPass _searchRoot(int depth, List<int> ordered, int randomness) {
    final scores = <int, int>{};
    var alpha = -_infinity;
    var bestMove = -1;
    var bestScore = -_infinity;
    var complete = true;

    for (final move in ordered) {
      final captured = _apply(move);
      // 随机档不收敛窗口，保留全部着法的分数供后续挑档。
      final score = -_negamax(
        depth - 1,
        -_infinity,
        randomness > 0 ? _infinity : -alpha,
        1,
      );
      _restore(move, captured);
      if (_context.aborted) {
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

  /// 下一层先搜本轮得分高的着法，让 Alpha-Beta 更早截断。
  void _sortRoot(List<int> ordered, Map<int, int> scores) {
    if (scores.length < 2) return;
    ordered.sort(
      (a, b) => (scores[b] ?? -_infinity) - (scores[a] ?? -_infinity),
    );
  }

  int _negamax(int depth, int alpha, int beta, int ply) {
    _context.nodes++;
    if (_context.exhausted) {
      _context.aborted = true;
      return _evaluate(ply);
    }
    if (depth <= 0) return _quiescence(alpha, beta, ply, 0);

    final side = _sideAt(ply);
    final alphaOrig = alpha;
    if (_table.probe(_hashLow, _hashHigh, depth, alpha, beta, ply)) {
      return _table.score;
    }
    final ttMove = _table.bestMove;

    final moves = XiangqiRules.pseudoMoves(cells, side);
    if (moves.isEmpty) return -_mateScore + ply;
    _orderMoves(moves, ply, ttMove);

    var best = -_infinity;
    var bestMove = -1;
    var legalCount = 0;
    for (final move in moves) {
      final captured = _apply(move);
      if (!XiangqiRules.isPositionSafe(cells, side)) {
        _restore(move, captured);
        continue;
      }
      legalCount++;
      final score = -_negamax(depth - 1, -beta, -alpha, ply + 1);
      _restore(move, captured);
      if (_context.aborted) return best == -_infinity ? score : best;
      if (score > best) {
        best = score;
        bestMove = move;
      }
      if (score > alpha) alpha = score;
      if (alpha >= beta) {
        _recordCutoff(move, ply, depth, captured);
        break;
      }
    }
    if (legalCount == 0) return -_mateScore + ply;

    final flag = best <= alphaOrig
        ? TranspositionTable.upper
        : best >= beta
        ? TranspositionTable.lower
        : TranspositionTable.exact;
    _table.store(_hashLow, _hashHigh, depth, best, flag, bestMove, ply);
    return best;
  }

  /// 静态搜索：只展开吃子，消除固定深度搜索的"地平线效应"。
  /// 被将军时不能停招，需展开所有应将着法。
  int _quiescence(int alpha, int beta, int ply, int qdepth) {
    _context.nodes++;
    if (_context.exhausted) {
      _context.aborted = true;
      return _evaluate(ply);
    }

    final side = _sideAt(ply);
    final inCheck = XiangqiRules.isKingInCheck(cells, side);
    if (qdepth >= 8) return _evaluate(ply);
    if (!inCheck) {
      final standPat = _evaluate(ply);
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
    _orderMoves(candidates, ply, -1);

    var best = -_infinity;
    for (final move in candidates) {
      final captured = _apply(move);
      if (!XiangqiRules.isPositionSafe(cells, side)) {
        _restore(move, captured);
        continue;
      }
      final score = -_quiescence(-beta, -alpha, ply + 1, qdepth + 1);
      _restore(move, captured);
      if (_context.aborted) return inCheck && best > -_infinity ? best : alpha;
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    if (inCheck && best == -_infinity) return -_mateScore + ply;
    return inCheck ? best : alpha;
  }

  int _sideAt(int ply) => _rootSide ^ (ply & 1);

  int _evaluate(int ply) =>
      XiangqiEvaluation.evaluateForSide(cells, _sideAt(ply));

  /// 搜索中落子，返回被吃的棋子；同时增量更新局面键。
  int _apply(int move) {
    final from = moveFrom(move);
    final to = moveTo(move);
    final piece = cells[from];
    final captured = cells[to];
    _hashLow ^= Zobrist.lowKey(piece, from) ^ Zobrist.lowKey(piece, to);
    _hashHigh ^= Zobrist.highKey(piece, from) ^ Zobrist.highKey(piece, to);
    if (captured != 0) {
      _hashLow ^= Zobrist.lowKey(captured, to);
      _hashHigh ^= Zobrist.highKey(captured, to);
    }
    _hashLow ^= Zobrist.sideLowKey;
    _hashHigh ^= Zobrist.sideHighKey;
    cells[to] = piece;
    cells[from] = 0;
    return captured;
  }

  void _restore(int move, int captured) {
    final from = moveFrom(move);
    final to = moveTo(move);
    final piece = cells[to];
    _hashLow ^= Zobrist.sideLowKey;
    _hashHigh ^= Zobrist.sideHighKey;
    _hashLow ^= Zobrist.lowKey(piece, from) ^ Zobrist.lowKey(piece, to);
    _hashHigh ^= Zobrist.highKey(piece, from) ^ Zobrist.highKey(piece, to);
    if (captured != 0) {
      _hashLow ^= Zobrist.lowKey(captured, to);
      _hashHigh ^= Zobrist.highKey(captured, to);
    }
    cells[from] = piece;
    cells[to] = captured;
  }

  /// 记录截断着法：静默着法进杀手表与历史表，供同类局面优先搜索。
  void _recordCutoff(int move, int ply, int depth, int captured) {
    if (captured != 0 || ply >= _killerPlies) return;
    final index = ply * 2;
    if (_killers[index] != move) {
      _killers[index + 1] = _killers[index];
      _killers[index] = move;
    }
    final weighted = _history[move] + depth * depth;
    _history[move] = weighted > _historyCap ? _historyCap : weighted;
  }

  /// 着法排序：置换表着法 > 吃子 > 杀手着法 > 历史启发 > 其余静默着法。
  void _orderMoves(List<int> moves, int ply, int ttMove) {
    final count = moves.length;
    if (count < 2) return;
    if (count > _bufferSize) {
      moves.sort(
        (a, b) => _priority(b, ply, ttMove) - _priority(a, ply, ttMove),
      );
      return;
    }
    for (var index = 0; index < count; index++) {
      final move = moves[index];
      _sortMoves[index] = move;
      _sortScores[index] = _priority(move, ply, ttMove);
    }
    // 插入排序：着法数量不大，且上一轮结果已让高分着法靠前。
    for (var index = 1; index < count; index++) {
      final move = _sortMoves[index];
      final score = _sortScores[index];
      var cursor = index - 1;
      while (cursor >= 0 && _sortScores[cursor] < score) {
        _sortMoves[cursor + 1] = _sortMoves[cursor];
        _sortScores[cursor + 1] = _sortScores[cursor];
        cursor--;
      }
      _sortMoves[cursor + 1] = move;
      _sortScores[cursor + 1] = score;
    }
    for (var index = 0; index < count; index++) {
      moves[index] = _sortMoves[index];
    }
  }

  int _priority(int move, int ply, int ttMove) {
    if (move == ttMove) return 1 << 20;
    final to = moveTo(move);
    final captured = cells[to];
    if (captured != 0) {
      final attacker = cells[moveFrom(move)];
      return (1 << 18) +
          XiangqiEvaluation.pieceValues[typeOf(captured)] * 10 -
          XiangqiEvaluation.pieceValues[typeOf(attacker)];
    }
    if (ply < _killerPlies) {
      final index = ply * 2;
      if (_killers[index] == move) return 100000;
      if (_killers[index + 1] == move) return 90000;
    }
    return _history[move];
  }
}

class _SearchContext {
  _SearchContext(this.maxNodes, this.timeLimitMillis);

  final int maxNodes;
  final int timeLimitMillis;
  int nodes = 0;
  bool aborted = false;
  final Stopwatch _watch = Stopwatch()..start();

  /// 节点数或时间任一超限即视为耗尽，时间检查每 512 个节点做一次。
  bool get exhausted =>
      nodes >= maxNodes ||
      (timeLimitMillis > 0 &&
          (nodes & 511) == 0 &&
          _watch.elapsedMilliseconds >= timeLimitMillis);
}

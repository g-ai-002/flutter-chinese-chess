import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import 'engine/search.dart';

/// AI 搜索回包直接复用引擎结果，避免两套同构类型。
typedef AiReply = SearchResult;

typedef AiMoveProvider = Future<AiReply> Function(
  Uint8List cells,
  int side,
  Difficulty difficulty,
);

/// 走子提示：返回编码后的着法，无可用着法时返回 null。
typedef HintMoveProvider = Future<int?> Function(Uint8List cells, int side);

/// 一次 AI 搜索的摘要，供界面展示引擎状态。
class AiInsight {
  const AiInsight({required this.reply, required this.millis});

  /// 由搜索回包与实际耗时生成摘要。
  factory AiInsight.of(SearchResult reply, Duration elapsed) =>
      AiInsight(reply: reply, millis: elapsed.inMilliseconds);

  /// 引擎回包，层数、节点与评分都取自这里。
  final AiReply reply;

  /// 从发起搜索到拿回结果的真实耗时。
  final int millis;

  int get depth => reply.depth;
  int get nodes => reply.nodes;
  int get score => reply.score;

  /// 状态条上的紧凑文案，例如 `AI 第 5 层 · 1.8s`。
  String get label => 'AI 第 $depth 层 · ${(millis / 1000).toStringAsFixed(1)}s';

  /// 悬停提示：节点数与评分。
  String get detail => '节点 $nodes · 评分 $score';
}

class AiPlayer {
  AiPlayer._();

  /// 在独立 isolate 中搜索（Web 上自动退化为同线程执行）。
  static Future<AiReply> chooseMove(
    Uint8List cells,
    int side,
    Difficulty difficulty,
  ) {
    final limits = _limitsFor(difficulty);
    return compute(
      _runSearch,
      _AiRequest(
        Uint8List.fromList(cells),
        side,
        limits.depth,
        difficulty.randomness,
        limits.timeLimitMillis,
      ),
    );
  }

  /// 人机对战的走子提示：浅层搜索，不引入随机性，返回编码后的着法。
  static Future<int?> hintMove(Uint8List cells, int side) async {
    const limits = kIsWeb
        ? (depth: 2, timeLimitMillis: 350)
        : (depth: 3, timeLimitMillis: 800);
    final reply = await compute(
      _runSearch,
      _AiRequest(
        Uint8List.fromList(cells),
        side,
        limits.depth,
        0,
        limits.timeLimitMillis,
      ),
    );
    return reply.move >= 0 ? reply.move : null;
  }

  /// 实际搜索深度与时限。Web 端算力有限且同线程执行，深度与时限都压一档，
  /// 避免界面长时间无响应。
  static ({int depth, int timeLimitMillis}) _limitsFor(Difficulty difficulty) {
    if (!kIsWeb) {
      return (
        depth: difficulty.depth,
        timeLimitMillis: difficulty.timeLimitMillis,
      );
    }
    return (
      depth: difficulty.depth <= 1 ? 1 : difficulty.depth - 1,
      timeLimitMillis: min(difficulty.timeLimitMillis, 900),
    );
  }
}

class _AiRequest {
  const _AiRequest(
    this.cells,
    this.side,
    this.depth,
    this.randomness,
    this.timeLimitMillis,
  );

  final Uint8List cells;
  final int side;
  final int depth;
  final int randomness;
  final int timeLimitMillis;
}

SearchResult _runSearch(_AiRequest request) => XiangqiSearch.bestMove(
  cells: request.cells,
  side: request.side,
  depth: request.depth,
  randomness: request.randomness,
  timeLimitMillis: request.timeLimitMillis,
);

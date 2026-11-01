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

/// 一次 AI 搜索的摘要，供界面展示引擎状态。
class AiInsight {
  const AiInsight({
    required this.depth,
    required this.nodes,
    required this.score,
    required this.millis,
  });

  /// 实际完成的搜索层数。
  final int depth;
  final int nodes;
  final int score;
  final int millis;

  /// 状态条上的紧凑文案，例如 `AI 第 5 层 · 1.8s`。
  String get label => 'AI 第 $depth 层 · ${(millis / 1000).toStringAsFixed(1)}s';
}

class AiPlayer {
  AiPlayer._();

  /// 在独立 isolate 中搜索（Web 上自动退化为同线程执行）。
  static Future<AiReply> chooseMove(
    Uint8List cells,
    int side,
    Difficulty difficulty,
  ) {
    final request = _AiRequest(
      Uint8List.fromList(cells),
      side,
      _effectiveDepth(difficulty),
      difficulty.randomness,
      _effectiveTimeLimit(difficulty),
    );
    return compute(_runSearch, request);
  }

  /// Web 端算力有限，适当降低搜索深度，避免界面长时间无响应。
  static int _effectiveDepth(Difficulty difficulty) {
    if (!kIsWeb) return difficulty.depth;
    return difficulty.depth <= 1 ? 1 : difficulty.depth - 1;
  }

  /// Web 端同线程搜索，思考时限再压一档。
  static int _effectiveTimeLimit(Difficulty difficulty) {
    if (!kIsWeb) return difficulty.timeLimitMillis;
    return min(difficulty.timeLimitMillis, 2000);
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

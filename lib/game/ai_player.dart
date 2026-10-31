import 'package:flutter/foundation.dart';

import '../models/game_models.dart';
import 'engine/search.dart';

/// 一次 AI 搜索的结果，供控制器记录日志。
class AiReply {
  const AiReply({
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

typedef AiMoveProvider = Future<AiReply> Function(
  Uint8List cells,
  int side,
  Difficulty difficulty,
);

class AiPlayer {
  AiPlayer._();

  /// 在独立 isolate 中搜索（Web 上自动退化为同线程执行）。
  static Future<AiReply> chooseMove(
    Uint8List cells,
    int side,
    Difficulty difficulty,
  ) async {
    final request = _AiRequest(
      Uint8List.fromList(cells),
      side,
      _effectiveDepth(difficulty),
      difficulty.randomness,
    );
    return compute(_runSearch, request);
  }

  /// Web 端算力有限，适当降低搜索深度，避免界面长时间无响应。
  static int _effectiveDepth(Difficulty difficulty) {
    if (!kIsWeb) return difficulty.depth;
    return difficulty.depth <= 1 ? 1 : difficulty.depth - 1;
  }
}

class _AiRequest {
  const _AiRequest(this.cells, this.side, this.depth, this.randomness);

  final Uint8List cells;
  final int side;
  final int depth;
  final int randomness;
}

AiReply _runSearch(_AiRequest request) {
  final result = XiangqiSearch.bestMove(
    cells: request.cells,
    side: request.side,
    depth: request.depth,
    randomness: request.randomness,
  );
  return AiReply(
    move: result.move,
    score: result.score,
    nodes: result.nodes,
    depth: result.depth,
  );
}

/// 供界面显示 AI 搜索深度。
int effectiveDepthFor(Difficulty difficulty) =>
    AiPlayer._effectiveDepth(difficulty);

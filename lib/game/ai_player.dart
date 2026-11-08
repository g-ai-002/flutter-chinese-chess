import 'dart:async';
import 'dart:isolate';

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

  /// 实际搜索深度与时限：三端使用同一套难度参数，Web 不再降档。
  @visibleForTesting
  static ({int depth, int timeLimitMillis}) limitsFor(Difficulty difficulty) =>
      (depth: difficulty.depth, timeLimitMillis: difficulty.timeLimitMillis);
}

/// AI 搜索被取消（对局页已关闭）时抛出，调用方直接忽略即可。
class AiSearchCancelled implements Exception {
  const AiSearchCancelled();

  @override
  String toString() => 'AI 搜索已取消';
}

/// 可取消的 AI 搜索：在独立 isolate 中计算，离开对局页时立即回收，
/// 不会让一次思考在后台残留。
class AiSearch {
  Isolate? _isolate;
  ReceivePort? _port;
  final Completer<void> _cancelled = Completer<void>();
  bool _closed = false;

  Future<AiReply> chooseMove(Uint8List cells, int side, Difficulty difficulty) {
    final limits = AiPlayer.limitsFor(difficulty);
    return _run(
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
  Future<int?> hintMove(Uint8List cells, int side) async {
    final reply = await _run(
      _AiRequest(Uint8List.fromList(cells), side, 3, 0, 800),
    );
    return reply.move >= 0 ? reply.move : null;
  }

  /// 结束在途搜索并立即回收 isolate。
  void cancel() {
    _closed = true;
    if (!_cancelled.isCompleted) _cancelled.complete();
    _kill();
  }

  Future<AiReply> _run(_AiRequest request) async {
    if (_closed) throw const AiSearchCancelled();
    if (kIsWeb) return _search(request);
    final port = ReceivePort();
    final pending = Completer<AiReply>();
    _port = port;
    port.listen((message) {
      if (pending.isCompleted) return;
      if (message is SearchResult) {
        pending.complete(message);
      } else {
        pending.completeError(StateError('AI 搜索失败: $message'));
      }
    });
    _isolate = await Isolate.spawn(searchInIsolate, (
      request,
      port.sendPort,
    ), onError: port.sendPort);
    if (_closed) {
      _kill();
      throw const AiSearchCancelled();
    }
    try {
      // 与取消信号赛跑：页面关闭后立刻返回，不等 isolate 跑完。
      return await Future.any([
        pending.future,
        _cancelled.future.then<AiReply>((_) => throw const AiSearchCancelled()),
      ]);
    } finally {
      _kill();
    }
  }

  void _kill() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
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

/// 隔离区入口：跑完搜索后把结果发回主 isolate。
void searchInIsolate((_AiRequest, SendPort) message) {
  final (request, send) = message;
  send.send(_search(request));
}

SearchResult _search(_AiRequest request) => XiangqiSearch.bestMove(
  cells: request.cells,
  side: request.side,
  depth: request.depth,
  randomness: request.randomness,
  timeLimitMillis: request.timeLimitMillis,
);

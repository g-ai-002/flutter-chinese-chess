import 'dart:typed_data';

import 'mate_score.dart';

/// 置换表条目：缓存层数、分数、边界类型与最优着法。
///
/// [score] 已按查询时传入的层数还原，可直接当作当前节点的分数使用。
typedef TtEntry = ({int depth, int score, int move, int bound});

/// 置换表：缓存搜索结果，供重复局面直接取分并复用最优着法。
///
/// 采用定长散列槽（键值同槽覆盖），同槽已有更深条目时保留原条目。
/// 局面键由低半 + 高半两个 32 位哈希组成，两半都匹配才算命中。
/// 这里只负责存取，能否用于裁剪由搜索方判断；
/// 杀棋分数按层数归一化（存 `分数 + 层数`，取 `分数 - 层数`），
/// 让同一局面在不同搜索深度下都能复用。
class TranspositionTable {
  TranspositionTable({int size = 1 << 16})
    : assert(size > 0 && (size & (size - 1)) == 0, '槽位数需为 2 的幂'),
      _mask = size - 1,
      _keys = Uint32List(size),
      _checks = Uint32List(size),
      _flags = Uint8List(size),
      _depths = Uint8List(size),
      _scores = Int32List(size),
      _moves = Int32List(size);

  /// 分数为精确值。
  static const int exact = 1;

  /// 分数为下界（发生 beta 截断）。
  static const int lower = 2;

  /// 分数为上界（未超过原有 alpha）。
  static const int upper = 3;

  final int _mask;
  final Uint32List _keys;
  final Uint32List _checks;
  final Uint8List _flags;
  final Uint8List _depths;
  final Int32List _scores;
  final Int32List _moves;

  /// 查询局面，未命中返回 null。
  TtEntry? lookup(int low, int high, int ply) {
    final slot = low & _mask;
    final flag = _flags[slot];
    if (flag == 0 || _keys[slot] != low || _checks[slot] != high) return null;
    return (
      depth: _depths[slot],
      score: MateScore.fromStored(_scores[slot], ply),
      move: _moves[slot],
      bound: flag,
    );
  }

  /// 写入搜索结果；[bound] 取 [exact] / [lower] / [upper]。
  void store({
    required int low,
    required int high,
    required int ply,
    required int depth,
    required int score,
    required int bound,
    required int move,
  }) {
    final slot = low & _mask;
    if (_flags[slot] != 0 &&
        _keys[slot] == low &&
        _checks[slot] == high &&
        _depths[slot] > depth) {
      // 同局面已有更深的结果，只补一个更优着法供排序使用。
      if (move >= 0) _moves[slot] = move;
      return;
    }
    _keys[slot] = low;
    _checks[slot] = high;
    _flags[slot] = bound;
    _depths[slot] = depth > 255 ? 255 : depth;
    _scores[slot] = MateScore.toStored(score, ply);
    _moves[slot] = move;
  }
}

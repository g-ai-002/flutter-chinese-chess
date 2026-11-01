import 'dart:typed_data';

/// 置换表：缓存搜索结果，供重复局面直接取分并复用最优着法。
///
/// 采用定长散列槽（键值同槽覆盖），同槽已有更深条目时保留原条目。
/// 局面键由低半 + 高半两个 32 位哈希组成，两半都匹配才算命中。
/// 分数按杀棋距离归一化（存 `分数 + 层数`，取 `分数 - 层数`），
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

  static const int _mateThreshold = 999000;

  final int _mask;
  final Uint32List _keys;
  final Uint32List _checks;
  final Uint8List _flags;
  final Uint8List _depths;
  final Int32List _scores;
  final Int32List _moves;

  int _hitScore = 0;
  int _bestMove = -1;

  /// 最近一次 [probe] 命中时的条目着法，未命中为 -1。
  int get bestMove => _bestMove;

  /// 最近一次 [probe] 命中时的分数（已按当前层数还原）。
  int get score => _hitScore;

  /// 查询局面，命中且可直接用于裁剪时返回 true，结果见 [score]。
  /// 无论是否可用于裁剪，命中时 [bestMove] 都会填上条目着法。
  bool probe(int low, int high, int depth, int alpha, int beta, int ply) {
    _bestMove = -1;
    final slot = low & _mask;
    final flag = _flags[slot];
    if (flag == 0 || _keys[slot] != low || _checks[slot] != high) return false;
    _bestMove = _moves[slot];
    if (_depths[slot] < depth) return false;

    final value = _fromStored(_scores[slot], ply);
    if (flag == lower && value < beta) return false;
    if (flag == upper && value > alpha) return false;
    _hitScore = value;
    return true;
  }

  /// 写入搜索结果；[flag] 取 [exact] / [lower] / [upper]。
  void store(
    int low,
    int high,
    int depth,
    int score,
    int flag,
    int move,
    int ply,
  ) {
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
    _flags[slot] = flag;
    _depths[slot] = depth > 255 ? 255 : depth;
    _scores[slot] = _toStored(score, ply);
    _moves[slot] = move;
  }

  static int _toStored(int score, int ply) {
    if (score > _mateThreshold) return score + ply;
    if (score < -_mateThreshold) return score - ply;
    return score;
  }

  static int _fromStored(int score, int ply) {
    if (score > _mateThreshold) return score - ply;
    if (score < -_mateThreshold) return score + ply;
    return score;
  }
}

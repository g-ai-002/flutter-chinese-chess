import 'dart:math';
import 'dart:typed_data';

import 'board_utils.dart';

/// 局面哈希（Zobrist）：每个棋子与格子的组合各有一个随机键，异或即得局面键。
///
/// 键在进程内固定生成，只用于同一次搜索内的置换表比对，不落盘。
/// 低半与高半各用一组独立随机键，置换表同时校验两半，
/// 把 32 位哈希的碰撞概率压到可忽略。
class Zobrist {
  Zobrist._();

  static final Uint32List _low = _buildKeys(0x5F3759DF);
  static final Uint32List _high = _buildKeys(0x2545F491);
  static final int _sideLow = _nextKey(Random(0x9E3779B9));
  static final int _sideHigh = _nextKey(Random(0x6A09E667));

  static Uint32List _buildKeys(int seed) {
    final random = Random(seed);
    final keys = Uint32List(16 * cellCount);
    for (var index = 0; index < keys.length; index++) {
      keys[index] = _nextKey(random);
    }
    return keys;
  }

  static int _nextKey(Random random) => random.nextInt(1 << 32);

  /// 指定棋子落在指定格子上的低半键。
  static int lowKey(int piece, int cell) => _low[piece * cellCount + cell];

  /// 指定棋子落在指定格子上的高半键，仅用于校验。
  static int highKey(int piece, int cell) => _high[piece * cellCount + cell];

  /// 行棋方低半键：切换行棋方时异或一次。
  static int get sideLowKey => _sideLow;

  /// 行棋方高半键。
  static int get sideHighKey => _sideHigh;

  /// 由棋盘与行棋方计算局面键，搜索开始时调用一次，其后增量维护。
  static ({int low, int high}) hashOf(Uint8List cells, int side) {
    var low = side == red ? 0 : _sideLow;
    var high = side == red ? 0 : _sideHigh;
    for (var index = 0; index < cellCount; index++) {
      final piece = cells[index];
      if (piece == 0) continue;
      low ^= lowKey(piece, index);
      high ^= highKey(piece, index);
    }
    return (low: low, high: high);
  }
}

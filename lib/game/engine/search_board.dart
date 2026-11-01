import 'dart:typed_data';

import 'board_utils.dart';
import 'rules.dart';
import 'zobrist.dart';

/// 搜索用棋盘：局面、行棋方与增量维护的局面键。
///
/// 搜索只做「试着走一步、再走回去」，[make] / [unmake] 成对调用即可，
/// 被吃子记录在内部撤销栈里，不必回传给调用方；局面键同步增删，
/// 与 [Zobrist.hashOf] 在根节点算出的键保持一致。
class SearchBoard {
  SearchBoard(Uint8List cells, int side)
    : cells = Uint8List.fromList(cells),
      sideToMove = side {
    final hash = Zobrist.hashOf(this.cells, side);
    _low = hash.low;
    _high = hash.high;
  }

  /// 撤销栈初始容量，够覆盖「搜索层数 + 静态搜索层数」。
  static const int _initialStack = 64;

  final Uint8List cells;
  int sideToMove;

  late int _low;
  late int _high;

  Int32List _undoMoves = Int32List(_initialStack);
  Int32List _undoCaptured = Int32List(_initialStack);
  int _depth = 0;

  /// 局面键低半，供置换表索引。
  int get hashLow => _low;

  /// 局面键高半，供置换表校验。
  int get hashHigh => _high;

  /// 已试走的步数，撤销回零即回到构造时的局面。
  int get depth => _depth;

  /// 试走着法，返回被吃的棋子（空位为 0）。
  int make(int move) {
    final from = moveFrom(move);
    final to = moveTo(move);
    final piece = cells[from];
    final captured = cells[to];
    _low ^= Zobrist.lowKey(piece, from) ^ Zobrist.lowKey(piece, to);
    _high ^= Zobrist.highKey(piece, from) ^ Zobrist.highKey(piece, to);
    if (captured != 0) {
      _low ^= Zobrist.lowKey(captured, to);
      _high ^= Zobrist.highKey(captured, to);
    }
    _low ^= Zobrist.sideLowKey;
    _high ^= Zobrist.sideHighKey;
    cells[to] = piece;
    cells[from] = 0;
    sideToMove = opponentOf(sideOf(piece));
    _push(move, captured);
    return captured;
  }

  /// 撤销最近一次 [make]；撤销栈为空时抛出 [StateError]。
  void unmake() {
    if (_depth == 0) throw StateError('撤销栈为空，没有可撤销的落子');
    _depth--;
    final move = _undoMoves[_depth];
    final captured = _undoCaptured[_depth];
    final from = moveFrom(move);
    final to = moveTo(move);
    final piece = cells[to];
    _low ^= Zobrist.sideLowKey;
    _high ^= Zobrist.sideHighKey;
    _low ^= Zobrist.lowKey(piece, from) ^ Zobrist.lowKey(piece, to);
    _high ^= Zobrist.highKey(piece, from) ^ Zobrist.highKey(piece, to);
    if (captured != 0) {
      _low ^= Zobrist.lowKey(captured, to);
      _high ^= Zobrist.highKey(captured, to);
    }
    cells[from] = piece;
    cells[to] = captured;
    sideToMove = opponentOf(sideToMove);
  }

  void _push(int move, int captured) {
    if (_depth == _undoMoves.length) _growStack();
    _undoMoves[_depth] = move;
    _undoCaptured[_depth] = captured;
    _depth++;
  }

  /// 搜索极少超过初始容量，真遇到深局面时翻倍扩容。
  void _growStack() {
    final size = _undoMoves.length * 2;
    _undoMoves = Int32List(size)..setRange(0, _depth, _undoMoves);
    _undoCaptured = Int32List(size)..setRange(0, _depth, _undoCaptured);
  }
}

import 'package:flutter/foundation.dart';

import '../models/move_record.dart';
import 'board_state.dart';
import 'board_view.dart';
import 'engine/board_utils.dart';
import 'engine/rules.dart';

/// 复盘控制器：按步回放一局棋谱，棋盘从开局局面逐着重演。
class ReplayController extends ChangeNotifier implements BoardView {
  ReplayController({
    required List<MoveRecord> moves,
    required this.layout,
    this.startSide = red,
  }) : moves = List.unmodifiable(moves) {
    _validateAll();
    _board = _build(0);
  }

  /// 开局布局（十行），用于重建每一步的局面。
  final List<String> layout;
  final int startSide;

  /// 完整棋谱，超出当前进度的部分视为「未来」。
  final List<MoveRecord> moves;

  late XiangqiBoard _board;
  int _cursor = 0;

  @override
  XiangqiBoard get board => _board;

  @override
  int? get selected => null;

  @override
  List<int> get legalTargets => const [];

  @override
  bool get showHints => false;

  @override
  bool get inCheck =>
      XiangqiRules.isKingInCheck(_board.cells, _board.sideToMove);

  @override
  List<MoveRecord> get history => _board.history;

  int get cursor => _cursor;

  int get total => moves.length;

  bool get canPrevious => _cursor > 0;

  bool get canNext => _cursor < moves.length;

  /// 自动回放是否已到终局。
  bool get finished => !canNext;

  String get progressText => '第 $_cursor / $total 手';

  void next() => jumpTo(_cursor + 1);

  void previous() => jumpTo(_cursor - 1);

  void first() => jumpTo(0);

  void last() => jumpTo(moves.length);

  /// 跳到第 [cursor] 手之后（0 为开局局面），越界时自动收敛。
  void jumpTo(int cursor) {
    final target = cursor.clamp(0, moves.length);
    if (target == _cursor) return;
    _board = _build(target);
    _cursor = target;
    notifyListeners();
  }

  @override
  void tapCell(int index) {}

  XiangqiBoard _build(int cursor) {
    final board = XiangqiBoard.fromLayout(layout, sideToMove: startSide);
    for (var index = 0; index < cursor; index++) {
      _applyTo(board, index);
    }
    return board;
  }

  /// 构造时整体校验一遍，非法棋谱在进入复盘页前就暴露出来。
  void _validateAll() {
    final board = XiangqiBoard.fromLayout(layout, sideToMove: startSide);
    for (var index = 0; index < moves.length; index++) {
      _applyTo(board, index);
    }
  }

  void _applyTo(XiangqiBoard board, int index) {
    final record = moves[index];
    if (!XiangqiRules.isPlayable(
      board.cells,
      board.sideToMove,
      record.from,
      record.to,
    )) {
      throw ArgumentError('第 ${index + 1} 手「${record.notation}」不是合法着法');
    }
    board.applyMove(record.from, record.to);
  }
}

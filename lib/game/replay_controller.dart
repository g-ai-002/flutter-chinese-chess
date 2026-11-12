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
    _validate();
    _board = _initialBoard();
    _refreshCheck();
  }

  /// 开局布局（十行），用于重建每一步的局面。
  final List<String> layout;
  final int startSide;

  /// 完整棋谱，超出当前进度的部分视为「未来」。
  final List<MoveRecord> moves;

  late XiangqiBoard _board;
  int _cursor = 0;
  bool _inCheck = false;

  @override
  XiangqiBoard get board => _board;

  @override
  int? get selected => null;

  @override
  List<int> get legalTargets => const [];

  @override
  bool get showHints => false;

  /// 棋盘逐帧读取将军状态，缓存在跳转时算好，避免每帧扫描整盘。
  @override
  bool get inCheck => _inCheck;

  @override
  int? get hintFrom => null;

  @override
  int? get hintTo => null;

  @override
  List<MoveRecord> get history => _board.history;

  int get cursor => _cursor;

  int get total => moves.length;

  /// 每手棋前停顿 0.32 秒：先在起点高亮将要走动的棋子，棋子不再突然起走。
  @override
  Duration get moveLeadIn => const Duration(milliseconds: 320);

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
  ///
  /// 前进沿当前局面续走，后退时回到开局重演，避免每步都从头构建。
  void jumpTo(int cursor) {
    final target = cursor.clamp(0, moves.length);
    if (target == _cursor) return;
    if (target < _cursor) {
      _board = _initialBoard();
      _cursor = 0;
    }
    while (_cursor < target) {
      _applyTo(_board, _cursor);
      _cursor++;
    }
    _refreshCheck();
    notifyListeners();
  }

  void _refreshCheck() {
    _inCheck = XiangqiRules.isKingInCheck(_board.cells, _board.sideToMove);
  }

  @override
  void tapCell(int index) {}

  XiangqiBoard _initialBoard() =>
      XiangqiBoard.fromLayout(layout, sideToMove: startSide);

  /// 构造时整体校验一遍，非法棋谱在进入复盘页前就暴露出来。
  void _validate() {
    final board = _initialBoard();
    for (var index = 0; index < moves.length; index++) {
      _applyTo(board, index);
    }
  }

  void _applyTo(XiangqiBoard board, int index) {
    final record = moves[index];
    if (board.tryApply(record.from, record.to) == null) {
      throw ArgumentError('第 ${index + 1} 手「${record.notation}」不是合法着法');
    }
  }
}

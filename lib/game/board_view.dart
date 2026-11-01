import '../models/move_record.dart';
import 'board_state.dart';

/// 棋盘组件所需的只读视图，对局与复盘共用同一套 Flame 渲染。
abstract class BoardView {
  XiangqiBoard get board;

  int? get selected;

  List<int> get legalTargets;

  bool get showHints;

  bool get inCheck;

  List<MoveRecord> get history;

  void tapCell(int index);
}

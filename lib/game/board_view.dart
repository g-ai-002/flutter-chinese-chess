import '../models/move_record.dart';
import 'board_state.dart';

/// 棋盘组件所需的只读视图，对局与复盘共用同一套 Flame 渲染。
abstract class BoardView {
  XiangqiBoard get board;

  int? get selected;

  List<int> get legalTargets;

  bool get showHints;

  bool get inCheck;

  /// 当前展示的走子提示，起止索引为空时不画箭头。
  int? get hintFrom;

  int? get hintTo;

  List<MoveRecord> get history;

  /// 落子动画开始前的停顿：复盘时先停一下并高亮将要走动的棋子。
  Duration get moveLeadIn;

  void tapCell(int index);
}

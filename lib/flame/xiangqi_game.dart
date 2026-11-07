import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/board_view.dart';
import '../game/logic_rate.dart';
import '../theme/board_skin.dart';
import 'board_component.dart';

/// Flame 游戏入口：目前只有一个棋盘组件，后续可扩展落子特效与音效。
class XiangqiGame extends FlameGame {
  XiangqiGame({
    required this.view,
    BoardSkin skin = kDefaultBoardSkin,
    this.logicRate = LogicRate.hz60,
  }) : _skin = ValueNotifier(skin);

  final BoardView view;

  /// 棋盘逻辑更新速率，见 [LogicRate]。
  final LogicRate logicRate;
  final ValueNotifier<BoardSkin> _skin;
  BoardComponent? _board;

  /// 当前棋盘皮肤，赋值后棋盘按新配色重绘。
  BoardSkin get skin => _skin.value;
  set skin(BoardSkin value) => _skin.value = value;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final board = BoardComponent(view: view, skin: _skin, logicRate: logicRate);
    _board = board;
    _fit(board);
    await add(board);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final board = _board;
    if (board != null) _fit(board);
  }

  /// 棋盘始终铺满游戏区域，随窗口或屏幕尺寸变化重建尺寸。
  void _fit(BoardComponent board) {
    board
      ..size = size.clone()
      ..position = Vector2.zero();
  }
}

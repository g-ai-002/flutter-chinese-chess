import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/board_view.dart';
import 'board_component.dart';

/// Flame 游戏入口：目前只有一个棋盘组件，后续可扩展落子特效与音效。
class XiangqiGame extends FlameGame {
  XiangqiGame({required this.view});

  final BoardView view;
  BoardComponent? _board;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final board = BoardComponent(view: view);
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
